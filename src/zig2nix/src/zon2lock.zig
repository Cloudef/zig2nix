const std = @import("std");
const cli = @import("cli.zig");
const zon2json = @import("zon2json.zig");

fn assumeNext(scanner: anytype, comptime expected: std.json.TokenType) !std.meta.TagPayload(std.json.Token, @enumFromInt(@intFromEnum(expected))) {
    const tok = try scanner.next();
    switch (tok) {
        inline else => |_, tag| if (!std.mem.eql(u8, @tagName(tag), @tagName(expected))) {
            std.log.err("expected token: {s}, got: {s}", .{ @tagName(expected), @tagName(tag) });
            return error.UnexpectedJson;
        },
    }
    return @field(tok, @tagName(expected));
}

fn assumeNextAlloc(allocator: std.mem.Allocator, scanner: anytype, comptime expected: std.json.TokenType) !std.meta.TagPayload(std.json.Token, @enumFromInt(@intFromEnum(expected))) {
    const tok = try scanner.nextAlloc(allocator, .alloc_always);
    switch (tok) {
        inline else => |_, tag| if (!std.mem.eql(u8, @tagName(tag), @tagName(expected))) {
            if (expected == .string and tag == .allocated_string) return tok.allocated_string;
            std.log.err("expected token: {s}, got: {s}", .{ @tagName(expected), @tagName(tag) });
            return error.UnexpectedJson;
        },
    }
    return @field(tok, @tagName(expected));
}

pub const LockDependency = struct {
    name: []const u8,
    url: []const u8,
    hash: []const u8,
    rev: ?[]const u8 = null,
};

pub const Lock = struct {
    arena: ?std.heap.ArenaAllocator = null,
    map: std.StringArrayHashMapUnmanaged(LockDependency) = .{},

    pub fn cacheHit(self: @This(), zdep: ZonDependency) bool {
        const ldep = self.map.get(zdep.hash.?) orelse return false;
        return std.mem.eql(u8, ldep.url, zdep.url.?);
    }

    pub fn deinit(self: *@This()) void {
        if (self.arena) |a| a.deinit();
        self.* = undefined;
    }
};

pub fn parse(allocator: std.mem.Allocator, reader: anytype) !?Lock {
    var arena_state: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena_state.deinit();
    const arena = arena_state.allocator();

    var map: std.StringArrayHashMapUnmanaged(LockDependency) = .{};
    assumeNext(reader, .object_begin) catch |err| switch (err) {
        error.UnexpectedEndOfInput => return null,
        else => |e| return e,
    };

    const opts: std.json.ParseOptions = .{ .max_value_len = 4096, .allocate = .alloc_always };
    while (true) {
        if (try reader.peekNextTokenType() == .object_end) break;
        const zhash = try assumeNextAlloc(arena, reader, .string);
        const dep = try std.json.innerParse(LockDependency, arena, reader, opts);
        try map.putNoClobber(arena, zhash, dep);
    }
    try assumeNext(reader, .object_end);

    return .{ .arena = arena_state, .map = map };
}

pub fn parsePath(allocator: std.mem.Allocator, cwd: std.fs.Dir, path: []const u8) !?Lock {
    var file = try cwd.openFile(path, .{});
    defer file.close();
    var reader = std.json.reader(allocator, file.deprecatedReader());
    defer reader.deinit();
    return parse(allocator, &reader);
}

const ZonDependency = struct {
    url: ?[]const u8 = null,
    hash: ?[]const u8 = null,
    path: ?[]const u8 = null,
    lazy: bool = false,
};

const LockBuilderContext = struct {
    tmp: std.fs.Dir,
    zig_cache: std.fs.Dir,
    cwd: std.fs.Dir,
    path: []const u8,
    set: *std.StringHashMapUnmanaged(void),
    lock: ?Lock,
    is_root: bool,

    pub fn with(self: @This(), cwd: std.fs.Dir, path: []const u8) @This() {
        var cpy = self;
        cpy.cwd = cwd;
        cpy.path = path;
        cpy.is_root = false;
        return cpy;
    }
};

const NixFetchResult = struct {
    hash: []const u8,
    rev: ?[]const u8 = null,
};

fn nixFetchHttp(allocator: std.mem.Allocator, ctx: LockBuilderContext, zhash: []const u8, url: []const u8) !NixFetchResult {
    defer ctx.tmp.deleteFile(zhash) catch {};
    {
        var file = try ctx.tmp.createFile(zhash, .{});
        defer file.close();
        try cli.download(allocator, url, file.deprecatedWriter(), std.math.maxInt(usize));
    }
    return .{ .hash = try cli.run(allocator, ctx.tmp, &.{ "nix", "hash", "path", "--mode", "flat", zhash }, 128) };
}

fn gitPrefetch(allocator: std.mem.Allocator, cwd: std.fs.Dir, zhash: []const u8, url: []const u8, rev: []const u8) !NixFetchResult {
    const json = try cli.run(
        allocator,
        cwd,
        &.{ "nix-prefetch-git", "--out", zhash, "--url", url, "--rev", rev, "--no-deepClone", "--fetch-submodules", "--quiet" },
        4096,
    );
    defer cwd.deleteTree(zhash) catch {};
    const Result = struct { hash: []const u8, rev: []const u8 };
    const res = try std.json.parseFromSliceLeaky(Result, allocator, json, .{ .ignore_unknown_fields = true, .max_value_len = 128 });
    return .{ .hash = res.hash, .rev = res.rev };
}

fn gitResolveRev(allocator: std.mem.Allocator, url: []const u8, sha_tag_branch: []const u8) ![]const u8 {
    const is_sha: bool = D: {
        if (sha_tag_branch.len == 40) {
            for (sha_tag_branch) |chr| {
                if (!std.ascii.isAlphanumeric(chr)) {
                    break :D false;
                }
            }
            break :D true;
        }
        break :D false;
    };
    if (is_sha) return sha_tag_branch;
    const out = try cli.run(allocator, null, &.{ "git", "ls-remote", "--refs", "-tb", url, sha_tag_branch }, 4096);
    var iter = std.mem.tokenizeAny(u8, out, &std.ascii.whitespace);
    return iter.next() orelse return error.GitResolveShaFailed;
}

fn nixFetchGit(allocator: std.mem.Allocator, ctx: LockBuilderContext, zhash: []const u8, url: []const u8) !NixFetchResult {
    const base: []const u8 = D: {
        var iter = std.mem.tokenizeAny(u8, url, "?#");
        break :D iter.next() orelse return error.InvalidGitUrl;
    };

    const rev: []const u8 = D: {
        var iter = std.mem.tokenizeScalar(u8, url, '#');
        _ = iter.next() orelse return error.InvalidGitUrl;
        break :D try gitResolveRev(allocator, base, iter.rest());
    };

    return gitPrefetch(allocator, ctx.tmp, zhash, base, rev);
}

fn nixFetch(allocator: std.mem.Allocator, ctx: LockBuilderContext, zhash: []const u8, url: []const u8, stderr: anytype) !NixFetchResult {
    const Prefix = enum {
        @"git+http://",
        @"git+https://",
        @"http://",
        @"https://",
    };

    try stderr.print("fetching (nix hash): {s}\n", .{url});
    inline for (std.meta.fields(Prefix)) |field| {
        if (std.mem.startsWith(u8, url, field.name)) {
            return switch (@as(Prefix, @enumFromInt(field.value))) {
                .@"git+http://", .@"git+https://" => nixFetchGit(allocator, ctx, zhash, url[4..]),
                .@"http://", .@"https://" => nixFetchHttp(allocator, ctx, zhash, url),
            };
        }
    }

    return error.UnsupportedUrl;
}

fn zigFetch(allocator: std.mem.Allocator, zhash: []const u8, url: []const u8, stderr: anytype) !void {
    const zfhash = try cli.run(allocator, null, &.{ "zig", "fetch", url }, 128);
    defer allocator.free(zfhash);
    if (!std.mem.eql(u8, zhash, zfhash)) {
        try stderr.print("fetching (zig fetch): {s}\n", .{url});
        try stderr.print("unexpected zig hash for dependency\ngot: {s}\nexpected: {s}\n", .{
            zfhash,
            zhash,
        });
        return error.BrokenZigZonDependency;
    }
}

fn writeInner(arena: std.mem.Allocator, ctx: LockBuilderContext, writer: anytype, stderr: anytype) !void {
    var json: std.ArrayListUnmanaged(u8) = .{};
    defer json.deinit(arena);
    zon2json.parsePath(arena, ctx.cwd, ctx.path, json.writer(arena), stderr) catch |err| switch (err) {
        error.FileNotFound => |e| if (ctx.is_root) return e else return,
        else => |e| return e,
    };

    var scanner = std.json.Scanner.initCompleteInput(arena, json.items);
    defer scanner.deinit();

    try assumeNext(&scanner, .object_begin);
    while (true) {
        switch (try scanner.next()) {
            .string => |tok| if (std.mem.eql(u8, tok, "dependencies")) break,
            .end_of_document => return,
            else => {},
        }
    }

    const opts: std.json.ParseOptions = .{ .max_value_len = 4096, .allocate = .alloc_always, .ignore_unknown_fields = true };
    try assumeNext(&scanner, .object_begin);
    while (true) {
        if (try scanner.peekNextTokenType() == .object_end) break;
        const name = try assumeNextAlloc(arena, &scanner, .string);
        const dep = try std.json.innerParse(ZonDependency, arena, &scanner, opts);
        if (dep.hash) |hash| {
            const res = try ctx.set.getOrPut(arena, hash);
            if (res.found_existing) continue;
            if (ctx.zig_cache.access(hash, .{})) continue else |_| {}
            res.value_ptr.* = {};
            res.key_ptr.* = try arena.dupe(u8, res.key_ptr.*);
        }

        if (dep.url) |url| {
            const zhash = dep.hash orelse return error.ZigZonDepMissingAHash;

            var pdir = ctx.zig_cache.openDir("p", .{}) catch D: {
                try zigFetch(arena, zhash, url, stderr);
                break :D try ctx.zig_cache.openDir("p", .{});
            };
            defer pdir.close();

            var dir = pdir.openDir(zhash, .{}) catch D: {
                try zigFetch(arena, zhash, url, stderr);
                break :D try pdir.openDir(zhash, .{});
            };
            defer dir.close();

            const nix: NixFetchResult = D: {
                if (ctx.lock == null or !ctx.lock.?.cacheHit(dep)) {
                    break :D try nixFetch(arena, ctx, zhash, url, stderr);
                } else {
                    const cached = ctx.lock.?.map.get(zhash).?;
                    break :D .{ .hash = cached.hash, .rev = cached.rev };
                }
            };

            try writer.objectField(zhash);
            try writer.beginObject();
            try writer.objectField("name");
            try writer.write(name);
            try writer.objectField("url");
            try writer.write(url);
            try writer.objectField("hash");
            try writer.write(nix.hash);
            if (nix.rev) |rev| {
                try writer.objectField("rev");
                try writer.write(rev);
            }
            try writer.endObject();

            try writeInner(arena, ctx.with(dir, "build.zig.zon"), writer, stderr);
        }

        if (dep.path) |path| {
            var dir = try ctx.cwd.openDir(path, .{});
            defer dir.close();
            try writeInner(arena, ctx.with(dir, "build.zig.zon"), writer, stderr);
        }
    }

    try assumeNext(&scanner, .object_end);
}

fn openFileDir(cwd: std.fs.Dir, path: []const u8) !std.fs.Dir {
    const dname = std.fs.path.dirname(path) orelse return cwd;
    return cwd.openDir(dname, .{});
}

pub fn write(allocator: std.mem.Allocator, cwd: std.fs.Dir, path: []const u8, stdout: anytype, stderr: anytype) !void {
    var dir = try openFileDir(cwd, path);
    defer if (cwd.fd != dir.fd) dir.close();
    var arena_state: std.heap.ArenaAllocator = .init(allocator);
    defer arena_state.deinit();
    var env = try cli.fetchZigEnv(allocator);
    defer env.deinit();
    var tmp = try cli.mktemp("zig2nix_");
    defer tmp.close();
    var set: std.StringHashMapUnmanaged(void) = .{};
    var writer = std.json.writeStream(stdout, .{ .whitespace = .indent_2 });
    defer writer.deinit();
    try writer.beginObject();
    const lock_path = try std.fmt.allocPrint(arena_state.allocator(), "{s}2json-lock", .{path});
    var lock = parsePath(arena_state.allocator(), cwd, lock_path) catch |err| switch (err) {
        error.FileNotFound => null,
        else => |e| return e,
    };
    defer if (lock) |*lck| lck.deinit();
    try writeInner(arena_state.allocator(), .{
        .tmp = tmp.dir,
        .zig_cache = try cwd.makeOpenPath(env.value.global_cache_dir, .{ .no_follow = true }),
        .cwd = dir,
        .path = std.fs.path.basename(path),
        .set = &set,
        .lock = lock,
        .is_root = true,
    }, &writer, stderr);
    try writer.endObject();
}

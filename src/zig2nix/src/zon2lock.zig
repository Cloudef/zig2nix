const std = @import("std");
const cli = @import("cli.zig");
const zon2json = @import("zon2json.zig");

test {
    comptime {
        _ = Ignore;
    }
}

fn assumeNext(reader_or_scanner: anytype, comptime expected: std.json.TokenType) !std.meta.TagPayload(std.json.Token, @enumFromInt(@intFromEnum(expected))) {
    const tok = try reader_or_scanner.next();
    switch (tok) {
        inline else => |_, tag| if (!std.mem.eql(u8, @tagName(tag), @tagName(expected))) {
            std.log.err("expected token: {s}, got: {s}", .{ @tagName(expected), @tagName(tag) });
            return error.UnexpectedJson;
        },
    }
    return @field(tok, @tagName(expected));
}

fn assumeNextAlloc(allocator: std.mem.Allocator, reader_or_scanner: anytype, comptime expected: std.json.TokenType) !std.meta.TagPayload(std.json.Token, @enumFromInt(@intFromEnum(expected))) {
    const tok = try reader_or_scanner.nextAlloc(allocator, .alloc_always);
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

pub fn parse(allocator: std.mem.Allocator, reader: *std.json.Reader) !?Lock {
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
    var buf: [1024]u8 = undefined;
    var file_reader = file.reader(&buf);
    var reader = std.json.Reader.init(allocator, &file_reader.interface);
    defer reader.deinit();
    return parse(allocator, &reader);
}

const ZonDependency = struct {
    url: ?[]const u8 = null,
    hash: ?[]const u8 = null,
    path: ?[]const u8 = null,
    lazy: bool = false,
};

const Ignore = union(enum) {
    self,
    list: List,

    const empty: Ignore = .{ .list = .empty };

    fn parseList(arena: std.mem.Allocator, rd: *std.Io.Reader) !Ignore {
        var result: Ignore = .empty;
        while (try rd.takeDelimiter('\n')) |line| {
            var target: *Ignore = &result;

            var tokenizer: Tokenizer = .init(line);
            while (try tokenizer.next(arena)) |token| switch (token) {
                .identifier => |id| {
                    switch (target.*) {
                        .self => {},
                        .list => |*tl| {
                            const res = try tl.getOrPut(arena, id);
                            if (!res.found_existing) {
                                res.value_ptr.* = .empty;
                            }
                            target = res.value_ptr;
                        },
                    }
                },
            };

            if (target != &result and target.* == .list) {
                target.list.deinit(arena);
                target.* = .self;
            }
        }
        return result;
    }

    const List = std.StringHashMapUnmanaged(Ignore);

    const Token = union(enum) {
        identifier: []u8,
    };

    const Tokenizer = struct {
        buffer: []const u8,
        pos: usize,

        fn init(buffer: []const u8) Tokenizer {
            return .{ .buffer = buffer, .pos = 0 };
        }

        fn next(self: *Tokenizer, arena: std.mem.Allocator) !?Token {
            const State = enum {
                start,
                saw_at_sign,
                string_literal,
                string_literal_backslash,
                identifier,
                identifier_end,
            };
            const first = self.pos == 0;
            var beg = D: {
                while (self.pos < self.buffer.len and std.ascii.isWhitespace(self.buffer[self.pos])) {
                    self.pos += 1;
                }
                break :D self.pos;
            };

            const token: Token = state: switch (@as(State, .start)) {
                .start => {
                    if (self.pos >= self.buffer.len) return null;
                    switch (self.buffer[self.pos]) {
                        '#' => return if (first) null else error.ParseError,
                        '@' => continue :state .saw_at_sign,
                        'a'...'z', 'A'...'Z', '_' => continue :state .identifier,
                        else => return error.ParseError,
                    }
                },

                .saw_at_sign => {
                    self.pos += 1;
                    if (self.pos >= self.buffer.len) return error.ParseError;
                    switch (self.buffer[self.pos]) {
                        '"' => {
                            beg = self.pos;
                            continue :state .string_literal;
                        },
                        else => return error.ParseError,
                    }
                },

                .string_literal => {
                    self.pos += 1;
                    if (self.pos >= self.buffer.len) return error.ParseError;
                    switch (self.buffer[self.pos]) {
                        0, '\n', 0x01...0x09, 0x0b...0x1f, 0x7f => return error.ParseError,
                        '\\' => continue :state .string_literal_backslash,
                        '"' => {
                            self.pos += 1;
                            break :state .{
                                .identifier = try std.zig.string_literal.parseAlloc(
                                    arena,
                                    self.buffer[beg..self.pos],
                                ),
                            };
                        },
                        else => continue :state .string_literal,
                    }
                },

                .string_literal_backslash => {
                    self.pos += 1;
                    if (self.pos >= self.buffer.len) return error.ParseError;
                    switch (self.buffer[self.pos]) {
                        0, '\n' => return error.ParseError,
                        else => continue :state .string_literal,
                    }
                },

                .identifier => {
                    self.pos += 1;
                    if (self.pos >= self.buffer.len) continue :state .identifier_end;
                    switch (self.buffer[self.pos]) {
                        'a'...'z', 'A'...'Z', '0'...'9', '_' => continue :state .identifier,
                        '.', '#' => continue :state .identifier_end,
                        else => |c| if (std.ascii.isWhitespace(c))
                            continue :state .identifier_end
                        else
                            return error.ParseError,
                    }
                },

                .identifier_end => .{ .identifier = try arena.dupe(u8, self.buffer[beg..self.pos]) },
            };

            while (self.pos < self.buffer.len) {
                if (self.buffer[self.pos] == '.') {
                    self.pos += 1;
                    break;
                }
                if (self.buffer[self.pos] == '#') {
                    self.pos = self.buffer.len;
                    break;
                }
                if (!std.ascii.isWhitespace(self.buffer[self.pos]))
                    return error.ParseError;
                self.pos += 1;
            }

            return token;
        }
    };

    test parseList {
        var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
        defer arena_state.deinit();
        {
            _ = arena_state.reset(.retain_capacity);
            var rd = std.Io.Reader.fixed(
                \\# Testident lazy deps
                \\  testident
                \\
                \\a.b.c
                \\a.b ##comment
                \\x.y      # another comment
                \\x.@"z".c
                \\x.z
                \\x.x.a1
                \\x.x.b
            );
            const i: Ignore = try .parseList(arena_state.allocator(), &rd);
            try std.testing.expect(i == .list);
            try std.testing.expectEqual(3, i.list.count());

            const testident = i.list.get("testident") orelse return error.TestUnexpectedNull;
            try std.testing.expect(testident == .self);

            const a = i.list.get("a") orelse return error.TestUnexpectedNull;
            try std.testing.expect(a == .list);
            try std.testing.expectEqual(1, a.list.count());

            const a_b = a.list.get("b") orelse return error.TestUnexpectedNull;
            try std.testing.expect(a_b == .self);

            const x = i.list.get("x") orelse return error.TestUnexpectedNull;
            try std.testing.expect(x == .list);
            try std.testing.expectEqual(3, x.list.count());

            const x_y = x.list.get("y") orelse return error.TestUnexpectedNull;
            try std.testing.expect(x_y == .self);

            const x_z = x.list.get("z") orelse return error.TestUnexpectedNull;
            try std.testing.expect(x_z == .self);

            const x_x = x.list.get("x") orelse return error.TestUnexpectedNull;
            try std.testing.expect(x_x == .list);
            try std.testing.expectEqual(2, x_x.list.count());

            const x_x_a1 = x_x.list.get("a1") orelse return error.TestUnexpectedNull;
            try std.testing.expect(x_x_a1 == .self);

            const x_x_b = x_x.list.get("b") orelse return error.TestUnexpectedNull;
            try std.testing.expect(x_x_b == .self);
        }

        {
            _ = arena_state.reset(.retain_capacity);
            var rd = std.Io.Reader.fixed("# Comment only");
            const i: Ignore = try .parseList(arena_state.allocator(), &rd);
            try std.testing.expect(i == .list);
            try std.testing.expectEqual(0, i.list.count());
        }

        {
            _ = arena_state.reset(.retain_capacity);
            var rd = std.Io.Reader.fixed("*");
            try std.testing.expectError(error.ParseError, Ignore.parseList(arena_state.allocator(), &rd));
        }

        {
            _ = arena_state.reset(.retain_capacity);
            var rd = std.Io.Reader.fixed(
                \\# Testident lazy deps
                \\  testident.*
                \\
                \\a.b.c
                \\a.b.* ##comment
                \\x.y      # another comment
                \\x.@"z".c
                \\x.z
                \\x.*.a
                \\x.x.b
            );
            try std.testing.expectError(error.ParseError, Ignore.parseList(arena_state.allocator(), &rd));
        }

        {
            _ = arena_state.reset(.retain_capacity);
            var rd = std.Io.Reader.fixed("0.b.c");
            try std.testing.expectError(error.ParseError, Ignore.parseList(arena_state.allocator(), &rd));
        }
    }
};

const LockBuilderContext = struct {
    tmp: std.fs.Dir,
    zig_cache: std.fs.Dir,
    zig_version: std.SemanticVersion,
    cwd: std.fs.Dir,
    path: []const u8,
    set: *std.StringHashMapUnmanaged(void),
    ignore: *const Ignore,
    lock: ?Lock,
    is_root: bool,

    pub fn with(
        self: @This(),
        cwd: std.fs.Dir,
        path: []const u8,
        ignore: *const Ignore,
    ) @This() {
        var cpy = self;
        cpy.cwd = cwd;
        cpy.path = path;
        cpy.is_root = false;
        cpy.ignore = ignore;
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
        var buf: [1024]u8 = undefined;
        var file_writer = file.writer(&buf);
        try cli.download(allocator, url, &file_writer.interface);
        try file_writer.interface.flush();
    }
    return .{ .hash = try cli.run(allocator, ctx.tmp, &.{ "nix", "hash", "path", "--mode", "flat", zhash }) };
}

fn gitPrefetch(allocator: std.mem.Allocator, cwd: std.fs.Dir, zhash: []const u8, url: []const u8, rev: []const u8) !NixFetchResult {
    const json = try cli.run(
        allocator,
        cwd,
        &.{ "nix-prefetch-git", "--out", zhash, "--url", url, "--rev", rev, "--no-deepClone", "--quiet" },
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
    const out = try cli.run(allocator, null, &.{ "git", "ls-remote", "--refs", "-tb", url, sha_tag_branch });
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

fn nixFetch(allocator: std.mem.Allocator, ctx: LockBuilderContext, zhash: []const u8, url: []const u8, stderr: *std.Io.Writer) !NixFetchResult {
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

fn zigFetch(allocator: std.mem.Allocator, cwd: std.fs.Dir, zhash: []const u8, url: []const u8, stderr: *std.Io.Writer) !void {
    const zfhash = try cli.run(allocator, cwd, &.{ "zig", "fetch", url });
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

fn writeInner(arena: std.mem.Allocator, ctx: LockBuilderContext, writer: *std.json.Stringify, stderr: *std.Io.Writer) !void {
    const parent_ignore = ctx.ignore.*;
    var json = try std.Io.Writer.Allocating.initCapacity(arena, 1024);
    defer json.deinit();
    zon2json.parsePath(arena, ctx.cwd, ctx.path, &json.writer, stderr) catch |err| switch (err) {
        error.FileNotFound => |e| if (ctx.is_root) return e else return,
        else => |e| return e,
    };

    var scanner = std.json.Scanner.initCompleteInput(arena, try json.toOwnedSlice());
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
        const ignore: *const Ignore = switch (parent_ignore) {
            .self => unreachable,
            .list => |*l| l.getPtr(name) orelse &.empty,
        };
        if (ignore.* == .self) {
            if (!dep.lazy) {
                try stderr.print(
                    "error: Non-lazy dependency '{s}' ({s}) found in ignore list.\n",
                    .{ name, dep.hash orelse dep.path orelse "<unknown>" },
                );
                return error.NonLazyDepIgnored;
            }
            continue;
        }

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
                try zigFetch(arena, ctx.tmp, zhash, url, stderr);
                break :D try ctx.zig_cache.openDir("p", .{});
            };
            defer pdir.close();

            var dir: std.fs.Dir = DIR: {
                if (ctx.zig_version.minor >= 16) {
                    const tar_name = try std.fmt.allocPrint(arena, "{s}.tar.gz", .{zhash});
                    var tar = pdir.openFile(tar_name, .{}) catch D: {
                        try zigFetch(arena, ctx.tmp, zhash, url, stderr);
                        break :D try pdir.openFile(tar_name, .{});
                    };
                    tar.close();
                    // TODO: This is suboptimal, should extract the ^ tar
                    const dep_path = try std.fmt.allocPrint(arena, "zig-pkg/{s}", .{zhash});
                    break :DIR ctx.tmp.openDir(dep_path, .{}) catch D: {
                        try zigFetch(arena, ctx.tmp, zhash, url, stderr);
                        break :D try ctx.tmp.openDir(dep_path, .{});
                    };
                } else {
                    break :DIR pdir.openDir(zhash, .{}) catch D: {
                        try zigFetch(arena, ctx.tmp, zhash, url, stderr);
                        break :D try pdir.openDir(zhash, .{});
                    };
                }
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

            try writeInner(arena, ctx.with(dir, "build.zig.zon", ignore), writer, stderr);

            if (ctx.zig_version.minor >= 16) {
                const dep_path = try std.fmt.allocPrint(arena, "zig-pkg/{s}", .{zhash});
                dir.deleteTree(dep_path) catch @panic("deleteTree failed");
            }
        }

        if (dep.path) |path| {
            var dir = try ctx.cwd.openDir(path, .{});
            defer dir.close();
            try writeInner(arena, ctx.with(dir, "build.zig.zon", ignore), writer, stderr);
        }
    }

    try assumeNext(&scanner, .object_end);
}

fn openFileDir(cwd: std.fs.Dir, path: []const u8) !std.fs.Dir {
    const dname = std.fs.path.dirname(path) orelse return cwd;
    return cwd.openDir(dname, .{});
}

pub fn write(allocator: std.mem.Allocator, cwd: std.fs.Dir, path: []const u8, stdout: *std.Io.Writer, stderr: *std.Io.Writer) !void {
    var dir = try openFileDir(cwd, path);
    defer if (cwd.fd != dir.fd) dir.close();
    var arena_state: std.heap.ArenaAllocator = .init(allocator);
    defer arena_state.deinit();
    const ignore: Ignore = D: {
        var file = dir.openFile("zig2nix.ignore", .{}) catch |err| switch (err) {
            error.FileNotFound => break :D .empty,
            else => |e| return e,
        };
        defer file.close();
        var buf: [4096]u8 = undefined;
        var rd = file.reader(&buf);
        break :D try .parseList(arena_state.allocator(), &rd.interface);
    };

    var env = try cli.fetchZigEnv(allocator);
    defer env.deinit();
    const zig_version: std.SemanticVersion = try .parse(env.value.version);
    var tmp = try cli.mktemp("zig2nix_");
    defer tmp.close();

    if (zig_version.minor >= 16) {
        // workaround <https://codeberg.org/ziglang/zig/issues/31866>
        _ = tmp.dir.createFile("build.zig", .{}) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => |e| return e,
        };
    }

    var set: std.StringHashMapUnmanaged(void) = .{};
    var writer = std.json.Stringify{
        .writer = stdout,
        .options = .{ .whitespace = .indent_2 },
    };
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
        .zig_version = zig_version,
        .cwd = dir,
        .path = std.fs.path.basename(path),
        .set = &set,
        .ignore = &ignore,
        .lock = lock,
        .is_root = true,
    }, &writer, stderr);
    try writer.endObject();
}

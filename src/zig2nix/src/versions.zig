const std = @import("std");
const cli = @import("cli.zig");
const Target = @import("Target.zig");

const Meta = enum {
    version,
    date,
    docs,
    stdDocs,
    notes,
    machNominated,
    machDocs,
};

const Source = struct {
    tarball: []const u8,
    shasum: []const u8,
    size: u64,
};

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

pub fn write(allocator: std.mem.Allocator, json: []const u8, mirrorlist: []const u8, out: *std.Io.Writer) !void {
    var arena_state: std.heap.ArenaAllocator = .init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var scanner = std.json.Scanner.initCompleteInput(arena, json);
    defer scanner.deinit();

    var pipe = try cli.pipe(arena, null, &.{ "nixfmt", "-v" });
    defer pipe.deinit();
    var buf: [1024]u8 = undefined;
    var pipe_writer = pipe.writer(&buf);
    const writer = &pipe_writer.interface;

    try writer.writeAll(
        \\{
        \\  zigHook
        \\  , zigBin
        \\  , zigSrc
        \\  , fetchFromMirror
        \\  , llvmPackages_20
        \\  , llvmPackages_19
        \\  , llvmPackages_18
        \\}:
        \\
        \\let
        \\  bin = release: zigBin { inherit zigHook release fetchRelease; };
        \\  src = release: llvmPackages: zigSrc { inherit zigHook release fetchRelease llvmPackages; };
        \\
    );

    try writer.print(
        \\
        \\fetchRelease = fetchFromMirror {{
        \\  zigMirrors = ''{s}'';
        \\}};
        \\
    , .{mirrorlist});

    var releases: std.ArrayList([]const u8) = .empty;
    defer releases.deinit(arena);

    try assumeNext(&scanner, .object_begin);
    const opts: std.json.ParseOptions = .{ .max_value_len = 4096, .allocate = .alloc_always, .ignore_unknown_fields = true };
    while (true) {
        if (try scanner.peekNextTokenType() == .object_end) break;
        const release = try assumeNextAlloc(arena, &scanner, .string);
        const release_name = try arena.dupe(u8, release);
        std.mem.replaceScalar(u8, release_name, '.', '_');
        try releases.append(arena, release_name);
        try assumeNext(&scanner, .object_begin);
        try writer.print("\nmeta-{s} = {{\n", .{release_name});
        if (!std.mem.eql(u8, release, "master")) {
            try writer.print("version = \"{s}\";\n", .{release});
        }
        while (true) {
            if (try scanner.peekNextTokenType() == .object_end) break;
            const str_key = try assumeNextAlloc(arena, &scanner, .string);
            if (std.meta.stringToEnum(Meta, str_key)) |key| {
                if (!std.mem.eql(u8, release, "master") and key == .version) {
                    const value = try assumeNextAlloc(arena, &scanner, .string);
                    try writer.print("zigVersion = \"{s}\";\n", .{value});
                } else {
                    const value = try assumeNextAlloc(arena, &scanner, .string);
                    try writer.print("{s} = \"{s}\";\n", .{ str_key, value });
                }
            } else {
                if (std.json.innerParse(Source, arena, &scanner, opts)) |src| {
                    if (std.mem.eql(u8, str_key, "src") or
                        std.mem.eql(u8, str_key, "bootstrap"))
                    {
                        try writer.print("\n{s} = {{\n", .{str_key});
                    } else {
                        if (Target.parse(arena, str_key)) |target| {
                            try writer.print("\n{s} = {{\n", .{target.system});
                        } else |_| {
                            try writer.print("\n{s} = {{\n", .{str_key});
                        }
                    }

                    const slash = std.mem.lastIndexOfScalar(u8, src.tarball, '/') orelse 0;
                    const filename = if (src.tarball.len > slash) src.tarball[slash + 1 ..] else "";

                    try writer.print("filename = \"{s}\";\n", .{filename});
                    try writer.print("shasum = \"{s}\";\n", .{src.shasum});
                    try writer.print("size = {};\n", .{src.size});
                    try writer.writeAll("};\n");
                } else |_| {
                    // ignore
                }
            }
        }
        try writer.writeAll("};\n");
        try assumeNext(&scanner, .object_end);
        if (std.mem.eql(u8, release, "0.8.0")) break;
    }

    try writer.writeAll("in {\n");

    const latest: []const u8 = D: {
        for (releases.items) |rel| {
            if (std.mem.eql(u8, rel, "master")) continue;
            break :D rel;
        }
        return error.NoVersions;
    };

    const llvm = std.StaticStringMap([]const u8).initComptime(.{
        .{ "master", "llvmPackages_20" },
        .{ "0_15_1", "llvmPackages_20" },
        .{ "0_14_1", "llvmPackages_19" },
        .{ "0_14_0", "llvmPackages_19" },
        .{ "0_13_0", "llvmPackages_18" },
        // No longer maintained in nixpkgs
        // .{ "0_12_1", "llvmPackages_17" },
        // .{ "0_12_0", "llvmPackages_17" },
        // .{ "0_11_0", "llvmPackages_16" },
        // .{ "0_10_1", "llvmPackages_15" },
        // .{ "0_10_0", "llvmPackages_15" },
        // .{ "0_9_1", "llvmPackages_13" },
        // .{ "0_9_0", "llvmPackages_13" },
        // .{ "0_8_1", "llvmPackages_12" },
        // .{ "0_8_0", "llvmPackages_12" },
    });

    const default_llvm = llvm.get("master") orelse unreachable;

    try writer.print("latest = bin meta-{s};\n", .{latest});
    try writer.print("src-latest = src meta-{s} {s};\n", .{ latest, llvm.get(latest) orelse default_llvm });
    for (releases.items) |release| {
        if (std.mem.eql(u8, release, "master")) {
            try writer.print("{s} = bin meta-{s};\n", .{ release, release });
            if (llvm.get(release)) |llvm_pkg| {
                try writer.print("src-{s} = src meta-{s} {s};\n", .{ release, release, llvm_pkg });
            }
        } else if (std.mem.eql(u8, release, "latest")) {
            // ignore
        } else {
            try writer.print("\"{s}\" = bin meta-{s};\n", .{ release, release });
            if (llvm.get(release)) |llvm_pkg| {
                try writer.print("src-{s} = src meta-{s} {s};\n", .{ release, release, llvm_pkg });
            }
        }
    }

    try writer.writeAll("}");
    try writer.flush();

    pipe.close();

    var pipe_reader = pipe.reader(&buf);

    _ = pipe_reader.interface.streamDelimiter(out, 0) catch |err| switch (err) {
        error.EndOfStream => {},
        else => |e| return e,
    };

    return switch (try pipe.finish()) {
        .Exited => |status| switch (status) {
            0 => {},
            else => error.NixFmtFailed,
        },
        else => error.NixFmtFailed,
    };
}

const std = @import("std");
const cli = @import("cli.zig");
const Target = @import("Target.zig");

const Meta = enum {
    version,
    date,
    docs,
    stdDocs,
    notes,
};

const Source = struct {
    tarball: []const u8,
    shasum: []const u8,
    size: u64,

    pub fn write(self: @This(), writer: anytype) !void {
        inline for (std.meta.fields(@This())) |field| {
            switch (field.type) {
                []const u8 => try writer.print("{s} = \"{s}\";\n", .{ field.name, @field(self, field.name) }),
                else => try writer.print("{s} = {};\n", .{ field.name, @field(self, field.name) }),
            }
        }
    }
};

fn assumeNext(scanner: anytype, comptime expected: std.json.TokenType) !std.meta.TagPayload(std.json.Token, @enumFromInt(@intFromEnum(expected))) {
    const tok = try scanner.next();
    switch (tok) {
        inline else => |_, tag| if (!std.mem.eql(u8, @tagName(tag), @tagName(expected))) {
            std.log.err("expected token: {s}, got: {s}", .{@tagName(expected), @tagName(tag)});
            return error.UnexpectedJson;
        }
    }
    return @field(tok, @tagName(expected));
}

fn assumeNextAlloc(allocator: std.mem.Allocator, scanner: anytype, comptime expected: std.json.TokenType) !std.meta.TagPayload(std.json.Token, @enumFromInt(@intFromEnum(expected))) {
    const tok = try scanner.nextAlloc(allocator, .alloc_always);
    switch (tok) {
        inline else => |_, tag| if (!std.mem.eql(u8, @tagName(tag), @tagName(expected))) {
            if (expected == .string and tag == .allocated_string) return tok.allocated_string;
            std.log.err("expected token: {s}, got: {s}", .{@tagName(expected), @tagName(tag)});
            return error.UnexpectedJson;
        }
    }
    return @field(tok, @tagName(expected));
}

pub fn write(allocator: std.mem.Allocator, json: []const u8, out: anytype) !void {
    var arena_state: std.heap.ArenaAllocator = .init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var scanner = std.json.Scanner.initCompleteInput(arena, json);
    defer scanner.deinit();

    var pipe = try cli.pipe(arena, null, &.{ "nixfmt", "-v" });
    defer pipe.deinit();
    const writer = pipe.writer();

    try writer.writeAll(
        \\{
        \\  callPackage
        \\  , zigHook
        \\  , zigBin
        \\  , zigSrc
        \\}:
        \\
        \\let
        \\  bin = release: callPackage zigBin { inherit zigHook release; };
        \\  src = release: callPackage zigSrc { inherit zigHook release; };
        \\
    );

    var releases: std.ArrayListUnmanaged([]const u8) = .{};
    defer releases.deinit(arena);

    try assumeNext(&scanner, .object_begin);
    const opts: std.json.ParseOptions = .{ .max_value_len = 4096, .allocate = .alloc_always };
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
            if (std.meta.stringToEnum(Meta, str_key)) |_| {
                const value = try assumeNextAlloc(arena, &scanner, .string);
                try writer.print("{s} = \"{s}\";\n", .{ str_key, value });
            } else {
                const src = try std.json.innerParse(Source, arena, &scanner, opts);
                if (Target.parse(arena, str_key)) |target| {
                    try writer.print("\n{s} = {{\n", .{target.system});
                } else |_| {
                    try writer.print("\n{s} = {{\n", .{str_key});
                }
                try src.write(writer);
                try writer.writeAll("};\n");
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

    try writer.print("latest = bin meta-{s};\n", .{latest});
    for (releases.items) |release| {
        if (std.mem.eql(u8, release, "master")) {
            try writer.print("{s} = bin meta-{s};\n", .{ release, release });
        } else {
            try writer.print("\"{s}\" = bin meta-{s};\n", .{ release, release });
        }
        try writer.print("src-{s} = src meta-{s};\n", .{ release, release });
    }

    try writer.writeAll("}");

    pipe.close();
    pipe.reader().streamUntilDelimiter(out, 0, null) catch |err| switch (err) {
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

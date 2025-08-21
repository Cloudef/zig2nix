const std = @import("std");

const Debug = false;

fn stringifyFieldName(allocator: std.mem.Allocator, ast: std.zig.Ast, idx: std.zig.Ast.Node.Index) !?[]const u8 {
    if (ast.firstToken(idx) < 2) return null;
    const slice = ast.tokenSlice(ast.firstToken(idx) - 2);
    if (slice[0] == '@') {
        const v = try std.zig.string_literal.parseAlloc(allocator, slice[1..]);
        defer allocator.free(v);
        return try std.json.Stringify.valueAlloc(allocator, v, .{.whitespace = .indent_2});
    }
    return try std.json.Stringify.valueAlloc(allocator, slice, .{.whitespace = .indent_2});
}

fn stringifyValue(allocator: std.mem.Allocator, ast: std.zig.Ast, idx: std.zig.Ast.Node.Index) !?[]const u8 {
    const ridx = if (@typeInfo(@TypeOf(idx)) == .@"enum") @intFromEnum(idx) else idx;
    const slice = ast.tokenSlice(ast.nodes.items(.main_token)[ridx]);
    if (Debug) std.log.debug("value: {s}", .{slice});
    if (slice[0] == '\'') {
        switch (std.zig.parseCharLiteral(slice)) {
            .success => |v| return try std.json.Stringify.valueAlloc(allocator, v, .{.whitespace = .indent_2}),
            .failure => return error.parseCharLiteralFailed,
        }
    } else if (slice[0] == '"') {
        const v = try std.zig.string_literal.parseAlloc(allocator, slice);
        defer allocator.free(v);
        return try std.json.Stringify.valueAlloc(allocator, v, .{.whitespace = .indent_2});
    }
    if (std.mem.startsWith(u8, slice, "0x")) {
        return try std.fmt.allocPrint(allocator, "\"{s}\"", .{slice});
    }
    switch (std.zig.number_literal.parseNumberLiteral(slice)) {
        .int => |v| return try std.json.Stringify.valueAlloc(allocator, v, .{.whitespace = .indent_2}),
        .float => |v| return try std.json.Stringify.valueAlloc(allocator, v, .{.whitespace = .indent_2}),
        .big_int => |v| return try std.json.Stringify.valueAlloc(allocator, v, .{.whitespace = .indent_2}),
        .failure => {},
    }
    if (std.mem.eql(u8, slice, "true") or std.mem.eql(u8, slice, "false")) {
        return try allocator.dupe(u8, slice);
    }
    if (std.mem.eql(u8, slice, "null")) {
        return try allocator.dupe(u8, slice);
    }
    // literal
    return try std.json.Stringify.valueAlloc(allocator, slice, .{.whitespace = .indent_2});
}

fn stringify(allocator: std.mem.Allocator, writer: *std.Io.Writer, ast: std.zig.Ast, idx: std.zig.Ast.Node.Index, has_name: bool) !void {
    if (has_name) {
        if (try stringifyFieldName(allocator, ast, idx)) |name| {
            defer allocator.free(name);
            if (Debug) std.log.debug("field: {s}", .{name});
            try writer.print("{s}:", .{name});
        }
    }

    var buf: [2]std.zig.Ast.Node.Index = undefined;
    if (ast.fullStructInit(&buf, idx)) |v| {
        try writer.writeAll("{");
        for (v.ast.fields, 0..) |i, n| {
            try stringify(allocator, writer, ast, i, true);
            if (n + 1 != v.ast.fields.len) try writer.writeAll(",");
        }
        try writer.writeAll("}");
    } else if (ast.fullArrayInit(&buf, idx)) |v| {
        try writer.writeAll("[");
        for (v.ast.elements, 0..) |i, n| {
            try stringify(allocator, writer, ast, i, false);
            if (n + 1 != v.ast.elements.len) try writer.writeAll(",");
        }
        try writer.writeAll("]");
    } else if (try stringifyValue(allocator, ast, idx)) |v| {
        defer allocator.free(v);
        try writer.writeAll(v);
    } else {
        return error.UnknownType;
    }
}

pub const Options = struct {
    limit: usize = std.math.maxInt(usize),
    file_name: []const u8 = "build.zig.zon", // for errors
};

pub fn parse(allocator: std.mem.Allocator, reader: *std.Io.Reader, writer: *std.Io.Writer, error_writer: *std.Io.Writer, opts: Options) !void {
    var arena_state: std.heap.ArenaAllocator = .init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const zon: [:0]u8 = blk: {
        var w = try std.Io.Writer.Allocating.initCapacity(allocator, 1024);
        defer w.deinit();
        _ = try reader.streamRemaining(&w.writer);
        break :blk try w.toOwnedSliceSentinel(0);
    };
    defer allocator.free(zon);

    var ast = try std.zig.Ast.parse(arena, zon, .zon);

    if (ast.errors.len > 0) {
        if (@TypeOf(error_writer) != void) {
            for (ast.errors) |e| {
                const loc = ast.tokenLocation(ast.errorOffset(e), e.token);
                try error_writer.print("error: {s}:{}:{}: ", .{ opts.file_name, loc.line, loc.column });
                try ast.renderError(e, error_writer);
                try error_writer.writeAll("\n");
            }
        }
        return error.ParseFailed;
    }

    if (@hasField(std.zig.Ast.Node.Data, "lhs")) {
        try stringify(arena, writer, ast, ast.nodes.items(.data)[0].lhs, false);
    } else {
        try stringify(arena, writer, ast, ast.nodes.items(.data)[0].node, false);
    }
}

pub fn parsePath(allocator: std.mem.Allocator, cwd: std.fs.Dir, path: []const u8, writer: *std.Io.Writer, error_writer: *std.Io.Writer) !void {
    var file = try cwd.openFile(path, .{ .mode = .read_only });
    defer file.close();
    var buf: [1024]u8 = undefined;
    var file_reader = file.reader(&buf);
    try parse(allocator, &file_reader.interface, writer, error_writer, .{ .file_name = path });
}

pub fn parseFromSlice(allocator: std.mem.Allocator, slice: []const u8, writer: *std.Io.Writer, error_writer: *std.Io.Writer, opts: Options) !void {
    var stream = std.Io.Reader.fixed(slice);
    return parse(allocator, &stream, writer, error_writer, opts);
}

test {
    const allocator = std.testing.allocator;
    var json = try std.Io.Writer.Allocating.initCapacity(allocator, 1024);
    defer json.deinit();
    const zon =
        \\.{
        \\    .name = .fixture1,
        \\    .version = "0.0.1",
        \\    .paths = .{
        \\        "src",
        \\        "build.zig",
        \\        "build.zig.zon",
        \\    },
        \\    .dependencies = .{
        \\        .router = .{
        \\            .path = ".",
        \\        },
        \\        .getty = .{
        \\            .url = "https://github.com/getty-zig/getty/archive/cb007b8ed148510de71ccc52143343b2e11413ff.tar.gz",
        \\            .hash = "getty-0.4.0-AAAAAI4bCAAwD1LXWSkUZg7jyORh3HwQvUVwjrMt6w40",
        \\        },
        \\    },
        \\}
    ;
    try parseFromSlice(allocator, zon, &json.writer, undefined, .{});
    try std.testing.expectEqualStrings(
        \\{"name":"fixture1","version":"0.0.1","paths":["src","build.zig","build.zig.zon"],"dependencies":{"router":{"path":"."},"getty":{"url":"https://github.com/getty-zig/getty/archive/cb007b8ed148510de71ccc52143343b2e11413ff.tar.gz","hash":"getty-0.4.0-AAAAAI4bCAAwD1LXWSkUZg7jyORh3HwQvUVwjrMt6w40"}}}
    , json.written());
}

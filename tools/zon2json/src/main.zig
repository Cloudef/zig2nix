const std = @import("std");
const zon2json = @import("zon2json.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path: ?[]const u8 = blk: {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);
        if (args.len > 1) break :blk try allocator.dupe(u8, args[1]);
        break :blk null;
    };
    defer if (path) |p| allocator.free(p);

    var json = std.ArrayList(u8).init(allocator);
    defer json.deinit();

    const fname = path orelse "build.zig.zon";
    var file = try std.fs.cwd().openFile(fname, .{.mode = .read_only});
    defer file.close();

    try zon2json.parse(
        allocator,
        file.reader().any(),
        json.writer(),
        std.io.getStdErr().writer(),
        .{
            .file_name = fname
        }
    );

    try std.io.getStdOut().writer().writeAll(json.items);
}

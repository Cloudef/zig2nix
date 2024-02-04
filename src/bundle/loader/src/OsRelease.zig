const std = @import("std");

// Only because BoundedArray has no comptime len field or const
// and @sizeOf(bounded.buffer) apparently isn't comptime O_o
const bufsz = 4096;
bounded: std.BoundedArray(u8, bufsz) = .{},
bug_report_url: ?[]const u8 = null,
build_id: ?[]const u8 = null,
documentation_url: ?[]const u8 = null,
home_url: ?[]const u8 = null,
id: ?[]const u8 = null,
logo: ?[]const u8 = null,
name: ?[]const u8 = null,
pretty_name: ?[]const u8 = null,
support_url: ?[]const u8 = null,
version: ?[]const u8 = null,
version_codename: ?[]const u8 = null,
version_id: ?[]const u8 = null,

pub fn init() ?@This() {
    var this: @This() = .{};
    {
        const f = std.fs.openFileAbsolute("/etc/os-release", .{ .mode = .read_only }) catch return null;
        defer f.close();
        f.reader().readIntoBoundedBytes(bufsz, &this.bounded) catch return null;
    }
    var tokens = std.mem.splitAny(u8, this.bounded.constSlice(), "=\n");
    while (tokens.next()) |key| if (tokens.next()) |value| {
        inline for (std.meta.fields(@This())) |f| {
            if (comptime !std.mem.eql(u8, f.name, "bounded")) {
                comptime var upper: [f.name.len]u8 = undefined;
                _ = comptime std.ascii.upperString(&upper, f.name);
                if (std.mem.eql(u8, upper[0..], key)) {
                    const stripped = if (value.len > 0 and value[0] == '"') value[1 .. value.len - 1] else value;
                    @field(this, f.name) = stripped;
                }
            }
        }
    };
    return this;
}

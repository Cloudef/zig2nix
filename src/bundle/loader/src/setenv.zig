const std = @import("std");
const builtin = @import("builtin");

const c = struct {
    extern fn setenv(key: [*:0]u8, value: [*:0]u8, overwrite: c_int) c_int;
};

pub fn setenv(key: []const u8, value: []const u8) !void {
    if (builtin.link_libc) {
        const allocator = std.heap.c_allocator;
        const c_key = try allocator.dupeZ(u8, key);
        defer allocator.free(c_key);
        const c_value = try allocator.dupeZ(u8, value);
        defer allocator.free(c_value);
        if (c.setenv(c_key, c_value, 1) != 0) {
            return error.SetEnvFailed;
        }
    } else {
        const allocator = std.heap.page_allocator;

        // Potential footgun here?
        // https://github.com/ziglang/zig/issues/4524
        const state = struct {
            var start: usize = 0;
            var end: usize = 0;
            var once = std.once(do_once);
            fn do_once() void {
                start = if (std.os.environ.len > 0) @intFromPtr(std.os.environ[0]) else 0;
                end = if (std.os.environ.len > 0) @intFromPtr(std.os.environ[std.os.environ.len - 1]) else start;
            }
        };
        state.once.call();

        var buf = try allocator.allocSentinel(u8, key.len + value.len + 1, 0);
        @memcpy(buf[0..key.len], key[0..]);
        buf[key.len] = '=';
        @memcpy(buf[key.len + 1 ..], value[0..]);

        for (std.os.environ) |*kv| {
            var token = std.mem.splitScalar(u8, std.mem.span(kv.*), '=');
            const env_key = token.first();

            if (std.mem.eql(u8, env_key, key)) {
                if (@intFromPtr(kv.*) < state.start or @intFromPtr(kv.*) > state.end) {
                    allocator.free(std.mem.span(kv.*));
                }
                kv.* = buf;
                return;
            }
        }

        if (!allocator.resize(std.os.environ, std.os.environ.len + 1)) {
            return error.SetEnvFailed;
        }

        std.os.environ[std.os.environ.len - 1] = buf;
    }
}

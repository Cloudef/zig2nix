const std = @import("std");
const builtin = @import("builtin");

const c = struct {
    extern fn setenv(key: [*:0]u8, value: [*:0]u8, overwrite: c_int) c_int;
    extern fn unsetenv(key: [*:0]u8) c_int;
};

pub const SetenvError = error{
    SetenvFailed,
};

// This keeps track of the env state in process to avoid double freeing stuff
// If some other parts in your code modifies `std.os.environ` then bad things can happen
// This is only used if not linked against libc
// Yes this is global, that's setenv for you
const env_state = struct {
    var allocator: std.mem.Allocator = std.heap.page_allocator;
    var start: usize = 0;
    var end: usize = 0;
    var original_envp: [][*:0]u8 = undefined;
    var allocated_envp: bool = false;
    var mutex: std.Thread.Mutex = .{};
    var once = std.once(do_once);

    fn do_once() void {
        start = if (std.os.environ.len > 0) @intFromPtr(std.os.environ[0]) else 0;
        end = if (std.os.environ.len > 0) @intFromPtr(std.os.environ[std.os.environ.len - 1]) else start;
        original_envp = std.os.environ;
    }

    fn resize_env(n: usize) bool {
        var newp = allocator.alloc([*:0]u8, n) catch return false;

        if (n >= std.os.environ.len) {
            for (std.os.environ, newp[0..std.os.environ.len]) |*old, *new| new.* = old.*;
        } else {
            for (std.os.environ[0..n], newp) |*old, *new| new.* = old.*;
        }

        if (allocated_envp) {
            allocator.free(std.os.environ);
        }

        std.os.environ = newp[0..n];
        allocated_envp = true;
        return true;
    }

    fn free_item(item: [*:0]u8) void {
        if (@intFromPtr(item) < start or @intFromPtr(item) > end) {
            allocator.free(std.mem.span(item));
        }
    }

    fn find_index(key: []const u8) ?usize {
        for (std.os.environ, 0..) |*kv, i| {
            var token = std.mem.splitScalar(u8, std.mem.span(kv.*), '=');
            const env_key = token.first();
            if (std.mem.eql(u8, env_key, key)) return i;
        }
        return null;
    }

    // only for tests
    fn reset_memory(free_items: bool) void {
        if (free_items) for (std.os.environ) |*kv| free_item(kv.*);
        if (env_state.allocated_envp) {
            env_state.allocator.free(std.os.environ);
        }

        env_state.allocated_envp = false;
        std.os.environ = original_envp;
    }
};

/// Calls either libc setenv / unsetenv or modifies std.os.environ on non-libc build
/// Returns `error.SetenvFailed` if there was error either calling the libc function
/// or reallocating memory failed.
pub fn setenv(key: []const u8, maybe_value: ?[]const u8) SetenvError!void {
    if (key.len == 0) {
        return error.SetenvFailed;
    }

    if (builtin.link_libc) {
        const allocator = std.heap.c_allocator;
        const c_key = try allocator.dupeZ(u8, key);
        defer allocator.free(c_key);
        if (maybe_value) |value| {
            const c_value = try allocator.dupeZ(u8, value);
            defer allocator.free(c_value);
            if (c.setenv(c_key, c_value, 1) != 0) {
                return error.SetenvFailed;
            }
        } else {
            if (c.unsetenv(c_key) != 0) {
                return error.SetenvFailed;
            }
        }
    } else {
        if (builtin.output_mode == .Lib) {
            @compileError(
                \\Subject: Apology for Miscommunication Regarding the Use of setenv in Library Development
                \\
                \\Dear [Developer's Name],
                \\
                \\I hope this message finds you well. I am writing to address an oversight on our part regarding the use of certain functions, specifically setenv, in library development. It has come to our attention that there may have been confusion regarding the appropriateness of calling setenv within libraries due to its implications on global variables such as _environ.
                \\
                \\Upon further review and consultation with our technical team, we have realized that allowing the usage of setenv in libraries poses inherent risks, particularly concerning the modification of global variables like _environ. While it may seem to work within the context of dynamically linked libraries such as libc, where internal states remain consistent due to centralized function calls, it can lead to unforeseen issues when multiple components within the same process attempt to modify this global state concurrently.
                \\
                \\The crux of the matter lies in the potential for double frees or heap corruption, which could arise from uncoordinated modifications to _environ. As a result, we must enforce a policy prohibiting the use of setenv within libraries to ensure the stability and reliability of our software ecosystem.
                \\
                \\We understand that this may inconvenience you and potentially require adjustments to your current development practices. We sincerely apologize for any confusion or frustration this may have caused. Our intention is to maintain the integrity and safety of our codebase, and we appreciate your cooperation in adhering to these guidelines.
                \\
                \\Moving forward, we will endeavor to provide clearer guidance and support to prevent similar misunderstandings. If you have any questions or concerns regarding this matter or require assistance in finding alternative approaches to achieve your development goals, please do not hesitate to reach out to us. Your feedback is invaluable in helping us improve our processes and communication.
                \\
                \\Once again, we apologize for any inconvenience and appreciate your understanding and cooperation in this matter.
                \\
                \\Thank you for your attention to this issue.
                \\
                \\Warm regards,
                \\[Your Name]
                \\[Your Position]
                \\[Your Contact Information]
                \\
                \\Btw, I originally planned for having a root option you could set to bypass this error, but it seems zig cannot expose `std.os.environ` in this scenario anyways.
                \\<https://github.com/ziglang/zig/issues/4524>
            );
        }

        // The simplified start logic doesn't populate environ.
        if (std.start.simplified_logic) {
            @compileError("ztd: setenv is unavailable with `std.start.simplified_logic`");
        }

        env_state.mutex.lock();
        defer env_state.mutex.unlock();
        env_state.once.call();
        const allocator = env_state.allocator;

        if (maybe_value) |value| {
            var buf = allocator.allocSentinel(u8, key.len + value.len + 1, 0) catch return error.SetenvFailed;
            @memcpy(buf[0..key.len], key[0..]);
            buf[key.len] = '=';
            @memcpy(buf[key.len + 1 ..], value[0..]);

            if (env_state.find_index(key)) |index| {
                const kv = &std.os.environ[index];
                env_state.free_item(kv.*);
                kv.* = buf;
                return;
            }

            if (!env_state.resize_env(std.os.environ.len + 1)) {
                return error.SetenvFailed;
            }

            std.os.environ[std.os.environ.len - 1] = buf;
        } else {
            if (env_state.find_index(key)) |index| {
                const kv = &std.os.environ[index];
                env_state.free_item(kv.*);

                for (index + 1..std.os.environ.len) |i| {
                    std.os.environ[i - 1] = std.os.environ[i];
                }

                if (!env_state.resize_env(std.os.environ.len - 1)) {
                    return error.SetenvFailed;
                }
            }
        }
    }
}

test "setenv" {
    // do not allow empty keys
    try std.testing.expectError(error.SetenvFailed, setenv("", "evil"));
    try std.testing.expectEqual(null, std.posix.getenv("evil"));
    // empty values are ok though
    try setenv("good", "");
    try std.testing.expectEqualSlices(u8, "", std.posix.getenv("good").?);
    try setenv("good", null);
    try std.testing.expectEqual(null, std.posix.getenv("good"));
    env_state.reset_memory(true);
}

test "setenv allocs" {
    env_state.allocator = std.testing.allocator;
    try setenv("joulupukki", "asuu pohjoisnavalla");
    try std.testing.expectEqualSlices(u8, "asuu pohjoisnavalla", std.posix.getenv("joulupukki").?);
    try setenv("joulupukki", null);
    try std.testing.expectEqual(null, std.posix.getenv("joulupukki"));
    try setenv("joulupukki", "tuo lahjoja");
    try std.testing.expectEqualSlices(u8, "tuo lahjoja", std.posix.getenv("joulupukki").?);
    try setenv("tontut", "vahtii lapsia");
    try std.testing.expectEqualSlices(u8, "vahtii lapsia", std.posix.getenv("tontut").?);
    try setenv("joulupukki", null);
    try setenv("tontut", null);
    env_state.reset_memory(false);
}

test "setenv failing allocs" {
    env_state.allocator = std.testing.failing_allocator;
    try std.testing.expectError(error.SetenvFailed, setenv("joulupukki", "asuu pohjoisnavalla"));
    try setenv("joulupukki", null); // no-op
}

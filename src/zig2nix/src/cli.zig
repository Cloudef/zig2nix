const std = @import("std");

pub const ExitStatus = enum(u8) {
    /// succesful termination
    ok = 0,
    /// command line usage error
    usage = 64,
    /// data format error
    dataerr = 65,
    /// cannot open input
    noinput = 66,
    /// addressee unknown
    nouser = 67,
    /// host name unknown
    nohost = 68,
    /// service unavailable
    unavailable = 69,
    /// internal software error
    software = 70,
    /// system error (e.g., can't fork)
    oserr = 71,
    /// critical os file missing
    osfile = 72,
    /// can't create (user) output file
    cantcreat = 73,
    /// input/output error
    ioerr = 74,
    /// temp failure; user is invited to retry
    tempfail = 75,
    /// remote error in proctol
    protocol = 76,
    /// permission denied
    noperm = 77,
    /// configuration error
    config = 78,
    /// rest is custom
    _,
};

pub fn exit(status: ExitStatus) noreturn {
    std.posix.exit(@intFromEnum(status));
}

pub fn download(allocator: std.mem.Allocator, url: []const u8, writer: anytype, max_read_size: usize) !void {
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    var body: std.ArrayList(u8) = .init(allocator);
    defer body.deinit();

    _ = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .response_storage = .{ .dynamic = &body },
        .max_append_size = max_read_size,
    });

    try writer.writeAll(body.items);
}

pub const Pipe = struct {
    child: std.process.Child,
    finished: bool = false,

    pub fn writer(self: *@This()) std.fs.File.DeprecatedWriter {
        return self.child.stdin.?.deprecatedWriter();
    }

    pub fn reader(self: *@This()) std.fs.File.DeprecatedReader {
        return self.child.stdout.?.deprecatedReader();
    }

    pub fn close(self: *@This()) void {
        self.child.stdin.?.close();
        self.child.stdin = null;
    }

    pub fn finish(self: *@This()) !std.process.Child.Term {
        defer self.finished = true;
        return self.child.wait();
    }

    pub fn deinit(self: *@This()) void {
        if (!self.finished) _ = self.child.kill() catch {};
        self.* = undefined;
    }
};

pub fn pipe(allocator: std.mem.Allocator, cwd: ?std.fs.Dir, argv: []const []const u8) !Pipe {
    var child: std.process.Child = .init(argv, allocator);
    child.cwd_dir = cwd;
    child.stdout_behavior = .Pipe;
    child.stdin_behavior = .Pipe;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    _ = child.stdin orelse return error.NoStdinAvailable;
    _ = child.stdout orelse return error.NoStdoutAvailable;
    return .{ .child = child };
}

pub fn run(allocator: std.mem.Allocator, cwd: ?std.fs.Dir, argv: []const []const u8, max_size: usize) ![]const u8 {
    var proc = try pipe(allocator, cwd, argv);
    defer proc.deinit();
    proc.close();
    const body = try proc.reader().readAllAlloc(allocator, max_size);
    switch (try proc.finish()) {
        .Exited => |status| switch (status) {
            0 => {},
            else => return error.ProcessRunFailed,
        },
        else => return error.ProcessRunFailed,
    }
    return std.mem.trim(u8, body, &std.ascii.whitespace);
}

pub const TmpDir = struct {
    path: std.BoundedArray(u8, 32),
    dir: std.fs.Dir,

    pub fn close(self: *@This()) void {
        defer self.* = undefined;
        var tmp = std.fs.openDirAbsolute("/tmp", .{}) catch return;
        defer tmp.close();
        tmp.deleteTree(self.path.constSlice()) catch unreachable;
    }
};

pub fn mktemp(comptime prefix: []const u8) !TmpDir {
    var tmp = try std.fs.openDirAbsolute("/tmp", .{ .access_sub_paths = false });
    defer tmp.close();
    const random_bytes = 8;
    var buf: [prefix.len + random_bytes * 2]u8 = (prefix ++ ("00" ** random_bytes)).*;
    var random_part = buf[prefix.len..][0..];
    std.crypto.random.bytes(random_part[0..random_bytes]);
    const hex = std.fmt.bytesToHex(random_part[0..random_bytes], .lower);
    random_part.* = hex;
    const dir = try tmp.makeOpenPath(&buf, .{ .no_follow = true, .access_sub_paths = false });
    var cpy: std.BoundedArray(u8, 32) = .{};
    try cpy.appendSlice(&buf);
    return .{ .path = cpy, .dir = dir };
}

const ZigEnv = struct {
    zig_exe: []const u8,
    lib_dir: []const u8,
    std_dir: []const u8,
    global_cache_dir: []const u8,
    version: []const u8,
};

pub fn fetchZigEnv(allocator: std.mem.Allocator) !std.json.Parsed(ZigEnv) {
    var proc = try pipe(allocator, null, &.{ "zig", "env" });
    defer proc.deinit();
    proc.close();
    var reader = std.json.reader(allocator, proc.reader());
    defer reader.deinit();
    const env = try std.json.parseFromTokenSource(ZigEnv, allocator, &reader, .{ .ignore_unknown_fields = true });
    _ = try proc.finish();
    return env;
}

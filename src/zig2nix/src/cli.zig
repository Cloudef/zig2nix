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

pub fn download(allocator: std.mem.Allocator, url: []const u8, writer: *std.Io.Writer) !void {
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    _ = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .response_writer = writer,
    });
}

pub const Pipe = struct {
    child: std.process.Child,
    finished: bool = false,

    pub fn writer(self: *@This(), buf: []u8) std.fs.File.Writer {
        return self.child.stdin.?.writer(buf);
    }

    pub fn reader(self: *@This(), buf: []u8) std.fs.File.Reader {
        return self.child.stdout.?.reader(buf);
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

pub fn run(allocator: std.mem.Allocator, cwd: ?std.fs.Dir, argv: []const []const u8) ![]const u8 {
    var proc = try pipe(allocator, cwd, argv);
    defer proc.deinit();
    proc.close();
    var proc_buf: [1024]u8 = undefined;
    var proc_reader = proc.reader(&proc_buf);
    var body_writer = try std.Io.Writer.Allocating.initCapacity(allocator, 1024);
    defer body_writer.deinit();
    _ = try proc_reader.interface.streamRemaining(&body_writer.writer);
    const body = try body_writer.toOwnedSlice();
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
    path_buf: [32]u8,
    path_len: usize,
    dir: std.fs.Dir,

    fn path(self: *const @This()) []const u8 {
        return self.path_buf[0..self.path_len];
    }

    pub fn close(self: *@This()) void {
        defer self.* = undefined;
        var tmp = std.fs.openDirAbsolute("/tmp", .{}) catch return;
        defer tmp.close();
        tmp.deleteTree(self.path()) catch unreachable;
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
    var cpy: [32]u8 = undefined;
    @memcpy(cpy[0..buf.len], &buf);
    return .{ .path_buf = cpy, .path_len = buf.len, .dir = dir };
}

const ZigEnv = struct {
    zig_exe: []const u8,
    lib_dir: []const u8,
    std_dir: []const u8,
    global_cache_dir: []const u8,
    version: []const u8,
};

pub fn fetchZigEnv(allocator: std.mem.Allocator, error_writer: *std.Io.Writer) !std.json.Parsed(ZigEnv) {
    var proc = try pipe(allocator, null, &.{ "zig", "env" });
    defer proc.deinit();
    proc.close();
    var buf: [1024]u8 = undefined;
    var proc_reader = proc.reader(&buf);
    var tmp = try std.Io.Writer.Allocating.initCapacity(allocator, 1024);
    defer tmp.deinit();
    try @import("zon2json.zig").parse(allocator, &proc_reader.interface, &tmp.writer, error_writer, .{.file_name = "zig env"});
    var scanner = std.json.Scanner.initCompleteInput(allocator, try tmp.toOwnedSlice());
    defer scanner.deinit();
    const env = try std.json.parseFromTokenSource(ZigEnv, allocator, &scanner, .{ .ignore_unknown_fields = true });
    _ = try proc.finish();
    return env;
}

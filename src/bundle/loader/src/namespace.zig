const std = @import("std");
const log = std.log.scoped(.namespace);

fn writeTo(path: []const u8, comptime format: []const u8, args: anytype) !void {
    var f = std.fs.openFileAbsolute(path, .{ .mode = .write_only }) catch |err| {
        log.err("write failed to: {s}", .{path});
        return err;
    };
    defer f.close();
    var bounded: std.BoundedArray(u8, 1024) = .{};
    try bounded.writer().print(format, args);
    f.writer().writeAll(bounded.constSlice()) catch |err| {
        log.err("write failed to: {s}", .{path});
        return err;
    };
}

fn oserr(rc: usize) !void {
    return switch (std.posix.errno(rc)) {
        .SUCCESS => {},
        else => |e| std.posix.unexpectedErrno(e),
    };
}

fn mount(special: [:0]const u8, dir: [:0]const u8, fstype: [:0]const u8, flags: u32, data: usize) !void {
    oserr(std.os.linux.mount(special, dir, fstype, flags, data)) catch |err| {
        log.err("mount {s} {s} -> {s}", .{ special, dir, fstype });
        return err;
    };
}

fn replicatePath(allocator: std.mem.Allocator, src: [:0]const u8, dst: [:0]const u8) !void {
    if (std.fs.accessAbsolute(dst, .{ .mode = .read_only })) {
        log.warn("destination already exists, skipping: {s}", .{dst});
        return;
    } else |_| {}

    const stat = std.fs.cwd().statFile(src) catch {
        log.warn("failed to stat, skipping: {s}", .{src});
        return;
    };

    std.fs.cwd().makePath(std.fs.path.dirname(dst).?) catch {};

    switch (stat.kind) {
        .directory => {
            std.fs.makeDirAbsolute(dst) catch |err| {
                log.err("failed to create directory: {s}", .{dst});
                return err;
            };
            try mount(src, dst, "none", std.os.linux.MS.BIND | std.os.linux.MS.REC, 0);
        },
        .file => {
            var f = std.fs.createFileAbsolute(dst, .{}) catch |err| {
                log.err("failed to create file: {s}", .{dst});
                return err;
            };
            f.close();
            try mount(src, dst, "none", std.os.linux.MS.BIND | std.os.linux.MS.REC, 0);
        },
        .sym_link => {
            var buf: [std.fs.max_path_bytes]u8 = undefined;
            const path = try std.fs.realpathAlloc(allocator, try std.fs.readLinkAbsolute(src, &buf));
            defer allocator.free(path);
            const sstat = std.fs.cwd().statFile(path) catch {
                log.warn("failed to stat, skipping: {s}", .{path});
                return;
            };
            std.fs.symLinkAbsolute(path, dst, .{ .is_directory = sstat.kind == .directory }) catch |err| {
                log.err("failed to create symlink: {s}", .{dst});
                return err;
            };
        },
        else => {
            log.warn("do not know how to replicate {s}: {s}", .{ @tagName(stat.kind), src });
        },
    }
}

fn replicatePathWithRoots(allocator: std.mem.Allocator, src_root: []const u8, src_base: []const u8, dst_root: []const u8, dst_base: []const u8) !void {
    std.debug.assert(src_root.len > 0 and dst_root.len > 1);
    std.debug.assert(src_root[0] == '/' and dst_root[0] == '/');
    const resolved_src_root = if (src_root.len > 1 or src_root[0] == '/') "" else src_root;
    const src = try std.fmt.allocPrintZ(allocator, "{s}/{s}", .{ resolved_src_root, src_base });
    defer allocator.free(src);
    const dst = try std.fmt.allocPrintZ(allocator, "{s}/{s}", .{ dst_root, dst_base });
    defer allocator.free(dst);
    try replicatePath(allocator, src, dst);
}

fn replicateDir(allocator: std.mem.Allocator, src: []const u8, dst: []const u8, comptime ignored: []const []const u8) !void {
    var dir = std.fs.openDirAbsolute(src, .{ .iterate = true }) catch {
        log.warn("directory does not exist, skipping replication of: {s}", .{src});
        return;
    };
    defer dir.close();
    std.fs.makeDirAbsolute(dst) catch {};

    var iter = dir.iterate();
    while (try iter.next()) |ent| {
        if (std.mem.eql(u8, ent.name, ".") or
            std.mem.eql(u8, ent.name, ".."))
        {
            continue;
        }

        const should_skip: bool = blk: {
            inline for (ignored) |ignore| if (std.mem.eql(u8, ent.name, ignore)) break :blk true;
            break :blk false;
        };

        if (should_skip) {
            continue;
        }

        try replicatePathWithRoots(allocator, src, ent.name, dst, ent.name);
    }
}

pub fn setup(allocator: std.mem.Allocator, workdir: []const u8, appdir: []const u8) !void {
    const mountroot = try std.fmt.allocPrintZ(allocator, "{s}/mountroot", .{workdir});
    defer allocator.free(mountroot);
    std.fs.makeDirAbsolute(mountroot) catch {};

    const uid = std.os.linux.getuid();
    const gid = std.os.linux.getgid();

    var clonens: usize = std.os.linux.CLONE.NEWNS;
    if (uid != 0) clonens |= std.os.linux.CLONE.NEWUSER;
    if (std.os.linux.unshare(clonens) < 0) {
        return error.UnshareFailed;
    }

    if (uid != 0) {
        // UID/GID Mapping -----------------------------------------------------------

        // see user_namespaces(7)
        // > The data written to uid_map (gid_map) must consist of a single line that
        // > maps the writing process's effective user ID (group ID) in the parent
        // > user namespace to a user ID (group ID) in the user namespace.
        try writeTo("/proc/self/uid_map", "{d} {d} 1", .{ uid, uid });

        // see user_namespaces(7):
        // > In the case of gid_map, use of the setgroups(2) system call must first
        // > be denied by writing "deny" to the /proc/[pid]/setgroups file (see
        // > below) before writing to gid_map.
        try writeTo("/proc/self/setgroups", "deny", .{});
        try writeTo("/proc/self/gid_map", "{d} {d} 1", .{ uid, gid });
    }

    // tmpfs so we don't need to cleanup
    try mount("tmpfs", mountroot, "tmpfs", 0, 0);
    // make unbindable to both prevent event propagation as well as mount explosion
    try mount(mountroot, mountroot, "none", std.os.linux.MS.UNBINDABLE, 0);

    // setup /
    try replicateDir(allocator, "/", mountroot, &.{"nix"});

    // setup nix
    {
        const src = try std.fmt.allocPrintZ(allocator, "{s}/nix/store", .{appdir});
        defer allocator.free(src);
        if (std.fs.accessAbsolute(src, .{ .mode = .read_only })) {
            const dst = try std.fmt.allocPrintZ(allocator, "{s}/nix/store", .{mountroot});
            defer allocator.free(dst);
            std.fs.cwd().makePath(dst) catch {};
            if (std.fs.accessAbsolute("/nix", .{ .mode = .read_only })) {
                const opts = try std.fmt.allocPrintZ(allocator, "lowerdir=/nix/store:{s}", .{src});
                defer allocator.free(opts);
                log.info("/nix exists, mounting {s} as a overlay: {s}", .{ dst, opts });
                try mount("overlay", dst, "overlay", 0, @intFromPtr(opts.ptr));
            } else |_| {
                try mount(src, dst, "none", std.os.linux.MS.BIND | std.os.linux.MS.REC, 0);
            }
        } else |_| {}
    }

    const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd);
    try oserr(std.os.linux.chroot(mountroot));
    try std.posix.chdir(cwd);
}

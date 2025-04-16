const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.loader);
const runtime = @import("runtime.zig");
const namespace = @import("namespace.zig");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

fn dynamicLinkerFromPath(allocator: std.mem.Allocator, path: []const u8) !?[]const u8 {
    var f = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |err| {
        log.err("unable to open: {s}", .{path});
        return err;
    };
    defer f.close();
    const target = try std.zig.system.abiAndDynamicLinkerFromFile(f, builtin.target.cpu, builtin.target.os, &.{}, .{});
    return try allocator.dupe(u8, target.dynamic_linker.get().?);
}

const Executor = struct {
    args: []const []const u8,
    dynamic: bool,

    pub fn resolve(allocator: std.mem.Allocator) !@This() {
        var iter = try std.process.argsWithAllocator(allocator);
        defer iter.deinit();
        _ = iter.skip();

        const exe = blk: {
            if (comptime @import("options").entrypoint) |entrypoint| {
                const appdir = try std.fs.selfExeDirPathAlloc(allocator);
                defer allocator.free(appdir);
                try std.posix.chdir(appdir);
                break :blk try allocator.dupe(u8, entrypoint);
            } else {
                if (iter.next()) |exe| {
                    break :blk try std.fs.realpathAlloc(allocator, exe);
                } else {
                    std.log.err("usage: loader exe [args]", .{});
                    std.posix.exit(1);
                }
            }
        };

        var args: std.ArrayListUnmanaged([]const u8) = .{};
        defer args.deinit(allocator);

        var dynamic = false;
        if (comptime @import("options").runtime) {
            if (dynamicLinkerFromPath(allocator, exe) catch null) |dl0| {
                defer allocator.free(dl0);
                if (try dynamicLinkerFromPath(allocator, "/usr/bin/env")) |dl| {
                    log.info("dynamic linker: {s}", .{dl});
                    try args.append(allocator, dl);
                } else {
                    log.warn("unable to figure out the dynamic linker, falling back to: {s}", .{dl0});
                }
                dynamic = true;
            }
        }

        try args.append(allocator, exe);
        while (iter.next()) |arg| try args.append(allocator, try allocator.dupe(u8, arg));

        return .{
            .args = try args.toOwnedSlice(allocator),
            .dynamic = dynamic,
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        for (self.args) |arg| allocator.free(arg);
        allocator.free(self.args);
    }

    pub fn exePath(self: @This()) []const u8 {
        return if (self.dynamic) self.args[1] else self.args[0];
    }
};

fn run(allocator: std.mem.Allocator) !void {
    var executor = try Executor.resolve(allocator);
    defer executor.deinit(allocator);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var env: ?std.process.EnvMap = null;
    defer if (env) |*e| e.deinit();
    if (comptime @import("options").runtime) {
        env = runtime.setup(arena.allocator(), executor.exePath()) catch |err| D: {
            log.warn("{}: runtime is incomplete and the program may not function properly", .{err});
            break :D null;
        };
    }

    if (comptime @import("options").namespace) {
        _ = arena.reset(.retain_capacity);
        const appdir = try std.fs.selfExeDirPathAlloc(arena.allocator());
        const workdir = blk: {
            if (comptime @import("options").workdir) |dir| {
                break :blk dir;
            } else {
                break :blk appdir;
            }
        };
        namespace.setup(arena.allocator(), workdir, appdir) catch |err| {
            log.err("failed to setup an namespace, cannot continue.", .{});
            return err;
        };
    }

    log.info("executing: {s}", .{executor.exePath()});
    if (env) |*e| {
        return std.process.execve(allocator, executor.args, e);
    } else {
        return std.process.execv(allocator, executor.args);
    }
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    run(gpa.allocator()) catch |err| {
        log.err("fatal error: {}", .{err});
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
        std.posix.exit(127);
    };
}

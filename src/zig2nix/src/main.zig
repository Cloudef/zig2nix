const std = @import("std");
const cli = @import("cli.zig");
const zon2json = @import("zon2json.zig");
const zon2lock = @import("zon2lock.zig");
const zon2nix = @import("zon2nix.zig");
const versions = @import("versions.zig");
const Target = @import("Target.zig");

test {
    comptime {
        _ = cli;
        _ = zon2json;
        _ = zon2lock;
        _ = versions;
        _ = Target;
    }
}

const mib_in_bytes = 1048576;

pub const MainCommand = enum {
    zon2json,
    zon2lock,
    zon2nix,
    target,
    versions,
    help,
    zen,
};

pub const GeneralOptions = enum {
    help,
};

fn usage(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: zig2nix [command] [options]
        \\
        \\Commands:
        \\
    );
    for (std.enums.values(MainCommand)) |cmd| {
        var counter = std.io.countingWriter(writer);
        try counter.writer().print("  {s}", .{@tagName(cmd)});
        try writer.writeByteNTimes(' ', 20 - counter.bytes_written);
        try switch (cmd) {
            .zon2json => writer.writeAll("Convert zon to json\n"),
            .zon2lock => writer.writeAll("Convert build.zig.zon to build.zig.zon2json-lock\n"),
            .zon2nix => writer.writeAll("Convert build.zig.zon2json-lock to a nix derivation\n"),
            .target => writer.writeAll("Print information about the target\n"),
            .versions => writer.writeAll("Generate versions.nix from a zig binary index\n"),
            .help => writer.writeAll("Print this help and exit\n"),
            .zen => writer.writeAll("Print zen of zig2nix and exit\n"),
        };
    }
    try writer.writeAll(
        \\
        \\General Options:
        \\
    );
    for (std.enums.values(GeneralOptions)) |opt| {
        var counter = std.io.countingWriter(writer);
        try counter.writer().print("  -{c}, --{s}", .{ @tagName(opt)[0], @tagName(opt) });
        try writer.writeByteNTimes(' ', 20 - counter.bytes_written);
        try switch (opt) {
            .help => writer.writeAll("Print command-specific usage\n"),
        };
    }
}

fn @"cmd::help"(_: std.mem.Allocator, _: *std.process.ArgIterator, stdout: anytype, _: anytype) !void {
    try usage(stdout);
}

fn @"cmd::zen"(_: std.mem.Allocator, _: *std.process.ArgIterator, stdout: anytype, _: anytype) !void {
    try stdout.writeAll(
        \\
        \\ * Death to NativePaths.zig
        \\
        \\
    );
}

fn @"cmd::target"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: anytype, _: anytype) !void {
    const result = try Target.parse(arena, args.next() orelse "native");
    try stdout.print("{s}", .{std.json.fmt(result, .{ .whitespace = .indent_2 })});
}

fn @"cmd::zon2json"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    const path = args.next() orelse "build.zig.zon";
    var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();
    try zon2json.parse(arena, file.reader(), stdout, stderr, .{ .file_name = path });
}

fn @"cmd::zon2lock"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    const path = args.next() orelse "build.zig.zon";
    try zon2lock.write(arena, std.fs.cwd(), path, stdout, stderr);
}

fn @"cmd::zon2nix"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    const path = args.next() orelse "build.zig.zon";
    if (std.mem.endsWith(u8, path, "zig.zon")) {
        const lock_path = try std.fmt.allocPrint(arena, "{s}2json-lock", .{path});
        if (std.fs.cwd().access(lock_path, .{})) {
            try zon2nix.write(arena, std.fs.cwd(), lock_path, stdout);
        } else |_| {
            var json: std.ArrayListUnmanaged(u8) = .{};
            defer json.deinit(arena);
            try zon2lock.write(arena, std.fs.cwd(), path, json.writer(arena), stderr);
            try zon2nix.writeFromSlice(arena, json.items, stdout);
        }
    } else {
        try zon2nix.write(arena, std.fs.cwd(), path, stdout);
    }
}

fn @"cmd::versions"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: anytype, _: anytype) !void {
    var json: std.ArrayListUnmanaged(u8) = .{};
    defer json.deinit(arena);
    const url = args.next() orelse "https://ziglang.org/download/index.json";
    try cli.download(arena, url, json.writer(arena), mib_in_bytes * 40);
    try versions.write(arena, json.items, stdout);
}

fn realMain(stdout: anytype, stderr: anytype) !void {
    var arena_state: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    const arena = arena_state.allocator();

    var args = try std.process.argsWithAllocator(arena);
    defer args.deinit();

    _ = args.skip();
    const cmd_str = args.next() orelse return error.MainCommandRequired;
    const cmd = std.meta.stringToEnum(MainCommand, cmd_str) orelse return error.UnknownMainCommand;

    switch (cmd) {
        inline else => |tag| {
            const fn_name = "cmd::" ++ @tagName(tag);
            try @call(.auto, @field(@This(), fn_name), .{ arena, &args, stdout, stderr });
        },
    }
}

pub fn main() !noreturn {
    var status: cli.ExitStatus = .ok;
    {
        var stdout = std.io.bufferedWriter(std.io.getStdOut().writer());
        defer stdout.flush() catch {};
        var stderr = std.io.bufferedWriter(std.io.getStdErr().writer());
        defer stderr.flush() catch {};
        realMain(stdout.writer(), stderr.writer()) catch |err| {
            switch (err) {
                error.MainCommandRequired,
                error.UnknownMainCommand,
                => {
                    try usage(stderr.writer());
                    status = .usage;
                },
                else => |suberr| {
                    try stderr.writer().print("{}", .{suberr});
                    if (@errorReturnTrace()) |trace| {
                        std.debug.dumpStackTrace(trace.*);
                    }
                    status = switch (suberr) {
                        else => .software,
                    };
                },
            }
        };
    }
    cli.exit(status);
}

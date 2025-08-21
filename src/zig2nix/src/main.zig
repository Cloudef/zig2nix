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

fn readInput(allocator: std.mem.Allocator, dir: std.fs.Dir, stdin_path_or_url: []const u8) ![]const u8 {
    if (std.mem.eql(u8, stdin_path_or_url, "-")) {
        return try readInputFile(allocator, std.fs.File.stdin());
    } else if (std.mem.startsWith(u8, stdin_path_or_url, "http://") or std.mem.startsWith(u8, stdin_path_or_url, "https://")) {
        var writer = try std.Io.Writer.Allocating.initCapacity(allocator, 1024);
        defer writer.deinit();
        try cli.download(allocator, stdin_path_or_url, &writer.writer);
        return try writer.toOwnedSlice();
    } else {
        var file = try dir.openFile(stdin_path_or_url, .{});
        defer file.close();
        return try readInputFile(allocator, file);
    }
}

fn readInputFile(allocator: std.mem.Allocator, file: std.fs.File) ![]const u8 {
    var writer = try std.Io.Writer.Allocating.initCapacity(allocator, 1024);
    defer writer.deinit();
    var reader_buf: [1024]u8 = undefined;
    var file_reader = file.reader(&reader_buf);
    _ = try writer.writer.sendFileAll(&file_reader, .unlimited);
    return try writer.toOwnedSlice();
}

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

fn printWithPadding(writer: *std.Io.Writer, comptime fmt: []const u8, args: anytype, padding: usize) !void {
    try writer.print(fmt, args);
    const count = std.fmt.count(fmt, args);
    const add_padding = padding -| count;
    _ = try writer.splatByte(' ', add_padding);
}

fn usage(writer: *std.Io.Writer) !void {
    try writer.writeAll(
        \\Usage: zig2nix [command] [options]
        \\
        \\Commands:
        \\
    );
    for (std.enums.values(MainCommand)) |cmd| {
        try printWithPadding(writer, "  {s}", .{@tagName(cmd)}, 20);
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
        try printWithPadding(writer, "  -{c}, --{s}", .{ @tagName(opt)[0], @tagName(opt) }, 20);
        try switch (opt) {
            .help => writer.writeAll("Print command-specific usage\n"),
        };
    }
}

fn @"cmd::help"(_: std.mem.Allocator, _: *std.process.ArgIterator, stdout: *std.Io.Writer, _: *std.Io.Writer) !void {
    try usage(stdout);
}

fn @"cmd::zen"(_: std.mem.Allocator, _: *std.process.ArgIterator, stdout: *std.Io.Writer, _: *std.Io.Writer) !void {
    try stdout.writeAll(
        \\
        \\ * Death to NativePaths.zig
        \\
        \\
    );
}

fn @"cmd::target"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: *std.Io.Writer, _: *std.Io.Writer) !void {
    const result = try Target.parse(arena, args.next() orelse "native");
    try stdout.print("{f}", .{std.json.fmt(result, .{ .whitespace = .indent_2 })});
}

fn @"cmd::zon2json"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: *std.Io.Writer, stderr: *std.Io.Writer) !void {
    const input = args.next() orelse "build.zig.zon";
    const zon = try readInput(arena, std.fs.cwd(), input);
    try zon2json.parseFromSlice(arena, zon, stdout, stderr, .{ .file_name = input });
}

fn @"cmd::zon2lock"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: *std.Io.Writer, stderr: *std.Io.Writer) !void {
    const path = args.next() orelse "build.zig.zon";
    const dest = args.next() orelse try std.fmt.allocPrint(arena, "{s}2json-lock", .{path});

    if (std.mem.eql(u8, dest, "-")) {
        try zon2lock.write(arena, std.fs.cwd(), path, stdout, stderr);
    } else {
        var file = try std.fs.cwd().createFile(dest, .{});
        defer file.close();
        var buf: [1024]u8 = undefined;
        var file_writer = file.writer(&buf);
        try zon2lock.write(arena, std.fs.cwd(), path, &file_writer.interface, stderr);
        try file_writer.interface.flush();
    }
}

fn @"cmd::zon2nix"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: *std.Io.Writer, stderr: *std.Io.Writer) !void {
    const path = args.next() orelse "build.zig.zon";
    const dest = args.next() orelse D: {
        if (std.mem.endsWith(u8, path, "2json-lock")) {
            break :D try std.fmt.allocPrint(arena, "{s}.nix", .{path[0 .. path.len - "2json-lock".len]});
        }
        break :D try std.fmt.allocPrint(arena, "{s}.nix", .{path});
    };

    var lock_path: []const u8 = path;
    if (std.mem.endsWith(u8, path, ".zig.zon")) {
        lock_path = try std.fmt.allocPrint(arena, "{s}2json-lock", .{path});
        if (std.fs.cwd().access(lock_path, .{})) |_| {} else |_| {
            var file = try std.fs.cwd().createFile(lock_path, .{});
            defer file.close();
            var buf: [1024]u8 = undefined;
            var file_writer = file.writer(&buf);
            try zon2lock.write(arena, std.fs.cwd(), path, &file_writer.interface, stderr);
            try file_writer.interface.flush();
        }
    }

    if (std.mem.eql(u8, dest, "-")) {
        try zon2nix.write(arena, std.fs.cwd(), lock_path, stdout);
    } else {
        var file = try std.fs.cwd().createFile(dest, .{});
        defer file.close();
        var buf: [1024]u8 = undefined;
        var file_writer = file.writer(&buf);
        try zon2nix.write(arena, std.fs.cwd(), lock_path, &file_writer.interface);
        try file_writer.interface.flush();
    }
}

fn @"cmd::versions"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: *std.Io.Writer, _: *std.Io.Writer) !void {
    const input = args.next() orelse "https://ziglang.org/download/index.json";
    const mirrors = args.next() orelse "https://ziglang.org/download/community-mirrors.txt";
    const json = try readInput(arena, std.fs.cwd(), input);
    const mirrorlist = try readInput(arena, std.fs.cwd(), mirrors);
    try versions.write(arena, json, mirrorlist, stdout);
}

fn realMain(stdout: *std.Io.Writer, stderr: *std.Io.Writer) !void {
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
        var stdout_buf: [1024]u8 = undefined;
        var stderr_buf: [1024]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
        const stdout = &stdout_writer.interface;
        defer stdout.flush() catch {};
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
        const stderr = &stderr_writer.interface;
        defer stderr.flush() catch {};
        realMain(stdout, stderr) catch |err| {
            switch (err) {
                error.MainCommandRequired,
                error.UnknownMainCommand,
                => {
                    try usage(stderr);
                    status = .usage;
                },
                else => |suberr| {
                    try stderr.print("{}", .{suberr});
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

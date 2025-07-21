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
    const mib_in_bytes = 1048576;
    if (std.mem.eql(u8, stdin_path_or_url, "-")) {
        return try std.fs.File.stdout().deprecatedReader().readAllAlloc(allocator, mib_in_bytes * 40);
    } else if (std.mem.startsWith(u8, stdin_path_or_url, "http://") or std.mem.startsWith(u8, stdin_path_or_url, "https://")) {
        var bytes: std.ArrayListUnmanaged(u8) = .{};
        errdefer bytes.deinit(allocator);
        try cli.download(allocator, stdin_path_or_url, bytes.writer(allocator), mib_in_bytes * 40);
        return try bytes.toOwnedSlice(allocator);
    } else {
        return try dir.readFileAlloc(allocator, stdin_path_or_url, mib_in_bytes * 40);
    }
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

fn usage(writer: *std.io.Writer) !void {
    try writer.writeAll(
        \\Usage: zig2nix [command] [options]
        \\
        \\Commands:
        \\
    );
    for (std.enums.values(MainCommand)) |cmd| {
        const n = std.fmt.count("  {s}", .{@tagName(cmd)});
        try writer.print("  {s}", .{@tagName(cmd)});
        try writer.splatByteAll(' ', 20 - n);
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
        const n = std.fmt.count("  -{c}, --{s}", .{ @tagName(opt)[0], @tagName(opt) });
        try writer.print("  -{c}, --{s}", .{ @tagName(opt)[0], @tagName(opt) });
        try writer.splatByteAll(' ', 20 - n);
        try switch (opt) {
            .help => writer.writeAll("Print command-specific usage\n"),
        };
    }
}

fn @"cmd::help"(_: std.mem.Allocator, _: *std.process.ArgIterator, stdout: *std.io.Writer, _: *std.io.Writer) !void {
    try usage(stdout);
}

fn @"cmd::zen"(_: std.mem.Allocator, _: *std.process.ArgIterator, stdout: *std.io.Writer, _: *std.io.Writer) !void {
    try stdout.writeAll(
        \\
        \\ * Death to NativePaths.zig
        \\
        \\
    );
}

fn @"cmd::target"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: *std.io.Writer, _: *std.io.Writer) !void {
    const result = try Target.parse(arena, args.next() orelse "native");
    try stdout.print("{f}", .{std.json.fmt(result, .{ .whitespace = .indent_2 })});
}

fn @"cmd::zon2json"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: *std.io.Writer, stderr: *std.io.Writer) !void {
    const input = args.next() orelse "build.zig.zon";
    const zon = try readInput(arena, std.fs.cwd(), input);
    try zon2json.parseFromSlice(arena, zon, stdout, stderr, .{ .file_name = input });
}

fn @"cmd::zon2lock"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: *std.io.Writer, stderr: *std.io.Writer) !void {
    const path = args.next() orelse "build.zig.zon";
    const dest = args.next() orelse try std.fmt.allocPrint(arena, "{s}2json-lock", .{path});

    if (std.mem.eql(u8, dest, "-")) {
        try zon2lock.write(arena, std.fs.cwd(), path, stdout, stderr);
    } else {
        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(arena);
        var json_writer = json.writer(arena).adaptToNewApi();
        try zon2lock.write(arena, std.fs.cwd(), path, &json_writer.new_interface, stderr);
        try std.fs.cwd().writeFile(.{ .data = json.items, .sub_path = dest });
    }
}

fn @"cmd::zon2nix"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: *std.io.Writer, stderr: *std.io.Writer) !void {
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
            var json: std.ArrayListUnmanaged(u8) = .{};
            defer json.deinit(arena);
            var json_writer = json.writer(arena).adaptToNewApi();
            try zon2lock.write(arena, std.fs.cwd(), path, &json_writer.new_interface, stderr);
            try std.fs.cwd().writeFile(.{ .data = json.items, .sub_path = lock_path });
        }
    }

    if (std.mem.eql(u8, dest, "-")) {
        try zon2nix.write(arena, std.fs.cwd(), lock_path, stdout);
    } else {
        var writer: std.io.Writer.Allocating = .init(arena);
        defer writer.deinit();
        try zon2nix.write(arena, std.fs.cwd(), lock_path, &writer.writer);
        var nix: std.ArrayListUnmanaged(u8) = writer.toArrayList();
        defer nix.deinit(arena);
        try std.fs.cwd().writeFile(.{ .data = nix.items, .sub_path = dest });
    }
}

fn @"cmd::versions"(arena: std.mem.Allocator, args: *std.process.ArgIterator, stdout: *std.io.Writer, _: *std.io.Writer) !void {
    const input = args.next() orelse "https://ziglang.org/download/index.json";
    const json = try readInput(arena, std.fs.cwd(), input);
    try versions.write(arena, json, stdout);
}

fn realMain(stdout: *std.io.Writer, stderr: *std.io.Writer) !void {
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
        var stdout_buffer: [1024]u8 = undefined;
        var stdout = std.fs.File.stdout().writer(&stdout_buffer);
        defer stdout.interface.flush() catch {};
        var stderr_buffer: [1024]u8 = undefined;
        var stderr = std.fs.File.stderr().writer(&stderr_buffer);
        defer stderr.interface.flush() catch {};
        realMain(&stdout.interface, &stderr.interface) catch |err| {
            switch (err) {
                error.MainCommandRequired,
                error.UnknownMainCommand,
                => {
                    try usage(&stderr.interface);
                    status = .usage;
                },
                else => |suberr| {
                    try stderr.interface.print("{}", .{suberr});
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

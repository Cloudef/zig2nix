const std = @import("std");

zig: []const u8,
system: []const u8,
config: []const u8,
os: []const u8,
libc: bool,

pub fn parse(allocator: std.mem.Allocator, arch_os_abi: []const u8) !@This() {
    var arena_state: std.heap.ArenaAllocator = .init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const Arch = enum {
        i686,
        armv7a,
        armv7l,
        armv6l,
        armv5tel,
        mipsel,
        mips,
        mipsel64,
        mips64,
        powerpc,
        _passthru,
    };

    const Platform = enum {
        apple,
        pc,
        w64,
        unknown,
        _passthru,
    };

    const Os = enum {
        darwin,
        mingw32,
        _passthru,
    };

    var cpu_features: std.ArrayListUnmanaged(u8) = .{};
    const fixed_arch_os_abi: []const u8 = D: {
        var buf: std.ArrayListUnmanaged(u8) = try .initCapacity(arena, arch_os_abi.len);
        var iter = std.mem.splitScalar(u8, arch_os_abi, '-');

        const arch = iter.next() orelse break :D arch_os_abi;
        switch (std.meta.stringToEnum(Arch, arch) orelse ._passthru) {
            .i686 => try buf.appendSlice(arena, "x86"),
            .armv7a, .armv7l => try buf.appendSlice(arena, "arm"),
            .armv6l => {
                try buf.appendSlice(arena, "arm");
                try cpu_features.appendSlice(arena, "-v7a+v6");
            },
            .armv5tel => {
                try buf.appendSlice(arena, "arm");
                try cpu_features.appendSlice(arena, "-v7a+v5te");
            },
            .mipsel,
            .mips,
            .mipsel64,
            .mips64,
            .powerpc,
            ._passthru,
            => try buf.appendSlice(arena, arch),
        }
        try buf.appendSlice(arena, "-");

        const platform = iter.peek() orelse break :D arch_os_abi;
        switch (std.meta.stringToEnum(Platform, platform) orelse ._passthru) {
            .w64 => {
                try buf.appendSlice(arena, "windows-");
                _ = iter.next();
            },
            ._passthru => {},
            else => _ = iter.next(),
        }

        const os = iter.next() orelse break :D arch_os_abi;
        switch (std.meta.stringToEnum(Os, os) orelse ._passthru) {
            .darwin => try buf.appendSlice(arena, "macos"),
            .mingw32 => try buf.appendSlice(arena, "gnu"),
            ._passthru => try buf.appendSlice(arena, os),
        }

        if (iter.peek()) |_| {
            try buf.appendSlice(arena, "-");
            try buf.appendSlice(arena, iter.rest());
        } else {
            if (std.mem.eql(u8, os, "linux")) {
                // default to -gnu
                try buf.appendSlice(
                    arena,
                    switch (std.meta.stringToEnum(Arch, arch) orelse ._passthru) {
                        .mipsel64, .mips64 => "-gnuabi64",
                        .mipsel, .mips, .powerpc, .armv7a, .armv7l, .armv6l => "-gnueabihf",
                        else => "-gnu",
                    },
                );
            }
        }

        break :D buf.items;
    };

    const target = try std.zig.system.resolveTargetQuery(try .parse(.{
        .arch_os_abi = fixed_arch_os_abi,
        .cpu_features = try std.fmt.allocPrint(arena, "baseline{s}", .{cpu_features.items}),
    }));

    const arch = switch (target.cpu.arch) {
        .x86 => "i686",
        .arm => D: {
            if (std.Target.arm.featureSetHas(target.cpu.features, .v6)) {
                break :D "armv6l";
            } else if (std.Target.arm.featureSetHas(target.cpu.features, .v5te)) {
                break :D "armv5tel";
            } else if (std.Target.arm.featureSetHas(target.cpu.features, .v7a)) {
                break :D "armv7l";
            }
            return error.UnknownArmSubArch;
        },
        else => |tag| @tagName(tag),
    };

    const os = switch (target.os.tag) {
        .windows => switch (target.abi) {
            .gnu => "mingw32",
            .msvc => "windows",
            else => @tagName(target.os.tag),
        },
        .macos => "darwin",
        .freestanding => "none",
        else => |tag| @tagName(tag),
    };

    const abi = switch (target.os.tag) {
        else => switch (target.cpu.arch) {
            .powerpc64 => switch (target.abi) {
                .gnu => "gnuabielfv2",
                else => @tagName(target.abi),
            },
            else => @tagName(target.abi),
        },
    };

    const vendor = switch (target.os.tag) {
        .macos, .ios, .watchos, .visionos => "apple",
        .windows => switch (target.abi) {
            .gnu => "w64",
            else => "pc",
        },
        else => "unknown",
    };

    const config_format: enum {
        quad,
        triple,
    } = switch (target.os.tag) {
        .linux => .quad,
        else => .triple,
    };

    const config = switch (config_format) {
        .quad => try std.fmt.allocPrint(allocator, "{s}-{s}-{s}-{s}", .{
            arch,
            vendor,
            os,
            abi,
        }),
        .triple => try std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{
            arch,
            vendor,
            os,
        }),
    };

    return .{
        .zig = try target.linuxTriple(allocator),
        .system = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ arch, os }),
        .config = config,
        .os = @tagName(target.os.tag),
        .libc = std.zig.target.canBuildLibC(target),
    };
}

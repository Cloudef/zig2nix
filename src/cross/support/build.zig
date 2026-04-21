const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    inline for (&.{"arc4random"}) |name| {
        const src = std.fmt.comptimePrint("src/{s}.zig", .{name});
        const lib = b.addLibrary(.{
            .linkage = .static,
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(src),
                .target = target,
                .optimize = optimize,
                .pic = true,
                .link_libc = false,
            }),
        });
        b.installArtifact(lib);
    }
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const test_step = b.step("test", "Run unit tests");
    inline for (&.{
        "arc4random"
    }) |name| {
        const src = std.fmt.comptimePrint("src/{s}.zig", .{name});
        const lib = b.addStaticLibrary(.{
            .name = name,
            .root_source_file = .{ .path = src },
            .target = target,
            .optimize = optimize,
            .pic = true,
            .link_libc = false,
        });
        b.installArtifact(lib);
        const unit_tests = b.addTest(.{
            .root_source_file = .{ .path = src },
            .target = target,
            .optimize = optimize,
        });
        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }
}

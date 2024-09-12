const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const opts = b.addOptions();
    opts.addOption(?[]const u8, "entrypoint", b.option([]const u8, "entrypoint", "Execute the given hardcoded path"));
    opts.addOption(bool, "runtime", b.option(bool, "runtime", "Detect linux distro and try to setup a runtime for the entrypoint") orelse false);
    opts.addOption(bool, "namespace", b.option(bool, "namespace", "Setup user namespace with mounted /nix") orelse false);
    opts.addOption(?[]const u8, "workdir", b.option([]const u8, "workdir", "Working directory for the namespace, defaults to entrypoint's directory"));

    const exe = b.addExecutable(.{
        .name = "loader",
        .root_source_file = b.path("src/loader.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = false,
        .linkage = .static,
        .single_threaded = true,
    });

    b.installArtifact(exe);
    exe.root_module.addOptions("options", opts);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the loader");
    run_step.dependOn(&run_cmd.step);
}

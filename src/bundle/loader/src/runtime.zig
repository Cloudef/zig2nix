const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.runtime);
const OsRelease = @import("OsRelease.zig");
const setenv = @import("setenv.zig").setenv;

// Only care about non-FHS distros
const Distro = enum {
    nixos,
    guix,
    gobolinux,
    other,
};

// https://old.reddit.com/r/linuxquestions/comments/62g28n/deleted_by_user/dfmjht6/
fn detectDistro() Distro {
    if (std.os.getenv("LOADER_DISTRO_OVERRIDE")) |env| {
        return std.meta.stringToEnum(Distro, env) orelse .other;
    }

    // This usually works, anything else is a fallback
    if (OsRelease.init()) |distro| {
        if (distro.id) |id| {
            log.info("detected linux distribution: {s}", .{distro.pretty_name orelse distro.name orelse id});
            if (std.meta.stringToEnum(Distro, id)) |d| return d;
            return .other;
        }
    }

    if (std.fs.accessAbsolute("/run/current-system/nixos-version", .{ .mode = .read_only })) {
        log.info("detected linux distribution: {s}", .{@tagName(.nixos)});
        return .nixos;
    } else |_| {}

    if (std.fs.accessAbsolute("/etc/GoboLinuxVersion", .{ .mode = .read_only })) {
        log.info("detected linux distribution: {s}", .{@tagName(.gobolinux)});
        return .gobolinux;
    } else |_| {}

    log.warn("unknown linux distribution", .{});
    return .other;
}

const StoreIterator = struct {
    iter: std.mem.TokenIterator(u8, .scalar),

    pub fn init(store: []const u8) @This() {
        return .{ .iter = std.mem.tokenizeScalar(u8, store, '\n') };
    }

    pub fn findNext(self: *@This(), needle: []const u8) ?[]const u8 {
        while (self.iter.next()) |path| if (std.mem.count(u8, path, needle) > 0) return path;
        return null;
    }

    pub fn get(allocator: std.mem.Allocator, store: []const u8, needle: []const u8, component: []const u8) ![]const u8 {
        var iter = StoreIterator.init(store);
        var tmp: std.ArrayListUnmanaged(u8) = .{};
        defer tmp.deinit(allocator);
        while (iter.findNext(needle)) |path| {
            try tmp.resize(allocator, 0);
            try tmp.writer(allocator).print("{s}/{s}", .{ path, component });
            if (std.fs.accessAbsolute(path, .{ .mode = .read_only })) {
                return try tmp.toOwnedSlice(allocator);
            } else |_| {}
        }
        log.err("could not find {s} from the store", .{needle});
        return error.StoreGetFailed;
    }
};

const SearchPath = struct {
    bytes: std.ArrayListUnmanaged(u8) = .{},

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
    }

    pub fn append(self: *@This(), allocator: std.mem.Allocator, path: []const u8) !bool {
        if (self.bytes.items.len > 0) {
            if (std.mem.count(u8, self.bytes.items, path) > 0) return true;
            if (std.meta.isError(std.fs.accessAbsolute(path, .{ .mode = .read_only }))) return false;
            try self.bytes.append(allocator, ':');
        }
        try self.bytes.appendSlice(allocator, path);
        return true;
    }

    pub fn appendWithPathComponent(self: *@This(), allocator: std.mem.Allocator, path: []const u8, component: []const u8) !bool {
        const buf = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, component });
        defer allocator.free(buf);
        return try self.append(allocator, buf);
    }
};

const SearchPathIterator = struct {
    paths: std.mem.TokenIterator(u8, .scalar),

    pub fn initEnv(env: []const u8) @This() {
        return .{ .paths = std.mem.tokenizeScalar(u8, std.os.getenv(env) orelse "", ':') };
    }

    pub fn initPath(path: []const u8) @This() {
        return .{ .paths = std.mem.tokenizeScalar(u8, path, ':') };
    }

    pub fn next(self: *@This()) ?[]const u8 {
        return self.paths.next();
    }
};

const SonameIterator = struct {
    iter: std.mem.TokenIterator(u8, .scalar),

    pub fn init(sonames: []const u8) @This() {
        return .{ .iter = std.mem.tokenizeScalar(u8, sonames, 0) };
    }

    pub fn next(self: *@This(), as_base: bool) ?[]const u8 {
        const ignored: []const []const u8 = &.{
            "libm", "libpthread", "libc", "libdl",
        };

        while (self.iter.next()) |soname| {
            var split = std.mem.splitScalar(u8, soname, '.');
            const base = split.first();

            if (std.mem.count(u8, base, "ld-linux-") > 0) {
                continue;
            }

            const is_ignored = blk: {
                inline for (ignored) |ignore| {
                    if (std.mem.eql(u8, base, ignore)) break :blk true;
                }
                break :blk false;
            };

            if (is_ignored) {
                continue;
            }

            return if (as_base) base else soname;
        }

        return null;
    }
};

fn runCmd(allocator: std.mem.Allocator, cmd: []const u8) ![]const u8 {
    const rr = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "sh", "-c", cmd },
        .max_output_bytes = std.math.maxInt(usize) / 2,
    }) catch |err| {
        log.err("failed to execute: {s}", .{cmd});
        return err;
    };
    errdefer allocator.free(rr.stdout);
    defer allocator.free(rr.stderr);
    switch (rr.term) {
        .Exited => |code| {
            if (code != 0) {
                log.err("exit code ({d}): {s}", .{ code, cmd });
                return error.RunCmdFailed;
            }
        },
        .Signal, .Unknown, .Stopped => {
            log.err("execution ended unexpectedly: {s}", .{cmd});
            return error.RunCmdFailed;
        },
    }
    return rr.stdout;
}

fn getSonames(allocator: std.mem.Allocator, grep: []const u8, path: []const u8) ![]const u8 {
    // TODO: do this without grep
    const cmd = try std.fmt.allocPrint(allocator, "{s} -a --null-data -o '.*[.]so[.0-9]*$' {s}", .{ grep, path });
    defer allocator.free(cmd);
    return runCmd(allocator, cmd);
}

fn setupLinux(allocator: std.mem.Allocator, bin: []const u8) !void {
    if (builtin.link_mode != .Static) {
        std.log.warn("the binary isn't statically linked, compatibility in different environments is worsened", .{});
    }

    var ld_library_path: SearchPath = .{};
    defer ld_library_path.deinit(allocator);

    if (std.os.getenv("LD_LIBRARY_PATH")) |path0| if (path0.len > 0) {
        _ = try ld_library_path.append(allocator, path0);
    };
    const orig_ld_path_len = ld_library_path.bytes.items.len;

    // NixOS, Guix and GoboLinux are to my knowledge the only non-FHS Linux distros
    // However GoboLinux apparently has FHS compatibility, so it probably works OOB?
    switch (detectDistro()) {
        .nixos => {
            log.info("setting up a {s} runtime ...", .{@tagName(.nixos)});

            // packages that match a soname don't have to be included
            // this list only includes common libs for doing multimedia stuff on linux
            const map = std.comptime_string_map.ComptimeStringMap([]const u8, .{
                .{ "libvulkan", "vulkan-loader" },
                .{ "libGL", "libglvnd" },
                .{ "libEGL", "libglvnd" },
                .{ "libGLdispatch", "libglvnd" },
                .{ "libGLES_CM", "libglvnd" },
                .{ "libGLESv1_CM", "libglvnd" },
                .{ "libGLESv2", "libglvnd" },
                .{ "libGLX", "libglvnd" },
                .{ "libOSMesa", "mesa" },
                .{ "libOpenGL", "libglvnd" },
                .{ "libX11-xcb", "libX11" },
                .{ "libwayland-client", "wayland" },
                .{ "libwayland-cursor", "wayland" },
                .{ "libwayland-server", "wayland" },
                .{ "libwayland-egl", "wayland" },
                .{ "libdecor-0", "libdecor" },
                .{ "libgamemode", "gamemode" },
                .{ "libasound", "alsa-lib" },
                .{ "libjack", "jack-libs:pipewire:libjack2" },
                .{ "pipewire", "pipewire" },
                .{ "pulse", "libpulseaudio:pulseaudio" },
                // below here really should be statically linked or bundled
                .{ "libgtk-4", "gtk4" },
                .{ "libgtk-3", "gtk+3" },
                .{ "libgdk-3", "gtk+3" },
                .{ "libgtk-x11", "gtk+" },
                .{ "libgdk-x11", "gtk+" },
                .{ "libQt6Core", "qtbase" },
                .{ "libQt5Core", "qtbase" },
                .{ "libavcodec", "ffmpeg" },
                .{ "libavdevice", "ffmpeg" },
                .{ "libavformat", "ffmpeg" },
                .{ "libavutil", "ffmpeg" },
                .{ "libpostproc", "ffmpeg" },
                .{ "libswresample", "ffmpeg" },
                .{ "libswscale", "ffmpeg" },
                .{ "libopusfile", "opusfile" },
                .{ "libopusurl", "opusfile" },
                .{ "libSDL", "SDL" },
                .{ "libSDL_mixer", "SDL_mixer" },
                .{ "libSDL_ttf", "SDL_ttf" },
                .{ "libSDL_image", "SDL_image" },
                .{ "libSDL2-2", "SDL2" },
                .{ "libSDL2_mixer", "SDL2_mixer" },
                .{ "libSDL2_ttf", "SDL2_ttf" },
                .{ "libSDL2_image", "SDL2_image" },
                .{ "libglfw", "glfw" },
            });

            const store = try runCmd(allocator, "/run/current-system/sw/bin/nix-store -q --requisites /run/current-system");
            defer allocator.free(store);

            const grep = try StoreIterator.get(allocator, store, "-gnugrep-", "bin/grep");
            defer allocator.free(grep);

            const sonames = try getSonames(allocator, grep, bin);
            defer allocator.free(sonames);

            var needle: std.ArrayListUnmanaged(u8) = .{};
            defer needle.deinit(allocator);

            var so_iter = SonameIterator.init(sonames);
            while (so_iter.next(true)) |soname| {
                const pkgs = std.fs.path.basename(map.get(soname) orelse soname);
                var found_any = false;
                var pkgs_iter = SearchPathIterator.initPath(pkgs);
                while (pkgs_iter.next()) |pkg| {
                    try needle.resize(allocator, 0);
                    try needle.writer(allocator).print("-{s}-", .{pkg});
                    var iter = StoreIterator.init(store);
                    while (iter.findNext(needle.items)) |path| {
                        if (try ld_library_path.appendWithPathComponent(allocator, path, "lib")) {
                            found_any = true;
                        }
                    }
                }

                if (!found_any) {
                    log.warn("missing library: {s}", .{soname});
                }
            }
        },
        .guix => {
            log.info("setting up a {s} runtime ...", .{@tagName(.guix)});

            // I'm not sure if this is okay, but guix seems to not be so opposed to global env like nix is
            // And this path at least in guix live cd has mostly everything neccessary
            _ = try ld_library_path.append(allocator, "/run/current-system/profile/lib");

            const sonames = try getSonames(allocator, "/run/current-system/profile/bin/grep", bin);
            defer allocator.free(sonames);

            var needle: std.ArrayListUnmanaged(u8) = .{};
            defer needle.deinit(allocator);

            // loop the sonames though to let guix user know if there's any missing libraries
            var so_iter = SonameIterator.init(sonames);
            while (so_iter.next(false)) |soname| {
                try needle.resize(allocator, 0);
                try needle.writer(allocator).print("/run/current-system/profile/lib/{s}", .{soname});
                if (std.fs.accessAbsolute(needle.items, .{ .mode = .read_only })) {
                    continue;
                } else |_| {}
                log.warn("missing library: {s}", .{soname});
            }
        },
        .gobolinux, .other => {},
    }

    if (ld_library_path.bytes.items.len != orig_ld_path_len) {
        try setenv("LD_LIBRARY_PATH", ld_library_path.bytes.items);
        log.info("LD_LIBRARY_PATH={s}", .{ld_library_path.bytes.items});
    }
}

pub fn setup(allocator: std.mem.Allocator, bin: ?[]const u8) !void {
    switch (builtin.os.tag) {
        inline .linux => try setupLinux(allocator, bin orelse "/proc/self/exe"),
        inline else => {},
    }
}

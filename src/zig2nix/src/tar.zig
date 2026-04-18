const std = @import("std");

// Not same as std, fixes path traversal exploit
pub fn pipeToFileSystem(dir: std.fs.Dir, reader: *std.Io.Reader, options: std.tar.PipeOptions) !void {
    var file_name_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var link_name_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var file_contents_buffer: [1024]u8 = undefined;
    var it: std.tar.Iterator = .init(reader, .{
        .file_name_buffer = &file_name_buffer,
        .link_name_buffer = &link_name_buffer,
        .diagnostics = options.diagnostics,
    });

    while (try it.next()) |file| {
        const file_name = stripComponents(file.name, options.strip_components);
        if (isBadFilename(file_name)) return error.TarBadFilename;
        if (file_name.len == 0 and file.kind != .directory) {
            const d = options.diagnostics orelse return error.TarComponentsOutsideStrippedPrefix;
            try d.errors.append(d.allocator, .{ .components_outside_stripped_prefix = .{
                .file_name = try d.allocator.dupe(u8, file.name),
            } });
            continue;
        }

        switch (file.kind) {
            .directory => {
                if (file_name.len > 0 and !options.exclude_empty_directories) {
                    try dir.makePath(file_name);
                }
            },
            .file => {
                if (createDirAndFile(dir, file_name, fileMode(file.mode, options))) |fs_file| {
                    defer fs_file.close();
                    var file_writer = fs_file.writer(&file_contents_buffer);
                    try it.streamRemaining(file, &file_writer.interface);
                    try file_writer.interface.flush();
                } else |err| {
                    const d = options.diagnostics orelse return err;
                    try d.errors.append(d.allocator, .{ .unable_to_create_file = .{
                        .code = err,
                        .file_name = try d.allocator.dupe(u8, file_name),
                    } });
                }
            },
            .sym_link => {
                const link_name = file.link_name;
                createDirAndSymlink(dir, link_name, file_name) catch |err| {
                    const d = options.diagnostics orelse return error.UnableToCreateSymLink;
                    try d.errors.append(d.allocator, .{ .unable_to_create_sym_link = .{
                        .code = err,
                        .file_name = try d.allocator.dupe(u8, file_name),
                        .link_name = try d.allocator.dupe(u8, link_name),
                    } });
                };
            },
        }
    }
}

fn isBadFilename(filename: []const u8) bool {
    if (filename.len == 0 or filename[0] == '/')
        return true;

    var it = std.mem.splitScalar(u8, filename, '/');
    while (it.next()) |part| {
        if (std.mem.eql(u8, part, ".."))
            return true;
    }

    return false;
}

fn createDirAndFile(dir: std.fs.Dir, file_name: []const u8, mode: std.fs.File.Mode) !std.fs.File {
    const fs_file = dir.createFile(file_name, .{ .exclusive = true, .mode = mode }) catch |err| {
        if (err == error.FileNotFound) {
            if (std.fs.path.dirname(file_name)) |dir_name| {
                try dir.makePath(dir_name);
                return try dir.createFile(file_name, .{ .exclusive = true, .mode = mode });
            }
        }
        return err;
    };
    return fs_file;
}

// Creates a symbolic link at path `file_name` which points to `link_name`.
fn createDirAndSymlink(dir: std.fs.Dir, link_name: []const u8, file_name: []const u8) !void {
    dir.symLink(link_name, file_name, .{}) catch |err| {
        if (err == error.FileNotFound) {
            if (std.fs.path.dirname(file_name)) |dir_name| {
                try dir.makePath(dir_name);
                return try dir.symLink(link_name, file_name, .{});
            }
        }
        return err;
    };
}

fn stripComponents(path: []const u8, count: u32) []const u8 {
    var i: usize = 0;
    var c = count;
    while (c > 0) : (c -= 1) {
        if (std.mem.indexOfScalarPos(u8, path, i, '/')) |pos| {
            i = pos + 1;
        } else {
            i = path.len;
            break;
        }
    }
    return path[i..];
}

const default_mode = std.fs.File.default_mode;

// File system mode based on tar header mode and mode_mode options.
fn fileMode(mode: u32, options: std.tar.PipeOptions) std.fs.File.Mode {
    if (!std.fs.has_executable_bit or options.mode_mode == .ignore)
        return default_mode;

    const S = std.posix.S;

    // The mode from the tar file is inspected for the owner executable bit.
    if (mode & S.IXUSR == 0)
        return default_mode;

    // This bit is copied to the group and other executable bits.
    // Other bits of the mode are left as the default when creating files.
    return default_mode | S.IXUSR | S.IXGRP | S.IXOTH;
}

//! Read and parse the /etc/os-release file
//! https://www.freedesktop.org/software/systemd/man/latest/os-release.html

const std = @import("std");

pub const Error = std.io.AnyReader.Error || std.mem.Allocator.Error;
pub const FileError = std.fs.File.OpenError || std.fs.File.ReadError || Error;

/// Buffer that actually holds the memory
buffer: []const u8,
/// A string identifying the operating system, without a version component, and suitable for presentation to the user.
/// If not set, a default of "NAME=Linux" may be used.
/// Examples: "NAME=Fedora", "NAME="Debian GNU/Linux"".
name: ?[]const u8 = null,
/// A lower-case string (no spaces or other characters outside of 0–9, a–z, ".", "_" and "-") identifying the operating system,
/// excluding any version information and suitable for processing by scripts or usage in generated filenames.
/// If not set, a default of "ID=linux" may be used.
/// Note that even though this string may not include characters that require shell quoting, quoting may nevertheless be used.
/// Examples: "ID=fedora", "ID=debian".
id: ?[]const u8 = null,
/// A space-separated list of operating system identifiers in the same syntax as the ID= setting.
/// Examples: for an operating system with "ID=centos", an assignment of "ID_LIKE="rhel fedora"" would be appropriate.
/// For an operating system with "ID=ubuntu", an assignment of "ID_LIKE=debian" is appropriate.
id_like: ?[]const u8 = null,
/// A pretty operating system name in a format suitable for presentation to the user.
/// May or may not contain a release code name or OS version of some kind, as suitable.
/// If not set, a default of "PRETTY_NAME="Linux"" may be used
/// Example: "PRETTY_NAME="Fedora 17 (Beefy Miracle)"".
pretty_name: ?[]const u8 = null,
/// A CPE name for the operating system, in URI binding syntax, following the Common Platform Enumeration Specification as proposed by the NIST.
/// This field is optional.
/// Example: "CPE_NAME="cpe:/o:fedoraproject:fedora:17""
cpe_name: ?[]const u8 = null,
/// A string identifying a specific variant or edition of the operating system suitable for presentation to the user.
/// This field may be used to inform the user that the configuration of this system is subject to a specific divergent set of rules or default configuration settings.
/// This field is optional and may not be implemented on all systems.
/// Examples: "VARIANT="Server Edition"", "VARIANT="Smart Refrigerator Edition"".
/// Note: this field is for display purposes only. The VARIANT_ID field should be used for making programmatic decisions.
variant: ?[]const u8 = null,
/// A lower-case string (no spaces or other characters outside of 0–9, a–z, ".", "_" and "-"), identifying a specific variant or edition of the operating system.
/// This may be interpreted by other packages in order to determine a divergent default configuration.
/// This field is optional and may not be implemented on all systems.
/// Examples: "VARIANT_ID=server", "VARIANT_ID=embedded".
variant_id: ?[]const u8 = null,
/// A string identifying the operating system version, excluding any OS name information, possibly including a release code name, and suitable for presentation to the user.
/// This field is optional.
/// Examples: "VERSION=17", "VERSION="17 (Beefy Miracle)"".
version: ?[]const u8 = null,
/// A lower-case string (mostly numeric, no spaces or other characters outside of 0–9, a–z, ".", "_" and "-") identifying the operating system version,
/// excluding any OS name information or release code name, and suitable for processing by scripts or usage in generated filenames.
/// This field is optional.
/// Examples: "VERSION_ID=17", "VERSION_ID=11.04".
version_id: ?[]const u8 = null,
/// A lower-case string (no spaces or other characters outside of 0–9, a–z, ".", "_" and "-") identifying the operating system release code name,
/// excluding any OS name information or release version, and suitable for processing by scripts or usage in generated filenames.
/// This field is optional and may not be implemented on all systems.
/// Examples: "VERSION_CODENAME=buster", "VERSION_CODENAME=xenial".
version_codename: ?[]const u8 = null,
/// A string uniquely identifying the system image originally used as the installation base.
/// In most cases, VERSION_ID or IMAGE_ID+IMAGE_VERSION are updated when the entire system image is replaced during an update.
/// BUILD_ID may be used in distributions where the original installation image version is important: VERSION_ID would change during incremental system updates, but BUILD_ID would not.
/// This field is optional.
/// Examples: "BUILD_ID="2013-03-20.3"", "BUILD_ID=201303203".
build_id: ?[]const u8 = null,
/// A lower-case string (no spaces or other characters outside of 0–9, a–z, ".", "_" and "-"), identifying a specific image of the operating system.
/// This is supposed to be used for environments where OS images are prepared, built, shipped and updated as comprehensive, consistent OS images.
/// This field is optional and may not be implemented on all systems, in particularly not on those that are not managed via images but put together and updated from individual packages and on the local system.
/// Examples: "IMAGE_ID=vendorx-cashier-system", "IMAGE_ID=netbook-image".
image_id: ?[]const u8 = null,
/// A lower-case string (mostly numeric, no spaces or other characters outside of 0–9, a–z, ".", "_" and "-") identifying the OS image version.
/// This is supposed to be used together with IMAGE_ID described above, to discern different versions of the same image.
/// Examples: "IMAGE_VERSION=33", "IMAGE_VERSION=47.1rc1".
image_version: ?[]const u8 = null,
/// Links to resources on the Internet related to the operating system.
home_url: ?[]const u8 = null,
/// Links to resources on the Internet related to the operating system.
documentation_url: ?[]const u8 = null,
/// Links to resources on the Internet related to the operating system.
support_url: ?[]const u8 = null,
/// Links to resources on the Internet related to the operating system.
bug_report_url: ?[]const u8 = null,
/// Links to resources on the Internet related to the operating system.
privacy_policy_url: ?[]const u8 = null,
/// The date at which support for this version of the OS ends.
/// (What exactly "lack of support" means varies between vendors, but generally users should assume that updates, including security fixes, will not be provided.)
/// The value is a date in the ISO 8601 format "YYYY-MM-DD", and specifies the first day on which support is not provided.
/// For example, "SUPPORT_END=2001-01-01" means that the system was supported until the end of the last day of the previous millennium.
support_end: ?[]const u8 = null,
/// A string, specifying the name of an icon as defined by freedesktop.org Icon Theme Specification.
/// This can be used by graphical applications to display an operating system's or distributor's logo.
/// This field is optional and may not necessarily be implemented on all systems.
/// Examples: "LOGO=fedora-logo", "LOGO=distributor-logo-opensuse"
logo: ?[]const u8 = null,
/// A suggested presentation color when showing the OS name on the console.
/// This should be specified as string suitable for inclusion in the ESC [ m ANSI/ECMA-48 escape code for setting graphical rendition.
/// This field is optional.
/// Examples: "ANSI_COLOR="0;31"" for red, "ANSI_COLOR="1;34"" for light blue, or "ANSI_COLOR="0;38;2;60;110;180"" for Fedora blue.
ansi_color: ?[]const u8 = null,
/// The name of the OS vendor. This is the name of the organization or company which produces the OS.
/// This field is optional.
/// This name is intended to be exposed in "About this system" UIs or software update UIs when needed to distinguish the OS vendor from the OS itself.
/// It is intended to be human readable.
/// Examples: "VENDOR_NAME="Fedora Project"" for Fedora Linux, "VENDOR_NAME="Canonical"" for Ubuntu.
vendor_name: ?[]const u8 = null,
/// The homepage of the OS vendor. This field is optional.
/// The VENDOR_NAME= field should be set if this one is, although clients must be robust against either field not being set.
/// The value should be in RFC3986 format, and should be "http:" or "https:" URLs. Only one URL shall be listed in the setting.
/// Examples: "VENDOR_URL="https://fedoraproject.org/"", "VENDOR_URL="https://canonical.com/"".
vendor_url: ?[]const u8 = null,
/// A string specifying the hostname if hostname(5) is not present and no other configuration source specifies the hostname.
/// Must be either a single DNS label (a string composed of 7-bit ASCII lower-case characters and no spaces or dots,
/// limited to the format allowed for DNS domain name labels), or a sequence of such labels separated by single dots that forms a valid DNS FQDN.
/// The hostname must be at most 64 characters, which is a Linux limitation (DNS allows longer names).
/// See org.freedesktop.hostname1(5) for a description of how systemd-hostnamed.service(8) determines the fallback hostname.
default_hostname: ?[]const u8 = null,
/// A string that specifies which CPU architecture the userspace binaries require.
/// The architecture identifiers are the same as for ConditionArchitecture= described in systemd.unit(5).
/// The field is optional and should only be used when just single architecture is supported.
/// It may provide redundant information when used in a GPT partition with a GUID type that already encodes the architecture.
/// If this is not the case, the architecture should be specified in e.g., an extension image, to prevent an incompatible host from loading it.
architecture: ?[]const u8 = null,
/// A lower-case string (mostly numeric, no spaces or other characters outside of 0–9, a–z, ".", "_" and "-") identifying the operating system extensions support level, to indicate which extension images are supported.
/// See /usr/lib/extension-release.d/extension-release.IMAGE, initrd and systemd-sysext(8)) for more information.
/// Examples: "SYSEXT_LEVEL=2", "SYSEXT_LEVEL=15.14".
sysext_level: ?[]const u8 = null,
/// Semantically the same as SYSEXT_LEVEL= but for confext images.
/// See /etc/extension-release.d/extension-release.IMAGE for more information.
/// Examples: "CONFEXT_LEVEL=2", "CONFEXT_LEVEL=15.14".
confext_level: ?[]const u8 = null,
/// Takes a space-separated list of one or more of the strings "system", "initrd" and "portable".
/// This field is only supported in extension-release.d/ files and indicates what environments the system extension is applicable to: i.e. to regular systems, to initrds, or to portable service images.
/// If unspecified, "SYSEXT_SCOPE=system portable" is implied, i.e. any system extension without this field is applicable to regular systems and to portable service environments, but not to initrd environments.
sysext_scope: ?[]const u8 = null,
/// Semantically the same as SYSEXT_SCOPE= but for confext images.
confext_scope: ?[]const u8 = null,
/// Takes a space-separated list of one or more valid prefix match strings for the Portable Services logic.
/// This field serves two purposes: it is informational, identifying portable service images as such (and thus allowing them to be distinguished from other OS images, such as bootable system images).
/// It is also used when a portable service image is attached: the specified or implied portable service prefix is checked against the list specified here, to enforce restrictions how images may be attached to a system.
portable_prefixes: ?[]const u8 = null,

/// Initialize from a unmanaged buffer
pub fn initFromContentsUnmanaged(buffer: []const u8) @This() {
    var self: @This() = .{ .buffer = buffer };
    var tokens = std.mem.splitAny(u8, self.buffer, "=\n");
    while (tokens.next()) |key| if (tokens.next()) |value| {
        inline for (std.meta.fields(@This())) |f| {
            if (comptime !std.mem.eql(u8, f.name, "buffer")) {
                const upper: [f.name.len]u8 = blk: {
                    @setEvalBranchQuota(f.name.len * 1000);
                    comptime var upper: [f.name.len]u8 = undefined;
                    _ = comptime std.ascii.upperString(&upper, f.name);
                    break :blk upper;
                };
                if (std.mem.eql(u8, &upper, key)) {
                    const stripped = if (value.len > 0 and value[0] == '"') value[1 .. value.len - 1] else value;
                    if (stripped.len > 0) @field(self, f.name) = stripped;
                }
            }
        }
    };
    return self;
}

/// Reads from a `std.io.AnyReader`
pub fn initFromAnyReader(allocator: std.mem.Allocator, reader: std.io.AnyReader) Error!@This() {
    return initFromContentsUnmanaged(try reader.readAllAlloc(allocator, 4e+6));
}

/// Reads from a anytype reader
pub fn initFromReader(allocator: std.mem.Allocator, reader: anytype) Error!@This() {
    return initFromContentsUnmanaged(try reader.readAllAlloc(allocator, 4e+6));
}

/// Reads from a custom path
pub fn initFromPath(allocator: std.mem.Allocator, path: []const u8) FileError!@This() {
    const f = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
    defer f.close();
    return initFromReader(allocator, f.reader());
}

/// Reads from the standard path "/etc/os-release"
pub fn init(allocator: std.mem.Allocator) FileError!@This() {
    return initFromPath(allocator, "/etc/os-release") catch initFromPath(allocator, "/usr/lib/os-release");
}

/// Only call this if you did not use initFromContentsUnmanaged directly
/// Or if you are fine with the buffer passed to that init method being freed
pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    allocator.free(self.buffer);
    self.* = undefined;
}

test "OsRelease" {
    const buf =
        \\ANSI_COLOR="1;34"
        \\BUG_REPORT_URL="https://github.com/NixOS/nixpkgs/issues"
        \\BUILD_ID="24.05.20240210.d934204"
        \\DOCUMENTATION_URL="https://nixos.org/learn.html"
        \\HOME_URL="https://nixos.org/"
        \\ID=nixos
        \\IMAGE_ID=""
        \\IMAGE_VERSION=""
        \\LOGO="nix-snowflake"
        \\NAME=NixOS
        \\PRETTY_NAME="NixOS 24.05 (Uakari)"
        \\SUPPORT_URL="https://nixos.org/community.html"
        \\VERSION="24.05 (Uakari)"
        \\VERSION_CODENAME=uakari
        \\VERSION_ID="24.05"
    ;
    const distro = initFromContentsUnmanaged(buf);
    try std.testing.expectEqualSlices(u8, "1;34", distro.ansi_color.?);
    try std.testing.expectEqualSlices(u8, "https://github.com/NixOS/nixpkgs/issues", distro.bug_report_url.?);
    try std.testing.expectEqualSlices(u8, "24.05.20240210.d934204", distro.build_id.?);
    try std.testing.expectEqualSlices(u8, "https://nixos.org/learn.html", distro.documentation_url.?);
    try std.testing.expectEqualSlices(u8, "https://nixos.org/", distro.home_url.?);
    try std.testing.expectEqualSlices(u8, "nixos", distro.id.?);
    try std.testing.expectEqual(null, distro.image_id);
    try std.testing.expectEqual(null, distro.image_version);
    try std.testing.expectEqualSlices(u8, "nix-snowflake", distro.logo.?);
    try std.testing.expectEqualSlices(u8, "NixOS", distro.name.?);
    try std.testing.expectEqualSlices(u8, "NixOS 24.05 (Uakari)", distro.pretty_name.?);
    try std.testing.expectEqualSlices(u8, "https://nixos.org/community.html", distro.support_url.?);
    try std.testing.expectEqualSlices(u8, "24.05 (Uakari)", distro.version.?);
    try std.testing.expectEqualSlices(u8, "uakari", distro.version_codename.?);
    try std.testing.expectEqualSlices(u8, "24.05", distro.version_id.?);

    if (std.fs.accessAbsolute("/etc/os-release", .{ .mode = .read_only })) {
        var lel = try init(std.testing.allocator);
        lel.deinit(std.testing.allocator);
    } else |_| {}
}

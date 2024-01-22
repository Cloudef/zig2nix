{ lib }:

with builtins;
with lib;
with lib.attrsets;

let
  # only do simple conversion in this function
  mk-triple = arch: kernel: vendor: abis: mergeAttrsList (map (abi: let
    zig-arch = if isString arch then arch else arch.zig or (throw "invalid arch argument");

    zig2nix-arch = {
      x86 = "i686";
      arm = "armv7a";
    }.${zig-arch} or zig-arch;

    nix-arch = if isString arch then zig2nix-arch else arch.nix or zig2nix-arch;

    zig-kernel = if isString kernel then kernel else kernel.zig or (throw "invalid kernel argument");

    zig2nix-kernel = {
      macos = "darwin";
      freestanding = "none";
    }.${zig-kernel} or zig-kernel;

    nix-kernel = if isString kernel then zig2nix-kernel else kernel.nix or zig2nix-kernel;

    zig-abi = if isString abi then abi else abi.zig or (throw "invalid abi argument");
    nix-abi = if isString abi then zig-abi else abi.nix or zig-abi;
    opt-nix-abi = if nix-abi != "none" then "-${nix-abi}" else "";
  in if vendor !=  null then {
    "${zig-arch}-${zig-kernel}-${zig-abi}" = "${nix-arch}-${vendor}-${nix-kernel}${opt-nix-abi}";
  } else {
    "${zig-arch}-${zig-kernel}-${zig-abi}" = "${nix-arch}-${nix-kernel}-${nix-abi}";
  }) abis);

  from-archs = kernel: vendor: archs: abis: mergeAttrsList (map (arch: mk-triple arch kernel vendor abis) archs);

  # nix unsupported archs: csky, armeb, thumb, gnux32, muslx32
  # broken archs: arm, aarch64_be (windows, unsupported arch), m68k (InvalidLlvmTriple), sparc, s390x (support lib)
  # broken platforms: ios, watchos, tvos, risv64-gnu (gnu/stubs-lp64d.h)
  # broken abis: gnuabin32 (support lib)
  zig2nix-target = {}
  // from-archs "linux" "unknown" [ "riscv64" ] [ "musl" ]
  // from-archs "linux" "unknown" [ "x86_64" ] [ "gnu" "musl" ]
  // from-archs "linux" "unknown" [ "x86" ] [ "gnu" "musl" ]
  // from-archs "linux" "unknown" [ "aarch64" "aarch64_be" ] [ "gnu" "musl" ]
  // from-archs "linux" "unknown" [ "arm" ] [ "gnueabi" "gnueabihf" "musleabi" "musleabihf" ]
  // from-archs "linux" "unknown" [ "mips64el" "mips64" ] [ "gnuabi64" "musl" ]
  // from-archs "linux" "unknown" [ "mipsel" "mips" ] [ "gnueabi" "gnueabihf" "musl" ]
  // from-archs "linux" "unknown" [ "powerpc64" ] [ { zig = "gnu"; nix = "gnuabielfv2"; } "musl" ]
  // from-archs "linux" "unknown" [ "powerpc64le" ] [ "gnu" "musl" ]
  // from-archs "linux" "unknown" [ "powerpc" ] [ "gnueabi" "gnueabihf" "musl" ]
  # // from-archs "linux" "unknown" [ "csky" ] [ "gnueabi" "gnueabihf" ]
  # // from-archs "linux" "unknown" [ "s390x" ] [ "gnu" "musl" ]
  # // from-archs "linux" "unknown" [ "sparc" "sparc64" ] [ "gnu" ]
  // from-archs "windows" "pc" [ "x86" "x86_64" "aarch64" ] [ "msvc" ]
  # maps to autotools mingw target triples
  // from-archs { zig = "windows"; nix = "w64"; } null [ "x86" "x86_64" "aarch64" ] [ { zig = "gnu"; nix = "mingw32"; } ]
  // from-archs "macos" "apple" [ "x86_64" "aarch64" ] [ "none" ]
  # // from-archs "ios" "apple" [ "x86_64" "aarch64" ] [ "none" ]
  # // from-archs "watchos" "apple" [ "x86_64" "aarch64" ] [ "none" ]
  # // from-archs "tvos" "apple" [ "x86_64" "aarch64" ] [ "none" ]
  // from-archs "wasi" "unknown" [ "wasm32" ] [ "musl" ];

  allTargetTriples = attrNames zig2nix-target;

  nix2zig-target = mergeAttrsList (map (k: {
    "${zig2nix-target.${k}}" = "${k}";
  }) allTargetTriples) // {
    # map flake targets
    "armv5tel-unknown-linux-gnueabi" = "arm-linux-gnueabi";
    "armv6l-unknown-linux-gnueabihf" = "arm-linux-gnueabihf";
    "armv7l-unknown-linux-gnueabihf" = "arm-linux-gnueabihf";
    "mipsel-unknown-linux-gnu" = "mipsel-linux-gnueabi";
    "powerpc64le-unknown-linux-gnu" = "powerpc64le-linux-gnu";
  };

  broken = [ "riscv64-linux" ];
  allFlakeTargetTriples = map (f: nix2zig-target.${(systems.elaborate f).config}) (subtractLists broken systems.flakeExposed);

  normalized-target = s: let
    n = concatStringsSep "-" (map (c: elemAt (splitString "." c) 0) (splitString "-" s));
    elaborated = (systems.elaborate n).config;
  in
    if (zig2nix-target.${n} or null) != null then n
    else if (nix2zig-target.${n} or null) != null then nix2zig-target.${n}
    else nix2zig-target.${elaborated} or (throw "invalid target string ${s}");

  zig-meta = s: let
    n0 = concatStringsSep "-" (map (c: elemAt (splitString "." c) 0) (splitString "-" s));
    n = if (zig2nix-target.${n0} or null) != null then s else normalized-target s;
    parts = splitString "-" n;
    meta = s: d: let
      splitted = splitString "." s;
    in {
      base = elemAt splitted 0;
      meta = if length splitted > 1 then elemAt splitted 1 else d;
    };
  in rec {
    cpu = elemAt parts 0;
    kernel = elemAt parts 1;
    abi = elemAt parts 2;
    versionlessKernel = (meta kernel null).base;
    kernelVersion = let
      default = {
        freebsd = "13";
      }.${versionlessKernel} or null;
    in (meta kernel default).meta;
    supportStaticLinking = any (p: p == versionlessKernel) [ "macos" "ios" "watchos" "tvos" ];
  };
in rec {
  mkZigSystemFromString = s: let
    n = normalized-target s;
    system = systems.parse.mkSystemFromString zig2nix-target.${n};
  in system // { zig = zig-meta s; };

  mkZigSystemFromPlatform = p: let
    system = mkZigSystemFromString p.config;
  in {
    darwin = let
      sdkVer =
        if (versionAtLeast p.darwinSdkVersion "10.13") then p.darwinSdkVersion
        else warn "zig only supports macOS 10.13+, forcing SDK 11.0" "11.0";
    in mkZigSystemFromString "${system.zig.cpu}-${system.zig.kernel}.${sdkVer}-${system.zig.abi}";
  }.${system.kernel.name} or system;

  zigTripleFromSystem = system: "${system.zig.cpu}-${system.zig.kernel}-${system.zig.abi}";
  zigDoubleFromSystem = system: "${system.zig.cpu}-${system.zig.kernel}";
  zigTripleFromString = s: zigTripleFromSystem (mkZigSystemFromString s);
  zigDoubleFromString = s: zigDoubleFromSystem (mkZigSystemFromString s);

  nixTripleFromSystem = s: zig2nix-target.${normalized-target (zigTripleFromSystem s)};
  nixDoubleFromSystem = systems.parse.doubleFromSystem;
  nixTripleFromString = s: zig2nix-target.${normalized-target s};
  nixDoubleFromString = s: nixDoubleFromSystem (mkZigSystemFromString s);

   # helpers for resolving the final target and system for building a package from derivation attrs
  resolveTargetSystem = { target ? null, platform ? null, musl ? false }: let
    resolved =
      if target != null then mkZigSystemFromString target
        else if platform != null then mkZigSystemFromPlatform platform
        else throw "either target or platform must be specified";
  in resolved // optionalAttrs (musl && resolved.zig.kernel == "linux") {
    abi = resolved.abi // {
      name = replaceStrings [ "gnu" "uclibc" ] [ "musl" "musl" ] resolved.abi.name;
    };
    zig = resolved.zig // {
      abi = replaceStrings [ "gnu" ] [ "musl" ] resolved.zig.abi;
    };
  };

  resolveTargetTriple = args: zigTripleFromSystem (resolveTargetSystem args);

  inherit allFlakeTargetTriples;
  allFlakeTargetSystems = map (s: mkZigSystemFromString s) allFlakeTargetTriples;

  inherit allTargetTriples;
  allTargetSystems = map (s: mkZigSystemFromString s) allTargetTriples;
}

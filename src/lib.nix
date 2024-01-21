{ lib }:

with builtins;
with lib;

let
  # Maintain list of doubles here that zigCross can't deal with
  unsupported = [ "riscv64-linux" ];
  flakeDoubles = subtractLists unsupported systems.flakeExposed;
  # Here we can have unsupported doubles as well
  # TODO: Use runCommandLocal and parse zig targets output
  zigDoubles = systems.doubles.all ++ [ "aarch64-ios" "x86_64-ios" ];
  allZigDoubles = zigDoubles ++ flakeDoubles;
in rec {
  mkZigSystemFromString = s: let
    res = tryEval (systems.parse.mkSystemFromString s);
  kind = if res.success then "nix" else "zig";
  in {
    zig = let
      parts = splitString "-" s;

      cpu = elemAt parts 0;

      kernel = {
        "3" = elemAt parts 1;
      }.${toString (length parts)} or "unknown";

      versionlessKernel = elemAt (splitString "." kernel) 0;

      kernelVersion = let
        splitted = splitString "." kernel;
      default = {
        freebsd = "13";
      }.${versionlessKernel} or null;
      in if length splitted > 1 then elemAt splitted 1 else default;

      abi = {
        "3" = elemAt parts 2;
      }.${toString (length parts)} or (throw "zig target string has invalid number of hyphen-separated components");

      nixCpu = {
        # TODO: how should we get this info
        x86 = "i686";
        arm = "armv7a";
      }.${cpu} or cpu;

      nixKernel = {
        freestanding = "none";
        freebsd = "freebsd${kernelVersion}";
      }.${versionlessKernel} or versionlessKernel;

      nixAbi = {
        none = "unknown";
        gnux32 = throw "nix does not support gnux32";
        muslx32 = throw "nix does not support muslx32";
      }.${abi} or abi;

      nixVendor = {
        windows = if abi == "gnu" then "w64" else "pc";
      }.${versionlessKernel} or null;

      system = systems.parse.mkSystemFromSkeleton ({
        cpu = nixCpu;
        kernel = nixKernel;
        abi = nixAbi;
      } // optionalAttrs (nixVendor != null) {
        vendor = nixVendor;
      });
    in system // {
      zig = {
        inherit cpu kernel versionlessKernel kernelVersion abi;
        supportsStaticLinking = system.kernel.execFormat.name != "macho";
      };
    };

    nix = let
      nixCpu = {
        # TODO: how should we get this info
        arm = "armv7a";
      }.${res.value.cpu.name} or res.value.cpu.name;

      nixKernel = {
        freebsd = "freebsd${toString res.value.kernel.version}";
      }.${res.value.kernel.name} or res.value.kernel.name;

      nixVendor = {
        windows = if res.value.abi.name == "gnu" then "w64" else "pc";
      }.${res.value.kernel.name} or null;

      nixAbi = {
        gnu = rec {
          mips64el = "gnuabi64";
          mips64 = mips64el;
          mipsel = "gnueabi";
          arm = "gnueabi";
          armeb = arm;
          thumb = arm;
          powerpc = "gnueabi";
          csky = "gnueabi";
        }.${nixCpu} or "gnu";

        musl = rec {
          mips64el = "muslabi64";
          mips64 = mips64el;
          mipsel = "musleabi";
          arm = "musleabi";
          armeb = arm;
          thumb = arm;
          powerpc = "musleabi";
          csky = "musleabi";
        }.${nixCpu} or "musl";
      }.${res.value.abi.name} or res.value.abi.name;

      system = systems.parse.mkSystemFromSkeleton ({
        cpu = nixCpu;
        kernel = nixKernel;
        abi = nixAbi;
      } // optionalAttrs (nixVendor != null) {
        vendor = nixVendor;
      });

      zigCpu = {
        # TODO: zig probably should be aware of the variant
        armv5tel = "arm";
        armv6m = "arm";
        armv6l = "arm";
        armv7a = "arm";
        armv7r = "arm";
        armv7m = "arm";
        armv7l = "arm";
        armv8a = "arm";
        armv8r = "arm";
        armv8m = "arm";
        i386 = "x86";
        i686 = "x86";
      }.${system.cpu.name} or system.cpu.name;

      zigKernel = {
        none = "freestanding";
        darwin = "macos";
      }.${system.kernel.name} or system.kernel.name;

      zigAbi = {
        unknown = "none";
      }.${system.abi.name} or system.abi.name;
    in system // {
      zig = {
        cpu = zigCpu;
        kernel = zigKernel;
        versionlessKernel = zigKernel;
        kernelVersion = system.kernel.version or null;
        abi = zigAbi;
        supportsStaticLinking = system.kernel.execFormat.name != "macho";
      };
    };
  }.${kind};

  mkZigSystemFromPlatform = p: let
    system = mkZigSystemFromString p.config;
  in {
    darwin = let
      sdkVer =
        if (versionAtLeast p.darwinSdkVersion "10.13") then p.darwinSdkVersion
        else warn "zig only supports macOS 10.13+, forcing SDK 11.0" "11.0";
    in mkZigSystemFromString "${system.zig.cpu}-${system.zig.kernel}.${sdkVer}-${system.zig.abi}";
  }.${system.kernel.name} or system;

  zigTriplesFromSystem = system: {
    linux = (rec {
      arm = [
        "${system.zig.cpu}-${system.zig.kernel}-gnueabi"
        "${system.zig.cpu}-${system.zig.kernel}-musleabi"
        "${system.zig.cpu}-${system.zig.kernel}-gnueabihf"
        "${system.zig.cpu}-${system.zig.kernel}-musleabihf"
      ];
      armeb = arm;
      thumb = arm;

      mips64el = [
        "${system.zig.cpu}-${system.zig.kernel}-gnuabi64"
        "${system.zig.cpu}-${system.zig.kernel}-gnuabin32"
        "${system.zig.cpu}-${system.zig.kernel}-musl"
      ];
      mips64 = mips64el;

      mipsel = [
        "${system.zig.cpu}-${system.zig.kernel}-gnueabi"
        "${system.zig.cpu}-${system.zig.kernel}-gnueabihf"
        "${system.zig.cpu}-${system.zig.kernel}-musl"
      ];
      mips = mipsel;

      powerpc = mipsel;

      csky = [
        "${system.zig.cpu}-${system.zig.kernel}-gnueabi"
        "${system.zig.cpu}-${system.zig.kernel}-gnueabihf"
      ];

      x86_64 = [
        "${system.zig.cpu}-${system.zig.kernel}-gnu"
        # nix does not support gnux32
        # "${system.zig.cpu}-${system.zig.kernel}-gnux32"
        "${system.zig.cpu}-${system.zig.kernel}-musl"
        # nix does not support muslx32
        # "${system.zig.cpu}-${system.zig.kernel}-muslx32"
      ];
    }.${system.zig.cpu} or [
      "${system.zig.cpu}-${system.zig.kernel}-gnu"
      "${system.zig.cpu}-${system.zig.kernel}-musl"
    ]) ++ [ "${system.zig.cpu}-${system.zig.kernel}-none" ];

    windows = [
      "${system.zig.cpu}-${system.zig.kernel}-msvc"
      "${system.zig.cpu}-${system.zig.kernel}-gnu"
    ];
  }.${system.zig.kernel} or [(zigTripleFromSystem system)];

  zigTripleFromSystem = system: "${system.zig.cpu}-${system.zig.kernel}-${system.zig.abi}";
  zigDoubleFromSystem = system: "${system.zig.cpu}-${system.zig.kernel}";
  zigTriplesFromString = s: zigTriplesFromSystem (mkZigSystemFromString s);
  zigTripleFromString = s: zigTripleFromSystem (mkZigSystemFromString s);
  zigDoubleFromString = s: zigDoubleFromSystem (mkZigSystemFromString s);

  # Unfortunately we have to monkeypatch some triples still for autotools
  nixTripleFromSystem = s: let
    default = systems.parse.tripleFromSystem s;
  in {
    windows = if s.abi.name == "gnu" then "${s.cpu.name}-${s.vendor.name}-mingw32" else default;
  }.${s.kernel.name} or default;

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

  flakeZigTriples = map (d: zigTripleFromString d) flakeDoubles;
  allNixZigTriples = flatten (map (d: zigTriplesFromString d) allZigDoubles);
  allNixZigSystems = map (s: mkZigSystemFromString s) allNixZigTriples;
}

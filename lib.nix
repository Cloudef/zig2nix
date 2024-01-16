{ lib }:

with builtins;
with lib;

rec {
   mkZigSystemFromString = s: let
      res = tryEval (systems.parse.mkSystemFromString s);
   in {
      zig = let
         parts = splitString "-" s;

         cpu = elemAt parts 0;

         kernel = {
            "2" = elemAt parts 1;
            "3" = elemAt parts 1;
            "4" = elemAt parts 2;
         }.${toString (length parts)} or (throw "zig target string has invalid number of hyphen-separated components");

         versionlessKernel = elemAt (splitString "." kernel) 0;

         kernelVersion = let
            splitted = splitString "." kernel;
         in if length splitted > 1 then elemAt splitted 1 else null;

         abi = {
            "2" = "none";
            "3" = elemAt parts 2;
            "4" = elemAt parts 3;
         }.${toString (length parts)} or (throw "zig target string has invalid number of hyphen-separated components");

         nixCpu = {
            x86 = "i686";
         }.${cpu} or cpu;

         nixKernel = {
            freestanding = "none";
         }.${versionlessKernel} or versionlessKernel;

         nixAbi = {
            none = "unknown";
         }.${abi} or abi;

         system = systems.parse.mkSystemFromSkeleton {
            cpu = nixCpu;
            kernel = nixKernel;
            abi = nixAbi;
         };
      in system // {
         zig = {
            inherit cpu kernel versionlessKernel kernelVersion abi;
            supportsStaticLinking = system.kernel.execFormat.name != "macho";
         };
      };

      nix = let
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
         }.${res.value.cpu.name} or res.value.cpu.name;

         zigKernel = {
            none = "freestanding";
            darwin = "macos";
         }.${res.value.kernel.name} or res.value.kernel.name;

         zigAbi = {
            unknown = "none";
         }.${res.value.abi.name} or res.value.abi.name;
      in res.value // {
         zig = {
            cpu = zigCpu;
            kernel = zigKernel;
            versionlessKernel = zigKernel;
            kernelVersion = null;
            abi = zigAbi;
            supportsStaticLinking = res.value.kernel.execFormat.name != "macho";
         };
      };
   }.${if res.success then "nix" else "zig"};

   mkZigSystemFromPlatform = p: let
      system = mkZigSystemFromString p.config;
   in {
      darwin = let
         sdkVer =
            if (versionAtLeast p.darwinSdkVersion "10.13") then p.darwinSdkVersion
            else warn "zig only supports macOS 10.13+, forcing SDK 11.0" "11.0";
      in mkZigSystemFromString "${system.zig.cpu}-${system.zig.kernel}.${sdkVer}-${system.zig.abi}";
   }.${system.kernel.name} or system;

   zigDoubleFromSystem = system: "${system.zig.cpu}-${system.zig.kernel}";
   zigTripleFromSystem = system: "${system.zig.cpu}-${system.zig.kernel}-${system.zig.abi}";
   zigDoubleFromString = s: zigDoubleFromSystem (mkZigSystemFromString s);
   zigTripleFromString = s: zigTripleFromSystem (mkZigSystemFromString s);

   # helpers for resolving the final target and system for building a package from derivation attrs
   resolveTargetSystem = { target ? null, platform ? null, musl ? false }: let
      resolved =
         if target != null then mkZigSystemFromString target
         else if platform != null then mkZigSystemFromPlatform platform
         else throw "either target or platform must be specified";
   in resolved // optionalAttrs (musl) {
      abi = resolved.abi // {
         name = replaceStrings [ "gnu" "uclibc" ] [ "musl" "musl" ] resolved.abi.name;
      };
   };

   resolveTargetTriple = args: zigTripleFromSystem (resolveTargetSystem args);
}

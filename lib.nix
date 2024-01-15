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

         abi = {
            "2" = "none";
            "3" = elemAt parts 2;
            "4" = elemAt parts 3;
         }.${toString (length parts)} or (throw "zig target string has invalid number of hyphen-separated components");

         nixKernel = let
            stripped = elemAt (splitString "." kernel) 0;
         in {
            freestanding = "none";
         }.${stripped} or stripped;

         nixAbi = {
            none = "unknown";
         }.${abi} or abi;

         system = systems.parse.mkSystemFromSkeleton {
            inherit cpu;
            kernel = nixKernel;
            abi = nixAbi;
         };
      in system // {
         zig = {
            inherit cpu kernel abi;
            supportsStaticLinking = system.kernel.execFormat.name != "macho";
         };
      };

      nix = let
         zigKernel = {
            none = "freestanding";
            darwin = "macos";
         }.${res.value.kernel.name} or res.value.kernel.name;

         zigAbi = {
            unknown = "none";
         }.${res.value.abi.name} or res.value.abi.name;
      in res.value // {
         zig = {
            cpu = res.value.cpu.name;
            kernel = zigKernel;
            abi = zigAbi;
            supportsStaticLinking = res.value.kernel.execFormat.name != "macho";
         };
      };
   }.${if res.success then "nix" else "zig"};

   zigDoubleFromSystem = system: "${system.zig.cpu}-${system.zig.kernel}";
   zigTripleFromSystem = system: "${system.zig.cpu}-${system.zig.kernel}-${system.zig.abi}";
   zigDoubleFromString = s: zigDoubleFromSystem (mkZigSystemFromString s);
   zigTripleFromString = s: zigTripleFromSystem (mkZigSystemFromString s);

   zigTripleFromPlatform = p: let
      system = mkZigSystemFromString p.config;
   in {
      darwin = let
         sdkVer =
            if (versionAtLeast p.darwinSdkVersion "10.13") then p.darwinSdkVersion
            else warn "zig only supports macOS 10.13+, forcing SDK 11.0" "11.0";
      in "${system.zig.cpu}-${system.zig.kernel}.${sdkVer}-${system.zig.abi}";
   }.${system.kernel.name} or (zigTripleFromSystem system);

   # helper for resolving final target for building a package from derivation attrs
   resolveTarget = args: let
      target =
         if args ? zig && args.zig != null then zigTripleFromString args.zig
         else if args ? nix && args.nix != null then zigTripleFromString args.nix
         else if args ? platform && args.platform != null then zigTripleFromPlatform args.platform
         else throw "either zig, nix or platform must be specified";
   in if args.musl or false then replaceStrings [ "-gnu" ] [ "-musl" ] target else target;
}

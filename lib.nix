{
   lib
   , runCommandLocal
   , zon2json
}:

with builtins;
with lib;

rec {
   zigTargetToNixTarget = target: let
      kernel = {
         freestanding = l: "${head l}-unknown-none-${last l}";
         linux = l: "${head l}-unknown-linux-${last l}";
         macos = l: "${head l}-apple-darwin";
         windows = l: "${head l}-w64-mingw32";
         wasi = l: "${head l}-unknown-wasi";
      };
      cpu = {
         powerpc64 = s: "${s}abi64";
         sparcv9 = s: "sparc64-${removePrefix "sparcv9-" s}";
         thumb = s: "armv5tel-${removePrefix "thumb-" s}";
         x86 = s: "i386-${removePrefix "x86-" s}";
      };
      split = splitString "-" target;
   in cpu."${head split}" or (_: _) (kernel."${elemAt split 1}" split);

   nixTargetToZigTarget = target: let
      kernel = {
         none = t: "${t.cpu.name}-freestanding-${t.abi.name}";
         linux = t: "${t.cpu.name}-linux-${t.abi.name}";
         darwin = t: "${t.cpu.name}-macos-none";
         windows = t: "${t.cpu.name}-windows-gnu";
         wasi = t: "${t.cpu.name}-wasi-musl";
      };
      cpu = {
         powerpc64 = s: removeSuffix "abi64" s;
         sparc64 = s: "sparcv9-${removePrefix "sparc64-" s}";
         armv5tel = s: "thumb-${removePrefix "armv5tel-" s}";
         i386 = s: "x86-${removePrefix "i386-" s}";
      };
   in cpu."${target.cpu.name}" or (_: _) (kernel."${target.kernel.name}" target);

   elaborate = system: let
      target = system.config;
   in systems.elaborate (system
         // optionalAttrs (hasSuffix "mingw32" target) { libc = "msvcrt"; }
         // optionalAttrs (hasSuffix "darwin" target) { libc = "libSystem"; }
         // optionalAttrs (hasSuffix "wasi" target) { libc = "wasilibc"; }
         // optionalAttrs (hasInfix "musl" target) { libc = "musl"; }
         // optionalAttrs (hasInfix "gnu" target) { libc = "glibc"; }
         );

   supportsStatic = target: let
      inherit (systems.elaborate target) parsed;
   in parsed.kernel.name != "darwin";

   resolveTarget = target: stdenv: preferMusl: let
      resolved = if target != null then target else nixTargetToZigTarget (elaborate stdenv.targetPlatform).parsed;
   in if preferMusl then replaceStrings [ "-gnu" ] [ "-musl" ] resolved else resolved;

   readBuildZigZon = path: fromJSON (readFile (runCommandLocal "build.zig.zon.json" {} ''${zon2json}/bin/zon2json "${path}" > "$out"''));
}

{ zig, zon2nix, zig2nix-lib, runtimeForTarget, stdenvNoCC, lib, runCommandLocal, makeWrapper, callPackage }:

{
  src
  # Specify target for zig compiler, defaults to stdenv.targetPlatform.
  , zigTarget ? null
  # Prefer musl libc without specifying the target.
  , zigPreferMusl ? false
  # makeWrapper will not be used. Might be useful if distributing outside nix.
  , zigDisableWrap ? false
  # Additional arguments to makeWrapper.
  , zigWrapperArgs ? []
  # Path to build.zig.zon file, defaults to build.zig.zon.
  , zigBuildZon ? "${src}/build.zig.zon"
  # Path to build.zig.zon2json-lock file, defaults to build.zig.zon2json-lock.
  , zigBuildZonLock ? "${zigBuildZon}2json-lock"
  , ...
} @attrs:

with builtins;
with lib;

let
  target = zig2nix-lib.resolveTarget zigTarget stdenvNoCC.targetPlatform zigPreferMusl;
  zon = zig2nix-lib.fromZON zigBuildZon;
  deps = runCommandLocal "deps" {} ''${zon2nix}/bin/zon2nix "${zigBuildZonLock}" > $out'';
  runtime = runtimeForTarget (zig2nix-lib.zigTargetToNixTarget target);
  wrapper-args = zigWrapperArgs
    ++ optionals (length runtime.bins > 0) [ "--prefix" "PATH" ":" (makeBinPath runtime.bins) ]
    ++ optionals (length runtime.libs > 0) [ "--prefix" runtime.env.LIBRARY_PATH ":" (makeLibraryPath runtime.libs) ];
in stdenvNoCC.mkDerivation (
  lib.optionalAttrs (pathExists zigBuildZon) {
    pname = zon.name;
    version = zon.version;
  }
  // attrs //
  {
    zigBuildFlags = (attrs.zigBuildFlags or []) ++ [ "-Dtarget=${target}" ];
    nativeBuildInputs = [ zig.hook makeWrapper ]
      ++ (runtime.env.nativeBuildInputs or [])
      ++ (attrs.nativeBuildInputs or []);
    postPatch = optionalString (pathExists zigBuildZonLock) ''
      ln -s ${callPackage "${deps}" {}} "$ZIG_GLOBAL_CACHE_DIR"/p
      ${attrs.postPatch or ""}
      '';
    postFixup = optionalString (!zigDisableWrap && length wrapper-args > 0) ''
      for bin in $out/bin/*; do
        wrapProgram $bin ${concatStringsSep " " wrapper-args}
      done
      ${attrs.postFixup or ""}
      '';
  }
)

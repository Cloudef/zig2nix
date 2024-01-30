{
  lib
  , zig
  , resolveTargetSystem
  , zigTripleFromSystem
  , fromZON
  , deriveLockFile
  , runtimeForTargetSystem
  , runCommandLocal
  , makeWrapper
  , callPackage
}:

{
  src
  , stdenvNoCC
  # Specify target for zig compiler, defaults to stdenv.targetPlatform.
  , zigTarget ? null
  # By default if zigTarget is specified, nixpkgs stdenv compatible environment is not used.
  # Set this to true, if you want to specify zigTarget, but still use the derived stdenv compatible environment.
  , zigInheritStdenv ? zigTarget == null
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
} @userAttrs:

with builtins;
with lib;

let
  target-system = resolveTargetSystem {
    target = zigTarget;
    platform = stdenvNoCC.targetPlatform;
    musl = zigPreferMusl;
  };

  target-triple = zigTripleFromSystem target-system;
  zon = fromZON zigBuildZon;
  runtime = runtimeForTargetSystem target-system;

  wrapper-args = zigWrapperArgs
    ++ optionals (length runtime.bins > 0) [ "--prefix" "PATH" ":" (makeBinPath runtime.bins) ]
    ++ optionals (length runtime.libs > 0) [ "--prefix" runtime.env.LIBRARY_PATH ":" (makeLibraryPath runtime.libs) ];

  attrs = optionalAttrs (pathExists zigBuildZon && !userAttrs ? name && !userAttrs ? pname) {
    pname = zon.name;
  } // optionalAttrs (pathExists zigBuildZon && !userAttrs ? version) {
    version = zon.version;
  } // userAttrs;

  deps = deriveLockFile zigBuildZonLock {
    inherit zig;
    name = "${attrs.pname or attrs.name}-dependencies";
  };

  default-flags =
    if hasPrefix "git" zig.version || versionAtLeast zig.version "0.11" then
      [ "-Doptimize=ReleaseSafe" ]
    else
      [ "-Drelease-safe=true" ];

  stdenv-flags = optionals (zigInheritStdenv) (runtime.env.stdenvZigFlags or []);
in stdenvNoCC.mkDerivation (
  (removeAttrs attrs [ "stdenvNoCC" ]) // {
    zigBuildFlags =
      (attrs.zigBuildFlags or default-flags)
      ++ [ "-Dtarget=${target-triple}" ]
      ++ stdenv-flags;

    nativeBuildInputs = [ zig.hook ]
      ++ optionals (!zigDisableWrap) ([ makeWrapper ] ++ (runtime.env.wrapperBuildInputs or []))
      ++ (runtime.env.nativeBuildInputs or [])
      ++ (attrs.nativeBuildInputs or []);

    postPatch = optionalString (pathExists zigBuildZonLock) ''
      ln -s ${deps} "$ZIG_GLOBAL_CACHE_DIR"/p
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

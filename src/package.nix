{
  lib
  , zig
  , fromZON
  , deriveLockFile
  , makeWrapper
  , removeReferencesTo
  , pkg-config
  , target
}:

{
  src
  , glibc
  , musl
  , stdenvNoCC
  # Specify target for zig compiler, defaults to stdenv.targetPlatform.
  , zigTarget ? null
  # Prefer musl libc without specifying the target.
  , zigPreferMusl ? false
  # Binaries available to the binary during runtime (PATH)
  , zigWrapperBins ? []
  # Libraries available to the binary during runtime (LD_LIBRARY_PATH)
  , zigWrapperLibs ? []
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
  zon = fromZON zigBuildZon;

  config =
    if zigPreferMusl then
      replaceStrings ["-gnu"] ["-musl"] stdenvNoCC.targetPlatform.config
    else stdenvNoCC.targetPlatform.config;

  default-target = (target config).zig;
  resolved-target = if zigTarget != null then zigTarget else default-target;

  wrapper-args = []
    ++ optionals (length zigWrapperBins > 0) [ "--prefix" "PATH" ":" (makeBinPath zigWrapperBins) ]
    ++ optionals (length zigWrapperLibs > 0 && stdenvNoCC.isLinux) [ "--prefix" "LD_LIBRARY_PATH" ":" (makeLibraryPath zigWrapperLibs) ]
    ++ optionals (length zigWrapperLibs > 0 && stdenvNoCC.isDarwin) [ "--prefix" "DYLD_LIBRARY_PATH" ":" (makeLibraryPath zigWrapperLibs) ]
    ++ zigWrapperArgs;

  attrs = optionalAttrs (pathExists zigBuildZon && !userAttrs ? name && !userAttrs ? pname) {
    pname = zon.name;
  } // optionalAttrs (pathExists zigBuildZon && !userAttrs ? version) {
    version = zon.version;
  } // userAttrs;

  deps = deriveLockFile zigBuildZonLock {
    inherit zig;
    name = "${attrs.pname or attrs.name}-dependencies";
  };

  abi = (target resolved-target).abi;
  dynamic-linker =
    if !stdenvNoCC.isLinux then null
    # -Ddynamic-linker doesn't seem to work with zig 0.16 ... packaging for nix may be broken :/
    else if versionAtLeast zig.version "0.16" then null
    # cross-compiling
    else if resolved-target != default-target && zigTarget != null then null
    else if ((target resolved-target).dynamicLinker or null) == null then null
    else if abi == "gnu" then "${glibc}${(target resolved-target).dynamicLinker}"
    else if abi == "musl" then "${musl}${(target resolved-target).dynamicLinker}"
    else null;

  default-flags =
    if versionAtLeast zig.version "0.11" then
      [ "-Doptimize=ReleaseSafe" ]
    else
      [ "-Drelease-safe=true" ];
in stdenvNoCC.mkDerivation (
  (removeAttrs attrs [ "stdenvNoCC" ]) // {
    zigBuildFlags =
      (attrs.zigBuildFlags or default-flags)
      ++ [ "-Dtarget=${resolved-target}" ]
      ++ optionals (length wrapper-args > 0 && dynamic-linker != null) [ "-Ddynamic-linker=${dynamic-linker}" ];

    nativeBuildInputs = [ zig.hook removeReferencesTo pkg-config ]
      ++ optionals (length wrapper-args > 0) [ makeWrapper ]
      ++ (attrs.nativeBuildInputs or []);

    postConfigure = optionalString (pathExists zigBuildZonLock) ''
      ln -s ${deps} "$ZIG_GLOBAL_CACHE_DIR"/p
      ${attrs.postPatch or ""}
      '';

    preFixup = optionalString (length wrapper-args > 0) ''
      for bin in $out/bin/*; do
        wrapProgram $bin ${concatStringsSep " " wrapper-args}
      done
      '' + ''
      ${attrs.preFixup or ""}
      '';

    postFixup = ''
      find "$out" -type f -exec remove-references-to -t ${zig} '{}' +
      ${attrs.postFixup or ""}
      '';

    disallowedReferences = [ zig zig.hook removeReferencesTo ]
      ++ optionals (pathExists zigBuildZonLock) [ deps ];
  }
)

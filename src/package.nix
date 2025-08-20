{
  lib
  , zig
  , fromZON
  , deriveLockFile
  , makeWrapper
  , removeReferencesTo
  , pkg-config
  , runCommandCC
  , patchelf
  , target
}:

{
  src
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
    ++ optionals (length zigWrapperLibs > 0) [ "--prefix" "LD_LIBRARY_PATH" ":" (makeLibraryPath zigWrapperLibs) ]
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

  # Do the same thing autopatchelf does, that is assume stdenv's dynamic-linker is what we want
  # We do not use autopatchelf because we already use makeWrapper to setup proper runtime environment otherwise
  dl-path = runCommandCC "dl-path" {} "ln -s $NIX_CC/nix-support/dynamic-linker $out";

  default-flags =
    if versionAtLeast zig.version "0.11" then
      [ "-Doptimize=ReleaseSafe" ]
    else
      [ "-Drelease-safe=true" ];
in stdenvNoCC.mkDerivation (
  (removeAttrs attrs [ "stdenvNoCC" ]) // {
    zigBuildFlags =
      (attrs.zigBuildFlags or default-flags)
      ++ [ "-Dtarget=${resolved-target}" ];

    nativeBuildInputs = [ zig.hook removeReferencesTo pkg-config ]
      ++ optionals (length wrapper-args > 0) [ makeWrapper ]
      ++ optionals (length wrapper-args > 0 && stdenvNoCC.isLinux) [ patchelf ]
      ++ (attrs.nativeBuildInputs or []);

    postPatch = optionalString (pathExists zigBuildZonLock) ''
      ln -s ${deps} "$ZIG_GLOBAL_CACHE_DIR"/p
      ${attrs.postPatch or ""}
      '';

    postFixup = optionalString (length wrapper-args > 0) (''
      for bin in $out/bin/*; do
        '' + optionalString (stdenvNoCC.isLinux) ''
        if patchelf --print-interpreter $bin &> /dev/null; then
          patchelf --set-interpreter "$(cat ${dl-path})" $bin
        fi
        '' + ''
        wrapProgram $bin ${concatStringsSep " " wrapper-args}
      done
      '') + ''
      find "$out" -type f -exec remove-references-to -t ${zig} '{}' +
      ${attrs.postFixup or ""}
      '';

    dontAutoPatchelf = true;

    disallowedReferences = [ zig zig.hook removeReferencesTo ]
      ++ optionals (pathExists zigBuildZonLock) [ deps ];
  }
)

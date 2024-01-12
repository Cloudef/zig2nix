{
    stdenvNoCC
    , lib
    , runCommandLocal
    , zon2nix
    , zig2nix-lib
    , zig
    , makeWrapper
    , autoPatchelfHook
    , callPackage
    , runtimeForTarget
}:

with builtins;
with lib;

attrs: let
  target = attrs.zigTarget or zig2nix-lib.nixTargetToZigTarget (zig2nix-lib.elaborate stdenvNoCC.targetPlatform).parsed;
  build-zig-zon-path = attrs.zigBuildZon or "${attrs.src}/build.zig.zon";
  has-build-zig-zon = pathExists build-zig-zon-path;
  build-zig-zon2json-lock-path = attrs.zigBuildZonLock or "${build-zig-zon-path}2json-lock";
  has-build-zig-zon2json-lock = pathExists build-zig-zon2json-lock-path;
  build-zig-zon = zig2nix-lib.readBuildZigZon build-zig-zon-path;
  zig-deps = runCommandLocal "zig-deps" {} ''${zon2nix}/bin/zon2nix "${build-zig-zon2json-lock-path}" > $out'';
  runtime = runtimeForTarget (zig2nix-lib.zigTargetToNixTarget target);
  wrapper-args = attrs.zigWrapperArgs or []
    ++ optionals (length runtime.bins > 0) [ "--prefix" "PATH" ":" (makeBinPath runtime.bins) ]
    ++ optionals (length runtime.libs > 0) [ "--prefix" runtime.env.LIBRARY_PATH ":" (makeLibraryPath runtime.libs) ];
  disable-wrap = attrs.zigDisableWrap or false;
in stdenvNoCC.mkDerivation (
  lib.optionalAttrs (has-build-zig-zon) {
    pname = build-zig-zon.name;
    version = build-zig-zon.version;
  }
  // attrs //
  {
    zigBuildFlags = (attrs.zigBuildFlags or []) ++ [ "-Dtarget=${target}" ];
    nativeBuildInputs = [ zig.hook makeWrapper ]
      ++ (runtime.env.nativeBuildInputs or [])
      ++ (attrs.nativeBuildInputs or []);
    postPatch = optionalString (has-build-zig-zon2json-lock) ''
      ln -s ${callPackage "${zig-deps}" {}} "$ZIG_GLOBAL_CACHE_DIR"/p
      '' + optionalString (attrs ? postPatch) attrs.postPatch;
    postFixup = optionalString (!disable-wrap && length wrapper-args > 0) ''
      for bin in $out/bin/*; do
        wrapProgram $bin ${concatStringsSep " " wrapper-args}
      done
      '' + optionalString (attrs ? postFixup) attrs.postFixup;
  }
)

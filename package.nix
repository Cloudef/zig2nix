{
    stdenv
    , system
    , lib
    , runCommandLocal
    , zon2nix
    , zig2nix-lib
    , zig
    , autoPatchelfHook
    , callPackage
}:

with builtins;
with lib;

attrs: let
  target = attrs.zigTarget or zig2nix-lib.nixTargetToZigTarget (zig2nix-lib.elaborate {config = system;}).parsed;
  build-zig-zon-path = attrs.zigBuildZon or "${attrs.src}/build.zig.zon";
  has-build-zig-zon = pathExists build-zig-zon-path;
  build-zig-zon2json-lock-path = attrs.zigBuildZonLock or "${build-zig-zon-path}2json-lock";
  has-build-zig-zon2json-lock = pathExists build-zig-zon2json-lock-path;
  build-zig-zon = zig2nix-lib.readBuildZigZon build-zig-zon-path;
  zig-deps = runCommandLocal "zig-deps" {} ''${zon2nix}/bin/zon2nix "${build-zig-zon2json-lock-path}" > $out'';
in stdenv.mkDerivation (
  lib.optionalAttrs (has-build-zig-zon) {
    pname = build-zig-zon.name;
    version = build-zig-zon.version;
  }
  // attrs //
  {
    zigBuildFlags = (attrs.zigBuildFlags or []) ++ [ "-Dtarget=${target}" ];
    nativeBuildInputs = [ zig.hook autoPatchelfHook ] ++ (attrs.nativeBuildInputs or []);
    postPatch = optionalString (has-build-zig-zon2json-lock) ''
      ln -s ${callPackage "${zig-deps}" {}} "$ZIG_GLOBAL_CACHE_DIR"/p
      '' + optionalString (attrs ? postPatch) attrs.postPatch;
  }
)

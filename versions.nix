{
  lib
  , callPackage
  , zigSystem
  , zigHook
}:

with builtins;
with lib;

mapAttrs (k: v: callPackage ./zig.nix {
  inherit zigHook zigSystem;
  version = v.version or k;
  release = v;
}) (fromJSON (readFile ./versions.json))

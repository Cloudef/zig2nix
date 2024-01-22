{
  lib
  , path
  , callPackage
  , localSystem
  , crossSystem
  , zig
  , zigPackage
  , allTargetSystems
  , nixTripleFromSystem
  , zigTripleFromSystem
  , mkZigSystemFromPlatform
  , nixCrossPkgs
}:

with builtins;
with lib;

warn "toolchain: ${crossSystem.config}"
import path {
  inherit localSystem crossSystem;
  stdenvStages = callPackage ./stdenv.nix {
    mkZigToolchain = callPackage ./toolchain.nix {
      inherit zig zigPackage allTargetSystems nixTripleFromSystem zigTripleFromSystem mkZigSystemFromPlatform;
    };
  };

  overlays = [(self: super: {
    # We do in fact have install_name_tool
    fixDarwinDylibNames = super.fixDarwinDylibNames.overrideAttrs (old: {
      meta = old.meta // {
        platforms = systems.doubles.all;
      };
    });
  })];

  crossOverlays = [(self: super: {
    # XXX: fails tests
    libffi = nixCrossPkgs.libffi;
    # XXX: undefined symbol: main
    python3 = nixCrossPkgs.python3;
    # XXX: libX11 fails preprocessor check
    xorg = nixCrossPkgs.xorg;
  })];
}

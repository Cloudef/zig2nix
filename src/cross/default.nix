{
  lib
  , path
  , callPackage
  , stdenv
  , localSystem
  , crossSystem
  , writeShellScriptBin
  , coreutils
  , zig
  , zigPackage
  , allNixZigSystems
  , nixTripleFromSystem
  , zigTripleFromString
}:

with builtins;
with lib;

warn "toolchain: ${crossSystem.config}"
import path {
  inherit localSystem crossSystem;
  stdenvStages = callPackage ./stdenv.nix {
    inherit zigTripleFromString;
    mkZigToolchain = callPackage ./toolchain.nix { inherit zig zigPackage allNixZigSystems nixTripleFromSystem; };
  };

  overlays = [(self: super: {
    # We do in fact have install_name_tool
    fixDarwinDylibNames = super.fixDarwinDylibNames.overrideAttrs (old: {
      meta = old.meta // {
        platforms = systems.doubles.all;
      };
    });
  })];

  # TODO: check the fixes here
  # TODO: test for every issue
  crossOverlays = [(self: super: {
    # XXX: broken on aarch64 at least
    gmp = super.gmp.overrideAttrs (old: {
      configureFlags = old.configureFlags ++ [ "--disable-assembly" ];
    });

    # XXX: libsepol issue on darwin, should be fixed upstream instead
    libsepol = super.libsepol.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ optionals (stdenv.isDarwin) [
        (writeShellScriptBin "gln" ''${coreutils}/bin/ln "$@"'')
      ];
    });
  })];
}

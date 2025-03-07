{
  lib
  , path
  , localSystem
  , crossSystem
  , zig
  , zigPackage
  , nixCrossPkgs
  , nixBinaryPkgs
  , target
  , writeText
  , callPackage
}:

with builtins;
with lib;

let
  mkToolchain = callPackage ./toolchain.nix {
    inherit zig zigPackage target;
  };

in warn "toolchain: ${crossSystem.config}"
import path {
  inherit localSystem crossSystem;
  stdenvStages = callPackage (import ./stdenv.nix) {};

  config = {
    replaceCrossStdenv = { buildPackages, baseStdenv }: baseStdenv.override (old: {
      buildPlatform = old.buildPlatform // {
        # Override nixpkgs's canExecute
        # This is to prevent nixpkgs trying to execute x86 binaries on x86_64 for example
        # We don't provide libc through nix, so there is no loader
        canExecute = other: other.config == old.buildPlatform.config;
      };

      allowedRequisites = null;
      cc = nixCrossPkgs.callPackage mkToolchain {};

      preHook = let
        libc = nixBinaryPkgs.stdenv.cc.libc;
        builtin_libc = (target old.targetPlatform.config).libc;
        libc-file = writeText "libc.txt" ''
          include_dir=${getDev libc}/include
          sys_include_dir=${getDev libc}/include
          crt_dir=${getLib libc}/lib
          msvc_lib_dir=
          kernel32_lib_dir=
          gcc_dir=
          '';
      in ''
        ${old.preHook}
        export NIX_CC_USE_RESPONSE_FILE=0
        '' + optionalString (!builtin_libc) ''
        export ZIG_LIBC=${libc-file}
        '';

      extraBuildInputs = [];
      extraNativeBuildInputs = with buildPackages; old.extraNativeBuildInputs
      # without proper `file` command, libtool sometimes fails
      # to recognize 64-bit DLLs
      ++ optional (hostPlatform.config == "x86_64-w64-mingw32") file;
    });
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

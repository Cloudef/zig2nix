{
  path
  , mkZigToolchain
}:

{
  lib
  , localSystem
  , crossSystem
  , config
  , overlays
  , crossOverlays ? []
}:

with builtins;
with lib;

let
  prehook = prelude: ''
    ${prelude}
    export NIX_CC_USE_RESPONSE_FILE=0
  '';

  bootStages = import "${path}/pkgs/stdenv" {
    inherit lib localSystem overlays;
    crossSystem = localSystem;
    crossOverlays = [];
    # Ignore custom stdenvs when cross compiling for compatability
    config = removeAttrs config [ "replaceStdenv" ];
  };
in init bootStages ++ [
  (somePrevStage: last bootStages somePrevStage // { allowCustomOverrides = true; })

  # First replace native compiler with zig
  # This gives us more deterministic environment
  (vanillaPackages: warn "local: ${localSystem.config}" {
    inherit config overlays;
    selfBuild = false;
    stdenv = (vanillaPackages.stdenv.override (old: {
      targetPlatform = crossSystem;
      allowedRequisites = null;
      hasCC = true;
      cc = vanillaPackages.callPackage mkZigToolchain {
        inherit (old.cc) libc;
      };
      preHook = prehook old.preHook;
      # Propagate everything to the next step as we do not need to bootstrap
      # We exclude packages that would break nixpkgs cross-compiling setup
      overrides = self: super: genAttrs (filter (a: ! any (b: hasPrefix b a) [
        "callPackage" "newScope" "pkgs" "stdenv" "system" "wrapBintools" "wrapCC"
      ]) (attrNames vanillaPackages)) (x: vanillaPackages."${x}");
    }));
    # It's OK to change the built-time dependencies
    allowCustomOverrides = true;
  })

  # Then use zig as a cross-compiler as well
  (buildPackages: let
    adaptStdenv = if crossSystem.isStatic then buildPackages.stdenvAdapters.makeStatic else id;
  in {
    inherit config;
    overlays = overlays ++ crossOverlays;
    selfBuild = false;
    stdenv = adaptStdenv (buildPackages.stdenv.override (old: rec {
      buildPlatform = localSystem // {
        # Override nixpkgs's canExecute
        # This is to prevent nixpkgs trying to execute x86 binaries on x86_64 for example
        # We don't provide libc through nix, so there is no loader
        canExecute = other: other.config == localSystem.config;
      };
      hostPlatform = crossSystem;
      targetPlatform = crossSystem;

      # Prior overrides are surely not valid as packages built with this run on
      # a different platform, and so are disabled.
      overrides = _: _: {};
      allowedRequisites = null;
      hasCC = true;
      cc = buildPackages.callPackage mkZigToolchain {
        inherit (old.cc) libc;
      };
      preHook = prehook old.preHook;

      extraNativeBuildInputs = with buildPackages; old.extraNativeBuildInputs
      ++ optionals (hostPlatform.isLinux && !buildPlatform.isLinux) [ patchelf ]
      ++ optional
           (let f = p: !p.isx86 || elem p.libc [ "musl" "wasilibc" "relibc" ] || p.isiOS || p.isGenode;
             in f hostPlatform && !(f buildPlatform))
           updateAutotoolsGnuConfigScriptsHook
         # without proper `file` command, libtool sometimes fails
         # to recognize 64-bit DLLs
      ++ optional (hostPlatform.config == "x86_64-w64-mingw32") file;
    }));
  })
]

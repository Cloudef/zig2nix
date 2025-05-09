{
  description = "zig2nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, ... }: with builtins; let
    outputs = (flake-utils.lib.eachDefaultSystem (system: let
      # Used only for top level stuff, everything else should be done with env.pkgs
      _callPackage = self.inputs.nixpkgs.outputs.legacyPackages.${system}.callPackage;

      #! Structures.

      # Use our own zig hook.
      # The nixpkgs one forces flags which can't be overridden.
      # Also -target is recommended over use of -Dcpu=baseline.
      # https://ziggit.dev/t/exe-files-not-interchangeable-among-identical-linux-systems/2708/6
      # I would've reused the setup-hook.sh, but it breaks when cross-compiling.
      zigHook = { makeSetupHook, zig }: makeSetupHook {
        name = "zig-hook";
        propagatedBuildInputs = [ zig ];
        substitutions.zig_default_flags = [];
        passthru = { inherit zig; };
      } ./src/setup-hook.sh;

      # Zig versions
      # <https://ziglang.org/download/index.json>
      zigv = import ./src/zig/versions.nix {
        inherit zigHook;
        zigBin = _callPackage ./src/zig/bin.nix;
        zigSrc = _callPackage ./src/zig/src.nix;
      };

      # zig2nix bridge utility
      # always compiled with zig-latest, does not have zig in the path
      # can be used for zon2json, zon2nix and target queries
      zig2nix-zigless = _callPackage ./src/zig2nix/default.nix {
        zig = zigv.latest;
        zigBuildFlags = [ "-Dcpu=baseline" ];
      };

      #:! Helper function for building and running Zig projects.
      zig-env = {
        # Overrideable nixpkgs.
        nixpkgs ? self.inputs.nixpkgs,
        # Zig version to use.
        zig ? zigv.latest,
      }: with nixpkgs.lib; let
        #! --- Outputs of zig-env {} function.
        #!     access: (zig-env {}).thing

        # Use provided nixpkgs in here.
        pkgs = nixpkgs.outputs.legacyPackages.${system};

        #! Tools for bridging zig and nix
        #! The correct zig version is put into the PATH
        zig2nix = pkgs.writeShellApplication {
          name = "zig2nix";
          runtimeInputs = [ zig ];
          text = ''${zig2nix-zigless}/bin/zig2nix "$@"'';
        };

        exec = cmd: args: pkgs.runCommandLocal cmd {} ''${zig2nix-zigless}/bin/zig2nix ${cmd} ${escapeShellArgs args} > $out'';
        exec-path = cmd: path: args: pkgs.runCommandLocal cmd {} ''${zig2nix-zigless}/bin/zig2nix ${cmd} ${path} ${escapeShellArgs args} > $out'';
        exec-json = cmd: args: fromJSON (readFile (exec cmd args));
        exec-json-path = cmd: path: args: fromJSON (readFile (exec-path cmd path args));

        #! Translates zig and nix compatible targets
        target = system: (exec-json "target" [ system ]);

        #! Reads zon file into a attribute set
        fromZON = path: exec-json-path "zon2json" path [];

        #! Creates derivation from zon2json-lock file
        deriveLockFile = path: pkgs.callPackage (exec-path "zon2nix" path [ "-" ]);

        # Provides small shell runtime
        shell-runtime = pkgs.callPackage ./src/shell.nix { inherit system; };

        #! Returns true if target is nix flake compatible.
        #! <https://github.com/NixOS/nixpkgs/blob/master/lib/systems/flake-systems.nix>
        isFlakeTarget = any: pkgs.lib.any (s: (systems.elaborate s).config == (target any).config) systems.flakeExposed;

        #! Returns crossPkgs from nixpkgs for target string or system.
        #! This will always cross-compile the package.
        crossPkgsForTarget = any: let
          crossPkgs = import nixpkgs { localSystem = system; crossSystem = { config = (target any).config; }; };
          this-system = (systems.elaborate system).config == (target any).config;
        in if this-system then pkgs else crossPkgs;

        #! Returns pkgs from nixpkgs for target string or system.
        #! This does not cross-compile and you'll get a error if package does not exist in binary cache.
        binaryPkgsForTarget = any: let
          binaryPkgs = import nixpkgs { localSystem = { config = (target any).config; }; };
          this-system = (systems.elaborate system).config == (target any).config;
        in if this-system then pkgs else binaryPkgs;

        #! Returns either binaryPkgs or crossPkgs depending if the target is flake target or not.
        pkgsForTarget = any:
          if isFlakeTarget any then binaryPkgsForTarget any
          else crossPkgsForTarget any;

        # Package a Zig project
        zigPackage = pkgs.callPackage (pkgs.callPackage ./src/package.nix {
          inherit zig target fromZON deriveLockFile;
        });

        #! Cross-compile nixpkgs using zig :)
        #! NOTE: This is an experimental feature, expect it not faring well
        zigCrossPkgsForTarget = any: let
          crossPkgs = pkgs.callPackage ./src/cross {
            inherit zig zigPackage target;
            nixCrossPkgs = pkgsForTarget any;
            nixBinaryPkgs = binaryPkgsForTarget any;
            localSystem = system;
            crossSystem = { config = (target any).config; };
          };
        in warn "zigCross: ${(target any).zig}" crossPkgs;

        _deps = [ zig zig2nix pkgs.pkg-config ];
      in rec {
        inherit pkgs pkgsForTarget crossPkgsForTarget zigCrossPkgsForTarget binaryPkgsForTarget;
        inherit zig zigHook zig2nix target fromZON deriveLockFile;

        #! Flake app helper (Without zig-env and root dir restriction).
        app-bare-no-root = deps: script: {
          type = "app";
          program = toString (pkgs.writeShellApplication {
            name = "app";
            runtimeInputs = [] ++ deps;
            text = ''
              # shellcheck disable=SC2059
              error() { printf -- "error: $1\n" "''${@:2}" 1>&2; exit 1; }
              ${script}
              '';
          }) + "/bin/app";
          meta = {
            description = "";
          };
        };

        #! Flake app helper (Without zig-env).
        app-bare = deps: script: app-bare-no-root deps ''
          [[ -f ./flake.nix ]] || error 'Run this from the project root'
          ${script}
          '';

        #! Flake app helper (without root dir restriction).
        app-no-root = deps: script: app-bare-no-root (deps ++ _deps) ''
          ${shell-runtime deps}
          ${script}
          '';

        #! Flake app helper.
        app = deps: script: app-bare (deps ++ _deps) ''
          ${shell-runtime deps}
          ${script}
          '';

        #! Creates dev shell.
        mkShell = pkgs.callPackage ({
          nativeBuildInputs ? [],
          ...
        } @attrs: pkgs.mkShellNoCC (attrs // {
          nativeBuildInputs = (remove zig.hook nativeBuildInputs) ++ _deps;
          shellHook = ''
            ${shell-runtime nativeBuildInputs}
            ${attrs.shellHook or ""}
          '';
        }));

        #! Packages zig project.
        #! NOTE: If your project has build.zig.zon you must first generate build.zig.zon2json-lock using zon2json-lock.
        #!       It is recommended to commit the build.zig.zon2json-lock to your repo.
        #!
        #! Additional attributes:
        #!    zigTarget: Specify target for zig compiler, defaults to stdenv.targetPlatform of given target.
        #!    zigPreferMusl: Prefer musl libc without specifying the target.
        #!    zigWrapperBins: Binaries available to the binary during runtime (PATH)
        #!    zigWrapperLibs: Libraries available to the binary during runtime (LD_LIBRARY_PATH)
        #!    zigWrapperArgs: Additional arguments to makeWrapper.
        #!    zigBuildZon: Path to build.zig.zon file, defaults to build.zig.zon.
        #!    zigBuildZonLock: Path to build.zig.zon2json-lock file, defaults to build.zig.zon2json-lock.
        #!
        #! <https://github.com/NixOS/nixpkgs/blob/master/doc/hooks/zig.section.md>
        package = zigPackage;

        #! Bundle a package into a zip
        bundle.zip = pkgs.callPackage ./src/bundle/zip.nix { inherit zigPackage; };

        #! Bundle a package for running in AWS lambda
        bundle.aws.lambda = pkgs.callPackage ./src/bundle/lambda.nix { bundleZip = bundle.zip; };
      };

      test-env = zig-env { zig = zigv.master; };
      test-app = test-env.app-bare;

      test = removeAttrs (_callPackage src/test.nix {
        inherit test-app;
        inherit (test-env) zig zig2nix target deriveLockFile;
        zig-env = test-env;
      }) [ "override" "overrideDerivation" "overrideAttrs" ];

      flake-outputs = _callPackage (import ./src/zig/outputs.nix) {
        inherit zigv zig-env;
      };
    in with test-env.pkgs.lib; {
      #! --- Architecture dependent flake outputs.
      #!     access: `zig2nix.outputs.thing.${system}`

      #! Helper functions for building and running Zig projects.
      inherit zig-env;

      #! Versioned Zig packages.
      #! nix build .#zig-master
      #! nix build .#zig-latest
      #! nix run .#zig-0_13_0
      packages = mapAttrs' (k: v: nameValuePair ("zig-" + k) v) zigv;

      # Generates flake apps for all the zig versions.
      apps = flake-outputs.apps // {
        default = flake-outputs.apps.zig2nix-latest;

        # Backwards compatibility
        zon2json = flake-outputs.apps.zon2json-latest;
        zon2json-lock = flake-outputs.apps.zon2json-lock-latest;
        zon2nix = flake-outputs.apps.zon2nix-latest;

        # nix run .#update-versions
        update-versions = with test-env.pkgs; test-app [ curl test-env.zig2nix ] ''
          tmp="$(mktemp)"
          trap 'rm -f "$tmp"' EXIT
          # use curl because zig's std.net is flaky
          curl "''${@:-https://ziglang.org/download/index.json}" | zig2nix versions - > "$tmp"
          cp -f "$tmp" src/zig/versions.nix
        '';

        # nix run .#update-templates
        update-templates = with test-env.pkgs; test-app [ coreutils gnused ] ''
          rm -rf templates/default
          mkdir -p templates/default
          sed 's#/[*]SED_ZIG_VER[*]/##' templates/flake.nix > templates/default/flake.nix
          sed -i 's#@SED_ZIG_BIN@#default#' templates/default/flake.nix
          cp -f templates/gitignore templates/default/.gitignore
          cp -f .gitattributes templates/default/.gitattributes
          (cd templates/default; ${zigv.latest}/bin/zig init)
          sed -i 's#.fingerprint = 0xe35e00df[a-f0-9]*#.fingerprint = 0xe35e00df11111111#' templates/default/build.zig.zon
          (cd templates/default; nix flake check --override-input zig2nix ../..)

          rm -rf templates/master
          mkdir -p templates/master
          # shellcheck disable=SC2016
          sed 's#/[*]SED_ZIG_VER[*]/# zig = zig2nix.outputs.packages.''${system}.zig-master; #' templates/flake.nix > templates/master/flake.nix
          sed -i 's#@SED_ZIG_BIN@#master#' templates/master/flake.nix
          cp -f templates/gitignore templates/master/.gitignore
          cp -f .gitattributes templates/master/.gitattributes
          (cd templates/master; ${zigv.master}/bin/zig init)
          sed -i 's#.fingerprint = 0x2d09a3d6[a-f0-9]*#.fingerprint = 0x2d09a3d611111111#' templates/master/build.zig.zon
          (cd templates/master; nix flake check --override-input zig2nix ../..)
          '';

        # nix run .#readme
        readme = let
          project = "zig2nix flake";
        in with test-env.pkgs; test-app [ gawk gnused ] (replaceStrings ["`"] ["\\`"] ''
        cat <<EOF
        # ${project}

        Flake for packaging, building and running Zig projects.

        https://ziglang.org/

        * Cachix: `cachix use zig2nix`

        ---

        [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

        * Zig master: `${zigv.master.version} @ ${zigv.master.date}`
        * Zig latest: `${zigv.latest.version} @ ${zigv.latest.date}`

        ## Examples

        ### Zig project template

        ```bash
        nix flake init -t github:Cloudef/zig2nix
        nix run .
        # for more options check the flake.nix file
        ```

        #### With master version of Zig

        ```bash
        nix flake init -t github:Cloudef/zig2nix#master
        nix run .
        # for more options check the flake.nix file
        ```

        ### Build zig from source

        ```bash
        nix build github:Cloudef/zig2nix#zig-src-master
        nix build github:Cloudef/zig2nix#zig-src-latest
        nix build github:Cloudef/zig2nix#zig-src-0_8_0
        ```

        ### Running zig compiler directly

        ```bash
        nix run github:Cloudef/zig2nix#master -- version
        nix run github:Cloudef/zig2nix#latest -- version
        nix run github:Cloudef/zig2nix#0_8_0 -- version
        ```

        #### Convenience zig for multimedia programs

        > This sets (DY)LD_LIBRARY_PATH and PKG_CONFIG_PATH so that common libs are available

        ```bash
        nix run github:Cloudef/zig2nix#multimedia-master -- version
        nix run github:Cloudef/zig2nix#multimedia-latest -- version
        nix run github:Cloudef/zig2nix#multimedia-0_8_0 -- version
        ```

        ### Shell for building and running a Zig project

        ```bash
        nix develop github:Cloudef/zig2nix#master
        nix develop github:Cloudef/zig2nix#latest
        nix develop github:Cloudef/zig2nix#0_8_0
        ```

        ### Convert zon file to json

        ```bash
        nix run github:Cloudef/zig2nix -- zon2json build.zig.zon
        ```

        ### Convert build.zig.zon to a build.zig.zon2json-lock

        ```bash
        nix run github:Cloudef/zig2nix -- zon2lock build.zig.zon
        ```

        ### Convert build.zig.zon/2json-lock to a nix derivation

        ```bash
        # calls zon2json-lock if build.zig.zon2json-lock does not exist (requires network access)
        nix run github:Cloudef/zig2nix -- zon2nix build.zig.zon
        # alternatively run against the lock file (no network access required)
        nix run github:Cloudef/zig2nix -- zon2nix build.zig.zon2json-lock
        ```

        ### Github actions

        When using zig2nix in github actions, you have to disable apparmor in the ubuntu runner:

        ```bash
        sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
        ```

        ## Crude documentation

        Below is auto-generated dump of important outputs in this flake.

        ```nix
        $(awk -f doc.awk flake.nix | sed "s/```/---/g")
        ```
        EOF
        '');
      } // mapAttrs' (name: value: nameValuePair ("test-" + name) value) test;

      #! Develop shell for building and running Zig projects.
      #! nix develop .#zig_version
      #! example: nix develop .#master
      #! example: nix develop .#default
      devShells = flake-outputs.devShells // {
        default = flake-outputs.devShells.latest;
      };
    }));

  welcome-template = description: ''
    # ${description}
    - Zig: https://ziglang.org/

    ## Build & Run

    ```
    nix run .
    ```

    See flake.nix for more options.
    '';

  in outputs // {
    #! --- Generic flake outputs.
    #!     access: `zig2nix.outputs.thing`

    #! Default project template
    #! nix flake init -t templates
    templates.default = rec {
      path = ./templates/default;
      description = "Default Zig project template";
      welcomeText = welcome-template description;
    };

    #! Master project template
    #! nix flake init -t templates#master
    templates.master = rec {
      path = ./templates/master;
      description = "Master Zig project template";
      welcomeText = welcome-template description;
    };
  };
}

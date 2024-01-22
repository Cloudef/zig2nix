{
  description = "zig2nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, ... }: with builtins; let
    outputs = (flake-utils.lib.eachDefaultSystem (system: let
      pkgs = self.inputs.nixpkgs.outputs.legacyPackages.${system};

      #! Structures.

      zig2nix-lib-base = pkgs.callPackage ./src/lib.nix {};

      # Use our own zig hook.
      # The nixpkgs one forces flags which can't be overridden.
      # Also -target is recommended over use of -Dcpu=baseline.
      # https://ziggit.dev/t/exe-files-not-interchangeable-among-identical-linux-systems/2708/6
      # I would've reused the setup-hook.sh, but it breaks when cross-compiling.
      zig-hook = { makeSetupHook, zig }: makeSetupHook {
        name = "zig-hook";
        propagatedBuildInputs = [ zig ];
        substitutions.zig_default_flags = [];
        passthru = { inherit zig; };
      } ./src/setup-hook.sh;

      # Zig versions.
      # <https://ziglang.org/download/index.json>
      zigv = with zig2nix-lib-base; pkgs.callPackage ./versions.nix {
        zigSystem = zigDoubleFromString system;
        zigHook = zig-hook;
      };

      # Converts zon files to json
      zon2json = with zig2nix-lib-base; let
        target = resolveTargetTriple { target = system; musl = true; };
      in pkgs.callPackage tools/zon2json/default.nix {
        zig = zigv.master;
        zigBuildFlags = [ "-Dtarget=${target}" ];
      };

      # Converts build.zig.zon to a build.zig.zon2json lock file
      zon2json-lock = pkgs.callPackage tools/zon2json-lock.nix {
        zig = zigv.master;
        inherit zon2json;
      };

      # Converts build.zig.zon and build.zig.zon2json-lock to nix deriviation
      zon2nix = pkgs.callPackage tools/zon2nix.nix {
        inherit zon2json-lock;
      };

      # Tools for bridging zig and nix
      zig2nix-lib = with pkgs; zig2nix-lib-base // {
        fromZON = path: fromJSON (readFile (runCommandLocal "fromZON" {} ''${zon2json}/bin/zon2json "${path}" > "$out"''));
        deriveLockFile = path: callPackage (runCommandLocal "deriveLockFile" {} ''${zon2nix}/bin/zon2nix ${path} > $out'');
      };

      #:! Helper function for building and running Zig projects.
      zig-env = {
        # Overrideable nixpkgs.
        nixpkgs ? self.inputs.nixpkgs,
        # Zig version to use.
        zig ? zigv.default,
        # Additional runtime deps to inject into the helpers.
        customRuntimeDeps ? [],
        # Additional runtime libs to inject to the helpers.
        # Gets included in LD_LIBRARY_PATH and DYLD_LIBRARY_PATH.
        customRuntimeLibs ? [],
        # Custom prelude in the flake app helper.
        customAppHook ? "",
        # Custom prelude in the flake shell helper.
        customDevShellHook ? "",
        # Enable Vulkan support.
        enableVulkan ? false,
        # Enable OpenGL support.
        enableOpenGL ? false,
        # Enable Wayland support.
        enableWayland ? false,
        # Enable X11 support.
        enableX11 ? false,
      }: with pkgs.lib; let
        #! --- Outputs of zig-env {} function.
        #!     access: (zig-env {}).thing

        # Use provided nixpkgs in here.
        pkgs = nixpkgs.outputs.legacyPackages.${system};

        #! Returns true if target is nix flake compatible.
        #! <https://github.com/NixOS/nixpkgs/blob/master/lib/systems/flake-systems.nix>
        isFlakeTarget = with zig2nix-lib; args': let
          target-system = if isString args' then mkZigSystemFromString args' else args';
        in any (s: (systems.elaborate s).config == (nixTripleFromSystem target-system)) systems.flakeExposed;

        #! Returns crossPkgs from nixpkgs for target string or system.
        #! This will always cross-compile the package.
        crossPkgsForTarget = with zig2nix-lib; args': let
          target-system = if isString args' then mkZigSystemFromString args' else args';
          crossPkgs = import nixpkgs { localSystem = system; crossSystem = { config = nixTripleFromSystem target-system; }; };
          this-system = (systems.elaborate system).config == nixTripleFromSystem target-system;
        in if this-system then pkgs else crossPkgs;

        #! Returns pkgs from nixpkgs for target string or system.
        #! This does not cross-compile and you'll get a error if package does not exist in binary cache.
        binaryPkgsForTarget = with zig2nix-lib; args': let
          target-system = if isString args' then mkZigSystemFromString args' else args';
          binaryPkgs = import nixpkgs { localSystem = { config = nixTripleFromSystem target-system; }; };
          this-system = (systems.elaborate system).config == nixTripleFromSystem target-system;
        in if this-system then pkgs else binaryPkgs;

        #! Returns either binaryPkgs or crossPkgs depending if the target is flake target or not.
        pkgsForTarget = args':
          if isFlakeTarget args' then binaryPkgsForTarget args'
          else crossPkgsForTarget args';

        # Solving platform specific spaghetti
        runtimeForTargetSystem = pkgs.callPackage ./src/runtime.nix {
          inherit (zig2nix-lib) mkZigSystemFromString;
          inherit pkgsForTarget customAppHook customDevShellHook customRuntimeLibs;
          inherit enableVulkan enableOpenGL enableWayland enableX11;
        };

        # Package a Zig project
        zigPackage = target: (crossPkgsForTarget target).callPackage (pkgs.callPackage ./src/package.nix {
          inherit zig runtimeForTargetSystem;
          inherit (zig2nix-lib) resolveTargetSystem zigTripleFromSystem fromZON deriveLockFile;
        });

        #! Cross-compile nixpkgs using zig :)
        #! NOTE: This is an experimental feature, expect it not faring well
        zigCrossPkgsForTarget = with zig2nix-lib; args': let
          target-system = if isString args' then mkZigSystemFromString args' else args';
          crossPkgs = pkgs.callPackage ./src/cross {
            inherit zig zigPackage allTargetSystems nixTripleFromSystem zigTripleFromSystem mkZigSystemFromPlatform;
            nixCrossPkgs = pkgsForTarget target-system;
            localSystem = system;
            crossSystem = { config = nixTripleFromSystem target-system; };
          };
        in warn "zigCross: ${zigTripleFromSystem target-system}" crossPkgs;

        runtime = runtimeForTargetSystem system;
        _deps = [ zig ] ++ customRuntimeDeps;
      in rec {
        inherit pkgs pkgsForTarget crossPkgsForTarget zigCrossPkgsForTarget binaryPkgsForTarget;
        inherit zig zon2json zon2json-lock zon2nix zig-hook;

        #! Tools for bridging zig and nix
        lib = zig2nix-lib;

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
        };

        #! Flake app helper (Without zig-env).
        app-bare = deps: script: app-bare-no-root deps ''
          [[ -f ./flake.nix ]] || error 'Run this from the project root'
          ${script}
          '';

        #! Flake app helper (without root dir restriction).
        app-no-root = deps: script: app-bare-no-root (deps ++ _deps) ''
          ${runtime.app}
          ${script}
          '';

        #! Flake app helper.
        app = deps: script: app-bare (deps ++ _deps) ''
          ${runtime.app}
          ${script}
          '';

        #! Creates dev shell.
        mkShell = pkgs.callPackage ({
          nativeBuildInputs ? [],
          ...
        } @attrs: pkgs.mkShell (attrs // {
          nativeBuildInputs = optionals (attrs ? nativeBuildInputs) attrs.nativeBuildInputs ++ _deps;
          shellHook = ''
            ${runtime.shell}
            ${attrs.shellHook or ""}
          '';
        }));

        #! Print external dependencies of zig project
        showExternalDeps = app-no-root [] ''
          zig build --build-runner ${./src/build_runner.zig} "$@"
          '';

        #! Package for specific target supported by nix.
        #! You can still compile to other platforms by using package and specifying zigTarget.
        #! When compiling to non-nix supported targets, you can't rely on pkgsForTarget, but rather have to provide all the pkgs yourself.
        #! NOTE: Even though target is supported by nix, cross-compiling to it might not be, in that case you should get an error.
        packageForTarget = zigPackage;

        #! Packages zig project.
        #! NOTE: If your project has build.zig.zon you must first generate build.zig.zon2json-lock using zon2json-lock.
        #!       It is recommended to commit the build.zig.zon2json-lock to your repo.
        #!
        #! Additional attributes:
        #!    zigTarget: Specify target for zig compiler, defaults to stdenv.targetPlatform of given target.
        #!    zigInheritStdenv:
        #!       By default if zigTarget is specified, nixpkgs stdenv compatible environment is not used.
        #!       Set this to true, if you want to specify zigTarget, but still use the derived stdenv compatible environment.
        #!    zigPreferMusl: Prefer musl libc without specifying the target.
        #!    zigDisableWrap: makeWrapper will not be used. Might be useful if distributing outside nix.
        #!    zigWrapperArgs: Additional arguments to makeWrapper.
        #!    zigBuildZon: Path to build.zig.zon file, defaults to build.zig.zon.
        #!    zigBuildZonLock: Path to build.zig.zon2json-lock file, defaults to build.zig.zon2json-lock.
        #!
        #! <https://github.com/NixOS/nixpkgs/blob/master/doc/hooks/zig.section.md>
        package = packageForTarget system;
      };

      # Default zig env used by this flake
      env = zig-env { zig = zigv.master; };
      app = env.app-bare;
    in rec {
      #! --- Architecture dependent flake outputs.
      #!     access: `zig2nix.outputs.thing.${system}`

      #! Helper functions for building and running Zig projects.
      inherit zig-env zig2nix-lib zig-hook;

      #! Versioned Zig packages.
      packages.zig = zigv;

      #! zon2json: Converts zon files to json
      packages.zon2json = zon2json;

      #! zon2json-lock: Converts build.zig.zon to a build.zig.zon2json lock file
      packages.zon2json-lock = zon2json-lock;

      #! zon2nix: Converts build.zig.zon and build.zig.zon2json-lock to nix deriviation
      packages.zon2nix = zon2nix;

      #! Nixpkgs cross-compiled with zig
      packages.zigCross = env.pkgs.lib.genAttrs env.lib.allTargetTriples (t: env.zigCrossPkgsForTarget t);

      #! Default zig package.
      #! Latest released zig.
      packages.default = zigv.default;

      #! Print external dependencies of zig project
      #! nix run#deps."zig-version"
      #! example: nix run#deps.master
      apps.deps = mapAttrs (k: v: (zig-env {zig = v;}).showExternalDeps) zigv;

      #! Run a version of a Zig compiler inside a `zig-env`.
      #! nix run#zig."zig-version"
      #! example: nix run#zig.master
      apps.zig = mapAttrs (k: v: (zig-env {zig = v;}).app-no-root [] ''zig "$@"'') zigv;

      #! Run a version of a Zig compiler inside a `zig-env` (With Wayland support).
      #! nix run#zig-wayland."zig-version"
      #! example: nix run#zig-wayland.master
      apps.zig-wayland = mapAttrs (k: v: (zig-env {zig = v; enableWayland = true;}).app-no-root [] ''zig "$@"'') zigv;

      #! Run a version of a Zig compiler inside a `zig-env` (With X11 support).
      #! nix run#zig-x11."zig-version"
      #! example: nix run#zig-x11.master
      apps.zig-x11 = mapAttrs (k: v: (zig-env {zig = v; enableX11 = true;}).app-no-root [] ''zig "$@"'') zigv;

      #! Run a latest released version of a Zig compiler inside a `zig-env`.
      #! nix run
      apps.default = apps.zig.default;

      #! Develop shell for building and running Zig projects.
      #! nix develop#zig."zig-version"
      #! example: nix develop#zig.master
      devShells.zig = mapAttrs (k: v: (zig-env {zig = v;}).mkShell {}) zigv;

      #! Develop shell for building and running Zig projects. (With Wayland support)
      #! nix develop#zig-wayland."zig-version"
      #! example: nix develop#zig-wayland.master
      devShells.zig-wayland = mapAttrs (k: v: (zig-env {zig = v; enableWayland = true;}).mkShell {}) zigv;

      #! Develop shell for building and running Zig projects. (With X11 support)
      #! nix develop#zig-x11."zig-version"
      #! example: nix develop#zig-x11.master
      devShells.zig-x11 = mapAttrs (k: v: (zig-env {zig = v; enableX11 = true;}).mkShell {}) zigv;

      #! Develop shell for building and running Zig projects.
      #! Uses latest released version of Zig.
      #! nix develop
      devShells.default = devShells.zig.default;

      #! Develop shell for building and running Zig projects (with Wayland support).
      #! Uses latest released version of Zig.
      #! nix develop
      devShells.wayland = devShells.zig-wayland.default;

      #! Develop shell for building and running Zig projects (with X11 support).
      #! Uses latest released version of Zig.
      #! nix develop
      devShells.x11 = devShells.zig-x11.default;

      # nix run .#update-versions
      apps.update-versions = with env.pkgs; app [ curl jq ] ''
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        curl -sSL https://ziglang.org/download/index.json |\
          jq 'with_entries(select(.key != "0.1.1" and .key != "0.2.0" and .key != "0.3.0" and .key != "0.4.0" and .key != "0.5.0" and .key != "0.6.0" and .key != "0.7.0" and .key != "0.7.1"))' > "$tmpdir"/versions.json
        jq 'to_entries | {"default": ({"version": .[1].key} + .[1].value)}' "$tmpdir/versions.json" | cat "$tmpdir/versions.json" - | jq -s add
        '';

      # nix run .#update-templates
      apps.update-templates = with env.pkgs; app [ coreutils gnused ] ''
        rm -rf templates/default
        mkdir -p templates/default
        sed 's#/[*]SED_ZIG_VER[*]/##' templates/flake.nix > templates/default/flake.nix
        sed -i 's#@SED_ZIG_BIN@#default#' templates/default/flake.nix
        cp -f templates/gitignore templates/default/.gitignore
        cp -f .gitattributes templates/default/.gitattributes
        (cd templates/default; ${packages.zig.default}/bin/zig init || ${packages.zig.default}/bin/zig init-exe)

        rm -rf templates/master
        mkdir -p templates/master
        # shellcheck disable=SC2016
        sed 's#/[*]SED_ZIG_VER[*]/# zig = zig2nix.outputs.packages.''${system}.zig.master; #' templates/flake.nix > templates/master/flake.nix
        sed -i 's#@SED_ZIG_BIN@#master#' templates/master/flake.nix
        cp -f templates/gitignore templates/master/.gitignore
        cp -f .gitattributes templates/master/.gitattributes
        (cd templates/master; ${packages.zig.master}/bin/zig init)
        '';

      apps.test = env.pkgs.callPackage src/test.nix {
        inherit app zon2json-lock;
        inherit (zig2nix-lib) deriveLockFile resolveTargetSystem zigTripleFromSystem nixTripleFromSystem allFlakeTargetTriples;
        inherit (env) zig;
        envPackage = env.package;
      };

      # nix run .#readme
      apps.readme = let
        project = "zig2nix flake";
      in with env.pkgs; app [ gawk gnused jq ] (replaceStrings ["`"] ["\\`"] ''
      cat <<EOF
      # ${project}

      Flake for packaging, building and running Zig projects.

      https://ziglang.org/

      ---

      [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

      * Zig master: `${zigv.master.version} @ ${zigv.master.date}`
      * Zig default: `${zigv.default.version} @ ${zigv.default.date}`

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

      ### Running zig compiler directly

      ```bash
      nix run github:Cloudef/zig2nix -- version
      ```

      ### Shell for building and running a Zig project

      ```bash
      nix develop github:Cloudef/zig2nix
      ```

      ### Convert zon file to json

      ```bash
      nix run .#zon2json -- build.zig.zon
      ```

      ### Convert build.zig.zon to a build.zig.zon2json-lock

      ```bash
      nix run .#zon2json-lock -- build.zig.zon
      # alternatively output to stdout
      nix run .#zon2json-lock -- build.zig.zon -
      ```

      ### Convert build.zig.zon/2json-lock to a nix derivation

      ```bash
      # calls zon2json-lock if build.zig.zon2json-lock does not exist (requires network access)
      nix run .#zon2nix -- build.zig.zon
      # alternatively run against the lock file (no network access required)
      nix run .#zon2nix -- build.zig.zon2json-lock
      ```

      ### Cross-compile nixpkgs using zig

      > This is very experimental, and many things may not compile.

      ```bash
      nix build .#zigCross.x86_64-windows-gnu.zlib
      ```

      ## Crude documentation

      Below is auto-generated dump of important outputs in this flake.

      ```nix
      $(awk -f doc.awk flake.nix | sed "s/```/---/g")
      ```
      EOF
      '');
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
  in outputs // rec {
    #! --- Generic flake outputs.
    #!     access: `zig2nix.outputs.thing`

    #! Overlay for overriding Zig with specific version.
    overlays.zig = mapAttrs (k: v: (final: prev: {
      zig = v;
      inherit (outputs.packages) zon2json zon2json-lock zon2nix;
    })) outputs.packages.${prev.system}.zig;

    #! mitchellh/zig-overlay compatible overlay.
    overlays.zig-overlay = final: prev: {
      zigpkgs = outputs.packages.${prev.system}.zig;
      inherit (outputs.packages) zon2json zon2json-lock zon2nix;
    };

    #! Default overlay
    overlays.default = overlays.zig.default;

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

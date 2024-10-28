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
      in (pkgs.callPackage tools/zon2json/default.nix { zig = zigv.default.bin; }) {
        zigBuildFlags = [ "-Dtarget=${target}" ];
      };

      # Converts build.zig.zon to a build.zig.zon2json lock file
      zon2json-lock = pkgs.callPackage tools/zon2json-lock.nix {
        zig = zigv.default.bin;
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
        zig ? zigv.default.bin,
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
        # Enable Alsa support.
        enableAlsa ? false,
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
          inherit enableVulkan enableOpenGL enableWayland enableX11 enableAlsa;
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
            inherit zig zigPackage allTargetSystems;
            inherit nixTripleFromSystem zigTripleFromSystem;
            inherit mkZigSystemFromPlatform mkZigSystemFromString;
            nixCrossPkgs = pkgsForTarget target-system;
            localSystem = system;
            crossSystem = { config = nixTripleFromSystem target-system; };
          };
        in warn "zigCross: ${zigTripleFromSystem target-system}" crossPkgs;

        runtime = runtimeForTargetSystem system;
        _deps = [ zig ] ++ customRuntimeDeps ++ runtime.build-bins;
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
        } @attrs: pkgs.mkShellNoCC (attrs // {
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

        #! Bundle a package into a zip
        bundle.zip = pkgs.callPackage ./src/bundle/zip.nix { inherit packageForTarget; };

        #! Bundle a package for running in AWS lambda
        bundle.aws.lambda = pkgs.callPackage ./src/bundle/lambda.nix { bundleZip = bundle.zip; };
      };

      # Default zig env used for tests and automation.
      test-env = zig-env { zig = zigv.master.bin; };
      test-app = test-env.app-bare;

      # For the convenience flake outputs
      multimedia-attrs = {
        enableX11 = true;
        enableWayland = true;
        enableVulkan = true;
        enableOpenGL = true;
        enableAlsa = true;
      };
    in rec {
      #! --- Architecture dependent flake outputs.
      #!     access: `zig2nix.outputs.thing.${system}`

      #! Helper functions for building and running Zig projects.
      inherit zig-env zig2nix-lib zig-hook;

      #! Prints available zig versions
      apps.versions = with pkgs; test-app [ coreutils jq ] ''
        printf 'git\nmaster\ndefault\n'
        jq -r 'delpaths([["master"],["default"],["git"]]) | keys_unsorted | sort_by(split(".") | map(tonumber)) | reverse | .[]' ${./versions.json}
        '';

      #! Versioned Zig packages.
      #! nix build .#zigv.master.bin
      #! nix build .#zigv.master.src
      #! nix run .#zigv.master.bin
      #! nix run .#zigv.master.src
      packages.zig = zigv;

      #! Default zig package.
      #! Latest released binary zig.
      packages.default = zigv.default.bin;

      #! zon2json: Converts zon files to json
      packages.zon2json = zon2json;

      #! zon2json-lock: Converts build.zig.zon to a build.zig.zon2json lock file
      packages.zon2json-lock = zon2json-lock;

      #! zon2nix: Converts build.zig.zon and build.zig.zon2json-lock to nix deriviation
      packages.zon2nix = zon2nix;

      # Generate flake packages for all the zig versions.
      packages.env = mapAttrs (k: v: let
          pkgs-for = zig: let
            env = zig-env { inherit zig; };
          in {
            #! Nixpkgs cross-compiled with zig
            cross = env.pkgs.lib.genAttrs env.lib.allTargetTriples (t: env.zigCrossPkgsForTarget t);
          };
        in {
          bin = pkgs-for v.bin;
          src = pkgs-for v.src;
        }
      ) zigv;

      #! Cross-compile nixpkgs with master zig
      packages.zigCross = packages.env.master.bin.cross;

      # Generates flake apps for all the zig versions.
      apps.env = mapAttrs (k: v: let
          apps-for = zig: let
            apps-for = attrs: let
              env = zig-env ({ inherit zig; } // attrs);
            in {
              #! Run a version of a Zig compiler
              #! nix run .#env."zig-version"."build"."type".zig
              #! example: nix run .#env.master.src.bare.zig
              #! example: nix run .#env.default.bin.multimedia.zig
              zig = env.app-no-root [] ''zig "$@"'';

              #! Print external dependencies of zig project
              #! nix run .#env."zig-version"."build"."type".showExternalDeps
              #! example: nix run .#env.master.src.bare.showExternalDeps
              #! example: nix run .#env.default.bin.multimedia.showExternalDeps
              inherit (env) showExternalDeps;
            };
          in {
            # Minimal environment
            bare = apps-for {};
            # Environment for running multimedia programs
            multimedia = apps-for multimedia-attrs;
          };
        in {
          bin = apps-for v.bin;
          src = apps-for v.src;
        }
      ) zigv;

      #! Master zig
      apps.master = apps.env.master.bin.bare.zig;

      #! Default zig
      apps.default = apps.env.default.bin.bare.zig;

      # Develop shell for building and running Zig projects.
      # nix develop .#env."zig-version"."build"."type"
      # example: nix develop .#env.master.src.bare
      # example: nix develop .#env.default.bin.multimedia
      devShells.env = mapAttrs (k: v: let
          shells-for = zig: let
            shells-for = attrs: let
              env = zig-env ({ inherit zig; } // attrs);
            in env.mkShell {};
          in {
            # Minimal environment
            bare = shells-for {};
            # Environment for running multimedia programs
            multimedia = shells-for multimedia-attrs;
          };
        in {
          bin = shells-for v.bin;
          src = shells-for v.src;
        }
      ) zigv;

      #! Master dev shell
      devShells.master = devShells.env.master.bin.bare;

      #! Default dev shell
      devShells.default = devShells.env.default.bin.bare;

      # nix run .#update-versions
      apps.update-versions = with pkgs; test-app [ curl jq coreutils ] ''
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        read -r rev _ < <(git ls-remote https://github.com/ziglang/zig.git HEAD)
        url="https://github.com/ziglang/zig/archive/$rev.tar.gz"
        curl -sSL "$url" -o "$tmpdir/git.tar.gz"
        read -r size _ < <(wc -c "$tmpdir/git.tar.gz")
        date="$(date +"%Y-%m-%d")"
        cat <<EOF > "$tmpdir/git.json"
        {
          "git": {
            "version": "git+''${rev:0:7}+$date",
            "date": "$date",
            "docs": "https://ziglang.org/documentation/master/",
            "stdDocs": "https://ziglang.org/documentation/master/std/",
            "src": {
              "tarball": "$url",
              "shasum": "$(nix hash file --type sha256 --base16 "$tmpdir/git.tar.gz")",
              "size": "$size"
            }
          }
        }
        EOF
        curl -sSL https://ziglang.org/download/index.json |\
          jq 'with_entries(select(.key != "0.1.1" and .key != "0.2.0" and .key != "0.3.0" and .key != "0.4.0" and .key != "0.5.0" and .key != "0.6.0" and .key != "0.7.0" and .key != "0.7.1"))' > "$tmpdir"/versions.json
        jq 'to_entries | {"default": ({"version": .[1].key} + .[1].value)}' "$tmpdir/versions.json" | cat "$tmpdir/git.json" - "$tmpdir/versions.json" | jq -s add
        '';

      # nix run .#update-templates
      apps.update-templates = with pkgs; test-app [ coreutils gnused ] ''
        rm -rf templates/default
        mkdir -p templates/default
        sed 's#/[*]SED_ZIG_VER[*]/##' templates/flake.nix > templates/default/flake.nix
        sed -i 's#@SED_ZIG_BIN@#default#' templates/default/flake.nix
        cp -f templates/gitignore templates/default/.gitignore
        cp -f .gitattributes templates/default/.gitattributes
        (cd templates/default; ${packages.zig.default.bin}/bin/zig init)

        rm -rf templates/master
        mkdir -p templates/master
        # shellcheck disable=SC2016
        sed 's#/[*]SED_ZIG_VER[*]/# zig = zig2nix.outputs.packages.''${system}.zig.master.bin; #' templates/flake.nix > templates/master/flake.nix
        sed -i 's#@SED_ZIG_BIN@#master#' templates/master/flake.nix
        cp -f templates/gitignore templates/master/.gitignore
        cp -f .gitattributes templates/master/.gitattributes
        (cd templates/master; ${packages.zig.master.bin}/bin/zig init)
        '';

      apps.test = pkgs.callPackage src/test.nix {
        inherit test-app zon2json-lock;
        inherit (zig2nix-lib) deriveLockFile resolveTargetSystem zigTripleFromSystem nixTripleFromSystem allFlakeTargetTriples;
        inherit (test-env) zig;
        zig-env = test-env;
      };

      # nix run .#readme
      apps.readme = let
        project = "zig2nix flake";
      in with pkgs; test-app [ gawk gnused jq ] (replaceStrings ["`"] ["\\`"] ''
      cat <<EOF
      # ${project}

      Flake for packaging, building and running Zig projects.

      https://ziglang.org/

      * Cachix: `cachix use zig2nix`

      ---

      [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

      * Zig git: `${zigv.git.src.version} @ ${zigv.git.src.date}`
      * Zig master: `${zigv.master.bin.version} @ ${zigv.master.bin.date}`
      * Zig default: `${zigv.default.bin.version} @ ${zigv.default.bin.date}`

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
      nix build github:Cloudef/zig2nix#zig.master.src
      ```

      ### Running zig compiler directly

      ```bash
      nix run github:Cloudef/zig2nix#env.master.bin.bare.zig -- version
      nix run github:Cloudef/zig2nix#env.default.bin.bare.zig -- version
      # Or simply these aliases
      nix run github:Cloudef/zig2nix#master -- version
      nix run github:Cloudef/zig2nix -- version
      ```

      #### Convenience zig for multimedia programs

      > This sets (DY)LD_LIBRARY_PATH and PKG_CONFIG_PATH so that common libs are available

      ```bash
      nix run github:Cloudef/zig2nix#env.master.bin.multimedia.zig -- version
      nix run github:Cloudef/zig2nix#env.default.bin.multimedia.zig -- version
      ```

      ### Shell for building and running a Zig project

      ```bash
      nix develop github:Cloudef/zig2nix#env.master.bin.bare
      nix develop github:Cloudef/zig2nix#env.default.bin.bare
      # Or simply these aliases
      nix develop github:Cloudef/zig2nix#master
      nix develop github:Cloudef/zig2nix
      ```

      #### Convenience shell for multimedia programs

      > This sets (DY)LD_LIBRARY_PATH and PKG_CONFIG_PATH so that common libs are available

      ```bash
      nix develop github:Cloudef/zig2nix#env.master.bin.multimedia
      nix develop github:Cloudef/zig2nix#env.default.bin.multimedia
      ```

      ### Convert zon file to json

      ```bash
      nix run github:Cloudef/zig2nix#zon2json -- build.zig.zon
      ```

      ### Convert build.zig.zon to a build.zig.zon2json-lock

      ```bash
      nix run github:Cloudef/zig2nix#zon2json-lock -- build.zig.zon
      # alternatively output to stdout
      nix run github:Cloudef/zig2nix#zon2json-lock -- build.zig.zon -
      ```

      ### Convert build.zig.zon/2json-lock to a nix derivation

      ```bash
      # calls zon2json-lock if build.zig.zon2json-lock does not exist (requires network access)
      nix run github:Cloudef/zig2nix#zon2nix -- build.zig.zon
      # alternatively run against the lock file (no network access required)
      nix run github:Cloudef/zig2nix#zon2nix -- build.zig.zon2json-lock
      ```

      ### Cross-compile nixpkgs using zig

      > This is very experimental, and many things may not compile.

      ```bash
      nix build github:Cloudef/zig2nix#env.master.bin.cross.x86_64-windows-gnu.zlib
      nix build github:Cloudef/zig2nix#env.default.bin.cross.x86_64-windows-gnu.zlib
      # Or simply this alias that uses env.master.bin
      nix build github:Cloudef/zig2nix#zigCross.x86_64-windows-gnu.zlib
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

    #! Overlay for overriding Zig with specific version (source).
    overlays.zig.src = mapAttrs (k: v: (final: prev: {
      zig = v.src;
      inherit (outputs.packages) zon2json zon2json-lock zon2nix;
    })) outputs.packages.${prev.system}.zig;

    #! Overlay for overriding Zig with specific version (binary).
    overlays.zig.bin = mapAttrs (k: v: (final: prev: {
      zig = v.bin;
      inherit (outputs.packages) zon2json zon2json-lock zon2nix;
    })) outputs.packages.${prev.system}.zig;

    #! mitchellh/zig-overlay compatible overlay.
    overlays.zig-overlay = final: prev: {
      zigpkgs = mapAttrs (k: v: v.bin) outputs.packages.${prev.system}.zig;
      inherit (outputs.packages) zon2json zon2json-lock zon2nix;
    };

    #! Default overlay
    overlays.default = overlays.zig.bin.default;

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

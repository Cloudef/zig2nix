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

      zig2nix-lib-base = pkgs.callPackage ./lib.nix {};

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
      } ./setup-hook.sh;

      # Zig versions.
      # <https://ziglang.org/download/index.json>
      zigv = pkgs.callPackage ./versions.nix {
        zigSystem = zig2nix-lib.zigDoubleFromString system;
        zigHook = zig-hook;
      };

      # Converts zon files to json
      zon2json = let
        target = zig2nix-lib.resolveTargetTriple { target = system; musl = true; };
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
      zig2nix-lib = zig2nix-lib-base // {
        fromZON = path: fromJSON (readFile (pkgs.runCommandLocal "readZon" {} ''${zon2json}/bin/zon2json "${path}" > "$out"''));
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

        #! Returns crossPkgs from nixpkgs for target string or system.
        #! This will always cross-compile the package.
        pkgsForTarget = args': let
          target-system = if isString args' then zig2nix-lib.mkZigSystemFromString args' else args';
          crossPkgs = import nixpkgs { localSystem = system; crossSystem = { config = systems.parse.tripleFromSystem target-system; }; };
        in crossPkgs;

        #! Returns pkgs from nixpkgs for target string or system.
        #! This does not cross-compile and you'll get a error if package does not exist in binary cache.
        binaryPkgsForTarget = args': let
          target-system = if isString args' then zig2nix-lib.mkZigSystemFromString args' else args';
          binaryPkgs = import nixpkgs { localSystem = { config = systems.parse.tripleFromSystem target-system; }; };
        in binaryPkgs;

        # Solving platform specific spaghetti below
        # args' can be either target string or system
        runtimeForTargetSystem = args': let
          system = if isString args' then zig2nix-lib.mkZigSystemFromString args' else args';
          targetPkgs = pkgsForTarget system;
          env = rec {
            linux = {
              LIBRARY_PATH = "LD_LIBRARY_PATH";
              wrapperBuildInputs = [ pkgs.autoPatchelfHook ];
            };
            darwin = let
              sdkVer = targetPkgs.targetPlatform.darwinSdkVersion;
              sdk =
                if (versionAtLeast sdkVer "10.13") then targetPkgs.darwin.apple_sdk.MacOSX-SDK
                else warn "zig only supports macOS 10.13+, forcing SDK 11.0" targetPkgs.darwin.apple_sdk_11_0.MacOSX-SDK;
            in {
              LIBRARY_PATH = "DYLD_LIBRARY_PATH";
              stdenvZigFlags = [ "--sysroot" sdk ];
            };
            ios = darwin;
            watchos = darwin;
            tvos = darwin;
          };
          libs = {
            linux = with targetPkgs; []
              ++ optionals (enableVulkan) [ vulkan-loader ]
              ++ optionals (enableOpenGL) [ libGL ]
              # Some common runtime libs used by x11 apps, for example: https://www.glfw.org/docs/3.3/compat.html
              # You can always include more if you need with customRuntimeLibs.
              ++ optionals (enableX11) [ xorg.libX11 xorg.libXext xorg.libXfixes xorg.libXi xorg.libXrender xorg.libXrandr ]
              ++ optionals (enableWayland) [ wayland libxkbcommon libdecor ];
          };
          bins = {};
        in {
          env = env.${system.kernel.name} or {};
          libs = libs.${system.kernel.name} or [];
          bins = bins.${system.kernel.name} or [];
        };

        _linux_extra = let
          runtime = runtimeForTargetSystem system;
          ld_string = makeLibraryPath (runtime.libs ++ customRuntimeLibs);
        in ''
          export ZIG_BTRFS_WORKAROUND=1
          export ${runtime.env.LIBRARY_PATH}="${ld_string}:''${LD_LIBRARY_PATH:-}"
        '';

        _darwin_extra = let
          runtime = runtimeForTargetSystem system;
          ld_string = makeLibraryPath (runtime.libs ++ customRuntimeLibs);
        in ''
          export ${runtime.env.LIBRARY_PATH}="${ld_string}:''${DYLD_LIBRARY_PATH:-}"
        '';

        _deps = [ zig ] ++ customRuntimeDeps;
        _extraApp = customAppHook
          + optionalString (pkgs.stdenv.isLinux) _linux_extra
          + optionalString (pkgs.stdenv.isDarwin) _darwin_extra;
        _extraShell = customDevShellHook
          + optionalString (pkgs.stdenv.isLinux) _linux_extra
          + optionalString (pkgs.stdenv.isDarwin) _darwin_extra;
      in rec {
        #! Inherit given pkgs and zig version
        inherit pkgs pkgsForTarget binaryPkgsForTarget zig zon2json zon2json-lock zon2nix zig-hook;

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
          ${_extraApp}
          ${script}
          '';

        #! Flake app helper.
        app = deps: script: app-bare (deps ++ _deps) ''
          ${_extraApp}
          ${script}
          '';

        #! Creates dev shell.
        shell = pkgs.mkShell {
          buildInputs = _deps;
          shellHook = _extraShell;
        };

        #! Package for specific target supported by nix.
        #! You can still compile to other platforms by using package and specifying zigTarget.
        #! When compiling to non-nix supported targets, you can't rely on pkgsForTarget, but rather have to provide all the pkgs yourself.
        #! NOTE: Even though target is supported by nix, cross-compiling to it might not be, in that case you should get an error.
        packageForTarget = target: (pkgsForTarget target).callPackage (pkgs.callPackage ./package.nix {
          inherit zig zon2nix zig2nix-lib runtimeForTargetSystem;
        });

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
      env = zig-env {};
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

      #! Default zig package.
      #! Latest released zig.
      packages.default = zigv.default;

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
      devShells.zig = mapAttrs (k: v: (zig-env {zig = v;}).shell) zigv;

      #! Develop shell for building and running Zig projects. (With Wayland support)
      #! nix develop#zig-wayland."zig-version"
      #! example: nix develop#zig-wayland.master
      devShells.zig-wayland = mapAttrs (k: v: (zig-env {zig = v; enableWayland = true;}).shell) zigv;

      #! Develop shell for building and running Zig projects. (With X11 support)
      #! nix develop#zig-x11."zig-version"
      #! example: nix develop#zig-x11.master
      devShells.zig-x11 = mapAttrs (k: v: (zig-env {zig = v; enableX11 = true;}).shell) zigv;

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

      # nix run .#test-zon2json-lock
      apps.test-zon2json-lock = app [ zon2json-lock ] ''
        nix store add-file tools/fixtures/file-url-test.tar.gz
        for f in tools/fixtures/*.zig.zon; do
          echo "testing (zon2json-lock): $f"
          if ! cmp <(zon2json-lock "$f" -) "''${f}2json-lock"; then
            error "unexpected output"
          fi
        done
        '';

      # nix run .#test-zon2nix
      apps.test-zon2nix = with env.pkgs; with env.pkgs.lib; let
        fixtures = filter (f: hasSuffix ".zig.zon2json-lock" f) (attrNames (readDir ./tools/fixtures));
        drvs = map (f: {
          lck = f;
          out = callPackage (runCommandLocal "deps" {} ''${zon2nix}/bin/zon2nix ${./tools/fixtures/${f}} > $out'') {
            zig = zigv.master;
          };
        }) fixtures;
        test = drv: ''
          echo "testing (zon2nix): ${drv.lck}"
          if [[ -s "${./tools/fixtures/${drv.lck}}" ]]; then
            for d in ${drv.out}/*; do
              test -d "$d" || error 'is not a directory: %s' "$d"
              if [[ $(wc -l < <(find "$d/" -mindepth 1 -maxdepth 1 -type f)) == 0 ]]; then
                error "does not contain any regular files: %s" "$d"
              fi
              zhash="$(basename "$d")"
              if ! ${jq}/bin/jq -er --arg k "$zhash" '."\($k)"' ${./tools/fixtures/${drv.lck}} > /dev/null; then
                error 'missing zhash: %s' "$zhash"
              fi
            done
          else
            test "$(find ${drv.out}/ -mindepth 1 -maxdepth 1 | wc -l)" = 0 || error 'output not empty: %s' '${drv.out}'
          fi
          echo "  ${drv.out}"
          '';
      in app [ findutils coreutils ] (concatStringsSep "\n" (map test drvs));

      # nix run .#test-templates
      apps.test-templates = with env.pkgs; app [ file ] ''
        for var in default master; do
          printf -- 'run . (%s)\n' "$var"
          (cd templates/"$var"; nix run --override-input zig2nix ../.. .)
          printf -- 'run .#bundle.default (%s)\n' "$var"
          (cd templates/"$var"; nix run --override-input zig2nix ../.. .#bundle.default)
          printf -- 'run .#test (%s)\n' "$var"
          (cd templates/"$var"; nix run --override-input zig2nix ../.. .#test)
          printf -- 'build . (%s)\n' "$var"
          (cd templates/"$var"; nix build --override-input zig2nix ../.. .; ./result/bin/"$var")
          if [[ "$var" == master ]]; then
            for arch in x86_64-windows ${concatStringsSep " " lib.systems.flakeExposed}; do
              printf -- 'build .#target.%s (%s)\n' "$arch" "$var"
              (cd templates/"$var"; nix build --override-input zig2nix ../.. .#target."$arch"; file ./result/bin/"$var"*)
            done
          fi
          rm -f templates/"$var"/result
          rm -rf templates/"$var"/zig-out
          rm -rf templates/"$var"/zig-cache
        done
        '';

      # nix run .#test
      apps.test = app [] ''
        nix run .#test-zon2json-lock
        nix run .#test-zon2nix
        nix run .#test-templates
        '';

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

      ## Zig project template

      ```bash
      nix flake init -t github:Cloudef/zig2nix
      nix run .
      # for more options check the flake.nix file
      ```

      ### With master version of Zig

      ```bash
      nix flake init -t github:Cloudef/zig2nix#master
      nix run .
      # for more options check the flake.nix file
      ```

      ## Running zig compiler directly

      ```bash
      nix run github:Cloudef/zig2nix -- version
      ```

      ## Shell for building and running a Zig project

      ```bash
      nix develop github:Cloudef/zig2nix
      ```

      ## Convert zon file to json

      ```bash
      nix run .#zon2json -- build.zig.zon
      ```

      ## Convert build.zig.zon to a build.zig.zon2json-lock

      ```bash
      nix run .#zon2json-lock -- build.zig.zon
      # alternatively output to stdout
      nix run .#zon2json-lock -- build.zig.zon -
      ```

      ## Convert build.zig.zon/2json-lock to a nix derivation

      ```bash
      # calls zon2json-lock if build.zig.zon2json-lock does not exist (requires network access)
      nix run .#zon2nix -- build.zig.zon
      # alternatively run against the lock file (no network access required)
      nix run .#zon2nix -- build.zig.zon2json-lock
      ```

      ## Crude documentation

      Below is auto-generated dump of important outputs in this flake.

      ```nix
      $(awk -f doc.awk flake.nix | sed "s/```/---/g")
      ```
      EOF
      '');

      # for env.package testing
      packages.test = env.package { src = ./tools/zon2json; };

      # for debugging
      apps.repl = flake-utils.lib.mkApp {
        drv = env.pkgs.writeShellScriptBin "repl" ''
          confnix=$(mktemp)
          echo "builtins.getFlake (toString $(git rev-parse --show-toplevel))" >$confnix
          trap "rm $confnix" EXIT
          nix repl $confnix
          '';
      };
    }));
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
        welcomeText = ''
          # ${description}
          - Zig: https://ziglang.org/

          ## Build & Run

          ```
          nix run .
          ```

          See flake.nix for more options.
          '';
      };

      #! Master project template
      #! nix flake init -t templates
      templates.master = rec {
        path = ./templates/master;
        description = "Master Zig project template";
        welcomeText = ''
          # ${description}
          - Zig: https://ziglang.org/

          ## Build & Run

          ```
          nix run .
          ```

          See flake.nix for more options.
          '';
      };
    };
}

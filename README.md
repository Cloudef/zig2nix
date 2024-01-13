# zig2nix flake

Flake for packaging, building and running Zig projects.

https://ziglang.org/

---

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

* Zig master: `0.12.0-dev.2150+63de8a598 @ 2024-01-12`
* Zig default: `0.11.0 @ 2023-08-04`

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

## Crude documentation

Below is auto-generated dump of important outputs in this flake.

```nix
#! Structures.

#: Helper function for building and running Zig projects.
zig-env = {
  # Overrideable nixpkgs.
  pkgs ? _pkgs,
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
}: {};

#! --- Outputs of zig-env {} function.
#!     access: (zig-env {}).thing

#! Inherit given pkgs and zig version
inherit pkgs zig zon2json zon2json-lock zon2nix;

#! Tools for bridging zig and nix
lib = zig2nix-lib;

#: Flake app helper (Without zig-env and root dir restriction).
app-bare-no-root = deps: script: {
  type = "app";
  program = toString (pkgs.writeShellApplication {
  name = "app";
  runtimeInputs = [] ++ deps;
  text = ''
  # shellcheck disable=SC2059
  error() { printf -- "error: $1" "''${@:2}" 1>&2; exit 1; }
  ${script}
  '';
};

#! Flake app helper (Without zig-env).
app-bare = deps: script: app-bare-no-root deps 

#! Flake app helper (without root dir restriction).
app-no-root = deps: script: app-bare-no-root (deps ++ _deps) 

#! Flake app helper.
app = deps: script: app-bare (deps ++ _deps) 

#: Creates dev shell.
shell = pkgs.mkShell {
  buildInputs = _deps;
  shellHook = _extraShell;
};

#: Packages zig project.
#: NOTE: If your project has build.zig.zon you must first generate build.zig.zon2json-lock using zon2json-lock.
#:       It is recommended to commit the build.zig.zon2json-lock to your repo.
#:
#: Additional attributes:
#:    zigTarget: Specify target for zig compiler, defaults to stdenv.targetPlatform.
#:    zigPreferMusl: Prefer musl libc without specifying the target.
#:    zigDisableWrap: makeWrapper will not be used. Might be useful if distributing outside nix.
#:    zigWrapperArgs: Additional arguments to makeWrapper.
#:    zigBuildZon: Path to build.zig.zon file, defaults to build.zig.zon.
#:    zigBuildZonLock: Path to build.zig.zon2json-lock file, defaults to build.zig.zon2json-lock.
#:
#: <https://github.com/NixOS/nixpkgs/blob/master/doc/hooks/zig.section.md>
package = pkgs.callPackage (pkgs.callPackage ./package.nix {
  inherit zig zon2nix zig2nix-lib runtimeForTarget;
};

#! --- Architecture dependent flake outputs.
#!     access: `zig2nix.outputs.thing.${system}`

#! Helper functions for building and running Zig projects.
inherit zig-env zig2nix-lib;

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

#! Run zon2json
apps.zon2json = app-no-root [zon2json] ''zon2json "$@"'';

#! Run zon2json-lock
apps.zon2json-lock = app-no-root [zon2json-lock] ''zon2json-lock "$@"'';

#! Run zon2nix
apps.zon2nix = app-no-root [zon2nix] ''zon2nix "$@"'';

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

#! --- Generic flake outputs.
#!     access: `zig2nix.outputs.thing`

#: Overlay for overriding Zig with specific version.
overlays.zig = mapAttrs (k: v: (final: prev: {
  zig = v;
  zon2json = outputs.packages.zon2json;
  zon2nix = outputs.packages.zon2nix;
};

#: mitchellh/zig-overlay compatible overlay.
overlays.zig-overlay = final: prev: {
  zigpkgs = outputs.packages.${prev.system}.zig;
};

#! Default overlay
overlays.default = overlays.zig.default;

#: Default project template
#: nix flake init -t templates
templates.default = rec {
  path = ./templates/default;
  description = "Default Zig project template";
  welcomeText = ''
  # ${description}
  - Zig: https://ziglang.org/
  
  ## Build & Run
  
  ---
  nix run .
  ---
  
  See flake.nix for more options.
  '';
};

#: Master project template
#: nix flake init -t templates
templates.master = rec {
  path = ./templates/master;
  description = "Master Zig project template";
  welcomeText = ''
  # ${description}
  - Zig: https://ziglang.org/
  
  ## Build & Run
  
  ---
  nix run .
  ---
  
  See flake.nix for more options.
  '';
};
```

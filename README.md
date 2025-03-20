# zig2nix flake

Flake for packaging, building and running Zig projects.

https://ziglang.org/

* Cachix: `cachix use zig2nix`

---

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

* Zig master: `0.15.0-dev.75+03123916e @ 2025-03-19`
* Zig latest: `0.14.0 @ 2025-03-05`

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

## Crude documentation

Below is auto-generated dump of important outputs in this flake.

```nix
#! Structures.

#:! Helper function for building and running Zig projects.
zig-env = {
 # Overrideable nixpkgs.
 nixpkgs ? self.inputs.nixpkgs,
 # Zig version to use.
 zig ? zigv.latest,
}: { ... };

#! --- Outputs of zig-env {} function.
#!     access: (zig-env {}).thing

#! Tools for bridging zig and nix
#! The correct zig version is put into the PATH
zig2nix = pkgs.writeShellApplication {
 name = "zig2nix";
 runtimeInputs = [ zig ];
 text = ''${zig2nix-zigless}/bin/zig2nix "$@"'';
};

#! Translates zig and nix compatible targets
target = system: (exec-json "target" [ system ]);

#! Reads zon file into a attribute set
fromZON = path: exec-json-path "zon2json" path [];

#! Creates derivation from zon2json-lock file
deriveLockFile = path: pkgs.callPackage (exec-path "zon2nix" path [ "-" ]);

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
 nativeBuildInputs = nativeBuildInputs ++ _deps;
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

#! --- Architecture dependent flake outputs.
#!     access: `zig2nix.outputs.thing.${system}`

#! Helper functions for building and running Zig projects.
inherit zig-env;

#! Versioned Zig packages.
#! nix build .#zig-master
#! nix build .#zig-latest
#! nix run .#zig-0_13_0
packages = mapAttrs' (k: v: nameValuePair ("zig-" + k) v) zigv;

#! Develop shell for building and running Zig projects.
#! nix develop .#zig_version
#! example: nix develop .#master
#! example: nix develop .#default
devShells = flake-outputs.devShells // {
 default = flake-outputs.devShells.latest;
};

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
```

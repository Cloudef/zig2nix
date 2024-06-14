# zig2nix flake

Flake for packaging, building and running Zig projects.

https://ziglang.org/

* Cachix: `cachix use zig2nix`

---

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

* Zig git: `git+82a934b+2024-06-14 @ 2024-06-14`
* Zig master: `0.14.0-dev.32+4aa15440c @ 2024-06-13`
* Zig default: `0.13.0 @ 2024-06-07`

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
#! Structures.

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
}: { ... };

#! --- Outputs of zig-env {} function.
#!     access: (zig-env {}).thing

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

#! --- Architecture dependent flake outputs.
#!     access: `zig2nix.outputs.thing.${system}`

#! Helper functions for building and running Zig projects.
inherit zig-env zig2nix-lib zig-hook;

#! Prints available zig versions
apps.versions = with pkgs; test-app [ coreutils jq ] ''
 printf 'master\ndefault\n'
 jq -r 'delpaths([["master"],["default"]]) | keys_unsorted | sort_by(split(".") | map(tonumber)) | reverse | .[]' ${./versions.json}
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

#! Nixpkgs cross-compiled with zig
cross = env.pkgs.lib.genAttrs env.lib.allTargetTriples (t: env.zigCrossPkgsForTarget t);

#! Cross-compile nixpkgs with master zig
packages.zigCross = packages.env.master.bin.cross;

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

#! Master zig
apps.master = apps.env.master.bin.bare.zig;

#! Default zig
apps.default = apps.env.default.bin.bare.zig;

#! Master dev shell
devShells.master = devShells.env.master.bin.bare;

#! Default dev shell
devShells.default = devShells.env.default.bin.bare;

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
```

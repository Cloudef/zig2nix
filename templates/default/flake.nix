{
  description = "Zig project flake";

  inputs = {
    zig2nix.url = "github:Cloudef/zig2nix";
  };

  outputs = { zig2nix, ... }: let
    flake-utils = zig2nix.inputs.flake-utils;
  in (flake-utils.lib.eachDefaultSystem (system: let
      # Zig flake helper
      # Check the flake.nix in zig2nix project for more options:
      # <https://github.com/Cloudef/zig2nix/blob/master/flake.nix>
      env = zig2nix.outputs.zig-env.${system} {};
      doubles = env.pkgs.lib.systems.doubles.all ++ [ "aarch64-ios" ];
    in with builtins; with env.pkgs.lib; rec {
      # nix build .#target.{nix-target}
      # e.g. nix build .#target.x86_64-linux
      packages.target = genAttrs doubles (target: env.packageForTarget target ({
        src = ./.;

        nativeBuildInputs = with env.pkgs; [];
        buildInputs = with env.pkgsForTarget target; [];

        # Smaller binaries and avoids shipping glibc.
        zigPreferMusl = true;

        # This disables LD_LIBRARY_PATH mangling, binary patching etc...
        # The package won't be usable inside nix.
        zigDisableWrap = true;
      } // optionalAttrs (!pathExists ./build.zig.zon) {
        pname = "my-zig-project";
        version = "0.0.0";
      }));

      # nix build .
      packages.default = packages.target.${system}.override {
        # Prefer nix friendly settings.
        zigPreferMusl = false;
        zigDisableWrap = false;
      };

      # For bundling with nix bundle for running outside of nix
      # example: https://github.com/ralismark/nix-appimage
      apps.bundle.target = genAttrs doubles (target: let
        pkg = packages.target.${target};
      in {
        type = "app";
        program = "${pkg}/bin/default";
      });

      # default bundle
      apps.bundle.default = apps.bundle.target.${system};

      # nix run .
      apps.default = env.app [] "zig build run -- \"$@\"";

      # nix run .#build
      apps.build = env.app [] "zig build \"$@\"";

      # nix run .#test
      apps.test = env.app [] "zig build test -- \"$@\"";

      # nix run .#docs
      apps.docs = env.app [] "zig build docs -- \"$@\"";

      # nix run .#deps
      apps.deps = env.showExternalDeps;

      # nix run .#zon2json
      apps.zon2json = env.app [env.zon2json] "zon2json \"$@\"";

      # nix run .#zon2json-lock
      apps.zon2json-lock = env.app [env.zon2json-lock] "zon2json-lock \"$@\"";

      # nix run .#zon2nix
      apps.zon2nix = env.app [env.zon2nix] "zon2nix \"$@\"";

      # nix develop
      devShells.default = env.mkShell {};
    }));
}

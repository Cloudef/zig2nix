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
      env = zig2nix.outputs.zig-env.${system} {/*SED_ZIG_VER*/};
    in rec {
      # nix build .
      packages.default = with env.pkgs.lib; env.package ({
        src = ./.;
      } // optionalAttrs (!builtins.pathExists ./build.zig.zon) {
        pname = "my-zig-project";
        version = "0.0.0";
      });

      # For bundling with nix bundle for running outside of nix
      # example: https://github.com/ralismark/nix-appimage
      apps.bundle = let
        pkg = packages.default.override {
          # This disables LD_LIBRARY_PATH mangling.
          # vulkan-loader, x11, wayland, etc... won't be included in the bundle.
          zigDisableWrap = true;

          # Smaller binaries and avoids shipping glibc.
          zigPreferMusl = true;
        };
      in {
        type = "app";
        program = "${pkg}/bin/@SED_ZIG_BIN@";
      };

      # nix run .
      apps.default = env.app [] "zig build run -- \"$@\"";

      # nix run .#test
      apps.test = env.app [] "zig build test -- \"$@\"";

      # nix run .#docs
      apps.docs = env.app [] "zig build docs -- \"$@\"";

      # nix run .#zon2json
      apps.zon2json = env.app [env.zon2json] "zon2json \"$@\"";

      # nix run .#zon2json-lock
      apps.zon2json-lock = env.app [env.zon2json-lock] "zon2json-lock \"$@\"";

      # nix run .#zon2nix
      apps.zon2nix = env.app [env.zon2nix] "zon2nix \"$@\"";

      # nix develop
      devShells.default = env.shell;
    }));
}

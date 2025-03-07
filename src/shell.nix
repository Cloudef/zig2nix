{
  lib
  , coreutils
  , system
}:

with builtins;
with lib;

let
  os = let
    parts = splitString "-" system;
  in last parts;

  hook = { LIBRARY_PATH, pkgs }: let
    ld_string = makeLibraryPath pkgs;
    # xorgproto puts its pc file in share/pkgconfig for whatever reason
    pc_string = concatStringsSep ":" [
      (makeSearchPathOutput "dev" "lib/pkgconfig" pkgs)
      (makeSearchPathOutput "dev" "share/pkgconfig" pkgs)
    ];
  in ''
    export ${LIBRARY_PATH}="${ld_string}:''${${LIBRARY_PATH}:-}"
    export PKG_CONFIG_PATH="${pc_string}:''${PKG_CONFIG_PATH:-}"
    '';

  runtime = {
    linux = rec {
      LIBRARY_PATH = "LD_LIBRARY_PATH";
      shell = pkgs: ''
        ver_between() { printf '%s\n' "$@" | ${coreutils}/bin/sort -C -V; }
        if ver_between 6.4.12 "$(${coreutils}/bin/uname -r)" 6.5.5; then
          printf -- 'Using ZIG_BTRFS_WORKAROUND=1\n' 1>&2
          printf -- 'It is recommended to update your kernel to 6.5.6 or higher\n' 1>&2
          printf -- 'https://github.com/ziglang/zig/issues/17282\n' 1>&2
          export ZIG_BTRFS_WORKAROUND=1
        fi
        ${hook { inherit LIBRARY_PATH pkgs; }}
        '';
    };

    darwin = rec {
      LIBRARY_PATH = "DYLD_LIBRARY_PATH";
      shell = pkgs: hook { inherit LIBRARY_PATH pkgs; };
    };
    ios = darwin;
    watchos = darwin;
    tvos = darwin;
  };

  env = if runtime ? ${os} then runtime.${os} else throw "unknown system";
in env.shell

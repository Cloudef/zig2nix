{
  lib
  , test-app
  , zig-env
  , zig-stable-env
  , zig2nix
  , zig2nix-zigless
  , jq
  , findutils
  , coreutils
  , libarchive
  , zig
  , target
  , deriveLockFile
  , stdenvNoCC
}:

with builtins;
with lib;

rec {
  # nix run .#test-templates
  templates = test-app [] ''
    for var in default master; do
      printf -- 'run . (%s)\n' "$var"
      (cd templates/"$var"; nix run -L --override-input zig2nix ../.. .)
      printf -- 'run .#bundle (%s)\n' "$var"
      (cd templates/"$var"; nix run -L --override-input zig2nix ../.. .#bundle)
      printf -- 'run .#test (%s)\n' "$var"
      (cd templates/"$var"; nix run -L --override-input zig2nix ../.. .#test)
      printf -- 'build . (%s)\n' "$var"
      (cd templates/"$var"; nix build -L --override-input zig2nix ../.. .; ./result/bin/"$var")
      printf -- 'build .#foreign (%s)\n' "$var"
      (cd templates/"$var"; nix build -L --override-input zig2nix ../.. .#foreign; ./result/bin/"$var")
      rm -f templates/"$var"/result
      rm -rf templates/"$var"/zig-out
      rm -rf templates/"$var"/zig-cache
      rm -rf templates/"$var"/.zig-cache
    done
    '';

  # nix run .#test-package
  package = let
    pkg = zig-stable-env.package {
      name = "zig2nix";
      src = cleanSource ../src/zig2nix;
    };
  in test-app [] "echo ${pkg}";

  # nix run .#test-bundle
  bundle = let
    zip1 = zig-env.bundle.zip {
      package = zig-stable-env.package {
        name = "zig2nix";
        src = cleanSource ../src/zig2nix;
        meta.mainProgram = "zig2nix";
      };
    };
    zip2 = zig-env.bundle.zip {
      package = zig-stable-env.package {
        name = "zig2nix";
        src = cleanSource ../src/zig2nix;
        meta.mainProgram = "zig2nix";
      };
      packageAsRoot = true;
    };
    lambda = zig-env.bundle.aws.lambda {
      package = zig-stable-env.package {
        zigTarget = "aarch64-linux-musl";
        name = "zig2nix";
        src = cleanSource ../src/zig2nix;
        meta.mainProgram = "zig2nix";
      };
    };
  in test-app [ libarchive ] ''
    tmpdir="$(mktemp -d)"
    trap 'chmod -R 755 "$tmpdir"; rm -rf "$tmpdir"' EXIT
    (cd "$tmpdir"; bsdtar -xf ${zip1}; ./run zon2json ${../fixtures/zig-15/1.zig.zon}; echo)
    (cd "$tmpdir"; bsdtar -xf ${zip2}; ./run zon2json ${../fixtures/zig-15/1.zig.zon}; echo)
    echo ${lambda} | grep provided.al2023-arm64.zip
    bsdtar -tf ${lambda} | grep bootstrap
    '';

  # nix run .#test-cross
  cross = let
    blacklist =
      [ "armv6l-linux" "armv7l-linux" "x86_64-freebsd" "riscv64-linux" "powerpc64le-linux" "i686-linux" ]
      ++ optionals (!stdenvNoCC.buildPlatform.isDarwin) [ "aarch64-darwin" ];
    targets = [ "x86_64-windows-gnu" ] ++ (subtractLists blacklist systems.flakeExposed);
  in test-app [] (concatStrings (map (nix: let
    crossPkgs = zig-env.zigCrossPkgsForTarget nix;
  in ''
    printf 'zig cross build (zlib): ${nix}\n'
    echo "${crossPkgs.zlib}"
  '') targets));

  # nix run .#test-targets
  targets = test-app [] (concatStrings (map (nix: let
      # sigh
      # <https://github.com/NixOS/nixpkgs/commit/61582c704327002b75d61354a769ebf00f594cdf>
      double = if nix == "aarch64-darwin" then "arm64-darwin" else nix;
      system = (target nix).system;
      config1 = (systems.elaborate nix).config;
      config2 = (target (systems.elaborate nix).config).config;
    in ''
      # shellcheck disable=SC2268
      test '${double}' = '${system}' || error '${double} != ${system}'
      # shellcheck disable=SC2268
      test '${config1}' = '${config2}' || error '${config1} != ${config2}'
    '') systems.flakeExposed));

  # nix run .#test-all
  # TODO: add zig-16 package fixtures
  all = test-app [] ''
    nix flake check --keep-going
    ${targets.program}
    ${templates.program}
    ${package.program}
    ${bundle.program}
    '';
}

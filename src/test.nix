{
  lib
  , test-app
  , zig-env
  , zig2nix
  , jq
  , findutils
  , coreutils
  , libarchive
  , file
  , zig
  , target
  , deriveLockFile
  , buildPlatform
}:

with builtins;
with lib;

{
  # nix run .#test-zon2json-lock
  zon2lock = test-app [ zig2nix ] ''
    for f in ./fixtures/*.zig.zon ./fixtures/example/build.zig.zon; do
      echo "testing (zon2lock): $f"
      if ! cmp <(zig2nix zon2lock "$f" -) "''${f}2json-lock"; then
        error "unexpected output"
      fi
    done
    '';

  # nix run .#test-zon2nix
  zon2nix = let
    fixtures = filter (f: hasSuffix ".zig.zon2json-lock" f) (attrNames (readDir ../fixtures)) ++ [ "example/build.zig.zon2json-lock"];
    drvs = map (f: {
      lck = f;
      out = deriveLockFile (../fixtures + "/${f}") { inherit zig; };
    }) fixtures;
    test = drv: ''
      echo "testing (zon2nix): ${drv.lck}"
      if [[ "$(cat "${../fixtures/${drv.lck}}")" != "{}" ]]; then
        for d in ${drv.out}/*; do
          test -d "$d" || error 'is not a directory: %s' "$d"
          if [[ $(wc -l < <(find "$d/" -mindepth 1 -maxdepth 1 -type f)) == 0 ]]; then
            error "does not contain any regular files: %s" "$d"
          fi
          zhash="$(basename "$d")"
          if ! ${jq}/bin/jq -er --arg k "$zhash" '."\($k)"' ${../fixtures/${drv.lck}} > /dev/null; then
            error 'missing zhash: %s' "$zhash"
          fi
        done
      else
        test "$(find ${drv.out}/ -mindepth 1 -maxdepth 1 | wc -l)" = 0 || error 'output not empty: %s' '${drv.out}'
      fi
      echo "  ${drv.out}"
      '';
  in test-app [ findutils coreutils ] (concatStringsSep "\n" (map test drvs));

  # nix run .#test-templates
  templates = test-app [ file ] ''
    for var in default master; do
      printf -- 'run . (%s)\n' "$var"
      (cd templates/"$var"; nix run -L --override-input zig2nix ../.. .)
      printf -- 'run .#bundle (%s)\n' "$var"
      (cd templates/"$var"; nix run -L --override-input zig2nix ../.. .#bundle)
      printf -- 'run .#test (%s)\n' "$var"
      (cd templates/"$var"; nix run -L --override-input zig2nix ../.. .#test)
      printf -- 'build . (%s)\n' "$var"
      (cd templates/"$var"; nix build -L --override-input zig2nix ../.. .; ./result/bin/"$var")
      rm -f templates/"$var"/result
      rm -rf templates/"$var"/zig-out
      rm -rf templates/"$var"/zig-cache
      rm -rf templates/"$var"/.zig-cache
    done
    '';

  # nix run .#test-package
  package = let
    pkg = zig-env.package {
      name = "zig2nix";
      src = cleanSource ../src/zig2nix;
    };
  in test-app [] "echo ${pkg}";

  # nix run .#test-bundle
  bundle = let
    zip1 = zig-env.bundle.zip {
      package = zig-env.package {
        name = "zig2nix";
        src = cleanSource ../src/zig2nix;
        meta.mainProgram = "zig2nix";
      };
    };
    zip2 = zig-env.bundle.zip {
      package = zig-env.package {
        name = "zig2nix";
        src = cleanSource ../src/zig2nix;
        meta.mainProgram = "zig2nix";
      };
      packageAsRoot = true;
    };
    lambda = zig-env.bundle.aws.lambda {
      package = zig-env.package {
        zigTarget = "aarch64-linux-musl";
        name = "zig2nix";
        src = cleanSource ../src/zig2nix;
        meta.mainProgram = "zig2nix";
      };
    };
  in test-app [ libarchive ] ''
    tmpdir="$(mktemp -d)"
    trap 'chmod -R 755 "$tmpdir"; rm -rf "$tmpdir"' EXIT
    (cd "$tmpdir"; bsdtar -xf ${zip1}; ./run zon2json ${../fixtures/1.zig.zon}; echo)
    (cd "$tmpdir"; bsdtar -xf ${zip2}; ./run zon2json ${../fixtures/1.zig.zon}; echo)
    echo ${lambda} | grep provided.al2023-arm64.zip
    bsdtar -tf ${lambda} | grep bootstrap
    '';

  # nix run .#test-cross
  cross = let
    blacklist =
      [ "armv6l-linux" "armv7l-linux" "x86_64-freebsd" "riscv64-linux" "powerpc64le-linux" "i686-linux" ]
      ++ optionals (!buildPlatform.isDarwin) [ "aarch64-darwin" ];
    targets = [ "x86_64-windows-gnu" ] ++ (subtractLists blacklist systems.flakeExposed);
  in test-app [] (concatStrings (map (nix: let
    crossPkgs = zig-env.zigCrossPkgsForTarget nix;
  in ''
    printf 'zig cross build (zlib): ${nix}\n'
    echo "${crossPkgs.zlib}"
  '') targets));

  # nix run .#test-targets
  targets = test-app [] (concatStrings (map (nix: let
      system = (target nix).system;
      config1 = (systems.elaborate nix).config;
      config2 = (target (systems.elaborate nix).config).config;
    in ''
      # shellcheck disable=SC2268
      test '${nix}' = '${system}' || error '${nix} != ${system}'
      # shellcheck disable=SC2268
      test '${config1}' = '${config2}' || error '${config1} != ${config2}'
    '') systems.flakeExposed));

  # nix run .#test-all
  all = test-app [] ''
    nix flake check --keep-going
    nix run -L .#test-targets
    nix run -L .#test-zon2lock
    nix run -L .#test-zon2nix
    nix run -L .#test-templates
    nix run -L .#test-package
    nix run -L .#test-bundle
    '';
}

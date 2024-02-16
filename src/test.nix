{
  lib
  , test-app
  , envPackage
  , zon2json-lock
  , jq
  , findutils
  , coreutils
  , file
  , zig
  , deriveLockFile
  , resolveTargetSystem
  , zigTripleFromSystem
  , nixTripleFromSystem
  , allFlakeTargetTriples
}:

with builtins;
with lib;

{
  # nix run .#test.zon2json-lock
  zon2json-lock = test-app [ zon2json-lock ] ''
    nix store add-file tools/fixtures/file-url-test.tar.gz
    for f in tools/fixtures/*.zig.zon; do
      echo "testing (zon2json-lock): $f"
      if ! cmp <(zon2json-lock "$f" -) "''${f}2json-lock"; then
        error "unexpected output"
      fi
    done
    '';

  # nix run .#test.zon2nix
  zon2nix = let
    fixtures = filter (f: hasSuffix ".zig.zon2json-lock" f) (attrNames (readDir ../tools/fixtures));
    drvs = map (f: {
      lck = f;
      out = deriveLockFile (../tools/fixtures + "/${f}") { inherit zig; };
    }) fixtures;
    test = drv: ''
      echo "testing (zon2nix): ${drv.lck}"
      if [[ -s "${../tools/fixtures/${drv.lck}}" ]]; then
        for d in ${drv.out}/*; do
          test -d "$d" || error 'is not a directory: %s' "$d"
          if [[ $(wc -l < <(find "$d/" -mindepth 1 -maxdepth 1 -type f)) == 0 ]]; then
            error "does not contain any regular files: %s" "$d"
          fi
          zhash="$(basename "$d")"
          if ! ${jq}/bin/jq -er --arg k "$zhash" '."\($k)"' ${../tools/fixtures/${drv.lck}} > /dev/null; then
            error 'missing zhash: %s' "$zhash"
          fi
        done
      else
        test "$(find ${drv.out}/ -mindepth 1 -maxdepth 1 | wc -l)" = 0 || error 'output not empty: %s' '${drv.out}'
      fi
      echo "  ${drv.out}"
      '';
  in test-app [ findutils coreutils ] (concatStringsSep "\n" (map test drvs));

  # nix run .#test.templates
  templates = test-app [ file ] ''
    for var in default master; do
      printf -- 'run . (%s)\n' "$var"
      (cd templates/"$var"; nix run -L --override-input zig2nix ../.. .)
      printf -- 'run .#bundle.default (%s)\n' "$var"
      (cd templates/"$var"; nix run -L --override-input zig2nix ../.. .#bundle.default)
      printf -- 'run .#test (%s)\n' "$var"
      (cd templates/"$var"; nix run -L --override-input zig2nix ../.. .#test)
      printf -- 'build . (%s)\n' "$var"
      (cd templates/"$var"; nix build -L --override-input zig2nix ../.. .; ./result/bin/"$var")
      if [[ "$var" == master ]]; then
        for arch in x86_64-windows-gnu ${escapeShellArgs allFlakeTargetTriples}; do
          printf -- 'build .#target.%s (%s)\n' "$arch" "$var"
          (cd templates/"$var"; nix build -L --override-input zig2nix ../.. .#target."$arch"; file ./result/bin/"$var"*)
        done
      fi
      rm -f templates/"$var"/result
      rm -rf templates/"$var"/zig-out
      rm -rf templates/"$var"/zig-cache
    done
    '';

  # nix run .#test.package
  package = let
    pkg = zig-env.package { src = cleanSource ../tools/zon2json; };
  in test-app [] "echo ${pkg}";

  # nix run .#test.cross
  cross = test-app [] ''
    for target in x86_64-windows-gnu ${escapeShellArgs allFlakeTargetTriples}; do
      printf -- 'build .#env.master.bin.cross.%s.zlib\n' "$target"
      nix build -L .#env.master.bin.cross.$target.zlib
    done
    '';

  # nix run .#test.all
  all = let
    resolved = resolveTargetSystem { target = "x86_64-linux-gnu"; musl = true; };
    nix-triple = nixTripleFromSystem resolved;
    zig-triple = zigTripleFromSystem resolved;
  in test-app [] ''
    # shellcheck disable=SC2268
    test '${nix-triple}' = x86_64-unknown-linux-musl || error '${nix-triple} != x86_64-unknown-linux-musl'
    # shellcheck disable=SC2268
    test '${zig-triple}' = x86_64-linux-musl || error '${zig-triple} != x86_64-linux-musl'
    nix run -L .#test.zon2json-lock
    nix run -L .#test.zon2nix
    nix run -L .#test.templates
    nix run -L .#test.package
    nix run -L .#test.cross
    '';

  # nix run .#test.repl
  repl = test-app [] ''
    confnix="$(mktemp)"
    trap 'rm $confnix' EXIT
    echo "builtins.getFlake (toString $(git rev-parse --show-toplevel))" >"$confnix"
    nix repl "$confnix"
    '';
}

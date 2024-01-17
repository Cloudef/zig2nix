{
  lib
  , app
  , envPackage
  , zon2json-lock
  , jq
  , findutils
  , coreutils
  , file
  , zig
  , deriveLockFile
}:

with builtins;
with lib;

{
  # nix run .#test.zon2json-lock
  zon2json-lock = app [ zon2json-lock ] ''
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
  in app [ findutils coreutils ] (concatStringsSep "\n" (map test drvs));

  # nix run .#test.templates
  templates = app [ file ] ''
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

  # nix run .#test.package
  package = let
    pkg = envPackage { src = ../tools/zon2json; };
  in app [] "echo ${pkg}";

  # nix run .#test.all
  all = app [] ''
    nix run .#test.zon2json-lock
    nix run .#test.zon2nix
    nix run .#test.templates
    nix run .#test.package
    '';

  # nix run .#test.repl
  repl = app [] ''
    confnix="$(mktemp)"
    trap 'rm $confnix' EXIT
    echo "builtins.getFlake (toString $(git rev-parse --show-toplevel))" >"$confnix"
    nix repl "$confnix"
    '';
}

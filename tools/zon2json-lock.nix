{
    pkgs ? import <nixpkgs> {}
    , writeShellApplication ? pkgs.writeShellApplication
    , zon2json
    , jq ? pkgs.jq
    , zig ? pkgs.zig
    , curl ? pkgs.curl
    , coreutils ? pkgs.coreutils
}:

writeShellApplication {
    name = "zon2json-lock";
    runtimeInputs = [ zon2json jq zig curl coreutils ];
    text = ''
      path="''${1:-build.zig.zon}"
      if [[ ! -f "$path" ]]; then
          printf -- "error: file does not exist: %s" "$path" 1>&2
          exit 1
      fi

      tmpdir="$(mktemp -d)"
      trap 'rm -rf "$tmpdir"' EXIT
      read -r zig_cache < <(zig env | jq -r '.global_cache_dir')

      zon2json-recursive() {
        while {
          read -r name;
          read -r url;
          read -r zhash;
        } do
          # Prevent dependency loop
          if [[ ! -f "$tmpdir/$zhash.read" ]]; then
            # do not zig fetch if we have the dep already
            if [[ ! -d "$zig_cache/p/$zhash" ]]; then
              printf -- 'fetching (zig fetch): %s\n' "$url" 1>&2
              zig fetch "$url" 1>/dev/null
            fi

            # do not redownload artifact if we know its hash already
            maybe_hash="$(jq -r --arg k "$zhash" '."\($k)".hash' "''${path}2json-lock" 2>/dev/null || true)"
            if [[ ! "$maybe_hash" ]]; then
              printf -- 'fetching (nix hash): %s\n' "$url" 1>&2
              curl -sL "$url" -o "$tmpdir/$zhash.artifact"
              ahash="$(nix hash file "$tmpdir/$zhash.artifact")"
              rm -f "$tmpdir/$zhash.artifact"
            else
              ahash="$maybe_hash"
            fi

            printf '{"%s":{"name":"%s","url":"%s","hash":"%s"}}\n' "$zhash" "$name" "$url" "$ahash"

            if [[ -f "$zig_cache/p/$zhash/build.zig.zon" ]]; then
              zon2json-recursive "$zig_cache/p/$zhash/build.zig.zon"
            fi

            touch "$tmpdir/$zhash.read"
          fi
        done < <(zon2json "$1" | jq -r '.dependencies | to_entries | .[] | select(.value.url != null) | .key, .value.url, .value.hash')
      }

      if [[ "''${2:-}" == "-" ]]; then
        zon2json-recursive "$path" | jq -s add
      else
        zon2json-recursive "$path" | jq -s add > "$tmpdir/build.zig.zon2json-lock"
        cp -f "$tmpdir/build.zig.zon2json-lock" "''${2:-''${path}2json-lock}"
      fi
      '';
}

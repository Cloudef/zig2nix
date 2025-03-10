{
  lib
  , installDocs ? false
  , zigHook
  , release
  , stdenvNoCC
  , callPackage
  , fetchurl
  , zig-shell-completions
  , coreutils
  , bubblewrap
  , writeScriptBin
}:

with builtins;
with lib;

let
  system = stdenvNoCC.targetPlatform.system;
  meta-for = release: {
    homepage = "https://ziglang.org/";
    description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = []; # needed by the setup hook
    mainProgram = "zig";
  } // optionalAttrs (release ? notes) {
    changelog = release.notes;
  };
in if release ? ${system} then stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "zig";
  inherit (release) version;

  outputs = [ "out" ] ++ optionals installDocs [ "doc" ];

  src = fetchurl {
    url = release.${system}.tarball;
    sha256 = release.${system}.shasum;
  };

  phases = [ "unpackPhase" "installPhase" ];

  installPhase = ''
    mkdir -p $out/{bin,lib}
    cp -r lib/* $out/lib
    install -Dm755 zig $out/bin/zig
    install -m644 LICENSE $out/LICENSE
    '' + optionalString installDocs ''
    mkdir -p $out/doc
    if [[ -d docs ]]; then
      cp -r docs $out/doc
    else
      cp -r doc $out/doc
    fi
    '';

  passthru = {
    info = release;
    inherit (release) date notes stdDocs docs src;
    inherit (release.${system}) size;
    hook = callPackage zigHook {
      zig = if (stdenvNoCC.isLinux) then
        # Wrap binary package zig on linux so /usr/bin/env can be found inside a sandbox
        writeScriptBin "zig" ''
          args=()
          for d in /*; do
            args+=("--dev-bind" "$d" "$d")
          done
          ${bubblewrap}/bin/bwrap "''${args[@]}" \
            --bind ${coreutils} /usr \
            -- ${finalAttrs.finalPackage}/bin/zig "$@"
        ''
      else finalAttrs.finalPackage;
    };
    shell-completions = zig-shell-completions;
  };

  meta = meta-for release;
}) else throw "There is no zig-${release.version} binary available for ${system}, use _src variant to compile from source"

{
    lib
    , stdenvNoCC
    , callPackage
    , fetchurl
    , zigSystem
    , zigHook
}:

with lib;
with builtins;

let
  zig = k: v: { installDocs ? false }:
    stdenvNoCC.mkDerivation (finalAttrs: {
      pname = "zig";
      version = if v ? version then v.version else k;

      src = fetchurl {
        url = v.${zigSystem}.tarball;
        sha256 = v.${zigSystem}.shasum;
      };

      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;

      installPhase = ''
        mkdir -p $out/{bin,lib}
        cp -r lib/* $out/lib
        install -Dm755  zig $out/bin/zig
        install -m644 LICENSE $out/LICENSE
      '' + lib.optionalString (installDocs) ''
        mkdir -p $out/doc
        if [[ -d docs ]]; then
          cp -r docs $out/doc
        else
          cp -r doc $out/doc
        fi
      '';

      passthru = {
        date = v.date;
        notes = v.notes;
        stdDocs = v.stdDocs;
        docs = v.docs;
        size = res.size;
        src = v.src;
        hook = zigHook.override {zig = finalAttrs.finalPackage;};
      };

      meta = with lib; {
        homepage = "https://ziglang.org/";
        description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software";
        license = licenses.mit;
        platforms = platforms.unix;
        maintainers = []; # needed by the setup hook
      };
    });
in filterAttrs (n: v: v != null)
    (mapAttrs (k: v: if v ? ${zigSystem} then callPackage (zig k v) {} else null)
      (fromJSON (readFile ./versions.json)))

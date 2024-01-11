{ pkgs ? import <ni3pkgs> {}, lib ? pkgs.lib, stdenv ? pkgs.stdenvNoCC, system ? builtins.currentSystem, installDocs ? false }:

with lib;
with builtins;

let
  zig-system = concatStringsSep "-" (map (x: if x == "darwin" then "macos" else x) (splitString "-" system));
in filterAttrs (n: v: v != null) (mapAttrs (k: v: let
  res = v."${zig-system}" or null;
in if res == null then null else stdenv.mkDerivation (finalAttrs: {
  pname = "zig";
  version = if v ? version then v.version else k;

  src = pkgs.fetchurl {
    url = res.tarball;
    sha256 = res.shasum;
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
    hook = pkgs.zig.hook.override {zig = finalAttrs.finalPackage;};
  };

  meta = with lib; {
    homepage = "https://ziglang.org/";
    description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = []; # needed by the setup hook
  };
})) (fromJSON (readFile ./versions.json)))

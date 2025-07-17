{
  stdenvNoCC,
  curl,
  minisign,
  zigMirrors,
  writeText,
}: release:
stdenvNoCC.mkDerivation {
  name = release.filename;
  builder = ./fetch_builder.sh;
  nativeBuildInputs = [curl minisign];

  mirrorFile = writeText "community-mirrors.txt" zigMirrors;
  inherit (release) filename;
  urlQuery = "?source=zig2nix";
  minisignPublicKey = "RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U";

  outputHash = release.shasum;
  outputHashAlgo = "sha256";
  outputHashMode = "flat";

  postHook = null;
  preferLocalBuild = true;
}

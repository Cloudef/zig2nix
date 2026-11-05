{
  lib,
  stdenvNoCC,
  curl,
  minisign,
  writeText,
}: release:
stdenvNoCC.mkDerivation {
  name = release.filename;
  builder = ./fetch_builder.sh;
  nativeBuildInputs = [curl minisign];

  inherit (release) filename;
  urlQuery = "?source=zig2nix";
  minisignPublicKey = "RWR+9B91GBZ0zOjh6Lr17+zKf5BoSuFvrx2xSeDE57uIYvnKBGmMjOex";

  outputHash = release.shasum;
  outputHashAlgo = "sha256";
  outputHashMode = "flat";

  postHook = null;
  preferLocalBuild = true;

  impureEnvVars =
    lib.fetchers.proxyImpureEnvVars
    ++ [
      # This variable allows the user to pass additional options to curl
      "NIX_CURL_FLAGS"
    ];
}

{
  lib
  , stdenvNoCC
  , fetchurl
  , release
}:

with builtins;
with lib;

let
  # sigh
  # <https://github.com/NixOS/nixpkgs/commit/61582c704327002b75d61354a769ebf00f594cdf>
  system = if stdenvNoCC.targetPlatform.system == "aarch64-darwin" then "arm64-darwin" else stdenvNoCC.targetPlatform.system;
  meta-for = release: {
    homepage = "https://zigtools.org/";
    description = "Language server for Zig";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "zls";
  };
in if release ? ${system} then stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "zls";
  inherit (release) version;

  src = fetchurl {
    url = "https://builds.zigtools.org/${release."${system}".filename}";
    outputHash = release."${system}".shasum;
    outputHashAlgo = "sha256";
  };

  sourceRoot = ".";
  phases = [ "unpackPhase" "installPhase" ];
  installPhase = ''install -Dt "$out/bin" zls'';

  passthru = {
    info = release;
    inherit (release) date;
    inherit (release.${system}) size;
  };

  meta = meta-for release;
}) else throw "There is no zls-${release.version} binary available for ${system}"

{
  lib
  , stdenvNoCC
  , zig
  , git
  , nixfmt-rfc-style
  , nix-prefetch-git
  , nix
  , makeWrapper
  , zigBuildFlags ? []
}:

with builtins;
with lib;

stdenvNoCC.mkDerivation {
  inherit zigBuildFlags;
  name = "zig2nix";
  src = cleanSource ./.;
  nativeBuildInputs = [ zig.hook makeWrapper ];
  meta.mainProgram = "zig2nix";
  postFixup = ''
    wrapProgram $out/bin/zig2nix --prefix PATH : ${lib.makeBinPath [
      git
      nix
      nixfmt-rfc-style
      nix-prefetch-git
    ]}
  '';
}

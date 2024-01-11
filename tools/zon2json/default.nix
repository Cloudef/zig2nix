{
  pkgs ? import <nixpkgs> {}
  , stdenv ? pkgs.stdenvNoCC
  , zig ? pkgs.zig
}:

stdenv.mkDerivation {
  name = "zon2json";
  src = ./.;
  nativeBuildInputs = [ zig.hook ];
}

{
  lib
  , stdenvNoCC
  , zig
}:

{ ... }@attrs:

with builtins;
with lib;

stdenvNoCC.mkDerivation (attrs // {
  name = "zon2json";
  src = cleanSource ./.;
  nativeBuildInputs = [ zig.hook ];
  meta.mainProgram = "zon2json";
})

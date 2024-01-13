{
  stdenvNoCC
  , zig
  , ...
} @attrs:

stdenvNoCC.mkDerivation (attrs // {
  name = "zon2json";
  src = ./.;
  nativeBuildInputs = [ zig.hook ];
})

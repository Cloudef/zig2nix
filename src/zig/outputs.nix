{
  lib
  , zigv
  , zig-env
  , pkgs
}:

with lib;
with builtins;

let
  multimedia = with pkgs; []
    ++ optionals stdenv.isLinux [
      vulkan-loader libGL
      xorg.libX11 xorg.libXext xorg.libXfixes xorg.libXi xorg.libXrender
      xorg.libXrandr xorg.libXinerama xorg.libXcursor xorg.xorgproto
      wayland-scanner wayland libxkbcommon libdecor
      alsa-lib pulseaudio
    ];
in {
  apps = mergeAttrsList (attrValues (mapAttrs (k: zig: let
    env = zig-env { inherit zig; };
  in {
    "${k}" = env.app-no-root [] ''zig "$@"'';
    "multimedia-${k}" = env.app-no-root multimedia ''zig "$@"'';
    "zig2nix-${k}" = env.app-no-root [] ''zig2nix "$@"'';

    # Backwards compatiblity
    "zon2json-${k}" = env.app-no-root [] ''zig2nix zon2json "$@"'';
    "zon2json-lock-${k}" = env.app-no-root [] ''zig2nix zon2lock "$@"'';
    "zon2nix-${k}" = env.app-no-root [] ''zig2nix zon2nix "$@"'';
  }) zigv));

  devShells = mergeAttrsList (attrValues (mapAttrs (k: zig: let
    env = zig-env { inherit zig; };
  in {
    "${k}" = env.mkShell {};
    "multimedia-${k}" = env.mkShell {
      nativeBuildInputs = multimedia;
    };
  }) zigv));
}

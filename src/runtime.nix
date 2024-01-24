{
  lib
  , coreutils
  , pkgsForTarget
  , mkZigSystemFromString
  , autoPatchelfHook
  , customAppHook ? ""
  , customDevShellHook ? ""
  , customRuntimeLibs ? []
  , enableVulkan
  , enableOpenGL
  , enableWayland
  , enableX11
  , enableAlsa
  , buildPlatform
}:

with builtins;
with lib;

args':

let
  system = if isString args' then mkZigSystemFromString args' else args';
  targetPkgs = pkgsForTarget system;

  env = rec {
    linux = {
      LIBRARY_PATH = "LD_LIBRARY_PATH";
      wrapperBuildInputs = optionals (buildPlatform.isLinux) [ autoPatchelfHook ];
    };

    darwin = let
      sdkVer = targetPkgs.targetPlatform.darwinSdkVersion;
      sdk =
        if (versionAtLeast sdkVer "10.13") then targetPkgs.darwin.apple_sdk.MacOSX-SDK
        else warn "zig only supports macOS 10.13+, forcing SDK 11.0" targetPkgs.darwin.apple_sdk_11_0.MacOSX-SDK;
    in {
      LIBRARY_PATH = "DYLD_LIBRARY_PATH";
      stdenvZigFlags = [ "--sysroot" sdk ];
    };
    ios = darwin;
    watchos = darwin;
    tvos = darwin;
  };

  libs = {
    linux = with targetPkgs; []
      ++ optionals (enableVulkan) [ vulkan-loader ]
      ++ optionals (enableOpenGL) [ libGL ]
      # Some common runtime libs used by x11 apps, for example: https://www.glfw.org/docs/3.3/compat.html
      # You can always include more if you need with customRuntimeLibs.
      ++ optionals (enableX11) [ xorg.libX11 xorg.libXext xorg.libXfixes xorg.libXi xorg.libXrender xorg.libXrandr xorg.libXinerama ]
      ++ optionals (enableWayland) [ wayland libxkbcommon libdecor ]
      ++ optionals (enableAlsa) [ alsa-lib ];
  };

  bins = {};

  hook-for = kernel: let
    _libs = (libs.${kernel} or []) ++ customRuntimeLibs;
    ld_string = makeLibraryPath _libs;
    pc_string = makeSearchPathOutput "dev" "lib/pkgconfig" _libs;
  in ''
    export ${env.${kernel}.LIBRARY_PATH}="${ld_string}:''${${env.${kernel}.LIBRARY_PATH}:-}"
    export PKG_CONFIG_PATH="${pc_string}:''${PKG_CONFIG_PATH:-}"
    '';

  shell = {
    # https://github.com/ziglang/zig/issues/17282
    linux = ''
      ver_between() { printf '%s\n' "$@" | ${coreutils}/bin/sort -C -V; }
      if ver_between 6.4.12 "$(${coreutils}/bin/uname -r)" 6.5.5; then
        printf -- 'Using ZIG_BTRFS_WORKAROUND=1\n' 1>&2
        printf -- 'It is recommended to update your kernel to 6.5.6 or higher\n' 1>&2
        printf -- 'https://github.com/ziglang/zig/issues/17282\n' 1>&2
        export ZIG_BTRFS_WORKAROUND=1
      fi
      ${hook-for "linux"}
      '';

    darwin = hook-for "darwin";
  };
in {
  env = env.${system.kernel.name} or {};
  libs = libs.${system.kernel.name} or [];
  bins = bins.${system.kernel.name} or [];
  app = ''
    ${customAppHook}
    ${shell.${system.kernel.name} or ""}
    '';
  shell = ''
    ${customDevShellHook}
    ${shell.${system.kernel.name} or ""}
    '';
}

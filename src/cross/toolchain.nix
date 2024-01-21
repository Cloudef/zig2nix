{
  lib
  , writeShellApplication
  , writeText
  , emptyFile
  , coreutils
  , gnugrep
  , llvm
  , zig
  , zigPackage
  , allNixZigSystems
  , nixTripleFromSystem
}:

{
  libc
  , stdenvNoCC
  , wrapCCWith
  , wrapBintoolsWith
  , libllvm
}:

with lib;
with builtins;

let
  zigtool = writeShellApplication {
    name = "zigtool";
    runtimeInputs = [ zig ];
    text = ''
      if [[ ! "''${ZIG_TOOLCHAIN_TARGET:-}" ]]; then
        echo "ZIG_TOOLCHAIN_TARGET is not set, cannot continue" 1>&2
        exit 42
      fi
      export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-cache"
      export ZIG_GLOBAL_CACHE_DIR="$ZIG_LOCAL_CACHE_DIR"
      if [[ "$1" == cc ]] || [[ "$1" == c++ ]]; then
        if [[ ''${ZIG_TOOLCHAIN_DEBUG:-0} == 1 ]]; then
          printf -- "zigtool: warning: %s\n" "$*" 1>&2
        fi
      fi
      exec zig "$@"
      '';
  };

  # libs that should not be linked if using zig's builtin libcs
  sys_excluded = [
    "-lc" "-lm" "-latomic" "-liconv"
    "CoreFoundation/CoreFoundation.tbd"
  ];

  # FIXME: some quirks here should be fixed upstream
  #        meson: -Wl,--version, meson looks for (compatible with GNU linkers) string, otherwise it gives up
  #        v8/gn: inserts --target=, we do not want to ever compile to a platform we do not expect
  #        v8/gn: -latomic already built into compiler_rt
  #        SDL2: -liconv, probably built into zig as well
  #        -Wl,-arch, -march, -mcpu, -mtune are not compatible
  #        https://github.com/ziglang/zig/issues/4911
  #        this does not matter as -target encodes the needed information anyways
  zigcc = let
    support = zigPackage { src = ./support; };

    pp_args = [
      "-target" ''"$ZIG_TOOLCHAIN_TARGET"''
      # This is quite unfortunate, but zig ships recent glibc headers, but links against older glibc stubs
      # Thus compile fails as autotools detects we don't have arc4random but it's in the glibc headers
      # and the project provides its own symbol, causing collision with the header
      # https://github.com/spdk/spdk/issues/2637
      "-DHAVE_ARC4RANDOM=1" "-DHAVE_ARC4RANDOM_UNIFORM=1" "-DHAVE_ARC4RANDOM_BUF=1"
    ];

    # Has to be separate as these will be treated as inputs otherwise ...
    cc_args = [
      # Symbol versioning hell ...
      "-Wl,--undefined-version"
      # Provides arc4random family functions
      "${support}/lib/libarc4random.a"
    ];
  in cmd: writeShellApplication {
    name = "zig${cmd}";
    runtimeInputs = [ zigtool ];
    text = ''
      shopt -s extglob
      args=()
      has_output=0
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -Wl,*)
            wl="-Wl"
            while read -r -d , arg; do
              case "$arg" in
                --version)
                  printf '%s (compatible with GNU linkers)\n' "$(zigtool ${cmd} -Wl,--version)"
                  exit 0;;
                --unresolved-symbols=ignore-in-object-files)
                  wl="$wl,-undefined,dynamic_lookup";;
                --unresolved-symbols=*)
                  ;;
                -stats)
                  ;;
                -arch)
                  shift;;
                -Wl|${concatStringsSep "|" sys_excluded})
                  ;;
                *)
                  wl="$wl,$arg"
                  ;;
              esac
            done <<<"$1,"
            args+=("$wl")
            shift;;
          -target)
            shift;shift;;
          --target=*)
            shift;;
          -march=*|-mcpu=*|-mtune=*)
            shift;;
          -static-libgcc)
            shift;;
          ${concatStringsSep "|" sys_excluded})
            shift;;
          -o)
            has_output=1
            args+=("$1")
            shift;;
          *)
            args+=("$1")
            shift;;
        esac
      done
      if [[ $has_output == 0 ]]; then
        exec zigtool ${cmd} ${concatStringsSep " " pp_args} "''${args[@]}"
      else
        exec zigtool ${cmd} ${concatStringsSep " " (pp_args ++ cc_args)} "''${args[@]}"
      fi
      '';
  };

  zigld = writeShellApplication {
    name = "zigld";
    runtimeInputs = [ zigtool ];
    text = ''
      shopt -s extglob
      args=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -arch)
            shift;shift;;
          ${concatStringsSep "|" sys_excluded})
            shift;;
          *)
            args+=("$1")
            shift;;
        esac
      done
      exec zigtool ld.lld "''${args[@]}"
      '';
  };

  zigcmd = cmd: writeShellApplication {
    name = cmd;
    runtimeInputs = [ zigtool ];
    text = ''exec zigtool ${cmd} "$@"'';
  };

  toolchain-unwrapped = stdenvNoCC.mkDerivation {
    pname = "zig-toolchain";
    inherit (zig) version;

    passthru = {
      isClang = true;
      isLLVM = true;
      inherit libllvm;
    };

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    installPhase = let
      triples = map (s: nixTripleFromSystem s) allNixZigSystems;
      prefixes = map (t: t + "-") triples;
    in ''
      mkdir -p $out/bin $out/lib

      for prefix in "" ${escapeShellArgs prefixes}; do
        ln -sf ${llvm}/bin/llvm-install-name-tool $out/bin/''${prefix}install_name_tool
        ln -sf ${llvm}/bin/llvm-as $out/bin/''${prefix}as
        ln -sf ${llvm}/bin/llvm-dwp $out/bin/''${prefix}dwp
        ln -sf ${llvm}/bin/llvm-nm $out/bin/''${prefix}nm
        ln -sf ${llvm}/bin/llvm-objdump $out/bin/''${prefix}objdump
        ln -sf ${llvm}/bin/llvm-readelf $out/bin/''${prefix}readelf
        ln -sf ${llvm}/bin/llvm-size $out/bin/''${prefix}size
        ln -sf ${llvm}/bin/llvm-strip $out/bin/''${prefix}strip
        ln -sf ${llvm}/bin/llvm-rc $out/bin/''${prefix}rc
        ln -sf ${zigcmd "ar"}/bin/ar $out/bin/''${prefix}ar
        ln -sf ${zigcmd "ranlib"}/bin/ranlib $out/bin/''${prefix}ranlib
        ln -sf ${zigcmd "dlltool"}/bin/dlltool $out/bin/''${prefix}dlltool
        ln -sf ${zigcmd "lib"}/bin/lib $out/bin/''${prefix}lib
        ln -sf ${zigcmd "objcopy"}/bin/objcopy $out/bin/''${prefix}objcopy
        ln -sf $out/bin/''${prefix}rc $out/bin/''${prefix}windres
        ln -sf $out/bin/ld.lld $out/bin/ld
        ln -sf $out/bin/ld $out/bin/''${prefix}ld
        ln -sf $out/bin/clang $out/bin/''${prefix}cc
        ln -sf $out/bin/clang++ $out/bin/''${prefix}c++
        ln -sf $out/bin/clang $out/bin/''${prefix}clang
        ln -sf $out/bin/clang++ $out/bin/''${prefix}clang++
        ln -sf $out/bin/clang $out/bin/''${prefix}gcc
        ln -sf $out/bin/clang++ $out/bin/''${prefix}g++
      done

      ln -sf ${zigcc "cc"}/bin/zigcc $out/bin/clang
      ln -sf ${zigcc "c++"}/bin/zigc++ $out/bin/clang++
      ln -sf ${zigld}/bin/zigld $out/bin/ld.lld
      '';
  };
in wrapCCWith {
  inherit gnugrep coreutils libc;
  cc = toolchain-unwrapped;
  useCcForLibs = false;
  bintools = wrapBintoolsWith {
    inherit gnugrep coreutils libc;
    bintools = toolchain-unwrapped;
    postLinkSignHook = emptyFile;
    signingUtils = writeText "sign" ''
      sign() {
        echo "zigsign: !!! Not actually signing anything !!!"
        printf 'zigsign: %s\n' "$1"
      }
      '';
  };

  # nix really wants us to use nixpkgs libc
  # so make sure we don't pass extra garbage on the cc command line
  extraBuildCommands = ''
    rm -f $out/nix-support/cc-cflags
    rm -f $out/nix-support/cc-ldflags
    rm -f $out/nix-support/libc-crt1-cflags
    rm -f $out/nix-support/libc-cflags
    rm -f $out/nix-support/libc-ldflags
    rm -f $out/nix-support/libcxx-cxxflags
    rm -f $out/nix-support/libcxx-ldflags
    '';
}

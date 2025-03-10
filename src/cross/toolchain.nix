{
  lib
  , writeShellApplication
  , runCommandLocal
  , symlinkJoin
  , coreutils
  , gnugrep
  , llvm
  , zig
  , zigPackage
  , target
  , wrapCCWith
  , wrapBintoolsWith
  , stdenv
}:

with lib;
with builtins;

let
  zigtool = writeShellApplication {
    name = "zigtool";
    runtimeInputs = [ zig ];
    text = ''
      export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zigtool-cache"
      export ZIG_GLOBAL_CACHE_DIR="$ZIG_LOCAL_CACHE_DIR"
      ZIG_TOOLCHAIN_DEBUG=1
      if [[ ''${ZIG_TOOLCHAIN_DEBUG:-0} == 1 ]]; then
        printf -- "zigtool: warning: %s\n" "$*" 1>&2
      fi
      exec zig "$@"
      '';
  };

  # libs that should not be linked if using zig's builtin libcs
  sys_excluded = [
    "-lc" "-lm" "-latomic" "-liconv"
    "*/CoreFoundation.tbd"
  ];

  # FIXME: some quirks here should be fixed upstream
  #        meson: -Wl,--version, meson looks for (compatible with GNU linkers) string, otherwise it gives up
  #        v8/gn: inserts --target=, we do not want to ever compile to a platform we do not expect
  #        v8/gn: -latomic already built into compiler_rt
  #        SDL2: -liconv, probably built into zig as well
  #        -Wl,-arch, -march, -mcpu, -mtune are not compatible
  #        https://github.com/ziglang/zig/issues/4911
  #        this does not matter as -target encodes the needed information anyways
  zigcc = any: let
    support = zigPackage {
      name = "support";
      src = cleanSource ./support;
      zigTarget = (target any).zig;
    };

    pp_args = [ "-target" ''${any}'' ];

    os = (target any).os;

    # Does not support the -c compiler flag
    multiple-objects-supported = os != "windows" && os != "darwin";

    libname = lib: if os == "windows" then "${lib}.lib" else "lib${lib}.a";

    # Has to be separate as these will be treated as inputs otherwise ...
    cc_args = [
      # Symbol versioning hell ...
      "-Wl,--undefined-version"
    ] ++ optionals multiple-objects-supported [
      # Provides arc4random family functions
      # This is quite unfortunate, but zig ships recent glibc headers, but links against older glibc stubs
      # Thus compile fails as autotools detects we don't have arc4random but it's in the glibc headers
      # and the project provides its own symbol, causing collision with the header
      # https://github.com/spdk/spdk/issues/2637
      "${support}/lib/${libname "arc4random"}"
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
            if [[ "$wl" != "-Wl" ]]; then
              args+=("$wl")
            fi
            shift;;
          -target)
            shift;shift;;
          --target=*)
            shift;;
          -B/nix*|-L/nix*)
            shift;;
          -march=*|-mcpu=*|-mtune=*)
            shift;;
          -flto-partition=*)
            shift;;
          -static-libgcc)
            shift;;
          --gcc-toolchain=*)
            shift;;
          -fstack-clash-protection)
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

  zigrc = writeShellApplication {
    name = "zigrc";
    runtimeInputs = [ zigtool ];
    text = ''
      shopt -s extglob
      input=zigrc-failed-arg-parsing
      outputs=()
      args=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          *.rc)
            input="$1"
            shift;;
          -o)
            outputs+=("$2")
            shift;shift;;
          --define)
            args+=("/d" "$2")
            shift;;
          *)
            shift;;
        esac
      done
      exec zigtool rc "''${args[@]}" -- "$input" "''${outputs[@]}"
      '';
  };

  zigcmd = cmd: writeShellApplication {
    name = cmd;
    runtimeInputs = [ zigtool ];
    text = ''exec zigtool ${cmd} "$@"'';
  };

  tools-for-target = any: let
    z = (target any).zig;
  in runCommandLocal "zig-toolchain-${(target any).config}-symlinks" {} ''
    mkdir -p "$out/bin"
    ln -sf ${llvm}/bin/llvm-install-name-tool $out/bin/install_name_tool
    ln -sf ${llvm}/bin/llvm-as $out/bin/as
    ln -sf ${llvm}/bin/llvm-dwp $out/bin/dwp
    ln -sf ${llvm}/bin/llvm-nm $out/bin/nm
    ln -sf ${llvm}/bin/llvm-objdump $out/bin/objdump
    ln -sf ${llvm}/bin/llvm-readelf $out/bin/readelf
    ln -sf ${llvm}/bin/llvm-size $out/bin/size
    ln -sf ${llvm}/bin/llvm-strip $out/bin/strip
    ln -sf ${zigcmd "ar"}/bin/ar $out/bin/ar
    ln -sf ${zigcmd "ranlib"}/bin/ranlib $out/bin/ranlib
    ln -sf ${zigcmd "dlltool"}/bin/dlltool $out/bin/dlltool
    ln -sf ${zigcmd "lib"}/bin/lib $out/bin/lib
    ln -sf ${zigcmd "objcopy"}/bin/objcopy $out/bin/objcopy
    ln -sf ${zigrc}/bin/zigrc $out/bin/rc
    ln -sf $out/bin/rc $out/bin/windres
    ln -sf ${zigcc z "cc"}/bin/zigcc $out/bin/clang
    ln -sf ${zigcc z "c++"}/bin/zigc++ $out/bin/clang++
    ln -sf $out/bin/clang $out/bin/gcc
    ln -sf $out/bin/clang++ $out/bin/g++
    ln -sf $out/bin/clang $out/bin/cc
    ln -sf $out/bin/clang++ $out/bin/c++
    ln -sf ${zigld}/bin/zigld $out/bin/ld
    '';

  toolchain-unwrapped = { libllvm, targetPlatform }: symlinkJoin {
    name = "zig-toolchain-${targetPlatform.config}";
    inherit (zig) version;
    paths = [ (tools-for-target targetPlatform.config) ];
    passthru = {
      isClang = true;
      isLLVM = true;
      inherit libllvm;
    };
  };
in

{
  callPackage
  , targetPlatform
}:

wrapCCWith {
  inherit gnugrep coreutils;
  cc = callPackage toolchain-unwrapped {};
  useCcForLibs = false;
  libc = if (targetPlatform == stdenv.buildPlatform) then stdenv.cc.libc else null;
  bintools = wrapBintoolsWith {
    inherit gnugrep coreutils;
    libc = if (targetPlatform == stdenv.buildPlatform) then stdenv.cc.libc else null;
    bintools = callPackage toolchain-unwrapped {};
  };
}

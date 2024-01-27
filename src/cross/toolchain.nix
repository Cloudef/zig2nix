{
  lib
  , writeShellApplication
  , writeText
  , emptyFile
  , runCommandLocal
  , symlinkJoin
  , coreutils
  , gnugrep
  , llvm
  , zig
  , zigPackage
  , allTargetSystems
  , nixTripleFromSystem
  , zigTripleFromSystem
  , mkZigSystemFromPlatform
  , mkZigSystemFromString
  , buildPlatform
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
  zigcc = target: let
    support = zigPackage target { src = ./support; };

    pp_args = [ "-target" ''${target}'' ];

    system = mkZigSystemFromString target;

    # Does not support the -c compiler flag
    multiple-objects-supported = system.zig.kernel != "windows" && system.kernel.name != "darwin";

    libname = lib: if system.zig.kernel == "windows" then "${lib}.lib" else "lib${lib}.a";

    # Has to be separate as these will be treated as inputs otherwise ...
    cc_args = [
      # Symbol versioning hell ...
      "-Wl,--undefined-version"
    ] ++ optionals (multiple-objects-supported) [
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
          -march=*|-mcpu=*|-mtune=*)
            shift;;
          -flto-partition=*)
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

  tools-for-target = t: let
    local = zigTripleFromSystem (mkZigSystemFromPlatform buildPlatform);
    z = t.z or local;
    p = if t != null then "${t.n}-" else "";
  in ''
    ln -sf ${llvm}/bin/llvm-install-name-tool $out/bin/${p}install_name_tool
    ln -sf ${llvm}/bin/llvm-as $out/bin/${p}as
    ln -sf ${llvm}/bin/llvm-dwp $out/bin/${p}dwp
    ln -sf ${llvm}/bin/llvm-nm $out/bin/${p}nm
    ln -sf ${llvm}/bin/llvm-objdump $out/bin/${p}objdump
    ln -sf ${llvm}/bin/llvm-readelf $out/bin/${p}readelf
    ln -sf ${llvm}/bin/llvm-size $out/bin/${p}size
    ln -sf ${llvm}/bin/llvm-strip $out/bin/${p}strip
    ln -sf ${zigcmd "ar"}/bin/ar $out/bin/${p}ar
    ln -sf ${zigcmd "ranlib"}/bin/ranlib $out/bin/${p}ranlib
    ln -sf ${zigcmd "dlltool"}/bin/dlltool $out/bin/${p}dlltool
    ln -sf ${zigcmd "lib"}/bin/lib $out/bin/${p}lib
    ln -sf ${zigcmd "objcopy"}/bin/objcopy $out/bin/${p}objcopy
    ln -sf ${zigrc}/bin/zigrc $out/bin/${p}rc
    ln -sf $out/bin/${p}rc $out/bin/${p}windres
    ln -sf ${zigcc z "cc"}/bin/zigcc $out/bin/${p}clang
    ln -sf ${zigcc z "c++"}/bin/zigc++ $out/bin/${p}clang++
    ln -sf $out/bin/${p}clang $out/bin/${p}gcc
    ln -sf $out/bin/${p}clang++ $out/bin/${p}g++
    ln -sf $out/bin/${p}clang $out/bin/${p}cc
    ln -sf $out/bin/${p}clang++ $out/bin/${p}c++
    ln -sf ${zigld}/bin/zigld $out/bin/${p}ld
    '';

  toolchain-universal = let
    triples = map (s: { z = zigTripleFromSystem s; n = nixTripleFromSystem s; }) allTargetSystems;
  in runCommandLocal "zig-toolchain-universal" {} ''
    mkdir -p "$out/bin"
    ${concatStringsSep "\n" (map tools-for-target triples)}
    '';

  toolchain-local = runCommandLocal "zig-toolchain-local" {} ''
    mkdir -p "$out/bin"
    ${tools-for-target null}
    '';

  toolchain-unwrapped = libllvm: symlinkJoin {
    name = "zig-toolchain";
    inherit (zig) version;
    paths = [ toolchain-local toolchain-universal ];
    passthru = {
      isClang = true;
      isLLVM = true;
      inherit libllvm;
    };
  };
in

{
  libc
  , wrapCCWith
  , wrapBintoolsWith
  , libllvm
}:

wrapCCWith {
  inherit gnugrep coreutils libc;
  cc = toolchain-unwrapped libllvm;
  useCcForLibs = false;
  bintools = wrapBintoolsWith {
    inherit gnugrep coreutils libc;
    bintools = toolchain-unwrapped libllvm;
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

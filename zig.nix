{
  lib
  , installDocs ? false
  , zigSystem
  , zigHook
  , version
  , release
  , stdenv
  , stdenvNoCC
  , callPackage
  , fetchurl
  , zig-shell-completions
  , cmake
  , llvmPackages_18
  , libxml2
  , zlib
  , coreutils
}:

with builtins;
with lib;

let
  meta-for = release: {
    homepage = "https://ziglang.org/";
    description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = []; # needed by the setup hook
    mainProgram = "zig";
  } // optionalAttrs (release ? notes) {
    changelog = release.notes;
  };
in {
  src = with llvmPackages_18; stdenv.mkDerivation (finalAttrs: {
    pname = "zig";
    inherit version;

    outputs = [ "out" ] ++ optionals (installDocs) [ "doc" ];

    src = fetchurl {
      url = release.src.tarball;
      sha256 = release.src.shasum;
    };

    nativeBuildInputs = [ cmake llvm.dev ];
    buildInputs = [ libxml2 zlib libclang lld llvm ];

    cmakeFlags = [
      # file RPATH_CHANGE could not write new RPATH
      "-DCMAKE_SKIP_BUILD_RPATH=ON"

      # always link against static build of LLVM
      "-DZIG_STATIC_LLVM=ON"

      # ensure determinism in the compiler build
      "-DZIG_TARGET_MCPU=baseline"
    ];

    env.ZIG_GLOBAL_CACHE_DIR = "$TMPDIR/zig-cache";

    # Zig's build looks at /usr/bin/env to find dynamic linking info. This doesn't
    # work in Nix's sandbox. Use env from our coreutils instead.
    postPatch = ''
      substituteInPlace lib/std/zig/system/NativeTargetInfo.zig --replace "/usr/bin/env" "${coreutils}/bin/env" || true
      substituteInPlace lib/std/zig/system.zig --replace "/usr/bin/env" "${coreutils}/bin/env" || true
      '';

    postBuild = optionalString (installDocs) ''
      stage3/bin/zig run --cache-dir "$TMPDIR/zig-test-cache" ../tools/docgen.zig -- ../doc/langref.html.in langref.html --zig $PWD/stage3/bin/zig
      '';

    postInstall = optionalString (installDocs) ''
      install -Dm444 -t $doc/share/doc/zig-$version/html langref.html
      '';

    doInstallCheck = true;

    installCheckPhase = ''
      runHook preInstallCheck
      $out/bin/zig test --cache-dir "$TMPDIR/zig-test-cache" -I ../test ../test/behavior.zig
      runHook postInstallCheck
      '';

    passthru = {
      inherit (release) date notes stdDocs docs src;
      hook = callPackage zigHook {
        zig = finalAttrs.finalPackage;
      };
    };

    meta = meta-for release;
  });

  has-bin = release ? ${zigSystem};

  bin = if release ? ${zigSystem} then stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "zig";
    inherit version;

    outputs = [ "out" ] ++ optionals (installDocs) [ "doc" ];

    src = fetchurl {
      url = release.${zigSystem}.tarball;
      sha256 = release.${zigSystem}.shasum;
    };

    phases = [ "unpackPhase" "installPhase" ];

    installPhase = ''
      mkdir -p $out/{bin,lib}
      cp -r lib/* $out/lib
      install -Dm755 zig $out/bin/zig
      install -m644 LICENSE $out/LICENSE
      '' + optionalString (installDocs) ''
      mkdir -p $out/doc
      if [[ -d docs ]]; then
        cp -r docs $out/doc
      else
        cp -r doc $out/doc
      fi
      '';

    passthru = {
      inherit (release) date notes stdDocs docs src;
      inherit (release.${zigSystem}) size;
      hook = callPackage zigHook {
        zig = finalAttrs.finalPackage;
      };
    };

    meta = meta-for release;
  }) else throw "There is no zig-${version} binary available for ${zigSystem}, use .src to compile from source";

  shell-completions = zig-shell-completions;
}

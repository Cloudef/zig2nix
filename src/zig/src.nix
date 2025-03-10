{
  lib
  , installDocs ? false
  , zigHook
  , release
  , stdenv
  , callPackage
  , fetchurl
  , zig-shell-completions
  , cmake
  , llvmPackages_19
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
in with llvmPackages_19; stdenv.mkDerivation (finalAttrs: {
  pname = "zig";
  inherit (release) version;

  outputs = [ "out" ] ++ optionals installDocs [ "doc" ];

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

  postBuild = optionalString installDocs ''
    stage3/bin/zig run --cache-dir "$TMPDIR/zig-test-cache" ../tools/docgen.zig -- ../doc/langref.html.in langref.html --zig $PWD/stage3/bin/zig
    '';

  postInstall = optionalString installDocs ''
    install -Dm444 -t $doc/share/doc/zig-${release.version}/html langref.html
    '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/zig test --cache-dir "$TMPDIR/zig-test-cache" -I ../test ../test/behavior.zig
    runHook postInstallCheck
    '';

  passthru = {
    info = release;
    inherit (release) date notes stdDocs docs src;
    hook = callPackage zigHook {
      zig = finalAttrs.finalPackage;
    };
    shell-completions = zig-shell-completions;
  };

  meta = meta-for release;
})

{
  lib
  , zigHook
  , release
  , stdenv
  , callPackage
  , fetchRelease
  , zig-shell-completions
  , cmake
  , ninja
  , llvmPackages
  , libxml2
  , zlib
  , coreutils
  , xcbuild
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
in with llvmPackages; stdenv.mkDerivation (finalAttrs: {
  pname = "zig";
  inherit (release) version;

  outputs = [ "out" ];

  src = fetchRelease release.src;

  nativeBuildInputs = [ cmake llvm.dev ninja ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      # provides xcode-select, which is required for SDK detection
      xcbuild
    ];

  buildInputs = [ libxml2 zlib libclang lld llvm ];

  cmakeFlags = [
    # file RPATH_CHANGE could not write new RPATH
    (lib.cmakeBool "CMAKE_SKIP_BUILD_RPATH" true)
    # ensure determinism in the compiler build
    (lib.cmakeFeature "ZIG_TARGET_MCPU" "baseline")
    # always link against static build of LLVM
    (lib.cmakeBool "ZIG_STATIC_LLVM" true)
  ];

  strictDeps = true;

  # On Darwin, Zig calls std.zig.system.darwin.macos.detect during the build,
  # which parses /System/Library/CoreServices/SystemVersion.plist and
  # /System/Library/CoreServices/.SystemVersionPlatform.plist to determine the
  # OS version. This causes the build to fail during stage 3 with
  # OSVersionDetectionFail when the sandbox is enabled.
  __impureHostDeps = lib.optionals stdenv.hostPlatform.isDarwin [
    "/System/Library/CoreServices/.SystemVersionPlatform.plist"
  ];

  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache";
  '';

  # Zig's build looks at /usr/bin/env to find dynamic linking info. This doesn't
  # work in Nix's sandbox. Use env from our coreutils instead.
  postPatch = ''
    substituteInPlace lib/std/zig/system/NativeTargetInfo.zig --replace "/usr/bin/env" "${coreutils}/bin/env" || true
    substituteInPlace lib/std/zig/system.zig --replace "/usr/bin/env" "${coreutils}/bin/env" || true
    ''
    # Zig tries to access xcrun and xcode-select at the absolute system path to query the macOS SDK
    # location, which does not work in the darwin sandbox.
    # Upstream issue: https://github.com/ziglang/zig/issues/22600
    # Note that while this fix is already merged upstream and will be included in 0.14+,
    # we can't fetchpatch the upstream commit as it won't cleanly apply on older versions,
    # so we substitute the paths instead.
    + lib.optionalString (stdenv.hostPlatform.isDarwin && lib.versionOlder finalAttrs.version "0.14") ''
      substituteInPlace lib/std/zig/system/darwin.zig \
        --replace-fail /usr/bin/xcrun xcrun \
        --replace-fail /usr/bin/xcode-select xcode-select
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

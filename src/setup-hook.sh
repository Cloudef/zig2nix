# shellcheck shell=bash disable=SC2154,SC2086

function zigConfigurePhase {
  runHook preConfigure

  ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
  export ZIG_GLOBAL_CACHE_DIR
  ZIG_LOCAL_CACHE_DIR="$ZIG_GLOBAL_CACHE_DIR"
  export ZIG_LOCAL_CACHE_DIR
  runHook postConfigure
}

function zigBuildPhase {
  runHook preBuild

  local buildCores=1

  # Parallel building is enabled by default.
  if [ "${enableParallelBuilding-1}" ]; then
    buildCores="$NIX_BUILD_CORES"
  fi

  local flagsArray=(
    "-j$buildCores"
  )
  concatTo flagsArray \
    zigBuildFlags zigBuildFlagsArray

  echoCmd 'zig build flags' "${flagsArray[@]}"
  TERM=dumb zig build "${flagsArray[@]}" --verbose

  runHook postBuild
}

function zigCheckPhase {
  runHook preCheck

  local buildCores=1

  # Parallel building is enabled by default.
  if [ "${enableParallelChecking-1}" ]; then
    buildCores="$NIX_BUILD_CORES"
  fi

  local flagsArray=(
    "-j$buildCores"
  )
  concatTo flagsArray \
    zigCheckFlags zigCheckFlagsArray

  echoCmd 'zig check flags' "${flagsArray[@]}"
  TERM=dumb zig build test "${flagsArray[@]}" --verbose

  runHook postCheck
}

function zigInstallPhase {
  runHook preInstall

  local buildCores=1

  # Parallel building is enabled by default.
  if [ "${enableParallelInstalling-1}" ]; then
    buildCores="$NIX_BUILD_CORES"
  fi

  local flagsArray=(
    "-j$buildCores"
  )

  concatTo flagsArray \
    zigBuildFlags zigBuildFlagsArray \
    zigInstallFlags zigInstallFlagsArray

  if [ -z "${dontAddPrefix-}" ] && [ -n "$prefix" ]; then
    # Zig does not recognize `--prefix=/dir/`, only `--prefix /dir/`
    flagsArray+=("${prefixKey:---prefix}" "$prefix")
  fi

  echoCmd 'zig install flags' "${flagsArray[@]}"
  TERM=dumb zig build install "${flagsArray[@]}" --verbose

  runHook postInstall
}

if [ -z "${dontUseZigConfigure-}" ] && [ -z "${configurePhase-}" ]; then
  configurePhase=zigConfigurePhase
fi

if [ -z "${dontUseZigBuild-}" ] && [ -z "${buildPhase-}" ]; then
    buildPhase=zigBuildPhase
fi

if [ -z "${dontUseZigCheck-}" ] && [ -z "${checkPhase-}" ]; then
    checkPhase=zigCheckPhase
fi

if [ -z "${dontUseZigInstall-}" ] && [ -z "${installPhase-}" ]; then
    installPhase=zigInstallPhase
fi

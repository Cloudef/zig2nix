{
  lib
  , runCommandLocal
  , writeClosure
  , emptyFile
  , file
  , findutils
  , coreutils
  , bundleZip
}:

with builtins;
with lib;

let
  arch-map = {
    aarch64 = {
      zig-target = "aarch64-linux-musl";
      runtime = "provided.al2023";
      runtime-arch = "arm64";
      nix-arch = "aarch64";
    };
    x86_64 = {
      zig-target = "x86_64-linux-musl";
      runtime = "provided.al2023";
      runtime-arch = "x86_64";
      nix-arch = "x86_64";
    };
  };
  get-config = arch: arch-map.${arch} or (throw "architecture ${arch} is not supported");
  detect-arch = bin: readFile (runCommandLocal "${bin}-arch" {} ''
    IFS=, read -r _ arch _ < <(${file}/bin/file -b '${bin}')
    echo -n "''${arch##* }" | tr '-' '_' > $out
    '');
  detect-config = bin: get-config (detect-arch bin);
in {
  # Package derivation to bundle
  package
  # Optional name
  , name ? lib.getName package
  # Entrypoint from the package to run
  , entrypoint ? lib.getExe package
  # The package directory is used as root for the zip
  # Any references will still be bundled in nix/store/... however
  # NOTE: This is forced true because useLoader does not work in AWS
  , packageAsRoot ? false
  # Include all references of the package derivation
  # If you are sure your package can run standalone, you can set this to false
  , includeReferences ? true
  # Override architecture of the lambda
  , arch ? detect-arch entrypoint
  # Override runtime of the lambda
  , runtime ? (detect-config entrypoint).runtime
  # Handler for the lambda (not required on provided runtime)
  , handler ? if ! hasPrefix "provided." runtime then throw "handler must be specified" else "bootstrap"
  # Environment variables
  , env ? {}
}:

let
  zipEntrypoint = if hasPrefix "provided." runtime then "bootstrap" else baseNameOf entrypoint;
  refs = if includeReferences then writeClosure [ package ] else emptyFile;
  getPaths = dir: readFile (runCommandLocal "${name}-${dir}dirs" {} ''
    while read -r path; do
      ${findutils}/bin/find $path -type d -name "${dir}"
    done < ${refs} | ${coreutils}/bin/sort -u | while read -r path; do
      printf '.%s:' "$path"
    done > $out
    '');
in bundleZip {
  name = "${name}-${runtime}-${(get-config arch).runtime-arch}";
  inherit package entrypoint zipEntrypoint includeReferences;
  loaderRuntime = false;
  loaderArch = (get-config arch).nix-arch;
  loaderWorkdir = "/tmp";
  # Sadly AWS lambda does not allow creating user namespaces ;_;
  useLoader = false;
  packageAsRoot = true;
  passthru.aws = {
    inherit runtime handler;
    arch = (get-config arch).runtime-arch;
    entrypoint = zipEntrypoint;
    # Because user namespaces are not allowed lets do this trick
    env = optionalAttrs ((getPaths "bin") != "") {
      PATH = "${getPaths "bin"}/usr/bin:/bin";
    } // optionalAttrs ((getPaths "lib") != "") {
      LD_LIBRARY_PATH = "${getPaths "lib"}/usr/lib:/lib";
    } // env;
  };
}

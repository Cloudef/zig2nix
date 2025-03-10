{
  lib
  , stdenvNoCC
  , runCommandLocal
  , writeClosure
  , file
  , findutils
  , zip
  , zigPackage
}:

with lib;
with builtins;

let
  detect-type = bin: readFile (runCommandLocal "${bin}-type" {} ''
    read -r type _ < <(${file}/bin/file -b '${bin}')
    echo -n "$type" > $out
    '');
  detect-arch = bin: readFile (runCommandLocal "${bin}-arch" {} ''
    IFS=, read -r _ arch _ < <(${file}/bin/file -b '${bin}')
    echo -n "''${arch##* }" | tr '-' '_' > $out
    '');
in {
  # Package derivation to bundle
  package
  # Optional name
  , name ? lib.getName package
  # Entrypoint from the package to run
  , entrypoint ? lib.getExe package
  # Entrypoint name inside the zip
  , zipEntrypoint ? "run"
  # The package directory is used as root for the zip
  # Any references will still be bundled in nix/store/... however
  , packageAsRoot ? false
  # Include all references of the package derivation
  # If you are sure your package can run standalone, you can set this to false
  , includeReferences ? true
  # Should we use a ELF loader?
  # Defaults to true on linux
  # The loader setups user namespace and mounts /nix to create an nix environment
  # It can also try setup a runtime environment for the binary so dlopen of various system libraries might succeed.
  # Unfortunately this is linux only.
  , useLoader ? (detect-type entrypoint) == "ELF"
  # Should loader try detect a linux distro and setup a compatible runtime?
  , loaderRuntime ? true
  # Override the arch for the loader if the auto-detection fails
  , loaderArch ? detect-arch entrypoint
  # Workdir for the loader, defaults to wherever zipEntrypoint is located, must be a writable location
  , loaderWorkdir ? null
  , ...
}@userAttrs:

let
  refs = if includeReferences then writeClosure [ package ]
         else (runCommandLocal "${name}-no-references" {} ''${findutils}/bin/find ${package} -type f > $out'');

  tightly-packed = !useLoader && readFile (runCommandLocal "is-${name}-tightly-packed" {} ''
      while read -r path; do
        ${findutils}/bin/find $path -type f
      done < ${refs} > $out
    '') == "${entrypoint}\n";

  # This is used to setup user namespace that mounts /nix for the process
  # It can also try setup a compatible runtime for non-FHS distros
  # NOTE: this only works in linux
  loader = let
    entrypoint' = if packageAsRoot then ".${removePrefix (toString package) entrypoint}" else "${entrypoint}";
  in zigPackage {
    name = "loader";
    src = cleanSource ./loader;
    zigTarget = "${loaderArch}-linux-musl";
    zigBuildFlags = [
      "-Doptimize=ReleaseSmall"
      "-Dentrypoint=${entrypoint'}"
      "-Druntime=${if loaderRuntime then "true" else "false"}"
      "-Dnamespace=true"
    ] ++ optionals (loaderWorkdir != null) [
      "-Dworkdir=${loaderWorkdir}"
    ];
    meta.mainProgram = "loader";
    meta.platforms = platforms.linux;
  };
in stdenvNoCC.mkDerivation (userAttrs // {
  name = "${name}.zip";
  nativeBuildInputs = [ zip ];
  phases = [ "installPhase" ];
  installPhase = ''
  '' + optionalString useLoader ''
    cp -f ${loader}/bin/loader ${zipEntrypoint}
  '' + optionalString (!useLoader && (!packageAsRoot || tightly-packed)) ''
    ln -s ${entrypoint} ${zipEntrypoint}
  '' + optionalString (!useLoader && (packageAsRoot && !tightly-packed)) ''
    ln -s ./${removePrefix "${toString package}/" entrypoint} ${zipEntrypoint}
  '' + optionalString tightly-packed ''
    zip -9 $out ${zipEntrypoint}
  '' + optionalString (!tightly-packed && !packageAsRoot) ''
    zip -9 --symlinks $out ${zipEntrypoint}
    while read -r path; do
      zip -9 --symlinks -ru $out $path
    done < ${refs}
  '' + optionalString (!tightly-packed && packageAsRoot) ''
    zip -9 --symlinks $out ${zipEntrypoint}
    (cd ${package}; zip -9 -ru $out .)
    while read -r path; do
      if [ $path != ${package} ]; then
        zip -9 --symlinks -ru $out $path
      fi
    done < ${refs}
  '' + ''
    zip -9 -d $out 'nix-support/*' 'nix-support' '*/nix-support/*' '*/nix-support' 2>/dev/null || true
  '';
})

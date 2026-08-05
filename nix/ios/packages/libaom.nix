{
  lib,
  libaom,
  mkIOSCMakePackage,
  packageSpec,
  perl,
  python3,
  writeShellScriptBin,
}:

assert lib.assertMsg (
  libaom.version == packageSpec.version
) "libaom source version ${libaom.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "libaom iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "libaom-ios";
  inherit (packageSpec) version;
  src = libaom.src;
  cmakeFlags = packageSpec.cmake_args;
  enableFullAppleToolchain = true;
  nativeBuildInputs = [
    perl
    python3
    (writeShellScriptBin "git" ''
      echo v${packageSpec.version}
    '')
  ];

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  staticArchives = packageSpec.artifacts;

  meta = {
    description = "Static AOM AV1 codec cross-compiled for the Krita iPadOS target";
    inherit (libaom.meta) license;
  };
}

{
  lib,
  libaom-ios,
  libde265-ios,
  libheif,
  mkIOSCMakePackage,
  packageSpec,
  x265-ios,
}:

assert lib.assertMsg (
  libheif.version == packageSpec.version
) "libheif source version ${libheif.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [
    "libde265"
    "x265"
    "libaom"
  ]
) "libheif iOS manifest target dependencies changed";

mkIOSCMakePackage {
  pname = "libheif-ios";
  inherit (packageSpec) version;
  src = libheif.src;

  targetDependencies = [
    libde265-ios
    x265-ios
    libaom-ios
  ];
  cmakeFlags = packageSpec.cmake_args;
  enableTargetPkgConfig = true;

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  inspectAllAppleObjects = true;

  meta = {
    description = "Static HEIF/AVIF codec cross-compiled for the Krita iPadOS target";
    inherit (libheif.meta) license;
  };
}

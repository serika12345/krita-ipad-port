{
  brotli-ios,
  lcms2-ios,
  lib,
  libhwy-ios,
  libjxl,
  mkIOSCMakePackage,
  packageSpec,
}:

assert lib.assertMsg (
  libjxl.version == packageSpec.version
) "libjxl source version ${libjxl.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [
    "brotli"
    "libhwy"
    "lcms2"
  ]
) "libjxl iOS manifest target dependencies changed";

mkIOSCMakePackage {
  pname = "libjxl-ios";
  inherit (packageSpec) version;
  src = libjxl.src;

  targetDependencies = [
    brotli-ios
    libhwy-ios
    lcms2-ios
  ];
  cmakeFlags = packageSpec.cmake_args;
  enableTargetPkgConfig = true;

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  inspectAllAppleObjects = true;

  meta = {
    description = "Static JPEG XL codec cross-compiled for the Krita iPadOS target";
    inherit (libjxl.meta) license;
  };
}

{
  lib,
  libhwy,
  mkIOSCMakePackage,
  packageSpec,
}:

assert lib.assertMsg (
  libhwy.version == packageSpec.version
) "Highway source version ${libhwy.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "Highway iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "libhwy-ios";
  inherit (packageSpec) version;
  src = libhwy.src;
  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  staticArchives = packageSpec.artifacts;

  meta = {
    description = "Static Highway SIMD runtime cross-compiled for the Krita iPadOS target";
    inherit (libhwy.meta) license;
  };
}

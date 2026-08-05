{
  brotli,
  lib,
  mkIOSCMakePackage,
  packageSpec,
}:

assert lib.assertMsg (
  brotli.version == packageSpec.version
) "Brotli source version ${brotli.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "Brotli iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "brotli-ios";
  inherit (packageSpec) version;
  src = brotli.src;
  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  staticArchives = packageSpec.artifacts;

  meta = {
    description = "Static Brotli cross-compiled for the Krita iPadOS target";
    inherit (brotli.meta) license;
  };
}

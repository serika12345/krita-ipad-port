{
  lib,
  libde265,
  mkIOSCMakePackage,
  packageSpec,
}:

assert lib.assertMsg (
  libde265.version == packageSpec.version
) "libde265 source version ${libde265.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "libde265 iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "libde265-ios";
  inherit (packageSpec) version;
  src = libde265.src;
  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  staticArchives = packageSpec.artifacts;

  meta = {
    description = "Static HEVC decoder cross-compiled for the Krita iPadOS target";
    inherit (libde265.meta) license;
  };
}

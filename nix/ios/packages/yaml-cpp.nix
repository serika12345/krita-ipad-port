{
  lib,
  mkIOSCMakePackage,
  packageSpec,
  yaml-cpp,
}:

assert lib.assertMsg (
  yaml-cpp.version == packageSpec.version
) "yaml-cpp source version ${yaml-cpp.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "yaml-cpp iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "yaml-cpp-ios";
  inherit (packageSpec) version;
  src = yaml-cpp.src;
  patches = yaml-cpp.patches or [ ];
  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  staticArchives = packageSpec.artifacts;

  meta = {
    description = "Static yaml-cpp cross-compiled for the Krita iPadOS target";
    inherit (yaml-cpp.meta) license;
  };
}

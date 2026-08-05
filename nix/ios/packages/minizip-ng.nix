{
  lib,
  minizip-ng,
  mkIOSCMakePackage,
  packageSpec,
  zlib-ios,
}:

assert lib.assertMsg (minizip-ng.version == packageSpec.version)
  "minizip-ng source version ${minizip-ng.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ "zlib" ]
) "minizip-ng iOS manifest target dependencies changed";

mkIOSCMakePackage {
  pname = "minizip-ng-ios";
  inherit (packageSpec) version;
  src = minizip-ng.src;

  targetDependencies = [ zlib-ios ];
  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  staticArchives = packageSpec.artifacts;

  meta = {
    description = "Static minizip-ng cross-compiled for the Krita iPadOS target";
    inherit (minizip-ng.meta) license;
  };
}

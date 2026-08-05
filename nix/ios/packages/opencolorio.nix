{
  expat-ios,
  imath-ios,
  lib,
  minizip-ng-ios,
  mkIOSCMakePackage,
  opencolorio,
  packageSpec,
  pystring-ios,
  yaml-cpp-ios,
  zlib-ios,
}:

assert lib.assertMsg (opencolorio.version == packageSpec.version)
  "OpenColorIO source version ${opencolorio.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [
    "expat"
    "imath"
    "yaml-cpp"
    "pystring"
    "minizip-ng"
    "zlib"
  ]
) "OpenColorIO iOS manifest target dependencies changed";

mkIOSCMakePackage {
  pname = "opencolorio-ios";
  inherit (packageSpec) version;
  src = opencolorio.src;

  targetDependencies = [
    expat-ios
    imath-ios
    yaml-cpp-ios
    pystring-ios
    minizip-ng-ios
    zlib-ios
  ];
  cmakeFlags = packageSpec.cmake_args ++ [
    "-Dminizip-ng_INCLUDE_DIR=${minizip-ng-ios}/include/minizip-ng"
  ];
  enableTargetPkgConfig = true;

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  inspectAllAppleObjects = true;

  meta = {
    description = "Static OpenColorIO cross-compiled for the Krita iPadOS target";
    inherit (opencolorio.meta) license;
  };
}

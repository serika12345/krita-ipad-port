{
  imath,
  lib,
  mkIOSCMakePackage,
  packageSpec,
}:

assert lib.assertMsg (
  imath.version == packageSpec.version
) "imath source version ${imath.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "imath iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "imath-ios";
  inherit (packageSpec) version;
  src = imath.src;

  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = [
    "include/Imath/ImathBox.h"
    "lib/libImath-3_2.a"
    "lib/cmake/Imath/ImathConfig.cmake"
  ];
  staticArchives = [ "lib/libImath-3_2.a" ];

  meta = {
    description = "Static Imath cross-compiled for the Krita iPadOS target";
    inherit (imath.meta) license;
  };
}

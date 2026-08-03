{
  lib,
  zlib,
  mkIOSCMakePackage,
  packageSpec,
}:

assert lib.assertMsg (
  zlib.version == packageSpec.version
) "zlib source version ${zlib.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "zlib iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "zlib-ios";
  inherit (packageSpec) version;
  src = zlib.src;

  patches = [ ../patches/zlib-static-cmake-config.patch ];

  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = [
    "include/zconf.h"
    "include/zlib.h"
    "lib/cmake/zlib/ZLIBConfig.cmake"
    "lib/pkgconfig/zlib.pc"
  ];

  staticArchives = [ "lib/libz.a" ];

  meta = {
    description = "Static zlib cross-compiled for the pinned Krita iPadOS target";
    license = lib.licenses.zlib;
  };
}

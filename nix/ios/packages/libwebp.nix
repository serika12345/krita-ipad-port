{
  lib,
  libwebp,
  mkIOSCMakePackage,
  packageSpec,
}:

assert lib.assertMsg (
  libwebp.version == packageSpec.version
) "libwebp source version ${libwebp.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "libwebp iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "libwebp-ios";
  inherit (packageSpec) version;
  src = libwebp.src;

  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = [
    "include/webp/decode.h"
    "include/webp/encode.h"
    "lib/libwebp.a"
    "lib/libwebpdemux.a"
    "lib/libwebpmux.a"
    "lib/libsharpyuv.a"
  ];
  staticArchives = [
    "lib/libwebp.a"
    "lib/libwebpdemux.a"
    "lib/libwebpmux.a"
    "lib/libsharpyuv.a"
  ];

  meta = {
    description = "Static WebP codec cross-compiled for the Krita iPadOS target";
    inherit (libwebp.meta) license;
  };
}

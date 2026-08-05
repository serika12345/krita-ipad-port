{
  lib,
  libdeflate,
  mkIOSCMakePackage,
  packageSpec,
}:

assert lib.assertMsg (libdeflate.version == packageSpec.version)
  "libdeflate source version ${libdeflate.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "libdeflate iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "libdeflate-ios";
  inherit (packageSpec) version;
  src = libdeflate.src;

  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = [
    "include/libdeflate.h"
    "lib/libdeflate.a"
    "lib/cmake/Deflate/DeflateConfig.cmake"
  ];
  staticArchives = [ "lib/libdeflate.a" ];

  postInstall = ''
    install -Dm644 \
      ${../cmake/DeflateConfig.cmake} \
      "$out/lib/cmake/Deflate/DeflateConfig.cmake"
  '';

  meta = {
    description = "Static libdeflate cross-compiled for the Krita iPadOS target";
    inherit (libdeflate.meta) license;
  };
}

{
  lib,
  mkIOSCMakePackage,
  openjpeg,
  packageSpec,
}:

assert lib.assertMsg (
  openjpeg.version == packageSpec.version
) "openjpeg source version ${openjpeg.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "openjpeg iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "openjpeg-ios";
  inherit (packageSpec) version;
  src = openjpeg.src;

  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = [
    "include/openjpeg-2.5/openjpeg.h"
    "lib/libopenjp2.a"
  ];
  staticArchives = [ "lib/libopenjp2.a" ];

  meta = {
    description = "Static OpenJPEG cross-compiled for the Krita iPadOS target";
    inherit (openjpeg.meta) license;
  };
}

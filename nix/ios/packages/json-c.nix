{
  json_c,
  lib,
  mkIOSCMakePackage,
  packageSpec,
}:

assert lib.assertMsg (
  json_c.version == packageSpec.version
) "json-c source version ${json_c.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "json-c iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "json-c-ios";
  inherit (packageSpec) version;
  src = json_c.src;

  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = [
    "include/json-c/json.h"
    "lib/libjson-c.a"
    "lib/pkgconfig/json-c.pc"
  ];
  staticArchives = [ "lib/libjson-c.a" ];

  meta = {
    description = "Static json-c cross-compiled for the Krita iPadOS target";
    inherit (json_c.meta) license;
  };
}

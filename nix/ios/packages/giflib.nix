{
  giflib,
  lib,
  mkIOSAutotoolsPackage,
  packageSpec,
}:

assert lib.assertMsg (
  giflib.version == packageSpec.version
) "giflib source version ${giflib.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.build_system == "make"
) "giflib iOS manifest build system must be make";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "giflib iOS manifest unexpectedly gained target dependencies";

mkIOSAutotoolsPackage {
  pname = "giflib-ios";
  inherit (packageSpec) version;
  src = giflib.src;

  skipConfigure = true;
  makeTargets = packageSpec.make_targets;
  installTargets = [ ];

  requiredPaths = [
    "include/gif_lib.h"
    "lib/libgif.a"
  ];
  staticArchives = [ "lib/libgif.a" ];

  postInstall = ''
    mkdir -p "$out/include" "$out/lib"
    cp gif_lib.h "$out/include/gif_lib.h"
    cp libgif.a "$out/lib/libgif.a"
  '';

  meta = {
    description = "Static giflib cross-compiled for the Krita iPadOS target";
    inherit (giflib.meta) license;
  };
}

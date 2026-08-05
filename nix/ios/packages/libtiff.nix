{
  lib,
  libdeflate-ios,
  libjpeg-turbo-ios,
  libtiff,
  mkIOSCMakePackage,
  packageSpec,
  toolchain,
  zlib-ios,
}:

assert lib.assertMsg (
  libtiff.version == packageSpec.version
) "libtiff source version ${libtiff.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [
    "zlib"
    "libjpeg-turbo"
    "libdeflate"
  ]
) "libtiff iOS manifest target dependencies changed";

mkIOSCMakePackage {
  pname = "libtiff-ios";
  inherit (packageSpec) version;
  src = libtiff.src;

  targetDependencies = [
    zlib-ios
    libjpeg-turbo-ios
    libdeflate-ios
  ];
  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = [
    "include/tiff.h"
    "include/tiffio.h"
    "lib/libtiff.a"
  ];
  staticArchives = [ "lib/libtiff.a" ];

  # libtiff records the absolute SDK path to libm in its exported CMake target.
  # Consumers resolve -lm through their own selected iOS SDK, so retain that
  # link requirement without embedding this machine's Xcode location. Its
  # target also names static dependencies, so resolve those before importing.
  postInstall = ''
        config="$out/lib/cmake/tiff/tiff-config.cmake"
        sed -i '1i\
    include(CMakeFindDependencyMacro)\
    find_dependency(ZLIB)\
    find_dependency(Deflate CONFIG)\
    find_dependency(JPEG)\
    ' "$config"
        substituteInPlace "$out/lib/cmake/tiff/tiff-targets.cmake" \
          --replace-fail "${toolchain.sdkRoot}/usr/lib/libm.tbd" "m"
  '';

  meta = {
    description = "Static libtiff cross-compiled for the Krita iPadOS target";
    inherit (libtiff.meta) license;
  };
}

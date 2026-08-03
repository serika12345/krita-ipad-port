{
  lib,
  libpng,
  mkIOSCMakePackage,
  packageSpec,
  toolchain,
  zlib-ios,
}:

assert lib.assertMsg (
  libpng.version == packageSpec.version
) "libpng source version ${libpng.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ "zlib" ]
) "libpng iOS manifest target dependencies must be exactly [ zlib ]";

mkIOSCMakePackage {
  pname = "libpng-ios";
  inherit (packageSpec) version;
  src = libpng.src;

  targetDependencies = [ zlib-ios ];

  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = [
    "include/png.h"
    "include/pngconf.h"
    "include/pnglibconf.h"
    "lib/libpng.a"
    "lib/libpng16.a"
    "lib/libpng/libpng16.cmake"
    "lib/cmake/PNG/PNGConfig.cmake"
    "lib/cmake/PNG/PNGTargets.cmake"
    "lib/pkgconfig/libpng.pc"
    "lib/pkgconfig/libpng16.pc"
    "nix-support/propagated-build-inputs"
  ];

  # libpng.a is a relative compatibility symlink; inspect its real archive.
  staticArchives = [ "lib/libpng16.a" ];

  postInstallCheck = ''
    consumer_build="$NIX_BUILD_TOP/libpng-consumer"
    cmake \
      -S ${../tests/libpng-consumer} \
      -B "$consumer_build" \
      -G Ninja \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_SYSTEM_PROCESSOR=${toolchain.architecture} \
      -DCMAKE_OSX_ARCHITECTURES=${toolchain.architecture} \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=${toolchain.deploymentTarget} \
      -DCMAKE_OSX_SYSROOT=${toolchain.sdkRoot} \
      -DCMAKE_C_COMPILER=${toolchain.cc} \
      -DCMAKE_AR=${toolchain.ar} \
      -DCMAKE_RANLIB=${toolchain.ranlib} \
      -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
      -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE \
      -DCMAKE_PREFIX_PATH="$out;${zlib-ios}" \
      -DCMAKE_FIND_ROOT_PATH="$out;${zlib-ios}" \
      -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
      -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
      -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
      -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
    cmake --build "$consumer_build" --parallel

    consumer="$consumer_build/krita-ios-libpng-consumer.app/krita-ios-libpng-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta = {
    description = "Static libpng cross-compiled for the pinned Krita iPadOS target";
    license = lib.licenses.libpng2;
  };
}

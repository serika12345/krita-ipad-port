{
  lib,
  lcms2,
  mkIOSCMakePackage,
  packageSpec,
  toolchain,
}:

assert lib.assertMsg (
  lcms2.version == packageSpec.version
) "Little CMS source version ${lcms2.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "Little CMS iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "lcms2-ios";
  inherit (packageSpec) version;
  src = lcms2.src;

  patches = [ ../patches/lcms2-no-libm-on-apple.patch ];

  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = [
    "include/lcms2.h"
    "include/lcms2_plugin.h"
    "lib/liblcms2.a"
    "lib/cmake/lcms2/lcms2-config.cmake"
    "lib/cmake/lcms2/lcms2-config-version.cmake"
    "lib/cmake/lcms2/lcms2-targets.cmake"
    "lib/cmake/lcms2/lcms2-targets-release.cmake"
    "lib/pkgconfig/lcms2.pc"
  ];

  staticArchives = [ "lib/liblcms2.a" ];

  postInstall = ''
    config="$out/lib/cmake/lcms2/lcms2-config.cmake"
    {
      echo 'include(CMakeFindDependencyMacro)'
      echo 'find_dependency(Threads)'
      echo
      cat "$config"
    } > "$config.with-dependencies"
    mv "$config.with-dependencies" "$config"
  '';

  postInstallCheck = ''
    config="$out/lib/cmake/lcms2/lcms2-config.cmake"
    targets="$out/lib/cmake/lcms2/lcms2-targets.cmake"
    grep -Fxq 'find_dependency(Threads)' "$config"
    grep -Fq 'Threads::Threads' "$targets"

    consumer_build="$NIX_BUILD_TOP/lcms2-consumer"
    cmake \
      -S ${../tests/lcms2-consumer} \
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
      -DCMAKE_PREFIX_PATH="$out" \
      -DCMAKE_FIND_ROOT_PATH="$out" \
      -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
      -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
      -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
      -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
    cmake --build "$consumer_build" --parallel

    link_commands="$(ninja -C "$consumer_build" -t commands krita-ios-lcms2-consumer)"
    if ! grep -Fq -- "$out/lib/liblcms2.a" <<<"$link_commands"; then
      echo "error: Little CMS consumer did not link the target archive" >&2
      exit 1
    fi

    consumer="$consumer_build/krita-ios-lcms2-consumer.app/krita-ios-lcms2-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta = {
    description = "Static Little CMS cross-compiled for the pinned Krita iPadOS target";
    inherit (lcms2.meta) license;
  };
}

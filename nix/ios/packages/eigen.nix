{
  lib,
  eigen,
  mkIOSCMakePackage,
  packageSpec,
  toolchain,
}:

assert lib.assertMsg (
  eigen.version == packageSpec.version
) "Eigen source version ${eigen.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "Eigen iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "eigen-ios";
  inherit (packageSpec) version;
  src = eigen.src;

  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = [
    "include/eigen3/Eigen/Core"
    "share/eigen3/cmake/Eigen3Config.cmake"
    "share/eigen3/cmake/Eigen3ConfigVersion.cmake"
    "share/eigen3/cmake/Eigen3Targets.cmake"
    "share/pkgconfig/eigen3.pc"
  ];

  postInstallCheck = ''
    consumer_build="$NIX_BUILD_TOP/eigen-consumer"
    cmake \
      -S ${../tests/eigen-consumer} \
      -B "$consumer_build" \
      -G Ninja \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_SYSTEM_PROCESSOR=${toolchain.architecture} \
      -DCMAKE_OSX_ARCHITECTURES=${toolchain.architecture} \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=${toolchain.deploymentTarget} \
      -DCMAKE_OSX_SYSROOT=${toolchain.sdkRoot} \
      -DCMAKE_CXX_COMPILER=${toolchain.cxx} \
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

    build_commands="$(ninja -C "$consumer_build" -t commands krita-ios-eigen-consumer)"
    if ! grep -Fq -- "$out/include/eigen3" <<<"$build_commands"; then
      echo "error: Eigen consumer did not use the target package headers" >&2
      exit 1
    fi

    consumer="$consumer_build/krita-ios-eigen-consumer.app/krita-ios-eigen-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta = {
    description = "Eigen headers configured for the pinned Krita iPadOS target";
    inherit (eigen.meta) license;
  };
}

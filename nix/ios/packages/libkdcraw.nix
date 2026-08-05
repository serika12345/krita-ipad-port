{
  kfHostTooling,
  lib,
  libkdcraw,
  libraw-ios,
  mkIOSCMakePackage,
  packageSpec,
  qt6Packages,
  qtbase-ios,
  qtXcrunShim,
}:

let
  hostQt = qt6Packages.qtbase;
in
assert lib.assertMsg (libkdcraw.version == packageSpec.version)
  "libkdcraw source version ${libkdcraw.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg packageSpec.requires_qt "libkdcraw must remain a Qt target dependency";
assert lib.assertMsg (
  packageSpec.dependencies == [ "libraw" ]
) "libkdcraw iOS manifest target dependencies changed";

mkIOSCMakePackage {
  pname = "libkdcraw-ios";
  inherit (packageSpec) version;
  src = libkdcraw.src;
  patches = [
    ../patches/libkdcraw-static-libraw-config.patch
    ../patches/libkdcraw-heap-libraw-decoder.patch
  ];

  targetDependencies = [
    libraw-ios
    qtbase-ios
  ];
  appleSdkResolver = qtXcrunShim;
  cmakeToolchainFile = "${qtbase-ios}/lib/cmake/Qt6/qt.toolchain.cmake";
  enableFullAppleToolchain = true;
  enableTargetPkgConfig = true;
  tryCompileTargetType = null;
  cmakeFlags = packageSpec.cmake_args ++ [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE"
    "-DECM_DIR:PATH=${kfHostTooling.hostEcm}/share/ECM/cmake"
    "-DQT_APPLE_SDK=iphoneos"
    "-DQT_HOST_PATH:PATH=${hostQt}"
    "-DQT_HOST_PATH_CMAKE_DIR:PATH=${hostQt}/lib/cmake"
    "-DQT_XCRUN:FILEPATH=${qtXcrunShim}/bin/xcrun"
  ];

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  inspectAllAppleObjects = true;

  meta = {
    description = "Static libkdcraw Qt 6 wrapper cross-compiled for the Krita iPadOS target";
    inherit (libkdcraw.meta) license;
  };
}

{
  boost-ios,
  fontconfig-ios,
  freetype-ios,
  kfHostTooling,
  lcms2-ios,
  lib,
  libintl-ios,
  libjpeg-turbo-ios,
  mkIOSCMakePackage,
  openjpeg-ios,
  packageSpec,
  poppler,
  qt6Packages,
  qtbase-ios,
  qtXcrunShim,
  zlib-ios,
}:

let
  hostQt = qt6Packages.qtbase;
in
assert lib.assertMsg (
  poppler.version == packageSpec.version
) "Poppler source version ${poppler.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg packageSpec.requires_qt "Poppler must remain a Qt target dependency";

mkIOSCMakePackage {
  pname = "poppler-ios";
  inherit (packageSpec) version;
  src = poppler.src;

  targetDependencies = [
    boost-ios
    fontconfig-ios
    freetype-ios
    lcms2-ios
    libintl-ios
    libjpeg-turbo-ios
    openjpeg-ios
    qtbase-ios
    zlib-ios
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
    description = "Static Poppler Qt 6 PDF renderer cross-compiled for the Krita iPadOS target";
    inherit (poppler.meta) license;
  };
}

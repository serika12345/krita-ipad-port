{
  bison,
  flex,
  gettext,
  kfHostTooling,
  ki18n-ios,
  kseexpr,
  lib,
  mkIOSCMakePackage,
  packageSpec,
  qt6Packages,
  qtbase-ios,
  qtXcrunShim,
}:

let
  hostQt = qt6Packages.qtbase;
in
assert lib.assertMsg (
  kseexpr.version == packageSpec.version
) "KSeExpr source version ${kseexpr.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg packageSpec.requires_qt "KSeExpr must remain a Qt target dependency";

mkIOSCMakePackage {
  pname = "kseexpr-ios";
  inherit (packageSpec) version;
  src = kseexpr.src;
  patches = (kseexpr.patches or [ ]) ++ [ ../patches/kseexpr-static-libraries.patch ];

  targetDependencies = [
    qtbase-ios
    ki18n-ios
  ];
  appleSdkResolver = qtXcrunShim;
  cmakeToolchainFile = "${qtbase-ios}/lib/cmake/Qt6/qt.toolchain.cmake";
  enableFullAppleToolchain = true;
  tryCompileTargetType = null;
  nativeBuildInputs = [
    bison
    flex
    gettext
  ];
  cmakeFlags = packageSpec.cmake_args ++ [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE"
    "-DECM_DIR:PATH=${kfHostTooling.hostEcm}/share/ECM/cmake"
    "-DGETTEXT_MSGFMT_EXECUTABLE:FILEPATH=${gettext}/bin/msgfmt"
    "-DGETTEXT_MSGMERGE_EXECUTABLE:FILEPATH=${gettext}/bin/msgmerge"
    "-DQT_APPLE_SDK=iphoneos"
    "-DQT_HOST_PATH:PATH=${hostQt}"
    "-DQT_HOST_PATH_CMAKE_DIR:PATH=${hostQt}/lib/cmake"
    "-DQT_XCRUN:FILEPATH=${qtXcrunShim}/bin/xcrun"
  ];

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  inspectAllAppleObjects = true;

  meta = {
    description = "Static KSeExpr generator runtime cross-compiled for the Krita iPadOS target";
    inherit (kseexpr.meta) license;
  };
}

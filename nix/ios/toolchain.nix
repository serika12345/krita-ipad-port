{ lib, versions }:

let
  xcodeApp = "/Applications/Xcode.app";
  developerDir = "${xcodeApp}/Contents/Developer";
  toolchainDir = "${developerDir}/Toolchains/XcodeDefault.xctoolchain/usr/bin";
  sdkRoot = "${developerDir}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS${versions.KRITA_IOS_SDK_VERSION}.sdk";
in
{
  inherit
    developerDir
    sdkRoot
    toolchainDir
    xcodeApp
    ;

  architecture = versions.KRITA_IOS_ARCHITECTURE;
  deploymentTarget = versions.KRITA_IOS_DEPLOYMENT_TARGET;
  xcodeVersion = versions.KRITA_IOS_XCODE_VERSION;
  xcodeBuildVersion = versions.KRITA_IOS_XCODE_BUILD_VERSION;
  sdkVersion = versions.KRITA_IOS_SDK_VERSION;
  sdkBuildVersion = versions.KRITA_IOS_SDK_BUILD_VERSION;
  clangVersion = versions.KRITA_IOS_CLANG_VERSION;
  clangBuildVersion = versions.KRITA_IOS_CLANG_BUILD_VERSION;

  cc = "${toolchainDir}/clang";
  cxx = "${toolchainDir}/clang++";
  ar = "${toolchainDir}/ar";
  ranlib = "${toolchainDir}/ranlib";
  strip = "${toolchainDir}/strip";
  lipo = "${toolchainDir}/lipo";
  otool = "${toolchainDir}/otool";
  vtool = "${toolchainDir}/vtool";
  xcodebuild = "${developerDir}/usr/bin/xcodebuild";

  impureHostDeps = [
    xcodeApp
  ];

  identity = lib.concatStringsSep ";" [
    "xcode=${versions.KRITA_IOS_XCODE_VERSION}"
    "xcode-build=${versions.KRITA_IOS_XCODE_BUILD_VERSION}"
    "sdk=${versions.KRITA_IOS_SDK_VERSION}"
    "sdk-build=${versions.KRITA_IOS_SDK_BUILD_VERSION}"
    "clang=${versions.KRITA_IOS_CLANG_VERSION}"
    "clang-build=${versions.KRITA_IOS_CLANG_BUILD_VERSION}"
    "deployment=${versions.KRITA_IOS_DEPLOYMENT_TARGET}"
    "architecture=${versions.KRITA_IOS_ARCHITECTURE}"
  ];
}

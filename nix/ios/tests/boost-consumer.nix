{
  boost-ios,
  mkIOSCMakePackage,
  toolchain,
}:

mkIOSCMakePackage {
  pname = "boost-consumer-check";
  inherit (boost-ios) version;
  src = ./boost-consumer;

  targetDependencies = [ boost-ios ];

  cmakeFlags = [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE"
    "-DKRITA_IOS_BOOST_PREFIX=${boost-ios}"
    "-DKRITA_IOS_BOOST_VERSION=${boost-ios.version}"
  ];

  requiredPaths = [ "bin/krita-ios-boost-consumer.app/krita-ios-boost-consumer" ];

  postBuild = ''
    build_commands="$(ninja -t commands krita-ios-boost-consumer)"
    if ! grep -Fq -- "${boost-ios}/include" <<<"$build_commands"; then
      echo "error: Boost consumer did not use the target package headers" >&2
      exit 1
    fi
    if ! grep -Fq -- '-DBOOST_ALL_NO_LIB' <<<"$build_commands"; then
      echo "error: Boost consumer did not inherit the disable-autolinking definition" >&2
      exit 1
    fi
  '';

  postInstallCheck = ''
    consumer="$out/bin/krita-ios-boost-consumer.app/krita-ios-boost-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta.description = "Apple Clang iOS compile check for the installed Boost header targets";
}

{
  mkIOSCMakePackage,
  toolchain,
  zug-ios,
}:

mkIOSCMakePackage {
  pname = "zug-consumer-check";
  inherit (zug-ios) version;
  src = ./zug-consumer;

  targetDependencies = [ zug-ios ];

  cmakeFlags = [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE"
    "-DKRITA_IOS_ZUG_PREFIX=${zug-ios}"
    "-DKRITA_IOS_ZUG_VERSION=${zug-ios.version}"
  ];

  requiredPaths = [ "bin/krita-ios-zug-consumer.app/krita-ios-zug-consumer" ];

  postBuild = ''
    build_commands="$(ninja -t commands krita-ios-zug-consumer)"
    if ! grep -Fq -- "${zug-ios}/include" <<<"$build_commands"; then
      echo "error: Zug consumer did not use the target package headers" >&2
      exit 1
    fi
  '';

  postInstallCheck = ''
    consumer="$out/bin/krita-ios-zug-consumer.app/krita-ios-zug-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta.description = "Apple Clang iOS compile check for Zug's installed plain target";
}

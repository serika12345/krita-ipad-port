{
  immer-ios,
  mkIOSCMakePackage,
  toolchain,
}:

mkIOSCMakePackage {
  pname = "immer-consumer-check";
  inherit (immer-ios) version;
  src = ./immer-consumer;

  targetDependencies = [ immer-ios ];

  cmakeFlags = [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE"
    "-DKRITA_IOS_IMMER_PREFIX=${immer-ios}"
    "-DKRITA_IOS_IMMER_VERSION=${immer-ios.version}"
  ];

  requiredPaths = [ "bin/krita-ios-immer-consumer.app/krita-ios-immer-consumer" ];

  postBuild = ''
    build_commands="$(ninja -t commands krita-ios-immer-consumer)"
    if ! grep -Fq -- "${immer-ios}/include" <<<"$build_commands"; then
      echo "error: Immer consumer did not use the target package headers" >&2
      exit 1
    fi
  '';

  postInstallCheck = ''
    consumer="$out/bin/krita-ios-immer-consumer.app/krita-ios-immer-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta.description = "Apple Clang iOS compile check for Immer's installed plain target";
}

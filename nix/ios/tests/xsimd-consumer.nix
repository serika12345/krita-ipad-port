{
  mkIOSCMakePackage,
  toolchain,
  xsimd-ios,
}:

mkIOSCMakePackage {
  pname = "xsimd-consumer-check";
  inherit (xsimd-ios) version;
  src = ./xsimd-consumer;

  targetDependencies = [ xsimd-ios ];

  cmakeFlags = [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE"
    "-DKRITA_IOS_XSIMD_PREFIX=${xsimd-ios}"
    "-DKRITA_IOS_XSIMD_VERSION=${xsimd-ios.version}"
  ];

  requiredPaths = [ "bin/krita-ios-xsimd-consumer.app/krita-ios-xsimd-consumer" ];

  postBuild = ''
    build_commands="$(ninja -t commands krita-ios-xsimd-consumer)"
    if ! grep -Fq -- "${xsimd-ios}/include" <<<"$build_commands"; then
      echo "error: xsimd consumer did not use the target package headers" >&2
      exit 1
    fi
  '';

  postInstallCheck = ''
    consumer="$out/bin/krita-ios-xsimd-consumer.app/krita-ios-xsimd-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta.description = "iOS compile check for xsimd's installed header-only target";
}

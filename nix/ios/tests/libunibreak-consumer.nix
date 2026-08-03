{
  libunibreak-ios,
  mkIOSCMakePackage,
  pkg-config,
  toolchain,
}:

mkIOSCMakePackage {
  pname = "libunibreak-consumer-check";
  inherit (libunibreak-ios) version;
  src = ./libunibreak-consumer;

  targetDependencies = [ libunibreak-ios ];
  nativeBuildInputs = [ pkg-config ];
  enableTargetPkgConfig = true;

  cmakeFlags = [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE"
    "-DCMAKE_MODULE_PATH=${../../../cmake/modules}"
    "-DPKG_CONFIG_EXECUTABLE=${pkg-config}/bin/pkg-config"
    "-DKRITA_IOS_LIBUNIBREAK_PREFIX=${libunibreak-ios}"
    "-DKRITA_IOS_LIBUNIBREAK_VERSION=${libunibreak-ios.version}"
  ];

  requiredPaths = [ "bin/krita-ios-libunibreak-consumer.app/krita-ios-libunibreak-consumer" ];

  postBuild = ''
    build_commands="$(ninja -t commands krita-ios-libunibreak-consumer)"
    if ! grep -Fq -- "${libunibreak-ios}/include" <<<"$build_commands"; then
      echo "error: libunibreak consumer did not use the target package headers" >&2
      exit 1
    fi
    if ! grep -Fq -- "${libunibreak-ios}/lib/libunibreak.a" <<<"$build_commands"; then
      echo "error: libunibreak consumer did not link the target archive" >&2
      exit 1
    fi
  '';

  postInstallCheck = ''
    consumer="$out/bin/krita-ios-libunibreak-consumer.app/krita-ios-libunibreak-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta.description = "iOS link check for Krita's libunibreak imported-target contract";
}

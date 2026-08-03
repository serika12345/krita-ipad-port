{
  fribidi-ios,
  mkIOSCMakePackage,
  pkg-config,
  toolchain,
}:

mkIOSCMakePackage {
  pname = "fribidi-consumer-check";
  inherit (fribidi-ios) version;
  src = ./fribidi-consumer;

  targetDependencies = [ fribidi-ios ];
  nativeBuildInputs = [ pkg-config ];
  enableTargetPkgConfig = true;

  cmakeFlags = [
    "-DCMAKE_MODULE_PATH=${../../../cmake/modules}"
    "-DPKG_CONFIG_EXECUTABLE=${pkg-config}/bin/pkg-config"
    "-DKRITA_IOS_FRIBIDI_PREFIX=${fribidi-ios}"
    "-DKRITA_IOS_FRIBIDI_VERSION=${fribidi-ios.version}"
  ];

  requiredPaths = [ "bin/krita-ios-fribidi-consumer.app/krita-ios-fribidi-consumer" ];

  postBuild = ''
    build_commands="$(ninja -t commands krita-ios-fribidi-consumer)"
    if ! grep -Fq -- "${fribidi-ios}/include/fribidi" <<<"$build_commands"; then
      echo "error: FriBidi consumer did not use the target package headers" >&2
      exit 1
    fi
    if ! grep -Fq -- "${fribidi-ios}/lib/libfribidi.a" <<<"$build_commands"; then
      echo "error: FriBidi consumer did not link the target archive" >&2
      exit 1
    fi
  '';

  postInstallCheck = ''
    consumer="$out/bin/krita-ios-fribidi-consumer.app/krita-ios-fribidi-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta.description = "iOS link check for Krita's FriBidi imported-target contract";
}

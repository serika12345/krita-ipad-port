{
  libintl-ios,
  mkIOSCMakePackage,
  toolchain,
}:

mkIOSCMakePackage {
  pname = "libintl-consumer-check";
  inherit (libintl-ios) version;
  src = ./libintl-consumer;

  targetDependencies = [ libintl-ios ];

  cmakeFlags = [
    "-DKRITA_IOS_LIBINTL_PREFIX=${libintl-ios}"
    "-DKRITA_IOS_LIBINTL_VERSION=${libintl-ios.version}.0"
  ];

  requiredPaths = [ "bin/krita-ios-libintl-consumer.app/krita-ios-libintl-consumer" ];

  postBuild = ''
    link_commands="$(ninja -t commands krita-ios-libintl-consumer)"
    if ! grep -Fq -- "${libintl-ios}/lib/libintl.a" <<<"$link_commands"; then
      echo "error: libintl consumer did not link the target archive" >&2
      exit 1
    fi
    if ! grep -Eq -- '(-liconv|libiconv\.tbd)' <<<"$link_commands"; then
      echo "error: libintl consumer did not link the iOS SDK iconv implementation" >&2
      exit 1
    fi
    if ! grep -Eq -- '-framework[[:space:]]+CoreFoundation' <<<"$link_commands"; then
      echo "error: libintl consumer did not link CoreFoundation" >&2
      exit 1
    fi
  '';

  postInstallCheck = ''
    consumer="$out/bin/krita-ios-libintl-consumer.app/krita-ios-libintl-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta.description = "iOS link check for GNU libintl and its SDK-provided dependencies";
}

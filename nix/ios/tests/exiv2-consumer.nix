{
  exiv2-ios,
  mkIOSCMakePackage,
  toolchain,
  zlib-ios,
}:

mkIOSCMakePackage {
  pname = "exiv2-consumer-check";
  inherit (exiv2-ios) version;
  src = ./exiv2-consumer;

  # Exiv2 is the only direct dependency. Its propagated target closure must
  # supply zlib to the installed static CMake export.
  targetDependencies = [ exiv2-ios ];

  cmakeFlags = [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE"
    "-DKRITA_IOS_EXIV2_PREFIX=${exiv2-ios}"
    "-DKRITA_IOS_EXIV2_VERSION=${exiv2-ios.version}"
  ];

  requiredPaths = [ "bin/krita-ios-exiv2-consumer.app/krita-ios-exiv2-consumer" ];

  postBuild = ''
    link_commands="$(ninja -t commands krita-ios-exiv2-consumer)"
    for required_path in \
      "${exiv2-ios}/include" \
      "${exiv2-ios}/lib/libexiv2.a" \
      "${zlib-ios}/lib/libz.a"; do
      if ! grep -Fq -- "$required_path" <<<"$link_commands"; then
        echo "error: Exiv2 consumer command omits target path: $required_path" >&2
        exit 1
      fi
    done
    if ! grep -Fq -- '-liconv' <<<"$link_commands"; then
      echo "error: Exiv2 consumer command omits the iOS SDK Iconv link item" >&2
      exit 1
    fi
  '';

  postInstallCheck = ''
    consumer="$out/bin/krita-ios-exiv2-consumer.app/krita-ios-exiv2-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta.description = "iOS public API and transitive zlib link check for Exiv2";
}

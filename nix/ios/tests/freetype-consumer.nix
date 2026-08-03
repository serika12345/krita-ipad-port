{
  freetype-ios,
  libpng-ios,
  mkIOSCMakePackage,
  toolchain,
  zlib-ios,
}:

mkIOSCMakePackage {
  pname = "freetype-consumer-check";
  inherit (freetype-ios) version;
  src = ./freetype-consumer;

  # This direct-only dependency is intentional: the common builder must add
  # FreeType's propagated zlib/libpng closure to CMake's target search roots.
  targetDependencies = [ freetype-ios ];

  cmakeFlags = [ "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE" ];

  requiredPaths = [ "bin/krita-ios-freetype-consumer.app/krita-ios-freetype-consumer" ];

  postBuild = ''
    link_commands="$(ninja -t commands krita-ios-freetype-consumer)"
    for archive in \
      "${freetype-ios}/lib/libfreetype.a" \
      "${libpng-ios}/lib/libpng16.a" \
      "${zlib-ios}/lib/libz.a"; do
      if ! grep -Fq -- "$archive" <<<"$link_commands"; then
        echo "error: FreeType consumer did not link target archive: $archive" >&2
        exit 1
      fi
    done
  '';

  postInstallCheck = ''
    consumer="$out/bin/krita-ios-freetype-consumer.app/krita-ios-freetype-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta.description = "iOS link check for FreeType and its propagated target dependencies";
}

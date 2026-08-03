{
  freetype-ios,
  harfbuzz-ios,
  libpng-ios,
  mkIOSCMakePackage,
  toolchain,
  zlib-ios,
}:

mkIOSCMakePackage {
  pname = "harfbuzz-consumer-check";
  inherit (harfbuzz-ios) version;
  src = ./harfbuzz-consumer;

  # This direct-only dependency is intentional: the common builder must add
  # HarfBuzz's propagated FreeType/zlib/libpng closure to the CMake roots.
  targetDependencies = [ harfbuzz-ios ];

  cmakeFlags = [ "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE" ];

  requiredPaths = [ "bin/krita-ios-harfbuzz-consumer.app/krita-ios-harfbuzz-consumer" ];

  postBuild = ''
    link_commands="$(ninja -t commands krita-ios-harfbuzz-consumer)"
    for archive in \
      "${harfbuzz-ios}/lib/libharfbuzz.a" \
      "${freetype-ios}/lib/libfreetype.a" \
      "${libpng-ios}/lib/libpng16.a" \
      "${zlib-ios}/lib/libz.a"; do
      if ! grep -Fq -- "$archive" <<<"$link_commands"; then
        echo "error: HarfBuzz consumer did not link target archive: $archive" >&2
        exit 1
      fi
    done
    for framework in CoreFoundation CoreText CoreGraphics; do
      if ! grep -Eq -- "-framework[[:space:]]+$framework([[:space:]]|$)" <<<"$link_commands"; then
        echo "error: HarfBuzz consumer did not link Apple framework: $framework" >&2
        exit 1
      fi
    done
  '';

  postInstallCheck = ''
    consumer="$out/bin/krita-ios-harfbuzz-consumer.app/krita-ios-harfbuzz-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta.description = "iOS hb-ft link check for HarfBuzz and its propagated target dependencies";
}

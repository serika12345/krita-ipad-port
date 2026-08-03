{
  expat-ios,
  fontconfig-ios,
  freetype-ios,
  lib,
  libpng-ios,
  mkIOSCMakePackage,
  pkg-config,
  toolchain,
  zlib-ios,
}:

mkIOSCMakePackage {
  pname = "fontconfig-consumer-check";
  inherit (fontconfig-ios) version;
  src = ./fontconfig-consumer;

  # This direct-only dependency is intentional: the common builder must add
  # Fontconfig's propagated Expat/FreeType/zlib/libpng closure to CMake's
  # target-only search roots.
  targetDependencies = [ fontconfig-ios ];

  PKG_CONFIG_PATH = "";
  PKG_CONFIG_LIBDIR = lib.concatStringsSep ":" [
    "${fontconfig-ios}/lib/pkgconfig"
    "${expat-ios}/lib/pkgconfig"
    "${freetype-ios}/lib/pkgconfig"
    "${libpng-ios}/lib/pkgconfig"
    "${zlib-ios}/lib/pkgconfig"
  ];
  PKG_CONFIG_SYSROOT_DIR = "";

  cmakeFlags = [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE"
    "-DPKG_CONFIG_EXECUTABLE=${pkg-config}/bin/pkg-config"
    "-DKRITA_IOS_FONTCONFIG_VERSION=${fontconfig-ios.version}"
  ];

  requiredPaths = [ "bin/krita-ios-fontconfig-consumer.app/krita-ios-fontconfig-consumer" ];

  postBuild = ''
    link_commands="$(ninja -t commands krita-ios-fontconfig-consumer)"
    for archive in \
      "${fontconfig-ios}/lib/libfontconfig.a" \
      "${freetype-ios}/lib/libfreetype.a" \
      "${expat-ios}/lib/libexpat.a" \
      "${libpng-ios}/lib/libpng16.a" \
      "${zlib-ios}/lib/libz.a"; do
      if ! grep -Fq -- "$archive" <<<"$link_commands"; then
        echo "error: Fontconfig consumer did not link target archive: $archive" >&2
        exit 1
      fi
    done
  '';

  postInstallCheck = ''
    consumer="$out/bin/krita-ios-fontconfig-consumer.app/krita-ios-fontconfig-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta.description = "iOS link check for Fontconfig and its propagated target dependencies";
}

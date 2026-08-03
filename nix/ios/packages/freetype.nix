{
  lib,
  freetype,
  mkIOSCMakePackage,
  packageSpec,
  zlib-ios,
  libpng-ios,
}:

assert lib.assertMsg (
  freetype.version == packageSpec.version
) "FreeType source version ${freetype.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [
    "zlib"
    "libpng"
  ]
) "FreeType iOS manifest target dependencies must be exactly [ zlib libpng ]";

mkIOSCMakePackage {
  pname = "freetype-ios";
  inherit (packageSpec) version;
  src = freetype.src;

  targetDependencies = [
    zlib-ios
    libpng-ios
  ];

  cmakeFlags = [ "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE" ] ++ packageSpec.cmake_args;

  requiredPaths = [
    "include/freetype2/ft2build.h"
    "include/freetype2/freetype/freetype.h"
    "include/freetype2/freetype/config/ftoption.h"
    "lib/libfreetype.a"
    "lib/cmake/freetype/freetype-config.cmake"
    "lib/cmake/freetype/freetype-config-release.cmake"
    "lib/cmake/freetype/freetype-config-version.cmake"
    "lib/pkgconfig/freetype2.pc"
    "nix-support/propagated-build-inputs"
  ];

  staticArchives = [ "lib/libfreetype.a" ];

  postInstall = ''
    config="$out/lib/cmake/freetype/freetype-config.cmake"
    {
      echo 'include(CMakeFindDependencyMacro)'
      echo 'find_dependency(ZLIB CONFIG)'
      echo 'find_dependency(PNG CONFIG)'
      echo
      cat "$config"
    } > "$config.with-dependencies"
    mv "$config.with-dependencies" "$config"
  '';

  postInstallCheck = ''
    options="$out/include/freetype2/freetype/config/ftoption.h"
    grep -Eq '^#define[[:space:]]+FT_CONFIG_OPTION_SYSTEM_ZLIB([[:space:]]|$)' "$options"
    grep -Eq '^#define[[:space:]]+FT_CONFIG_OPTION_USE_PNG([[:space:]]|$)' "$options"
    if grep -Eq '^#define[[:space:]]+FT_CONFIG_OPTION_USE_(BZIP2|HARFBUZZ|BROTLI)([[:space:]]|$)' "$options"; then
      echo "error: FreeType enabled an unsupported optional dependency" >&2
      exit 1
    fi

    config="$out/lib/cmake/freetype/freetype-config.cmake"
    grep -Fxq 'find_dependency(ZLIB CONFIG)' "$config"
    grep -Fxq 'find_dependency(PNG CONFIG)' "$config"
  '';

  meta = {
    description = "Static FreeType cross-compiled for the pinned Krita iPadOS target";
    inherit (freetype.meta) license;
  };
}

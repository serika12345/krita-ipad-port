{
  lib,
  libunibreak,
  mkIOSCMakePackage,
  packageSpec,
  pkg-config,
  toolchain,
}:

assert lib.assertMsg (libunibreak.version == packageSpec.version)
  "libunibreak source version ${libunibreak.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "libunibreak iOS manifest unexpectedly gained target dependencies";
assert lib.assertMsg (
  packageSpec.cmake_source_dir == "packaging/ios/deps/libunibreak"
) "libunibreak iOS manifest must use the repository CMake wrapper";
assert lib.assertMsg (
  packageSpec.cmake_args == [ "-DLIBUNIBREAK_SOURCE_DIR={source_dir}" ]
) "libunibreak iOS manifest source argument contract changed";

mkIOSCMakePackage {
  pname = "libunibreak-ios";
  inherit (packageSpec) version;

  # The repository wrapper defines the minimal target build. Keep the pinned
  # upstream tree as a separate Nix input so changes to either side invalidate
  # the derivation independently.
  src = ../../../packaging/ios/deps/libunibreak;

  cmakeFlags = [
    "-DLIBUNIBREAK_SOURCE_DIR=${libunibreak.src}"
  ];

  requiredPaths = [
    "include/eastasianwidthdef.h"
    "include/graphemebreak.h"
    "include/linebreak.h"
    "include/linebreakdef.h"
    "include/unibreakbase.h"
    "include/unibreakdef.h"
    "include/wordbreak.h"
    "lib/libunibreak.a"
    "lib/pkgconfig/libunibreak.pc"
  ];

  staticArchives = [ "lib/libunibreak.a" ];

  postInstallCheck = ''
    if find "$out/lib" -maxdepth 1 -name 'libunibreak*.dylib' -print -quit | grep -q .; then
      echo "error: the static-only libunibreak output contains a dynamic library" >&2
      exit 1
    fi

    header="$out/include/unibreakbase.h"
    grep -Eq '^#define[[:space:]]+UNIBREAK_VERSION[[:space:]]+0x0700([[:space:]]|$)' "$header"

    pc="$out/lib/pkgconfig/libunibreak.pc"
    if grep -Fq '${libunibreak.src}' "$pc"; then
      echo "error: libunibreak.pc embeds the upstream source path" >&2
      exit 1
    fi

    pkg_config=${lib.getExe pkg-config}
    pc_version="$(
      PKG_CONFIG_PATH= \
      PKG_CONFIG_LIBDIR="$out/lib/pkgconfig" \
      PKG_CONFIG_SYSROOT_DIR= \
        "$pkg_config" --modversion libunibreak
    )"
    if test "$pc_version" != "${packageSpec.version}"; then
      echo "error: libunibreak.pc reports version '$pc_version'; expected ${packageSpec.version}" >&2
      exit 1
    fi

    pc_cflags="$(
      PKG_CONFIG_PATH= \
      PKG_CONFIG_LIBDIR="$out/lib/pkgconfig" \
      PKG_CONFIG_SYSROOT_DIR= \
        "$pkg_config" --static --cflags libunibreak
    )"
    if ! grep -Fq -- "-I$out/include" <<<"$pc_cflags"; then
      echo "error: libunibreak.pc cflags omit the target include directory: $pc_cflags" >&2
      exit 1
    fi

    pc_libs="$(
      PKG_CONFIG_PATH= \
      PKG_CONFIG_LIBDIR="$out/lib/pkgconfig" \
      PKG_CONFIG_SYSROOT_DIR= \
        "$pkg_config" --static --libs libunibreak
    )"
    for expected_flag in "-L$out/lib" "-lunibreak"; do
      if ! grep -Fq -- "$expected_flag" <<<"$pc_libs"; then
        echo "error: libunibreak.pc static libs omit $expected_flag: $pc_libs" >&2
        exit 1
      fi
    done
  '';

  meta = {
    description = "Static libunibreak cross-compiled for the pinned Krita iPadOS target";
    inherit (libunibreak.meta) license;
  };
}

{
  lib,
  mkIOSCMakePackage,
  packageSpec,
  pkg-config,
  toolchain,
  xsimd,
}:

assert lib.assertMsg (
  xsimd.version == packageSpec.version
) "xsimd source version ${xsimd.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "xsimd iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "xsimd-ios";
  inherit (packageSpec) version;
  src = xsimd.src;

  cmakeFlags = packageSpec.cmake_args;

  requiredPaths = [
    "include/xsimd/xsimd.hpp"
    "include/xsimd/config/xsimd_config.hpp"
    "share/cmake/xsimd/xsimdConfig.cmake"
    "share/cmake/xsimd/xsimdConfigVersion.cmake"
    "share/cmake/xsimd/xsimdTargets.cmake"
    "share/pkgconfig/xsimd.pc"
  ];

  postInstallCheck = ''
    if test -d "$out/bin" || find "$out" -type f \( -name '*.a' -o -name '*.dylib' \) -print -quit | grep -q .; then
      echo "error: the header-only xsimd output contains a tool or library" >&2
      exit 1
    fi

    targets="$out/share/cmake/xsimd/xsimdTargets.cmake"
    grep -Fq 'add_library(xsimd INTERFACE IMPORTED)' "$targets"
    grep -Fq 'INTERFACE_INCLUDE_DIRECTORIES "''${_IMPORT_PREFIX}/include"' "$targets"

    pkg_config=${lib.getExe pkg-config}
    pc_version="$(
      PKG_CONFIG_PATH= \
      PKG_CONFIG_LIBDIR="$out/share/pkgconfig" \
      PKG_CONFIG_SYSROOT_DIR= \
        "$pkg_config" --modversion xsimd
    )"
    if test "$pc_version" != "${packageSpec.version}"; then
      echo "error: xsimd.pc reports version '$pc_version'; expected ${packageSpec.version}" >&2
      exit 1
    fi

    pc_cflags="$(
      PKG_CONFIG_PATH= \
      PKG_CONFIG_LIBDIR="$out/share/pkgconfig" \
      PKG_CONFIG_SYSROOT_DIR= \
        "$pkg_config" --cflags xsimd
    )"
    if ! grep -Fq -- "-I$out/include" <<<"$pc_cflags"; then
      echo "error: xsimd.pc cflags omit the target include directory: $pc_cflags" >&2
      exit 1
    fi

    pc_libs="$(
      PKG_CONFIG_PATH= \
      PKG_CONFIG_LIBDIR="$out/share/pkgconfig" \
      PKG_CONFIG_SYSROOT_DIR= \
        "$pkg_config" --libs xsimd
    )"
    if test -n "$pc_libs"; then
      echo "error: header-only xsimd.pc unexpectedly reports link flags: $pc_libs" >&2
      exit 1
    fi
  '';

  meta = {
    description = "xsimd headers configured for the pinned Krita iPadOS target";
    inherit (xsimd.meta) license;
  };
}

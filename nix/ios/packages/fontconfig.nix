{
  expat-ios,
  fontconfig,
  freetype-ios,
  gperf,
  lib,
  libpng-ios,
  mkIOSAutotoolsPackage,
  packageSpec,
  pkg-config,
  python3,
  toolchain,
  zlib-ios,
}:

assert lib.assertMsg (fontconfig.version == packageSpec.version)
  "Fontconfig source version ${fontconfig.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.build_system == "autotools"
) "Fontconfig iOS manifest build system must be Autotools";
assert lib.assertMsg (
  packageSpec.dependencies == [
    "expat"
    "freetype"
  ]
) "Fontconfig iOS manifest target dependencies must be exactly [ expat freetype ]";
assert lib.assertMsg (
  packageSpec.configure_cache == {
    ac_cv_func_snprintf = "yes";
    ac_cv_func_vsnprintf = "yes";
    ac_cv_va_copy = "C99";
    fc_cv_c99_vsnprintf = "yes";
  }
) "Fontconfig iOS configure cache must describe the validated iOS C99 runtime";

mkIOSAutotoolsPackage {
  pname = "fontconfig-ios";
  inherit (packageSpec) version;
  src = fontconfig.src;

  patches = [ ../patches/fontconfig-autotools-fixes.patch ];

  targetDependencies = [
    expat-ios
    freetype-ios
  ];

  nativeBuildInputs = [
    gperf
    python3
  ];

  configureCache = packageSpec.configure_cache;
  configureFlags = packageSpec.configure_args;
  makeTargets = packageSpec.make_targets;
  installTargets = packageSpec.make_install_targets;

  requiredPaths = [
    "include/fontconfig/fontconfig.h"
    "include/fontconfig/fcfreetype.h"
    "include/fontconfig/fcprivate.h"
    "lib/libfontconfig.a"
    "lib/pkgconfig/fontconfig.pc"
    "nix-support/propagated-build-inputs"
  ];

  staticArchives = [ "lib/libfontconfig.a" ];

  postInstall = ''
    # Libtool archives are neither needed by CMake/pkg-config consumers nor
    # desirable in a relocatable Nix target package.
    rm -f "$out/lib/libfontconfig.la"
  '';

  postInstallCheck = ''
    if test -d "$out/bin" || find "$out/lib" -maxdepth 1 -name 'libfontconfig*.dylib' -print -quit | grep -q .; then
      echo "error: the target-only Fontconfig output contains tools or a dynamic library" >&2
      exit 1
    fi

    pc_version="$(
      PKG_CONFIG_PATH= \
      PKG_CONFIG_LIBDIR="${
        lib.concatStringsSep ":" [
          "$out/lib/pkgconfig"
          "${expat-ios}/lib/pkgconfig"
          "${freetype-ios}/lib/pkgconfig"
          "${libpng-ios}/lib/pkgconfig"
          "${zlib-ios}/lib/pkgconfig"
        ]
      }" \
      PKG_CONFIG_SYSROOT_DIR= \
        ${lib.getExe pkg-config} --modversion fontconfig
    )"
    if test "$pc_version" != "${packageSpec.version}"; then
      echo "error: fontconfig.pc reports version '$pc_version'; expected ${packageSpec.version}" >&2
      exit 1
    fi

    pc="$out/lib/pkgconfig/fontconfig.pc"
    grep -Eq '^Requires:[[:space:]]+freetype2[[:space:]]+>=[[:space:]]+21\.0\.15([[:space:]]|$)' "$pc"
    grep -Eq '^Requires\.private:[[:space:]]+expat([[:space:]]|$)' "$pc"
    for dependency in \
      "${expat-ios}" \
      "${freetype-ios}" \
      "${libpng-ios}" \
      "${zlib-ios}"; do
      if grep -Fq "$dependency" "$pc"; then
        echo "error: fontconfig.pc embeds a dependency store path: $dependency" >&2
        exit 1
      fi
    done

    pc_libs="$(
      PKG_CONFIG_PATH= \
      PKG_CONFIG_LIBDIR="${
        lib.concatStringsSep ":" [
          "$out/lib/pkgconfig"
          "${expat-ios}/lib/pkgconfig"
          "${freetype-ios}/lib/pkgconfig"
          "${libpng-ios}/lib/pkgconfig"
          "${zlib-ios}/lib/pkgconfig"
        ]
      }" \
      PKG_CONFIG_SYSROOT_DIR= \
        ${lib.getExe pkg-config} --static --libs fontconfig
    )"
    for expected_flag in \
      "-L$out/lib" \
      "-lfontconfig" \
      "-L${freetype-ios}/lib" \
      "-lfreetype" \
      "-L${expat-ios}/lib" \
      "-lexpat" \
      "-L${libpng-ios}/lib" \
      "-lpng16" \
      "-L${zlib-ios}/lib" \
      "-lz" \
      "-lm"; do
      if ! grep -F -- "$expected_flag" <<<"$pc_libs" >/dev/null; then
        echo "error: fontconfig.pc static libs omit $expected_flag: $pc_libs" >&2
        exit 1
      fi
    done

    archive_members="$(${toolchain.ar} -t "$out/lib/libfontconfig.a")"
    if ! grep -Fxq 'fcconffile.o' <<<"$archive_members"; then
      echo "error: libfontconfig.a omits fcconffile.o" >&2
      exit 1
    fi
  '';

  meta = {
    description = "Static Fontconfig cross-compiled for the pinned Krita iPadOS target";
    inherit (fontconfig.meta) license;
  };
}

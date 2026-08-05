{
  gettext,
  lib,
  mkIOSAutotoolsPackage,
  packageSpec,
  perl,
  toolchain,
}:

assert lib.assertMsg (gettext.version == packageSpec.version)
  "gettext source version ${gettext.version} does not match libintl iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.build_system == "autotools"
) "libintl iOS manifest build system must be Autotools";
assert lib.assertMsg (
  packageSpec.source_subdir == "gettext-runtime"
) "libintl iOS manifest must retain the gettext-runtime source boundary";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "libintl must not model SDK iconv or libSystem as Nix target dependencies";
assert lib.assertMsg (
  packageSpec.configure_args == [
    "--disable-java"
    "--disable-csharp"
    "--disable-openmp"
    "--without-emacs"
    "--without-libiconv-prefix"
    "--without-libncurses-prefix"
  ]
) "libintl iOS configure feature contract changed";
assert lib.assertMsg (
  packageSpec.configure_cache == {
    am_cv_func_iconv_works = "yes";
    gl_cv_func_wcwidth_works = "yes";
  }
) "libintl iOS configure cache must retain the validated Darwin cross answers";
assert lib.assertMsg (
  packageSpec.make_targets == [
    [
      "-C"
      "intl"
      "all"
    ]
  ]
) "libintl iOS build must remain limited to the runtime library";
assert lib.assertMsg (
  packageSpec.make_install_targets == [
    [
      "-C"
      "intl"
      "install"
    ]
  ]
) "libintl iOS install must remain limited to the runtime library";

mkIOSAutotoolsPackage {
  pname = "libintl-ios";
  inherit (packageSpec) version;
  src = gettext.src;

  nativeBuildInputs = [
    gettext
    perl
  ];

  preConfigure = ''
    cd ${lib.escapeShellArg packageSpec.source_subdir}
  '';

  configureCache = packageSpec.configure_cache;
  configureFlags = packageSpec.configure_args;
  makeTargets = packageSpec.make_targets;
  installTargets = packageSpec.make_install_targets;

  requiredPaths = [
    "include/libintl.h"
    "lib/libintl.a"
    "lib/pkgconfig/intl.pc"
  ];

  staticArchives = [ "lib/libintl.a" ];

  postInstall = ''
    rm -f "$out/lib/libintl.la"
    install -Dm644 ${../pkgconfig/intl.pc} "$out/lib/pkgconfig/intl.pc"
  '';

  postInstallCheck = ''
    if test -d "$out/bin"; then
      echo "error: target-only libintl output contains command-line tools" >&2
      exit 1
    fi
    unexpected_library="$(find "$out/lib" -maxdepth 1 -type f \( \
      -name '*.a' ! -name 'libintl.a' -o \
      -name '*.la' -o -name '*.dylib' -o -name '*.so' -o -name '*.so.*' \
    \) -print -quit)"
    if test -n "$unexpected_library"; then
      echo "error: target-only libintl output contains an unexpected library: $unexpected_library" >&2
      exit 1
    fi

    export PKG_CONFIG_DIR=
    export PKG_CONFIG_PATH=
    export PKG_CONFIG_LIBDIR="$out/lib/pkgconfig"
    export PKG_CONFIG_SYSROOT_DIR=
    if test "$(pkg-config --modversion intl)" != "1.0"; then
      echo "error: libintl pkg-config metadata reports an unexpected version" >&2
      exit 1
    fi
    pkg_config_libs="$(pkg-config --static --libs intl)"
    if ! grep -Fq -- "-L$out/lib" <<<"$pkg_config_libs" \
      || ! grep -Eq -- '(^|[[:space:]])-lintl([[:space:]]|$)' <<<"$pkg_config_libs" \
      || ! grep -Eq -- '(^|[[:space:]])-liconv([[:space:]]|$)' <<<"$pkg_config_libs" \
      || ! grep -Eq -- '(^|[[:space:]])CoreFoundation([[:space:]]|$)' <<<"$pkg_config_libs"; then
      echo "error: libintl pkg-config metadata does not provide its complete target link interface" >&2
      exit 1
    fi

    header="$out/include/libintl.h"
    grep -Eq '^#define[[:space:]]+LIBINTL_VERSION[[:space:]]+0x010000([[:space:]]|$)' "$header"

    archive_members="$(${toolchain.ar} -t "$out/lib/libintl.a")"
    for member in bindtextdom.o dcigettext.o loadmsgcat.o ngettext.o; do
      if ! grep -Fxq "$member" <<<"$archive_members"; then
        echo "error: libintl.a omits required implementation object $member" >&2
        exit 1
      fi
    done

    exported_symbols="$(${toolchain.toolchainDir}/nm -gU "$out/lib/libintl.a")"
    for symbol in \
      _libintl_bindtextdomain \
      _libintl_dcgettext \
      _libintl_gettext \
      _libintl_ngettext \
      _libintl_textdomain; do
      if ! grep -Eq "[[:space:]]T[[:space:]]+$symbol$" <<<"$exported_symbols"; then
        echo "error: libintl.a omits public symbol $symbol" >&2
        exit 1
      fi
    done
  '';

  meta = {
    description = "Minimal static GNU libintl runtime for Krita on iPadOS";
    license = lib.licenses.lgpl21Plus;
  };
}

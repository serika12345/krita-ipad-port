{
  autoreconfHook,
  gettext,
  glib-ios,
  intltool,
  json-c-ios,
  lib,
  libmypaint,
  libtool,
  mkIOSAutotoolsPackage,
  packageSpec,
  pkg-config,
  python3,
}:

assert lib.assertMsg (libmypaint.version == packageSpec.version)
  "libmypaint source version ${libmypaint.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.build_system == "autotools"
) "libmypaint iOS manifest build system must be Autotools";
assert lib.assertMsg (
  packageSpec.dependencies == [
    "glib"
    "json-c"
  ]
) "libmypaint iOS manifest target dependencies changed";

mkIOSAutotoolsPackage {
  pname = "libmypaint-ios";
  inherit (packageSpec) version;
  src = libmypaint.src;
  patches = [ ../patches/libmypaint-regular-gettext.patch ];

  targetDependencies = [
    glib-ios
    json-c-ios
  ];
  configureFlags = packageSpec.configure_args;
  nativeBuildInputs = [
    autoreconfHook
    gettext
    intltool
    libtool
    pkg-config
    python3
  ];

  preConfigure = ''
    export AUTOMAKE=automake
    export ACLOCAL=aclocal
    ./autogen.sh
  '';

  requiredPaths = [
    "include/libmypaint/mypaint-brush.h"
    "lib/libmypaint.a"
    "lib/pkgconfig/libmypaint.pc"
  ];
  staticArchives = [ "lib/libmypaint.a" ];

  postInstall = ''
    rm -f "$out/lib/libmypaint.la"
    rm -rf "$out/share"
  '';

  postInstallCheck = ''
    consumer_flags="$(PKG_CONFIG_LIBDIR="$out/lib/pkgconfig:$PKG_CONFIG_LIBDIR" \
      $PKG_CONFIG --cflags --libs libmypaint)"
    if ! grep -Fq -- '-ljson-c' <<<"$consumer_flags"; then
      echo "error: libmypaint pkg-config metadata omits its static json-c dependency" >&2
      exit 1
    fi

    cat > consumer.c <<'EOF'
    #include <mypaint-brush.h>

    int main(void)
    {
        MyPaintBrush *brush = mypaint_brush_new();
        const int parsed = mypaint_brush_from_string(brush, "{}");
        mypaint_brush_unref(brush);
        return parsed;
    }
    EOF
    $CC $CFLAGS consumer.c $consumer_flags -o libmypaint-consumer
  '';

  meta = {
    description = "Static libmypaint cross-compiled for the Krita iPadOS target";
    inherit (libmypaint.meta) license;
  };
}

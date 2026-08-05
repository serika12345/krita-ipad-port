{
  glib,
  lib,
  libffi-ios,
  libintl-ios,
  mkIOSMesonPackage,
  packageSpec,
  pcre2-ios,
  python3,
  zlib-ios,
}:

assert lib.assertMsg (
  glib.version == packageSpec.version
) "GLib source version ${glib.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.build_system == "meson"
) "GLib iOS manifest build system must be Meson";
assert lib.assertMsg (
  packageSpec.dependencies == [
    "zlib"
    "libffi"
    "pcre2"
    "libintl"
  ]
) "GLib iOS manifest target dependencies changed";

mkIOSMesonPackage {
  pname = "glib-ios";
  inherit (packageSpec) version;
  src = glib.src;

  targetDependencies = [
    zlib-ios
    libffi-ios
    pcre2-ios
    libintl-ios
  ];
  mesonFlags = packageSpec.meson_args;
  nativeBuildInputs = [ python3 ];
  extraTargetLinkArgs = [
    "-liconv"
    "-framework"
    "CoreFoundation"
  ];
  preConfigure = ''
    patchShebangs tools
  '';

  requiredPaths = [
    "include/glib-2.0/glib.h"
    "include/glib-2.0/gobject/gobject.h"
    "lib/libglib-2.0.a"
    "lib/libgobject-2.0.a"
    "lib/libgmodule-2.0.a"
    "lib/pkgconfig/glib-2.0.pc"
    "lib/pkgconfig/gobject-2.0.pc"
  ];
  staticArchives = [
    "lib/libglib-2.0.a"
    "lib/libgobject-2.0.a"
    "lib/libgmodule-2.0.a"
  ];

  postInstall = ''
    rm -rf "$out/bin" "$out/share/bash-completion" "$out/share/man"
  '';

  meta = {
    description = "Minimal static GLib runtime cross-compiled for the Krita iPadOS target";
    inherit (glib.meta) license;
  };
}

{
  autoreconfHook,
  lcms2-ios,
  lib,
  libraw,
  libtool,
  mkIOSAutotoolsPackage,
  packageSpec,
  pkg-config,
}:

assert lib.assertMsg (
  libraw.version == packageSpec.version
) "LibRaw source version ${libraw.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.build_system == "autotools"
) "LibRaw iOS manifest build system must be Autotools";
assert lib.assertMsg (
  packageSpec.dependencies == [ "lcms2" ]
) "LibRaw iOS manifest target dependencies changed";

mkIOSAutotoolsPackage {
  pname = "libraw-ios";
  inherit (packageSpec) version;
  src = libraw.src;

  targetDependencies = [ lcms2-ios ];
  configureFlags = packageSpec.configure_args;
  nativeBuildInputs = [
    autoreconfHook
    libtool
    pkg-config
  ];
  preConfigure = ''
    autoreconf -fiv
  '';

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  staticArchives = packageSpec.artifacts;

  postInstall = ''
    rm -f "$out/lib/libraw.la" "$out/lib/libraw_r.la"
  '';

  meta = {
    description = "Static LibRaw cross-compiled for the Krita iPadOS target";
    inherit (libraw.meta) license;
  };
}

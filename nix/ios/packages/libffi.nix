{
  lib,
  libffiReal,
  mkIOSAutotoolsPackage,
  packageSpec,
  toolchain,
}:

assert lib.assertMsg (
  libffiReal.version == packageSpec.version
) "libffi source version ${libffiReal.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.build_system == "autotools"
) "libffi iOS manifest build system must be Autotools";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "libffi iOS manifest unexpectedly gained target dependencies";
assert lib.assertMsg (
  packageSpec.configure_args == [ "--with-gcc-arch=generic" ]
) "libffi iOS configure feature contract changed";

mkIOSAutotoolsPackage {
  pname = "libffi-ios";
  inherit (packageSpec) version;
  src = libffiReal.src;

  configureFlags = packageSpec.configure_args;

  requiredPaths = [
    "include/ffi.h"
    "lib/libffi.a"
    "lib/pkgconfig/libffi.pc"
  ];
  staticArchives = [ "lib/libffi.a" ];

  postInstall = ''
    rm -f "$out/lib/libffi.la"
  '';

  postInstallCheck = ''
    exported_symbols="$(${toolchain.nm} -gU "$out/lib/libffi.a")"
    for symbol in \
      _ffi_call \
      _ffi_prep_cif_machdep \
      _ffi_prep_cif_machdep_var \
      _ffi_prep_closure_loc; do
      if ! grep -Eq "[[:space:]]T[[:space:]]+$symbol$" <<<"$exported_symbols"; then
        echo "error: libffi.a omits required arm64 implementation symbol $symbol" >&2
        exit 1
      fi
    done
  '';

  meta = {
    description = "Static libffi cross-compiled for the Krita iPadOS target";
    inherit (libffiReal.meta) license;
  };
}

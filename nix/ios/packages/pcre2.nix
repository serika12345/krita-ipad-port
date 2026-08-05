{
  lib,
  mkIOSAutotoolsPackage,
  packageSpec,
  pcre2,
}:

assert lib.assertMsg (
  pcre2.version == packageSpec.version
) "PCRE2 source version ${pcre2.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.build_system == "autotools"
) "PCRE2 iOS manifest build system must be Autotools";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "PCRE2 iOS manifest unexpectedly gained target dependencies";

mkIOSAutotoolsPackage {
  pname = "pcre2-ios";
  inherit (packageSpec) version;
  src = pcre2.src;

  configureFlags = packageSpec.configure_args;

  requiredPaths = [
    "include/pcre2.h"
    "lib/libpcre2-8.a"
    "lib/pkgconfig/libpcre2-8.pc"
  ];
  staticArchives = [ "lib/libpcre2-8.a" ];

  postInstall = ''
    rm -f "$out/lib/libpcre2-8.la"
  '';

  meta = {
    description = "Static PCRE2 runtime cross-compiled for the Krita iPadOS target";
    inherit (pcre2.meta) license;
  };
}

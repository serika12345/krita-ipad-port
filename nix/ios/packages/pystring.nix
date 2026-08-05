{
  lib,
  mkIOSMesonPackage,
  packageSpec,
  pystring,
}:

assert lib.assertMsg (
  pystring.version == packageSpec.version
) "pystring source version ${pystring.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.build_system == "meson"
) "pystring iOS manifest build system must be Meson";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "pystring iOS manifest unexpectedly gained target dependencies";

mkIOSMesonPackage {
  pname = "pystring-ios";
  inherit (packageSpec) version;
  src = pystring.src;
  mesonFlags = packageSpec.meson_args;

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  staticArchives = packageSpec.artifacts;

  meta = {
    description = "Static pystring cross-compiled for the Krita iPadOS target";
    inherit (pystring.meta) license;
  };
}

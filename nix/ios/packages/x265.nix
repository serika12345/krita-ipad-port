{
  lib,
  mkIOSCMakePackage,
  packageSpec,
  x265,
}:

assert lib.assertMsg (
  x265.version == packageSpec.version
) "x265 source version ${x265.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "x265 iOS manifest unexpectedly gained target dependencies";

mkIOSCMakePackage {
  pname = "x265-ios";
  inherit (packageSpec) version;
  src = x265.src;
  sourceRoot = "x265_${packageSpec.version}/${packageSpec.source_subdir}";
  patches = x265.patches or [ ];
  cmakeFlags = packageSpec.cmake_args;

  postPatch = ''
    substituteInPlace cmake/Version.cmake \
      --replace-fail "unknown" "${packageSpec.version}" \
      --replace-fail "0.0" "${packageSpec.version}"
  '';

  requiredPaths = packageSpec.required_paths ++ packageSpec.artifacts;
  staticArchives = packageSpec.artifacts;

  meta = {
    description = "Static x265 HEVC encoder cross-compiled for the Krita iPadOS target";
    inherit (x265.meta) license;
  };
}

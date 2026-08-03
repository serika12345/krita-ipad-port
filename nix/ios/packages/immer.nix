{
  immer,
  lib,
  mkCMakePackageVersion,
  mkIOSHeaderPackage,
  packageSpec,
}:

let
  immerConfig = ''
    get_filename_component(_IMMER_PREFIX "''${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
    if(NOT TARGET immer)
      add_library(immer INTERFACE IMPORTED)
      set_target_properties(immer PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "''${_IMMER_PREFIX}/include"
        INTERFACE_COMPILE_FEATURES cxx_std_14)
    endif()
    set(Immer_VERSION "${packageSpec.version}")
    unset(_IMMER_PREFIX)
  '';
  immerConfigVersion = mkCMakePackageVersion {
    compatibility = "SameMajorVersion";
    version = packageSpec.version;
  };
in
assert lib.assertMsg (
  immer.version == packageSpec.version
) "Immer source version ${immer.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "Immer iOS manifest unexpectedly gained target dependencies";
assert lib.assertMsg (
  packageSpec.cmake_args == [
    "-Dimmer_BUILD_TESTS=OFF"
    "-Dimmer_BUILD_EXAMPLES=OFF"
    "-Dimmer_BUILD_DOCS=OFF"
    "-Dimmer_BUILD_EXTRAS=OFF"
  ]
) "Immer iOS manifest feature contract changed";

mkIOSHeaderPackage {
  pname = "immer-ios";
  inherit (packageSpec) version;
  src = immer.src;

  headerTrees = [
    {
      source = "immer";
      destination = "include/immer";
    }
  ];

  generatedFiles = {
    "lib/cmake/Immer/ImmerConfig.cmake" = immerConfig;
    "lib/cmake/Immer/ImmerConfigVersion.cmake" = immerConfigVersion;
  };

  requiredPaths = [
    "include/immer/vector.hpp"
    "include/immer/vector_transient.hpp"
    "lib/cmake/Immer/ImmerConfig.cmake"
    "lib/cmake/Immer/ImmerConfigVersion.cmake"
  ];

  postInstallCheck = ''
    config="$out/lib/cmake/Immer/ImmerConfig.cmake"
    version_config="$out/lib/cmake/Immer/ImmerConfigVersion.cmake"
    grep -Fq 'add_library(immer INTERFACE IMPORTED)' "$config"
    grep -Fq 'INTERFACE_INCLUDE_DIRECTORIES "''${_IMMER_PREFIX}/include"' "$config"
    grep -Fq 'INTERFACE_COMPILE_FEATURES cxx_std_14' "$config"
    grep -Fxq 'unset(_IMMER_PREFIX)' "$config"
    grep -Fxq 'set(PACKAGE_VERSION "${packageSpec.version}")' "$version_config"
    grep -Fq 'if(PACKAGE_FIND_VERSION_RANGE)' "$version_config"
    grep -Fq 'PACKAGE_FIND_VERSION_RANGE_MAX STREQUAL "EXCLUDE"' "$version_config"

    if grep -Fq '${immer.src}' "$config" "$version_config"; then
      echo "error: Immer CMake metadata embeds the source path" >&2
      exit 1
    fi
  '';

  meta = {
    description = "Pure Immer immutable data structure headers for Krita";
    inherit (immer.meta) license;
  };
}

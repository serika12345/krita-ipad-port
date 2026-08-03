{
  lib,
  mkCMakePackageVersion,
  mkIOSHeaderPackage,
  packageSpec,
  zug,
}:

let
  zugConfig = ''
    get_filename_component(_ZUG_PREFIX "''${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
    if(NOT TARGET zug)
      add_library(zug INTERFACE IMPORTED)
      set_target_properties(zug PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "''${_ZUG_PREFIX}/include"
        INTERFACE_COMPILE_FEATURES cxx_std_14)
    endif()
    set(Zug_VERSION "${packageSpec.version}")
    unset(_ZUG_PREFIX)
  '';
  zugConfigVersion = mkCMakePackageVersion {
    compatibility = "SameMajorVersion";
    version = packageSpec.version;
  };
in
assert lib.assertMsg (
  zug.version == packageSpec.version
) "Zug source version ${zug.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [ ]
) "Zug iOS manifest unexpectedly gained target dependencies";
assert lib.assertMsg (
  packageSpec.cmake_args == [
    "-Dzug_BUILD_TESTS=OFF"
    "-Dzug_BUILD_EXAMPLES=OFF"
    "-Dzug_BUILD_DOCS=OFF"
  ]
) "Zug iOS manifest feature contract changed";

mkIOSHeaderPackage {
  pname = "zug-ios";
  inherit (packageSpec) version;
  src = zug.src;

  headerTrees = [
    {
      source = "zug";
      destination = "include/zug";
    }
  ];

  generatedFiles = {
    "lib/cmake/Zug/ZugConfig.cmake" = zugConfig;
    "lib/cmake/Zug/ZugConfigVersion.cmake" = zugConfigVersion;
  };

  requiredPaths = [
    "include/zug/transduce.hpp"
    "include/zug/transducer/filter.hpp"
    "include/zug/transducer/map.hpp"
    "lib/cmake/Zug/ZugConfig.cmake"
    "lib/cmake/Zug/ZugConfigVersion.cmake"
  ];

  postInstallCheck = ''
    config="$out/lib/cmake/Zug/ZugConfig.cmake"
    version_config="$out/lib/cmake/Zug/ZugConfigVersion.cmake"
    grep -Fq 'add_library(zug INTERFACE IMPORTED)' "$config"
    grep -Fq 'INTERFACE_INCLUDE_DIRECTORIES "''${_ZUG_PREFIX}/include"' "$config"
    grep -Fq 'INTERFACE_COMPILE_FEATURES cxx_std_14' "$config"
    grep -Fxq 'unset(_ZUG_PREFIX)' "$config"
    grep -Fxq 'set(PACKAGE_VERSION "${packageSpec.version}")' "$version_config"
    grep -Fq 'if(PACKAGE_FIND_VERSION_RANGE)' "$version_config"
    grep -Fq 'PACKAGE_FIND_VERSION_RANGE_MAX STREQUAL "EXCLUDE"' "$version_config"

    if grep -Fq '${zug.src}' "$config" "$version_config"; then
      echo "error: Zug CMake metadata embeds the source path" >&2
      exit 1
    fi
  '';

  meta = {
    description = "Pure Zug transducer headers for Krita";
    inherit (zug.meta) license;
  };
}

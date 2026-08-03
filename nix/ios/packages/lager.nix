{
  boost-ios,
  lager,
  lib,
  mkCMakePackageVersion,
  mkIOSHeaderPackage,
  packageSpec,
  zug-ios,
}:

let
  lagerConfig = ''
    include(CMakeFindDependencyMacro)
    find_dependency(Boost ${boost-ios.version} EXACT CONFIG)
    find_dependency(Zug ${zug-ios.version} EXACT CONFIG)

    get_filename_component(_LAGER_PREFIX "''${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
    if(NOT TARGET lager)
      add_library(lager INTERFACE IMPORTED)
      set_target_properties(lager PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "''${_LAGER_PREFIX}/include"
        INTERFACE_COMPILE_FEATURES cxx_std_17
        INTERFACE_LINK_LIBRARIES "Boost::boost;zug")
    endif()
    if(NOT TARGET lager::lager)
      add_library(lager::lager ALIAS lager)
    endif()
    set(Lager_VERSION "${packageSpec.version}")
    unset(_LAGER_PREFIX)
  '';
  lagerConfigVersion = mkCMakePackageVersion {
    compatibility = "SameMajorVersion";
    version = packageSpec.version;
  };
in
assert lib.assertMsg (
  lager.version == packageSpec.version
) "Lager source version ${lager.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.dependencies == [
    "boost"
    "zug"
  ]
) "Lager iOS manifest must retain its complete pure header dependency set";
assert lib.assertMsg (
  packageSpec.cmake_args == [
    "-Dlager_BUILD_TESTS=OFF"
    "-Dlager_BUILD_FAILURE_TESTS=OFF"
    "-Dlager_BUILD_EXAMPLES=OFF"
    "-Dlager_BUILD_DEBUGGER_EXAMPLES=OFF"
    "-Dlager_BUILD_DOCS=OFF"
    "-Dlager_EMBED_RESOURCES_PATH=OFF"
  ]
) "Lager iOS manifest feature contract changed";

mkIOSHeaderPackage {
  pname = "lager-ios";
  inherit (packageSpec) version;
  src = lager.src;

  targetDependencies = [
    boost-ios
    zug-ios
  ];

  headerTrees = [
    {
      source = "lager";
      destination = "include/lager";
    }
  ];

  generatedFiles = {
    "lib/cmake/Lager/LagerConfig.cmake" = lagerConfig;
    "lib/cmake/Lager/LagerConfigVersion.cmake" = lagerConfigVersion;
  };

  requiredPaths = [
    "include/lager/extra/qt.hpp"
    "include/lager/state.hpp"
    "include/lager/store.hpp"
    "include/lager/watch.hpp"
    "lib/cmake/Lager/LagerConfig.cmake"
    "lib/cmake/Lager/LagerConfigVersion.cmake"
    "nix-support/propagated-build-inputs"
  ];

  postInstallCheck = ''
    config="$out/lib/cmake/Lager/LagerConfig.cmake"
    version_config="$out/lib/cmake/Lager/LagerConfigVersion.cmake"
    grep -Fxq 'find_dependency(Boost ${boost-ios.version} EXACT CONFIG)' "$config"
    grep -Fxq 'find_dependency(Zug ${zug-ios.version} EXACT CONFIG)' "$config"
    grep -Fq 'add_library(lager INTERFACE IMPORTED)' "$config"
    grep -Fq 'INTERFACE_INCLUDE_DIRECTORIES "''${_LAGER_PREFIX}/include"' "$config"
    grep -Fq 'INTERFACE_COMPILE_FEATURES cxx_std_17' "$config"
    grep -Fq 'INTERFACE_LINK_LIBRARIES "Boost::boost;zug"' "$config"
    grep -Fq 'add_library(lager::lager ALIAS lager)' "$config"
    grep -Fxq 'unset(_LAGER_PREFIX)' "$config"
    grep -Fxq 'set(PACKAGE_VERSION "${packageSpec.version}")' "$version_config"
    grep -Fq 'if(PACKAGE_FIND_VERSION_RANGE)' "$version_config"

    if test -e "$out/include/lager/resources_path.hpp"; then
      echo "error: Lager embedded a non-relocatable installation prefix" >&2
      exit 1
    fi
    if grep -Fq '${lager.src}' "$config" "$version_config"; then
      echo "error: Lager CMake metadata embeds the source path" >&2
      exit 1
    fi
  '';

  meta = {
    description = "Pure Lager reactive state headers and core dependencies for Krita";
    inherit (lager.meta) license;
  };
}

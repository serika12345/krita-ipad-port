{
  diffutils,
  gnugrep,
  lib,
  mkIOSCMakePackage,
  ninja,
  packageSpec,
  qt6Packages,
  qt5compat-ios,
  qtbase-ios,
  qtXcrunShim,
  toolchain,
  zlib-ios,
}:

let
  quazip = qt6Packages.quazip;
  hostQt = qt6Packages.qtbase;

  expectedSourceHash = "sha256-AOamvy2UgN8n7EZ8EidWkVzRICzEXMmvZsB18UwxIVo=";
  expectedManifestCMakeArgs = [
    "-DQUAZIP_QT_MAJOR_VERSION=6"
    "-DQUAZIP_BZIP2=OFF"
    "-DQUAZIP_ENABLE_TESTS=OFF"
    "-DQUAZIP_FETCH_LIBS=OFF"
  ];

  expectedHeaders = [
    "include/QuaZip-Qt6-1.5/quazip/JlCompress.h"
    "include/QuaZip-Qt6-1.5/quazip/ioapi.h"
    "include/QuaZip-Qt6-1.5/quazip/minizip_crypt.h"
    "include/QuaZip-Qt6-1.5/quazip/quaadler32.h"
    "include/QuaZip-Qt6-1.5/quazip/quachecksum32.h"
    "include/QuaZip-Qt6-1.5/quazip/quacrc32.h"
    "include/QuaZip-Qt6-1.5/quazip/quagzipfile.h"
    "include/QuaZip-Qt6-1.5/quazip/quaziodevice.h"
    "include/QuaZip-Qt6-1.5/quazip/quazip.h"
    "include/QuaZip-Qt6-1.5/quazip/quazip_global.h"
    "include/QuaZip-Qt6-1.5/quazip/quazip_qt_compat.h"
    "include/QuaZip-Qt6-1.5/quazip/quazipdir.h"
    "include/QuaZip-Qt6-1.5/quazip/quazipfile.h"
    "include/QuaZip-Qt6-1.5/quazip/quazipfileinfo.h"
    "include/QuaZip-Qt6-1.5/quazip/quazipnewinfo.h"
    "include/QuaZip-Qt6-1.5/quazip/unzip.h"
    "include/QuaZip-Qt6-1.5/quazip/zip.h"
  ];
  expectedCMakeMetadata = [
    "lib/cmake/QuaZip-Qt6-1.5/QuaZip-Qt6Config.cmake"
    "lib/cmake/QuaZip-Qt6-1.5/QuaZip-Qt6ConfigVersion.cmake"
    "lib/cmake/QuaZip-Qt6-1.5/QuaZip-Qt6_StaticTargets-release.cmake"
    "lib/cmake/QuaZip-Qt6-1.5/QuaZip-Qt6_StaticTargets.cmake"
  ];
  staticArchives = [ "lib/libquazip1-qt6.a" ];
  requiredPaths =
    expectedHeaders
    ++ expectedCMakeMetadata
    ++ staticArchives
    ++ [
      "lib/pkgconfig/quazip1-qt6.pc"
      "nix-support/propagated-build-inputs"
    ];

  expectedArchiveMembers = [
    "mocs_compilation.cpp.o"
    "unzip.c.o"
    "zip.c.o"
    "JlCompress.cpp.o"
    "qioapi.cpp.o"
    "quaadler32.cpp.o"
    "quachecksum32.cpp.o"
    "quacrc32.cpp.o"
    "quagzipfile.cpp.o"
    "quaziodevice.cpp.o"
    "quazip.cpp.o"
    "quazipdir.cpp.o"
    "quazipfile.cpp.o"
    "quazipfileinfo.cpp.o"
    "quazipnewinfo.cpp.o"
  ];
in
assert lib.assertMsg (packageSpec.name == "quazip") "iOS dependency manifest entry must be QuaZip";
assert lib.assertMsg (
  quazip.version == packageSpec.version
) "QuaZip source version ${quazip.version} does not match iOS manifest ${packageSpec.version}";
assert lib.assertMsg (
  (quazip.src.outputHash or null) == expectedSourceHash
) "QuaZip source hash differs from the audited v1.5 source tree";
assert lib.assertMsg (
  (quazip.src.outputHashMode or null) == "recursive"
) "QuaZip source must retain its recursively hashed GitHub source tree";
assert lib.assertMsg (
  packageSpec.source_flake_attr == "source-quazip"
) "QuaZip iOS manifest must use the source-quazip flake output";
assert lib.assertMsg packageSpec.requires_qt "QuaZip must remain a Qt target dependency";
assert lib.assertMsg (
  packageSpec.dependencies == [ "zlib" ]
) "QuaZip non-Qt target dependencies must be exactly [ zlib ]";
assert lib.assertMsg (
  packageSpec.cmake_args == expectedManifestCMakeArgs
) "QuaZip manifest CMake arguments differ from the audited Qt 6, no-BZip2 configuration";
assert lib.assertMsg (
  packageSpec.artifacts == staticArchives
) "QuaZip manifest must contain exactly its one static archive";
assert lib.assertMsg (
  packageSpec.required_paths == [
    "include/QuaZip-Qt6-1.5/quazip/quazip.h"
    "lib/cmake/QuaZip-Qt6-1.5/QuaZip-Qt6Config.cmake"
  ]
) "QuaZip manifest bootstrap paths changed";
assert lib.assertMsg (
  qtbase-ios.version == hostQt.version && qt5compat-ios.version == hostQt.version
) "QuaZip target and host Qt versions must match";
mkIOSCMakePackage {
  pname = "quazip-ios";
  inherit (packageSpec) version;
  src = quazip.src;

  # QuaZip 1.5 still uses QTextCodec on Qt 6, so Core5Compat is a real
  # target dependency rather than a build-only compatibility aid.
  targetDependencies = [
    qtbase-ios
    qt5compat-ios
    zlib-ios
  ];

  appleSdkResolver = qtXcrunShim;
  cmakeToolchainFile = "${qtbase-ios}/lib/cmake/Qt6/qt.toolchain.cmake";
  enableFullAppleToolchain = true;
  tryCompileTargetType = null;
  nativeBuildInputs = [ gnugrep ];
  nativeInstallCheckInputs = [ diffutils ];

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS=OFF"
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE"
    "-DCMAKE_FIND_PACKAGE_TARGETS_GLOBAL=TRUE"
    "-DQT_ADDITIONAL_PACKAGES_PREFIX_PATH:STRING=${qt5compat-ios}"
    "-DQT_APPLE_SDK=iphoneos"
    "-DQT_HOST_PATH:PATH=${hostQt}"
    "-DQT_HOST_PATH_CMAKE_DIR:PATH=${hostQt}/lib/cmake"
    "-DQT_XCRUN:FILEPATH=${qtXcrunShim}/bin/xcrun"
    "-DZLIB_DIR:PATH=${zlib-ios}/lib/cmake/zlib"
    "-DQUAZIP_INSTALL=ON"
    "-DQUAZIP_USE_QT_ZLIB=OFF"
    "-DQUAZIP_FORCE_FETCH_LIBS=OFF"
    "-DQUAZIP_BZIP2_STDIO=ON"
    "-DZLIB_CONST=OFF"
  ]
  ++ packageSpec.cmake_args;

  inherit requiredPaths staticArchives;

  postConfigure = ''
    check_cache_string() {
      name="$1"
      expected="$2"
      count="$(grep -Ec "^$name:[^=]*=" CMakeCache.txt || true)"
      if test "$count" -ne 1; then
        echo "error: expected one QuaZip cache entry for $name; found $count" >&2
        exit 1
      fi
      actual="$(sed -n "s/^$name:[^=]*=//p" CMakeCache.txt)"
      if test "$actual" != "$expected"; then
        echo "error: QuaZip cache $name is '$actual'; expected '$expected'" >&2
        exit 1
      fi
    }

    check_cache_boolean() {
      name="$1"
      expected="$2"
      count="$(grep -Ec "^$name:[^=]*=" CMakeCache.txt || true)"
      if test "$count" -ne 1; then
        echo "error: expected one QuaZip boolean cache entry for $name; found $count" >&2
        exit 1
      fi
      actual="$(sed -n "s/^$name:[^=]*=//p" CMakeCache.txt)"
      case "$actual" in
        1 | ON | TRUE | YES) actual=ON ;;
        0 | OFF | FALSE | NO) actual=OFF ;;
        *)
          echo "error: QuaZip cache $name has non-boolean value '$actual'" >&2
          exit 1
          ;;
      esac
      if test "$actual" != "$expected"; then
        echo "error: QuaZip cache $name is '$actual'; expected '$expected'" >&2
        exit 1
      fi
    }

    check_cache_string CMAKE_BUILD_TYPE Release
    check_cache_string CMAKE_SYSTEM_NAME iOS
    check_cache_string CMAKE_SYSTEM_PROCESSOR ${toolchain.architecture}
    check_cache_string CMAKE_OSX_ARCHITECTURES ${toolchain.architecture}
    check_cache_string CMAKE_OSX_DEPLOYMENT_TARGET ${toolchain.deploymentTarget}
    check_cache_string CMAKE_OSX_SYSROOT iphoneos
    check_cache_boolean CMAKE_POSITION_INDEPENDENT_CODE ON
    check_cache_boolean CMAKE_FIND_PACKAGE_PREFER_CONFIG ON
    check_cache_boolean CMAKE_FIND_PACKAGE_TARGETS_GLOBAL ON
    check_cache_boolean BUILD_SHARED_LIBS OFF

    check_cache_string CMAKE_C_COMPILER ${lib.escapeShellArg toolchain.cc}
    check_cache_string CMAKE_CXX_COMPILER ${lib.escapeShellArg toolchain.cxx}
    check_cache_string CMAKE_OBJC_COMPILER ${lib.escapeShellArg toolchain.cc}
    check_cache_string CMAKE_OBJCXX_COMPILER ${lib.escapeShellArg toolchain.cxx}
    check_cache_string CMAKE_AR ${lib.escapeShellArg toolchain.ar}
    check_cache_string CMAKE_RANLIB ${lib.escapeShellArg toolchain.ranlib}
    check_cache_string CMAKE_STRIP ${lib.escapeShellArg toolchain.strip}
    check_cache_string CMAKE_LINKER ${lib.escapeShellArg toolchain.ld}
    check_cache_string CMAKE_NM ${lib.escapeShellArg toolchain.nm}
    check_cache_string CMAKE_INSTALL_NAME_TOOL ${lib.escapeShellArg toolchain.installNameTool}
    check_cache_string CMAKE_OTOOL ${lib.escapeShellArg toolchain.otool}
    check_cache_string CMAKE_TAPI ${lib.escapeShellArg toolchain.tapi}
    check_cache_string CMAKE_MAKE_PROGRAM ${lib.escapeShellArg "${ninja}/bin/ninja"}
    check_cache_string CMAKE_TOOLCHAIN_FILE ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6/qt.toolchain.cmake"}

    check_cache_string QUAZIP_QT_MAJOR_VERSION 6
    check_cache_boolean QUAZIP_BZIP2 OFF
    check_cache_boolean QUAZIP_BZIP2_STDIO ON
    check_cache_boolean QUAZIP_ENABLE_TESTS OFF
    check_cache_boolean QUAZIP_FETCH_LIBS OFF
    check_cache_boolean QUAZIP_FORCE_FETCH_LIBS OFF
    check_cache_boolean QUAZIP_INSTALL ON
    check_cache_boolean QUAZIP_USE_QT_ZLIB OFF
    check_cache_boolean ZLIB_CONST OFF

    check_cache_string QT_QMAKE_TARGET_MKSPEC macx-ios-clang
    check_cache_string QT_ADDITIONAL_PACKAGES_PREFIX_PATH ${lib.escapeShellArg (toString qt5compat-ios)}
    check_cache_string QT_APPLE_SDK iphoneos
    check_cache_string QT_HOST_PATH ${lib.escapeShellArg (toString hostQt)}
    check_cache_string QT_HOST_PATH_CMAKE_DIR ${lib.escapeShellArg "${hostQt}/lib/cmake"}
    check_cache_string QT_XCRUN ${lib.escapeShellArg "${qtXcrunShim}/bin/xcrun"}
    check_cache_string Qt6_DIR ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6"}
    check_cache_string Qt6BundledPcre2_DIR ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6BundledPcre2"}
    check_cache_string Qt6Core_DIR ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6Core"}
    check_cache_string Qt6Core5Compat_DIR ${lib.escapeShellArg "${qt5compat-ios}/lib/cmake/Qt6Core5Compat"}
    check_cache_string Qt6EntryPointPrivate_DIR ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6EntryPointPrivate"}
    check_cache_string Qt6Network_DIR ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6Network"}
    check_cache_string Qt6Test_DIR ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6Test"}
    check_cache_string Qt6HostInfo_DIR ${lib.escapeShellArg "${hostQt}/lib/cmake/Qt6HostInfo"}
    check_cache_string Qt6CoreTools_DIR ${lib.escapeShellArg "${hostQt}/lib/cmake/Qt6CoreTools"}
    check_cache_string ZLIB_DIR ${lib.escapeShellArg "${zlib-ios}/lib/cmake/zlib"}

    if ! test -x "${hostQt}/libexec/moc"; then
      echo "error: the pinned host Qt moc is missing" >&2
      exit 1
    fi
    for package in Qt6HostInfo Qt6CoreTools; do
      if ! test -f "${hostQt}/lib/cmake/$package/$package"Config.cmake; then
        echo "error: pinned host Qt package is missing: $package" >&2
        exit 1
      fi
    done

    autogen_info=quazip/CMakeFiles/QuaZip_autogen.dir/AutogenInfo.json
    if ! test -f "$autogen_info"; then
      echo "error: QuaZip automoc metadata was not generated" >&2
      exit 1
    fi
    grep -Fq '"QT_MOC_EXECUTABLE" : "${hostQt}/libexec/moc"' "$autogen_info"
    grep -Fq '"QUAZIP_STATIC"' "$autogen_info"
    if grep -Fq '"HAVE_BZIP2"' "$autogen_info"; then
      echo "error: QuaZip automoc unexpectedly enables BZip2" >&2
      exit 1
    fi
    grep -Fq -- '-std=gnu++17' build.ninja

    xcrun_log="$NIX_BUILD_TOP/qt-xcrun-shim.log"
    if ! test -s "$xcrun_log" || test -L "$xcrun_log"; then
      echo "error: QuaZip/CMake did not produce a regular xcrun shim log" >&2
      exit 1
    fi
    if grep -Ev -- '^-sdk iphoneos --show-sdk-path$' "$xcrun_log"; then
      echo "error: QuaZip/CMake made an unsupported xcrun invocation" >&2
      exit 1
    fi
    expected_xcrun_set="$NIX_BUILD_TOP/quazip-xcrun.expected"
    actual_xcrun_set="$NIX_BUILD_TOP/quazip-xcrun.actual"
    printf '%s\n' \
      '-sdk iphoneos --show-sdk-path' \
      | LC_ALL=C sort > "$expected_xcrun_set"
    LC_ALL=C sort -u "$xcrun_log" > "$actual_xcrun_set"
    if ! cmp -s "$expected_xcrun_set" "$actual_xcrun_set"; then
      echo "error: QuaZip xcrun invocation set differs from the audited Qt consumer contract" >&2
      echo "expected:" >&2
      cat "$expected_xcrun_set" >&2
      echo "actual:" >&2
      cat "$actual_xcrun_set" >&2
      exit 1
    fi

    if grep -E '(^|[=;])(/usr/local|/opt/homebrew)(;|$)' CMakeCache.txt; then
      echo "error: QuaZip configure cache contains a host package prefix" >&2
      exit 1
    fi
  '';

  postInstall = ''
    pc="$out/lib/pkgconfig/quazip1-qt6.pc"
    if test "$(grep -Fxc "prefix=$out" "$pc" || true)" -ne 1; then
      echo "error: QuaZip pkg-config prefix is not the one audited install prefix" >&2
      exit 1
    fi
    substituteInPlace "$pc" \
      --replace-fail "prefix=$out" 'prefix=''${pcfiledir}/../..'
  '';

  postInstallCheck = ''
    actual_headers="$NIX_BUILD_TOP/quazip-headers.actual"
    expected_headers="$NIX_BUILD_TOP/quazip-headers.expected"
    find "$out/include/QuaZip-Qt6-1.5/quazip" -maxdepth 1 -type f -print \
      | sed "s#^$out/##" \
      | LC_ALL=C sort > "$actual_headers"
    printf '%s\n' ${lib.escapeShellArgs expectedHeaders} \
      | LC_ALL=C sort > "$expected_headers"
    if ! cmp -s "$expected_headers" "$actual_headers"; then
      echo "error: QuaZip installed header set differs from the audited 17-header API" >&2
      diff -u "$expected_headers" "$actual_headers" >&2 || true
      exit 1
    fi

    actual_archives="$NIX_BUILD_TOP/quazip-archives.actual"
    expected_archives="$NIX_BUILD_TOP/quazip-archives.expected"
    find "$out" -type f -name '*.a' -print \
      | sed "s#^$out/##" \
      | LC_ALL=C sort > "$actual_archives"
    printf '%s\n' ${lib.escapeShellArgs staticArchives} \
      | LC_ALL=C sort > "$expected_archives"
    if ! cmp -s "$expected_archives" "$actual_archives"; then
      echo "error: QuaZip static archive set is not exactly the audited one-archive output" >&2
      diff -u "$expected_archives" "$actual_archives" >&2 || true
      exit 1
    fi
    if find "$out" -type f -name '*.o' -print -quit | grep -q .; then
      echo "error: QuaZip unexpectedly installs standalone objects" >&2
      exit 1
    fi
    if find "$out" \( \
      -type d -name '*.framework' -o \
      -type f \( -name '*.dylib' -o -name '*.so' -o -name '*.so.*' \) \
    \) -print -quit | grep -q .; then
      echo "error: static-only QuaZip output contains a dynamic library" >&2
      exit 1
    fi
    for forbidden_dir in bin libexec share doc docs examples qztest tests; do
      if test -e "$out/$forbidden_dir"; then
        echo "error: library-only QuaZip output contains $forbidden_dir" >&2
        exit 1
      fi
    done

    archive="$out/lib/libquazip1-qt6.a"
    actual_members="$NIX_BUILD_TOP/quazip-members.actual"
    expected_members="$NIX_BUILD_TOP/quazip-members.expected"
    ${toolchain.ar} -t "$archive" | grep -v '^__.SYMDEF' > "$actual_members"
    printf '%s\n' ${lib.escapeShellArgs expectedArchiveMembers} > "$expected_members"
    if ! cmp -s "$expected_members" "$actual_members"; then
      echo "error: libquazip1-qt6.a differs from its audited 15-object runtime" >&2
      diff -u "$expected_members" "$actual_members" >&2 || true
      exit 1
    fi

    exported_symbols="$(${toolchain.nm} -gU "$archive")"
    for symbol_pattern in \
      '_unzOpen64$' \
      '_zipOpen64$' \
      '__ZN6QuaZip4openE' \
      '__ZN10QuaZipFile4openE' \
      '__ZN10JlCompress12compressFileE'; do
      if ! grep -Eq "$symbol_pattern" <<<"$exported_symbols"; then
        echo "error: libquazip1-qt6.a omits required symbol pattern $symbol_pattern" >&2
        exit 1
      fi
    done
    undefined_symbols="$(${toolchain.nm} -u "$archive")"
    for symbol_pattern in '_crc32$' '__ZN10QTextCodec'; do
      if ! grep -Eq "$symbol_pattern" <<<"$undefined_symbols"; then
        echo "error: QuaZip no longer exposes its audited zlib/Core5Compat dependency" >&2
        exit 1
      fi
    done
    if grep -Eq '(^|[[:space:]])_?BZ2_' <<<"$undefined_symbols"; then
      echo "error: no-BZip2 QuaZip output references BZip2" >&2
      exit 1
    fi
    if grep -R -a -l -F ${lib.escapeShellArg (toString quazip.src)} "$out"; then
      echo "error: QuaZip output contains its immutable source path" >&2
      exit 1
    fi

    cmake_dir="$out/lib/cmake/QuaZip-Qt6-1.5"
    actual_cmake_metadata="$NIX_BUILD_TOP/quazip-cmake-metadata.actual"
    expected_cmake_metadata="$NIX_BUILD_TOP/quazip-cmake-metadata.expected"
    find "$cmake_dir" -maxdepth 1 -type f -print \
      | sed "s#^$out/##" \
      | LC_ALL=C sort > "$actual_cmake_metadata"
    printf '%s\n' ${lib.escapeShellArgs expectedCMakeMetadata} \
      | LC_ALL=C sort > "$expected_cmake_metadata"
    if ! cmp -s "$expected_cmake_metadata" "$actual_cmake_metadata"; then
      echo "error: QuaZip CMake metadata differs from its audited four-file set" >&2
      diff -u "$expected_cmake_metadata" "$actual_cmake_metadata" >&2 || true
      exit 1
    fi

    config="$cmake_dir/QuaZip-Qt6Config.cmake"
    version_config="$cmake_dir/QuaZip-Qt6ConfigVersion.cmake"
    targets="$cmake_dir/QuaZip-Qt6_StaticTargets.cmake"
    targets_release="$cmake_dir/QuaZip-Qt6_StaticTargets-release.cmake"
    grep -Fq 'include(CMakeFindDependencyMacro)' "$config"
    grep -Fq 'find_dependency(Qt6 REQUIRED COMPONENTS Core Core5Compat)' "$config"
    grep -Fq 'find_dependency(ZLIB REQUIRED)' "$config"
    grep -Fq 'set_target_properties(QuaZip::QuaZip PROPERTIES IMPORTED_GLOBAL TRUE)' "$config"
    grep -Fq 'set(PACKAGE_VERSION "1.5")' "$version_config"
    grep -Fq 'add_library(QuaZip::QuaZip STATIC IMPORTED)' "$targets"
    grep -Fq 'INTERFACE_COMPILE_DEFINITIONS "QUAZIP_STATIC"' "$targets"
    grep -Fq 'INTERFACE_INCLUDE_DIRECTORIES "''${_IMPORT_PREFIX}/include/QuaZip-Qt6-1.5;''${_IMPORT_PREFIX}/include/QuaZip-Qt6-1.5/quazip"' "$targets"
    grep -Fq 'INTERFACE_LINK_LIBRARIES "Qt6::Core;Qt6::Core5Compat;ZLIB::ZLIB"' "$targets"
    grep -Fq 'IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "C;CXX"' "$targets_release"
    grep -Fq 'IMPORTED_LOCATION_RELEASE "''${_IMPORT_PREFIX}/lib/libquazip1-qt6.a"' "$targets_release"

    pc="$out/lib/pkgconfig/quazip1-qt6.pc"
    grep -Fxq 'prefix=''${pcfiledir}/../..' "$pc"
    grep -Fxq 'exec_prefix=''${prefix}' "$pc"
    grep -Fxq 'libdir=''${prefix}/lib' "$pc"
    grep -Fxq 'includedir=''${prefix}/include' "$pc"
    grep -Fxq 'Name: QuaZip-Qt6' "$pc"
    grep -Fxq 'Version: 1.5' "$pc"
    grep -Fxq 'Libs: -lquazip1-qt6' "$pc"
    grep -Fxq 'Cflags: -I''${includedir}/QuaZip-Qt6-1.5 -I''${includedir}/QuaZip-Qt6-1.5/quazip' "$pc"
    grep -Fxq 'Requires: zlib, Qt6Core' "$pc"

    metadata_paths=("$cmake_dir" "$pc")
    for forbidden_path in \
      "$out" \
      "${quazip.src}" \
      "${qtbase-ios}" \
      "${qt5compat-ios}" \
      "${zlib-ios}" \
      "${hostQt}"; do
      if grep -R -a -l -F "$forbidden_path" "''${metadata_paths[@]}"; then
        echo "error: QuaZip installed metadata embeds a non-relocatable path: $forbidden_path" >&2
        exit 1
      fi
    done

    propagated="$out/nix-support/propagated-build-inputs"
    for dependency in "${qtbase-ios}" "${qt5compat-ios}" "${zlib-ios}"; do
      if ! grep -Fq "$dependency" "$propagated"; then
        echo "error: QuaZip output does not propagate target dependency $dependency" >&2
        exit 1
      fi
    done
  '';

  passthru = {
    iosSourceHash = expectedSourceHash;
    iosQtAdditionalPackages = [ qt5compat-ios ];
  };

  meta = {
    description = "Static QuaZip built against the pinned Qt for Krita on iPadOS";
    inherit (quazip.meta) license;
  };
}

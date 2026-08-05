{
  lib,
  stdenvNoCC,
  cmake,
  ninja,
  coreutils,
  file,
  findutils,
  gawk,
  gnugrep,
  gnused,
  toolchain,
}:

{
  pname,
  version,
  src,
  patches ? [ ],
  appleSdkResolver ? null,
  cmakeFlags ? [ ],
  cmakeToolchainFile ? null,
  enableFullAppleToolchain ? false,
  enableTargetPkgConfig ? false,
  inspectAllAppleObjects ? false,
  installScripts ? [ ],
  nativeBuildInputs ? [ ],
  nativeInstallCheckInputs ? [ ],
  passthru ? { },
  requiredPaths ? [ ],
  staticArchives ? [ ],
  targetDependencies ? [ ],
  tryCompileTargetType ? "STATIC_LIBRARY",
  meta ? { },
  ...
}@args:

let
  dependencyEntry = dependency: {
    key = dependency.outPath;
    value = dependency;
  };
  targetDependencyClosure = map (entry: entry.value) (
    builtins.genericClosure {
      startSet = map dependencyEntry targetDependencies;
      operator = entry: map dependencyEntry (entry.value.propagatedBuildInputs or [ ]);
    }
  );
  targetDependencyIsCompatible =
    dependency:
    let
      targetIndependent = dependency.iosTargetIndependent or false;
      dependencyToolchainIdentity = dependency.iosToolchainIdentity or null;
    in
    lib.isBool targetIndependent
    && (
      (targetIndependent && dependencyToolchainIdentity == null)
      || (!targetIndependent && dependencyToolchainIdentity == toolchain.identity)
    );
  targetRootPath = lib.concatStringsSep ";" (map toString targetDependencyClosure);
  targetPkgConfigPath = lib.concatStringsSep ":" (
    lib.concatMap (dependency: [
      "${dependency}/lib/pkgconfig"
      "${dependency}/share/pkgconfig"
    ]) targetDependencyClosure
  );
  targetPkgConfigLibDir =
    if targetPkgConfigPath == "" then "$NIX_BUILD_TOP/empty-pkg-config" else targetPkgConfigPath;
  cmakeOSXSysroot = if appleSdkResolver == null then toolchain.sdkRoot else "iphoneos";
  archiveInspectionHook = import ./inspect-ios-archive.nix { inherit gawk toolchain; };
  inspectAllAppleObjectsHook = ''
    ${archiveInspectionHook}
    inspect_ios_object() {
      object_file="$1"
      object_architectures="$(${toolchain.lipo} -archs "$object_file")"
      if test "$object_architectures" != "${toolchain.architecture}"; then
        echo "error: $object_file contains '$object_architectures'; expected ${toolchain.architecture}" >&2
        exit 1
      fi

      object_metadata="$(${toolchain.vtool} -show-build "$object_file")"
      if ! grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$object_metadata"; then
        echo "error: $object_file is not an iOS device object" >&2
        exit 1
      fi
      if ! grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$object_metadata"; then
        echo "error: $object_file does not target iOS ${toolchain.deploymentTarget}" >&2
        exit 1
      fi
      if ! grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$object_metadata"; then
        echo "error: $object_file was not built with SDK ${toolchain.sdkVersion}" >&2
        exit 1
      fi
    }

    all_archive_count=0
    while IFS= read -r -d "" archive; do
      all_archive_count=$((all_archive_count + 1))
      ${toolchain.ranlib} -D "$archive"
      file "$archive"

      architectures="$(${toolchain.lipo} -archs "$archive")"
      if test "$architectures" != "${toolchain.architecture}"; then
        echo "error: $archive contains '$architectures'; expected exactly ${toolchain.architecture}" >&2
        exit 1
      fi

      expected_member_count="$(${toolchain.ar} -t "$archive" | grep -v '^__.SYMDEF' | wc -l | tr -d ' ')"
      if test "$expected_member_count" -eq 0; then
        echo "error: $archive contains no object members" >&2
        exit 1
      fi
      if ! inspect_ios_archive_members "$archive" "$expected_member_count"; then
        exit 1
      fi
    done < <(find "$out" -type f -name '*.a' -print0)

    if test "$all_archive_count" -eq 0; then
      echo "error: inspectAllAppleObjects found no static archives" >&2
      exit 1
    fi

    while IFS= read -r -d "" object_file; do
      inspect_ios_object "$object_file"
    done < <(find "$out" -type f -name '*.o' -print0)
  '';
  reservedCMakeVariables = [
    "CMAKE_AR"
    "CMAKE_ASM_COMPILER"
    "CMAKE_ASM_FLAGS"
    "CMAKE_BUILD_TYPE"
    "CMAKE_CXX_COMPILER"
    "CMAKE_CXX_FLAGS"
    "CMAKE_C_COMPILER"
    "CMAKE_C_FLAGS"
    "CMAKE_EXE_LINKER_FLAGS"
    "CMAKE_FIND_ROOT_PATH"
    "CMAKE_FIND_ROOT_PATH_MODE_INCLUDE"
    "CMAKE_FIND_ROOT_PATH_MODE_LIBRARY"
    "CMAKE_FIND_ROOT_PATH_MODE_PACKAGE"
    "CMAKE_FIND_ROOT_PATH_MODE_PROGRAM"
    "CMAKE_INSTALL_BINDIR"
    "CMAKE_INSTALL_DATADIR"
    "CMAKE_INSTALL_DOCDIR"
    "CMAKE_INSTALL_INCLUDEDIR"
    "CMAKE_INSTALL_LIBDIR"
    "CMAKE_INSTALL_LIBEXECDIR"
    "CMAKE_INSTALL_LOCALEDIR"
    "CMAKE_INSTALL_MANDIR"
    "CMAKE_INSTALL_NAME_TOOL"
    "CMAKE_INSTALL_PREFIX"
    "CMAKE_INSTALL_SBINDIR"
    "CMAKE_LINKER"
    "CMAKE_MAKE_PROGRAM"
    "CMAKE_MODULE_LINKER_FLAGS"
    "CMAKE_NM"
    "CMAKE_OBJCXX_COMPILER"
    "CMAKE_OBJCXX_FLAGS"
    "CMAKE_OBJC_COMPILER"
    "CMAKE_OBJC_FLAGS"
    "CMAKE_OSX_ARCHITECTURES"
    "CMAKE_OSX_DEPLOYMENT_TARGET"
    "CMAKE_OSX_SYSROOT"
    "CMAKE_POSITION_INDEPENDENT_CODE"
    "CMAKE_PREFIX_PATH"
    "CMAKE_RANLIB"
    "CMAKE_OTOOL"
    "CMAKE_SHARED_LINKER_FLAGS"
    "CMAKE_STATIC_LINKER_FLAGS"
    "CMAKE_STRIP"
    "CMAKE_SYSTEM_NAME"
    "CMAKE_SYSTEM_PROCESSOR"
    "CMAKE_TAPI"
    "CMAKE_TOOLCHAIN_FILE"
    "CMAKE_TRY_COMPILE_TARGET_TYPE"
  ];
  reservedCMakeVariablePatterns = [
    "CMAKE_(ASM|C|CXX|OBJC|OBJCXX)_FLAGS(_[A-Za-z0-9_]+)?"
    "CMAKE_(EXE|MODULE|SHARED|STATIC)_LINKER_FLAGS(_[A-Za-z0-9_]+)?"
  ];
  cmakeDefinitionName =
    flag:
    let
      match = builtins.match "-D([^:=]+)(:[^=]+)?=.*" flag;
    in
    if match == null then null else builtins.elemAt match 0;
  cmakeVariableIsReserved =
    name:
    builtins.elem name reservedCMakeVariables
    || lib.any (pattern: builtins.match pattern name != null) reservedCMakeVariablePatterns;
  overriddenCMakeVariables = builtins.filter (name: name != null && cmakeVariableIsReserved name) (
    map cmakeDefinitionName cmakeFlags
  );
  reservedCMakeFlagForms = builtins.filter (
    flag:
    flag == "-D"
    || lib.hasPrefix "-C" flag
    || lib.hasPrefix "-G" flag
    || lib.hasPrefix "-S" flag
    || lib.hasPrefix "-B" flag
    || lib.hasPrefix "-U" flag
    || lib.hasPrefix "@" flag
    || lib.hasPrefix "--toolchain" flag
    || lib.hasPrefix "--install-prefix" flag
    || lib.hasPrefix "--preset" flag
  ) cmakeFlags;
  protectedDerivationAttrs = [
    "AR"
    "AS"
    "ASMFLAGS"
    "CC"
    "CFLAGS"
    "CMAKE_GENERATOR"
    "CMAKE_GENERATOR_INSTANCE"
    "CMAKE_GENERATOR_PLATFORM"
    "CMAKE_GENERATOR_TOOLSET"
    "CMAKE_FRAMEWORK_PATH"
    "CMAKE_INCLUDE_PATH"
    "CMAKE_LIBRARY_PATH"
    "CMAKE_PREFIX_PATH"
    "CMAKE_PREFIX_PATH_FOR_BUILD"
    "CMAKE_TOOLCHAIN_FILE"
    "CPATH"
    "CPP"
    "CPPFLAGS"
    "CXX"
    "CXXFLAGS"
    "DEVELOPER_DIR"
    "IPHONEOS_DEPLOYMENT_TARGET"
    "KRITA_IOS_TOOLCHAIN_IDENTITY"
    "LD"
    "LDFLAGS"
    "LIBRARY_PATH"
    "MACOSX_DEPLOYMENT_TARGET"
    "NIX_CFLAGS_COMPILE"
    "NIX_LDFLAGS"
    "NIXPKGS_CMAKE_PREFIX_PATH"
    "NM"
    "OBJC"
    "OBJCFLAGS"
    "OBJCXX"
    "OBJCXXFLAGS"
    "PKG_CONFIG"
    "PKG_CONFIG_DIR"
    "PKG_CONFIG_LIBDIR"
    "PKG_CONFIG_PATH"
    "PKG_CONFIG_SYSROOT_DIR"
    "QT_ADDITIONAL_HOST_PACKAGES_PREFIX_PATH"
    "QT_ADDITIONAL_PACKAGES_PREFIX_PATH"
    "QT_OPTIONAL_TOOLS_PATH"
    "SDKROOT"
    "SOURCE_DATE_EPOCH"
    "ZERO_AR_DATE"
    "__contentAddressed"
    "__darwinAllowLocalNetworking"
    "__impureHostDeps"
    "__noChroot"
    "__sandboxProfile"
    "args"
    "buildInputs"
    "buildPhase"
    "configurePhase"
    "doInstallCheck"
    "dontBuild"
    "dontConfigure"
    "dontFixup"
    "dontInstall"
    "dontInstallCheck"
    "dontPatch"
    "dontStrip"
    "dontUnpack"
    "enableParallelBuilding"
    "env"
    "fixupPhase"
    "installCheckPhase"
    "installPhase"
    "impureEnvVars"
    "outputHash"
    "outputHashAlgo"
    "outputHashMode"
    "outputs"
    "patchPhase"
    "phases"
    "postPhases"
    "preConfigure"
    "prePhases"
    "propagatedBuildInputs"
    "propagatedNativeBuildInputs"
    "strictDeps"
    "system"
    "unpackPhase"
    "builder"
  ];
  overriddenProtectedAttrs = builtins.filter (
    name: builtins.hasAttr name args
  ) protectedDerivationAttrs;
in
assert lib.assertMsg (lib.all lib.isDerivation targetDependencies)
  "iOS target dependencies must all be derivations";
assert lib.assertMsg (lib.all targetDependencyIsCompatible targetDependencyClosure)
  "iOS target dependency closures must be toolchain-independent or use the same pinned toolchain identity";
assert lib.assertMsg (
  appleSdkResolver == null || lib.isDerivation appleSdkResolver
) "iOS CMake appleSdkResolver must be null or a derivation";
assert lib.assertMsg (overriddenProtectedAttrs == [ ])
  "iOS CMake packages may not override protected derivation attributes: ${lib.concatStringsSep ", " overriddenProtectedAttrs}";
assert lib.assertMsg (lib.all lib.isString cmakeFlags) "iOS CMake cmakeFlags must all be strings";
assert lib.assertMsg (
  cmakeToolchainFile == null
  || (lib.isString cmakeToolchainFile && lib.hasPrefix "/" cmakeToolchainFile)
) "iOS CMake cmakeToolchainFile must be null or an absolute path";
assert lib.assertMsg (overriddenCMakeVariables == [ ])
  "iOS CMake packages may not override reserved cache variables: ${lib.concatStringsSep ", " overriddenCMakeVariables}";
assert lib.assertMsg (reservedCMakeFlagForms == [ ])
  "iOS CMake packages may not use reserved command flag forms: ${lib.concatStringsSep ", " reservedCMakeFlagForms}";
assert lib.assertMsg (lib.all lib.isDerivation nativeBuildInputs)
  "iOS CMake nativeBuildInputs must all be derivations";
assert lib.assertMsg (lib.all lib.isDerivation nativeInstallCheckInputs)
  "iOS CMake nativeInstallCheckInputs must all be derivations";
assert lib.assertMsg (lib.isAttrs passthru) "iOS CMake passthru must be an attribute set";
assert lib.assertMsg (lib.isBool enableFullAppleToolchain)
  "iOS CMake enableFullAppleToolchain must be a boolean";
assert lib.assertMsg (lib.isBool enableTargetPkgConfig)
  "iOS CMake enableTargetPkgConfig must be a boolean";
assert lib.assertMsg (lib.isBool inspectAllAppleObjects)
  "iOS CMake inspectAllAppleObjects must be a boolean";
assert lib.assertMsg (lib.all (
  script:
  lib.isString script
  && !(lib.hasPrefix "/" script)
  && builtins.match "(^|.*/)\.\.(/.*|$)" script == null
) installScripts) "iOS CMake install scripts must be relative paths below the build directory";
assert lib.assertMsg (
  !inspectAllAppleObjects || staticArchives == [ ]
) "iOS CMake inspectAllAppleObjects cannot be combined with explicit staticArchives";
assert lib.assertMsg (
  tryCompileTargetType == null
  || builtins.elem tryCompileTargetType [
    "EXECUTABLE"
    "STATIC_LIBRARY"
  ]
) "iOS CMake tryCompileTargetType must be null, EXECUTABLE, or STATIC_LIBRARY";
stdenvNoCC.mkDerivation (
  {
    inherit
      pname
      version
      src
      patches
      ;

    strictDeps = true;
    dontStrip = true;
    enableParallelBuilding = true;

    nativeBuildInputs = [
      cmake
      coreutils
      gawk
      gnused
      ninja
    ]
    ++ lib.optional (appleSdkResolver != null) appleSdkResolver
    ++ nativeBuildInputs;

    nativeInstallCheckInputs = [
      coreutils
      file
      findutils
      gnugrep
    ]
    ++ nativeInstallCheckInputs;

    # Static target dependencies must remain in the output closure so an
    # individual package can be cached and consumed without a mutable prefix.
    propagatedBuildInputs = targetDependencies;

    DEVELOPER_DIR = toolchain.developerDir;
    SDKROOT = toolchain.sdkRoot;
    KRITA_IOS_TOOLCHAIN_IDENTITY = toolchain.identity;
    SOURCE_DATE_EPOCH = "1";
    ZERO_AR_DATE = "1";

    # Xcode is the only non-store build input. The daemon validates this
    # declaration against its allowlist and exposes it only to this sandbox.
    __impureHostDeps = toolchain.impureHostDeps;

    preConfigure = ''
      check_toolchain_value() {
        name="$1"
        actual="$2"
        expected="$3"
        if test "$actual" != "$expected"; then
          echo "error: $name is '$actual'; expected '$expected'" >&2
          exit 1
        fi
      }

      read_plist_string() {
        key="$1"
        plist="$2"
        awk -v key="$key" '
          index($0, "<key>" key "</key>") { found = 1; next }
          found && match($0, /<string>([^<]*)<\/string>/, value) {
            print value[1]
            exit
          }
        ' "$plist"
      }

      # xcodebuild starts IDE frameworks and crashes inside a Nix Darwin
      # sandbox. These two canonical XML plists contain the same immutable
      # build identities without invoking an IDE/XPC process.
      actual_xcode_version="$(read_plist_string CFBundleShortVersionString ${toolchain.xcodeVersionPlist})"
      actual_xcode_build="$(read_plist_string ProductBuildVersion ${toolchain.xcodeVersionPlist})"
      actual_sdk_version="$(read_plist_string CFBundleShortVersionString ${toolchain.sdkVersionPlist})"
      actual_sdk_build="$(read_plist_string ProductBuildVersion ${toolchain.sdkVersionPlist})"
      clang_output="$(${toolchain.cc} --version | head -n 1)"
      actual_clang_version="$(sed -E 's/^Apple clang version ([^ ]+).*/\1/' <<<"$clang_output")"
      actual_clang_build="$(sed -E 's/^.*\(clang-([^\)]+)\).*$/\1/' <<<"$clang_output")"

      check_toolchain_value "Xcode" "$actual_xcode_version" "${toolchain.xcodeVersion}"
      check_toolchain_value "Xcode build" "$actual_xcode_build" "${toolchain.xcodeBuildVersion}"
      check_toolchain_value "iPhoneOS SDK" "$actual_sdk_version" "${toolchain.sdkVersion}"
      check_toolchain_value "iPhoneOS SDK build" "$actual_sdk_build" "${toolchain.sdkBuildVersion}"
      check_toolchain_value "Apple Clang" "$actual_clang_version" "${toolchain.clangVersion}"
      check_toolchain_value "Apple Clang build" "$actual_clang_build" "${toolchain.clangBuildVersion}"

      export SOURCE_DATE_EPOCH=1
      export CFLAGS="-ffile-prefix-map=$NIX_BUILD_TOP=/build -fdebug-prefix-map=$NIX_BUILD_TOP=/build"
      export CXXFLAGS="$CFLAGS"
    ''
    + lib.optionalString (cmakeToolchainFile != null) ''
      if ! test -f ${lib.escapeShellArg cmakeToolchainFile}; then
        echo "error: pinned CMake toolchain file is missing: ${cmakeToolchainFile}" >&2
        exit 1
      fi
    ''
    + lib.optionalString (appleSdkResolver != null) ''
      # Some Apple-aware projects require a logical SDK name. The resolver is
      # pinned in the Nix closure and maps that name to the validated SDK.
      if ! test -x "${appleSdkResolver}/bin/xcrun"; then
        echo "error: appleSdkResolver does not provide bin/xcrun" >&2
        exit 1
      fi
      export PATH="${appleSdkResolver}/bin:$PATH"
    ''
    + lib.optionalString enableFullAppleToolchain ''
      export ASMFLAGS="$CFLAGS"
      export OBJCFLAGS="$CFLAGS"
      export OBJCXXFLAGS="$CXXFLAGS"
      # Native setup hooks may expose host CMake/Qt packages. Cross builds
      # receive every target prefix explicitly below, so no ambient host
      # package search path is allowed to survive into configurePhase.
      unset \
        AR AS CC CPP CXX LD LDFLAGS NM OBJC OBJCXX \
        CMAKE_FRAMEWORK_PATH CMAKE_INCLUDE_PATH CMAKE_LIBRARY_PATH \
        CMAKE_PREFIX_PATH CMAKE_PREFIX_PATH_FOR_BUILD NIXPKGS_CMAKE_PREFIX_PATH \
        CPATH IPHONEOS_DEPLOYMENT_TARGET LIBRARY_PATH \
        MACOSX_DEPLOYMENT_TARGET NIX_CFLAGS_COMPILE NIX_LDFLAGS
      unset \
        QT_ADDITIONAL_HOST_PACKAGES_PREFIX_PATH \
        QT_ADDITIONAL_PACKAGES_PREFIX_PATH \
        QT_OPTIONAL_TOOLS_PATH
    ''
    + lib.optionalString enableTargetPkgConfig ''
      # CMake may invoke pkg-config only against the declared iOS target
      # closure. An SDK sysroot must not prefix Nix store paths.
      export PKG_CONFIG_PATH=
      export PKG_CONFIG_DIR=
      mkdir -p "$NIX_BUILD_TOP/empty-pkg-config"
      export PKG_CONFIG_LIBDIR="${targetPkgConfigLibDir}"
      export PKG_CONFIG_SYSROOT_DIR=
    '';

    cmakeFlags = [
      "-G=Ninja"
      "-DCMAKE_SYSTEM_NAME=iOS"
      "-DCMAKE_SYSTEM_PROCESSOR=${toolchain.architecture}"
      "-DCMAKE_OSX_ARCHITECTURES=${toolchain.architecture}"
      "-DCMAKE_OSX_DEPLOYMENT_TARGET=${toolchain.deploymentTarget}"
      "-DCMAKE_OSX_SYSROOT=${cmakeOSXSysroot}"
    ]
    ++ lib.optional (cmakeToolchainFile != null) "-DCMAKE_TOOLCHAIN_FILE=${cmakeToolchainFile}"
    ++ lib.optional (
      tryCompileTargetType != null
    ) "-DCMAKE_TRY_COMPILE_TARGET_TYPE=${tryCompileTargetType}"
    ++ [
      "-DCMAKE_BUILD_TYPE=Release"
      "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
      "-DCMAKE_INSTALL_BINDIR=bin"
      "-DCMAKE_INSTALL_SBINDIR=sbin"
      "-DCMAKE_INSTALL_LIBDIR=lib"
      "-DCMAKE_INSTALL_LIBEXECDIR=libexec"
      "-DCMAKE_INSTALL_INCLUDEDIR=include"
      "-DCMAKE_INSTALL_DATADIR=share"
      "-DCMAKE_INSTALL_DOCDIR=share/doc/${pname}"
      "-DCMAKE_INSTALL_MANDIR=share/man"
      "-DCMAKE_INSTALL_LOCALEDIR=share/locale"
      "-DCMAKE_C_COMPILER=${toolchain.cc}"
      "-DCMAKE_CXX_COMPILER=${toolchain.cxx}"
      "-DCMAKE_AR=${toolchain.ar}"
      "-DCMAKE_RANLIB=${toolchain.ranlib}"
      "-DCMAKE_STRIP=${toolchain.strip}"
      "-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
      "-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
      "-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
      "-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY"
    ]
    ++ lib.optionals enableFullAppleToolchain [
      "-DCMAKE_ASM_COMPILER=${toolchain.cc}"
      "-DCMAKE_OBJC_COMPILER=${toolchain.cc}"
      "-DCMAKE_OBJCXX_COMPILER=${toolchain.cxx}"
      "-DCMAKE_LINKER=${toolchain.ld}"
      "-DCMAKE_NM=${toolchain.nm}"
      "-DCMAKE_INSTALL_NAME_TOOL=${toolchain.installNameTool}"
      "-DCMAKE_OTOOL=${toolchain.otool}"
      "-DCMAKE_TAPI=${toolchain.tapi}"
      "-DCMAKE_MAKE_PROGRAM=${ninja}/bin/ninja"
    ]
    ++ lib.optionals (targetDependencies != [ ]) [
      "-DCMAKE_PREFIX_PATH=${targetRootPath}"
      "-DCMAKE_FIND_ROOT_PATH=${targetRootPath}"
    ]
    ++ cmakeFlags;

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      for relative_path in ${lib.escapeShellArgs requiredPaths}; do
        if ! test -e "$out/$relative_path"; then
          echo "error: required output is missing: $relative_path" >&2
          exit 1
        fi
      done

      ${archiveInspectionHook}

      archive_index=0
      for relative_archive in ${lib.escapeShellArgs staticArchives}; do
        archive_index=$((archive_index + 1))
        archive="$out/$relative_archive"
        test -f "$archive"

        # Normalize archive metadata before it enters the Nix store/cache.
        # Apple ranlib's -D mode writes deterministic symbol-table timestamps.
        ${toolchain.ranlib} -D "$archive"
        file "$archive"

        architectures="$(${toolchain.lipo} -archs "$archive")"
        if test "$architectures" != "${toolchain.architecture}"; then
          echo "error: $archive contains '$architectures'; expected exactly ${toolchain.architecture}" >&2
          exit 1
        fi

        expected_member_count="$(${toolchain.ar} -t "$archive" | grep -v '^__.SYMDEF' | wc -l | tr -d ' ')"
        if test "$expected_member_count" -eq 0; then
          echo "error: $archive contains no object members" >&2
          exit 1
        fi
        if ! inspect_ios_archive_members "$archive" "$expected_member_count"; then
          exit 1
        fi
      done

      if grep -R -a -l -F '${toolchain.xcodeApp}' "$out"; then
        echo "error: output contains a reference to the external Xcode installation" >&2
        exit 1
      fi
      if grep -R -a -l -F "$NIX_BUILD_TOP" "$out"; then
        echo "error: output contains a reference to its temporary build directory" >&2
        exit 1
      fi

      runHook postInstallCheck
    '';

    passthru = passthru // {
      iosToolchainIdentity = toolchain.identity;
      iosTargetDependencyClosure = targetDependencyClosure;
    };

    meta = {
      platforms = [ "aarch64-darwin" ];
    }
    // meta;
  }
  // lib.optionalAttrs (installScripts != [ ]) {
    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      for install_script in ${lib.escapeShellArgs installScripts}; do
        if ! test -f "$install_script"; then
          echo "error: CMake install script is missing: $install_script" >&2
          exit 1
        fi
        cmake -DCMAKE_INSTALL_PREFIX="$out" -P "$install_script"
      done

      runHook postInstall
    '';
  }
  // removeAttrs args [
    "appleSdkResolver"
    "cmakeFlags"
    "cmakeToolchainFile"
    "enableFullAppleToolchain"
    "enableTargetPkgConfig"
    "inspectAllAppleObjects"
    "installScripts"
    "meta"
    "nativeBuildInputs"
    "nativeInstallCheckInputs"
    "passthru"
    "requiredPaths"
    "staticArchives"
    "targetDependencies"
    "tryCompileTargetType"
  ]
  // lib.optionalAttrs inspectAllAppleObjects {
    postInstallCheck = inspectAllAppleObjectsHook + (args.postInstallCheck or "");
  }
)

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
  cmakeFlags ? [ ],
  enableTargetPkgConfig ? false,
  nativeBuildInputs ? [ ],
  nativeInstallCheckInputs ? [ ],
  passthru ? { },
  requiredPaths ? [ ],
  staticArchives ? [ ],
  targetDependencies ? [ ],
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
  targetRootPath = lib.concatStringsSep ";" (map toString targetDependencyClosure);
  targetPkgConfigPath = lib.concatStringsSep ":" (
    lib.concatMap (dependency: [
      "${dependency}/lib/pkgconfig"
      "${dependency}/share/pkgconfig"
    ]) targetDependencyClosure
  );
  targetPkgConfigLibDir =
    if targetPkgConfigPath == "" then "$NIX_BUILD_TOP/empty-pkg-config" else targetPkgConfigPath;
  reservedCMakeVariables = [
    "CMAKE_AR"
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
    "CMAKE_INSTALL_PREFIX"
    "CMAKE_INSTALL_SBINDIR"
    "CMAKE_OSX_ARCHITECTURES"
    "CMAKE_OSX_DEPLOYMENT_TARGET"
    "CMAKE_OSX_SYSROOT"
    "CMAKE_POSITION_INDEPENDENT_CODE"
    "CMAKE_PREFIX_PATH"
    "CMAKE_RANLIB"
    "CMAKE_SHARED_LINKER_FLAGS"
    "CMAKE_STATIC_LINKER_FLAGS"
    "CMAKE_STRIP"
    "CMAKE_SYSTEM_NAME"
    "CMAKE_SYSTEM_PROCESSOR"
    "CMAKE_TOOLCHAIN_FILE"
    "CMAKE_TRY_COMPILE_TARGET_TYPE"
  ];
  cmakeDefinitionName =
    flag:
    let
      match = builtins.match "-D([^:=]+)(:[^=]+)?=.*" flag;
    in
    if match == null then null else builtins.elemAt match 0;
  overriddenCMakeVariables = builtins.filter (
    name: name != null && builtins.elem name reservedCMakeVariables
  ) (map cmakeDefinitionName cmakeFlags);
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
    "DEVELOPER_DIR"
    "KRITA_IOS_TOOLCHAIN_IDENTITY"
    "PKG_CONFIG"
    "PKG_CONFIG_DIR"
    "PKG_CONFIG_LIBDIR"
    "PKG_CONFIG_PATH"
    "PKG_CONFIG_SYSROOT_DIR"
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
assert lib.assertMsg (lib.all
  (dependency: (dependency.iosToolchainIdentity or null) == toolchain.identity)
  targetDependencyClosure
) "iOS target dependency closures must use the same pinned toolchain identity";
assert lib.assertMsg (overriddenProtectedAttrs == [ ])
  "iOS CMake packages may not override protected derivation attributes: ${lib.concatStringsSep ", " overriddenProtectedAttrs}";
assert lib.assertMsg (lib.all lib.isString cmakeFlags) "iOS CMake cmakeFlags must all be strings";
assert lib.assertMsg (overriddenCMakeVariables == [ ])
  "iOS CMake packages may not override reserved cache variables: ${lib.concatStringsSep ", " overriddenCMakeVariables}";
assert lib.assertMsg (reservedCMakeFlagForms == [ ])
  "iOS CMake packages may not use reserved command flag forms: ${lib.concatStringsSep ", " reservedCMakeFlagForms}";
assert lib.assertMsg (lib.all lib.isDerivation nativeBuildInputs)
  "iOS CMake nativeBuildInputs must all be derivations";
assert lib.assertMsg (lib.all lib.isDerivation nativeInstallCheckInputs)
  "iOS CMake nativeInstallCheckInputs must all be derivations";
assert lib.assertMsg (lib.isAttrs passthru) "iOS CMake passthru must be an attribute set";
assert lib.assertMsg (lib.isBool enableTargetPkgConfig)
  "iOS CMake enableTargetPkgConfig must be a boolean";
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
      "-DCMAKE_OSX_SYSROOT=${toolchain.sdkRoot}"
      "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY"
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

      inspection_root="$(mktemp -d)"
      trap 'rm -rf "$inspection_root"' EXIT

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

        archive_dir="$inspection_root/archive-$archive_index"
        mkdir -p "$archive_dir"
        (
          cd "$archive_dir"
          ${toolchain.ar} -x "$archive"
        )

        extracted_count=0
        while IFS= read -r -d "" member; do
          extracted_count=$((extracted_count + 1))
          member_architectures="$(${toolchain.lipo} -archs "$member")"
          if test "$member_architectures" != "${toolchain.architecture}"; then
            echo "error: $member contains '$member_architectures'; expected ${toolchain.architecture}" >&2
            exit 1
          fi
          build_metadata="$(${toolchain.vtool} -show-build "$member")"
          if ! grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$build_metadata"; then
            echo "error: $member is not an iOS device object" >&2
            exit 1
          fi
          if ! grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$build_metadata"; then
            echo "error: $member does not target iOS ${toolchain.deploymentTarget}" >&2
            exit 1
          fi
          if ! grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$build_metadata"; then
            echo "error: $member was not built with SDK ${toolchain.sdkVersion}" >&2
            exit 1
          fi
        done < <(find "$archive_dir" -type f ! -name '__.SYMDEF*' -print0)

        if test "$extracted_count" -ne "$expected_member_count"; then
          echo "error: inspected $extracted_count of $expected_member_count members; duplicate names are not allowed" >&2
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
  // removeAttrs args [
    "cmakeFlags"
    "enableTargetPkgConfig"
    "meta"
    "nativeBuildInputs"
    "nativeInstallCheckInputs"
    "passthru"
    "requiredPaths"
    "staticArchives"
    "targetDependencies"
  ]
)

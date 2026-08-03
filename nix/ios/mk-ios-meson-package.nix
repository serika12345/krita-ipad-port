{
  lib,
  stdenv,
  stdenvNoCC,
  meson,
  ninja,
  coreutils,
  file,
  findutils,
  gawk,
  gnugrep,
  gnused,
  pkg-config,
  toolchain,
}:

{
  pname,
  version,
  src,
  patches ? [ ],
  mesonFlags ? [ ],
  nativeBuildInputs ? [ ],
  nativeInstallCheckInputs ? [ ],
  preConfigure ? "",
  requiredPaths ? [ ],
  staticArchives ? [ ],
  targetDependencies ? [ ],
  passthru ? { },
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
  targetPkgConfigDirs = lib.concatMap (dependency: [
    "${dependency}/lib/pkgconfig"
    "${dependency}/share/pkgconfig"
  ]) targetDependencyClosure;
  targetCMakePrefixPaths = map (dependency: "${dependency}") targetDependencyClosure;
  effectiveTargetPkgConfigDirs =
    if targetPkgConfigDirs == [ ] then [ "$NIX_BUILD_TOP/empty-pkg-config" ] else targetPkgConfigDirs;
  mesonString = value: "'${lib.replaceStrings [ "\\" "'" ] [ "\\\\" "\\'" ] value}'";
  mesonArray = values: "[${lib.concatStringsSep ", " (map mesonString values)}]";
  nativeToolCommand =
    tool:
    mesonArray [
      "${coreutils}/bin/env"
      "-u"
      "SDKROOT"
      "-u"
      "DEVELOPER_DIR"
      tool
    ];
  targetCompileArgs = [
    "-arch"
    toolchain.architecture
    "-isysroot"
    toolchain.sdkRoot
    "-miphoneos-version-min=${toolchain.deploymentTarget}"
    "-fPIC"
    "-ffile-prefix-map=$NIX_BUILD_TOP=/build"
    "-fdebug-prefix-map=$NIX_BUILD_TOP=/build"
  ];
  targetLinkArgs = [
    "-arch"
    toolchain.architecture
    "-isysroot"
    toolchain.sdkRoot
    "-miphoneos-version-min=${toolchain.deploymentTarget}"
  ];
  mesonDefinitionName =
    flag:
    let
      match = builtins.match "-D([^=]+)=.*" flag;
    in
    if match == null then null else builtins.elemAt match 0;
  reservedMesonOptions = [
    "auto_features"
    "backend"
    "bindir"
    "buildtype"
    "b_staticpic"
    "c_args"
    "c_link_args"
    "cmake_prefix_path"
    "cpp_args"
    "cpp_link_args"
    "datadir"
    "debug"
    "default_both_libraries"
    "default_library"
    "errorlogs"
    "force_fallback_for"
    "includedir"
    "infodir"
    "install_umask"
    "layout"
    "libdir"
    "libexecdir"
    "licensedir"
    "localedir"
    "localstatedir"
    "mandir"
    "namingscheme"
    "optimization"
    "pkg_config_path"
    "pkgconfig.relocatable"
    "prefer_static"
    "prefix"
    "sbindir"
    "sharedstatedir"
    "strip"
    "sysconfdir"
    "unity"
    "unity_size"
    "warning_level"
    "werror"
    "wrap_mode"
  ];
  invalidMesonFlags = builtins.filter (
    flag: builtins.match "-D[A-Za-z0-9][A-Za-z0-9_.-]*=.*" flag == null
  ) mesonFlags;
  overriddenMesonOptions = builtins.filter (
    name:
    name != null
    && (
      builtins.elem name reservedMesonOptions
      || lib.hasPrefix "b_" name
      || lib.hasPrefix "build." name
      || lib.hasPrefix "host." name
    )
  ) (map mesonDefinitionName mesonFlags);
  protectedDerivationAttrs = [
    "AR"
    "AR_FOR_BUILD"
    "CC"
    "CC_FOR_BUILD"
    "CC_LD"
    "CC_LD_FOR_BUILD"
    "CFLAGS"
    "CFLAGS_FOR_BUILD"
    "CMAKE_PREFIX_PATH"
    "CMAKE_PREFIX_PATH_FOR_BUILD"
    "CPP"
    "CPP_FOR_BUILD"
    "CPPFLAGS"
    "CPPFLAGS_FOR_BUILD"
    "CXX"
    "CXX_FOR_BUILD"
    "CXX_LD"
    "CXX_LD_FOR_BUILD"
    "CXXFLAGS"
    "CXXFLAGS_FOR_BUILD"
    "DEVELOPER_DIR"
    "DESTDIR"
    "KRITA_IOS_TOOLCHAIN_IDENTITY"
    "LDFLAGS"
    "LDFLAGS_FOR_BUILD"
    "LD"
    "LD_FOR_BUILD"
    "MESON_BUILD_ROOT"
    "MESON_SOURCE_ROOT"
    "NIX_CFLAGS_COMPILE"
    "NIX_LDFLAGS"
    "PKG_CONFIG"
    "PKG_CONFIG_DIR"
    "PKG_CONFIG_DIR_FOR_BUILD"
    "PKG_CONFIG_FOR_BUILD"
    "PKG_CONFIG_LIBDIR"
    "PKG_CONFIG_LIBDIR_FOR_BUILD"
    "PKG_CONFIG_PATH"
    "PKG_CONFIG_PATH_FOR_BUILD"
    "PKG_CONFIG_SYSROOT_DIR"
    "PKG_CONFIG_SYSROOT_DIR_FOR_BUILD"
    "RANLIB"
    "RANLIB_FOR_BUILD"
    "SDKROOT"
    "SOURCE_DATE_EPOCH"
    "STRIP"
    "STRIP_FOR_BUILD"
    "ZERO_AR_DATE"
    "__contentAddressed"
    "__darwinAllowLocalNetworking"
    "__impureHostDeps"
    "__noChroot"
    "__sandboxProfile"
    "args"
    "buildInputs"
    "builder"
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
    "impureEnvVars"
    "installCheckPhase"
    "installPhase"
    "outputHash"
    "outputHashAlgo"
    "outputHashMode"
    "outputs"
    "patchPhase"
    "phases"
    "postPhases"
    "prePhases"
    "propagatedBuildInputs"
    "propagatedNativeBuildInputs"
    "strictDeps"
    "system"
    "unpackPhase"
  ];
  overriddenProtectedAttrs = builtins.filter (
    name: builtins.hasAttr name args
  ) protectedDerivationAttrs;
in
assert lib.assertMsg (lib.all lib.isDerivation targetDependencies)
  "iOS target dependencies must all be derivations";
assert lib.assertMsg (lib.all targetDependencyIsCompatible targetDependencyClosure)
  "iOS target dependency closures must be toolchain-independent or use the same pinned toolchain identity";
assert lib.assertMsg (overriddenProtectedAttrs == [ ])
  "iOS Meson packages may not override protected derivation attributes: ${lib.concatStringsSep ", " overriddenProtectedAttrs}";
assert lib.assertMsg (lib.all lib.isString mesonFlags) "iOS Meson mesonFlags must all be strings";
assert lib.assertMsg (invalidMesonFlags == [ ])
  "iOS Meson package flags must use the -Doption=value form: ${lib.concatStringsSep ", " invalidMesonFlags}";
assert lib.assertMsg (overriddenMesonOptions == [ ])
  "iOS Meson packages may not override reserved options: ${lib.concatStringsSep ", " overriddenMesonOptions}";
assert lib.assertMsg (lib.all lib.isDerivation nativeBuildInputs)
  "iOS Meson nativeBuildInputs must all be derivations";
assert lib.assertMsg (lib.all lib.isDerivation nativeInstallCheckInputs)
  "iOS Meson nativeInstallCheckInputs must all be derivations";
assert lib.assertMsg (lib.all lib.isString requiredPaths)
  "iOS Meson requiredPaths must all be strings";
assert lib.assertMsg (lib.all lib.isString staticArchives)
  "iOS Meson staticArchives must all be strings";
assert lib.assertMsg (lib.isAttrs passthru) "iOS Meson passthru must be an attribute set";
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
      coreutils
      gawk
      gnused
      meson
      ninja
      pkg-config
      stdenv.cc
    ]
    ++ nativeBuildInputs;

    nativeInstallCheckInputs = [
      coreutils
      file
      findutils
      gnugrep
    ]
    ++ nativeInstallCheckInputs;

    # Static target dependencies remain in the package closure, while their
    # pkg-config directories are exposed only to the cross-machine lookup.
    propagatedBuildInputs = targetDependencies;

    DEVELOPER_DIR = toolchain.developerDir;
    SDKROOT = toolchain.sdkRoot;
    KRITA_IOS_TOOLCHAIN_IDENTITY = toolchain.identity;
    SOURCE_DATE_EPOCH = "1";
    ZERO_AR_DATE = "1";

    # Xcode is available only to the target cross compiler. Native generators
    # use the Nix compiler declared in the separate native machine file.
    __impureHostDeps = toolchain.impureHostDeps;

    preConfigure = preConfigure + ''
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
      export PKG_CONFIG_PATH=
      export PKG_CONFIG_DIR=
      export PKG_CONFIG_LIBDIR=
      export PKG_CONFIG_SYSROOT_DIR=
      export CMAKE_PREFIX_PATH=
      export CMAKE_PREFIX_PATH_FOR_BUILD=
      export PKG_CONFIG_DIR_FOR_BUILD=
      export PKG_CONFIG_LIBDIR_FOR_BUILD=
      export PKG_CONFIG_PATH_FOR_BUILD=
      export PKG_CONFIG_SYSROOT_DIR_FOR_BUILD=
      unset \
        AR_FOR_BUILD CC_FOR_BUILD CC_LD_FOR_BUILD CFLAGS_FOR_BUILD \
        CPP_FOR_BUILD CPPFLAGS_FOR_BUILD CXX_FOR_BUILD CXX_LD_FOR_BUILD \
        CXXFLAGS_FOR_BUILD LDFLAGS_FOR_BUILD LD_FOR_BUILD \
        PKG_CONFIG_FOR_BUILD RANLIB_FOR_BUILD STRIP_FOR_BUILD
      mkdir -p "$NIX_BUILD_TOP/empty-pkg-config"

      cat > "$NIX_BUILD_TOP/ios-cross.ini" <<EOF
      [binaries]
      c = '${toolchain.cc}'
      cpp = '${toolchain.cxx}'
      ar = '${toolchain.ar}'
      ranlib = '${toolchain.ranlib}'
      strip = '${toolchain.strip}'
      pkg-config = '${pkg-config}/bin/pkg-config'

      [host_machine]
      system = 'darwin'
      kernel = 'xnu'
      subsystem = 'ios'
      cpu_family = 'aarch64'
      cpu = '${toolchain.architecture}'
      endian = 'little'

      [properties]
      needs_exe_wrapper = true
      pkg_config_libdir = ${mesonArray effectiveTargetPkgConfigDirs}

      [built-in options]
      c_args = ${mesonArray targetCompileArgs}
      cpp_args = ${mesonArray targetCompileArgs}
      c_link_args = ${mesonArray targetLinkArgs}
      cpp_link_args = ${mesonArray targetLinkArgs}
      cmake_prefix_path = ${mesonArray targetCMakePrefixPaths}
      pkg_config_path = []
      EOF

      # DEVELOPER_DIR would make the Nix compiler wrapper discover Xcode's
      # impure MacOSX SDK even after SDKROOT is cleared.
      cat > "$NIX_BUILD_TOP/native.ini" <<EOF
      [binaries]
      c = ${nativeToolCommand "${stdenv.cc}/bin/cc"}
      cpp = ${nativeToolCommand "${stdenv.cc}/bin/c++"}
      ar = ${nativeToolCommand "${stdenv.cc}/bin/ar"}
      ranlib = ${nativeToolCommand "${stdenv.cc}/bin/ranlib"}
      strip = ${nativeToolCommand "${stdenv.cc}/bin/strip"}
      pkg-config = '${pkg-config}/bin/pkg-config'

      [built-in options]
      cmake_prefix_path = []
      pkg_config_path = []
      EOF
    '';

    configurePhase = ''
      runHook preConfigure

      ${meson}/bin/meson setup build . \
        --cross-file="$NIX_BUILD_TOP/ios-cross.ini" \
        --native-file="$NIX_BUILD_TOP/native.ini" \
        --backend=ninja \
        --buildtype=release \
        --default-library=static \
        --auto-features=disabled \
        --wrap-mode=nofallback \
        --prefix="$out" \
        --bindir=bin \
        --sbindir=sbin \
        --libdir=lib \
        --libexecdir=libexec \
        --includedir=include \
        --datadir=share \
        --mandir=share/man \
        --localedir=share/locale \
        --sysconfdir=etc \
        --localstatedir=var \
        --sharedstatedir=com \
        -Db_staticpic=true \
        ${lib.escapeShellArgs mesonFlags}

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      ${meson}/bin/meson compile -C build -j "''${NIX_BUILD_CORES:-1}"
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      ${meson}/bin/meson install -C build --no-rebuild
      runHook postInstall
    '';

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
    "mesonFlags"
    "meta"
    "nativeBuildInputs"
    "nativeInstallCheckInputs"
    "passthru"
    "preConfigure"
    "requiredPaths"
    "staticArchives"
    "targetDependencies"
  ]
)

{
  lib,
  stdenv,
  stdenvNoCC,
  coreutils,
  file,
  findutils,
  gawk,
  gnugrep,
  gnused,
  gnumake,
  pkg-config,
  toolchain,
}:

{
  pname,
  version,
  src,
  patches ? [ ],
  configureFlags ? [ ],
  configureCache ? { },
  configureScript ? "./configure",
  makeTargets ? [ [ ] ],
  installTargets ? [ [ "install" ] ],
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
  targetIncludeFlags = lib.concatStringsSep " " (
    map (dependency: "-I${dependency}/include") targetDependencyClosure
  );
  targetLibraryFlags = lib.concatStringsSep " " (
    map (dependency: "-L${dependency}/lib") targetDependencyClosure
  );
  targetPkgConfigPath = lib.concatStringsSep ":" (
    lib.concatMap (dependency: [
      "${dependency}/lib/pkgconfig"
      "${dependency}/share/pkgconfig"
    ]) targetDependencyClosure
  );
  targetPkgConfigLibDir =
    if targetPkgConfigPath == "" then "$NIX_BUILD_TOP/empty-pkg-config" else targetPkgConfigPath;
  configureCacheExports = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") configureCache
  );
  validArgumentList = arguments: lib.isList arguments && lib.all lib.isString arguments;
  buildCommands = lib.concatStringsSep "\n" (
    map (target: ''
      make -j"''${NIX_BUILD_CORES:-1}" ${lib.escapeShellArgs target}
    '') makeTargets
  );
  installCommands = lib.concatStringsSep "\n" (
    map (target: "make ${lib.escapeShellArgs target}") installTargets
  );
  reservedConfigureOptions = [
    "--bindir"
    "--build"
    "--cache-file"
    "--datadir"
    "--datarootdir"
    "--docdir"
    "--dvidir"
    "--enable-shared"
    "--enable-static"
    "--exec-prefix"
    "--host"
    "--htmldir"
    "--includedir"
    "--infodir"
    "--libdir"
    "--libexecdir"
    "--localedir"
    "--localstatedir"
    "--mandir"
    "--oldincludedir"
    "--pdfdir"
    "--prefix"
    "--psdir"
    "--runstatedir"
    "--sbindir"
    "--sharedstatedir"
    "--srcdir"
    "--sysconfdir"
    "--target"
    "--disable-shared"
    "--disable-static"
  ];
  reservedConfigureAssignments = [
    "AR="
    "CC="
    "CC_FOR_BUILD="
    "CFLAGS="
    "CONFIG_SITE="
    "CPP="
    "CPPFLAGS="
    "CXX="
    "CXXFLAGS="
    "DSYMUTIL="
    "LD="
    "LDFLAGS="
    "LIPO="
    "NM="
    "NMEDIT="
    "OBJDUMP="
    "OTOOL="
    "PKG_CONFIG="
    "PKG_CONFIG_DIR="
    "PKG_CONFIG_LIBDIR="
    "PKG_CONFIG_PATH="
    "PKG_CONFIG_SYSROOT_DIR="
    "RANLIB="
    "STRIP="
  ];
  reservedConfigureFlags = builtins.filter (
    flag:
    flag == "-C"
    || flag == "--config-cache"
    || lib.any (option: flag == option || lib.hasPrefix "${option}=" flag) reservedConfigureOptions
    || lib.any (assignment: lib.hasPrefix assignment flag) reservedConfigureAssignments
  ) configureFlags;
  protectedDerivationAttrs = [
    "CONFIG_SITE"
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
assert lib.assertMsg (lib.all
  (dependency: (dependency.iosToolchainIdentity or null) == toolchain.identity)
  targetDependencyClosure
) "iOS target dependency closures must use the same pinned toolchain identity";
assert lib.assertMsg (overriddenProtectedAttrs == [ ])
  "iOS Autotools packages may not override protected derivation attributes: ${lib.concatStringsSep ", " overriddenProtectedAttrs}";
assert lib.assertMsg (lib.all lib.isString configureFlags)
  "Autotools configureFlags must all be strings";
assert lib.assertMsg (reservedConfigureFlags == [ ])
  "iOS Autotools packages may not override reserved configure options: ${lib.concatStringsSep ", " reservedConfigureFlags}";
assert lib.assertMsg (lib.all validArgumentList makeTargets)
  "Autotools makeTargets must be a list of argument lists";
assert lib.assertMsg (lib.all validArgumentList installTargets)
  "Autotools installTargets must be a list of argument lists";
assert lib.assertMsg (lib.all
  (name: builtins.match "[A-Za-z][A-Za-z0-9]*_cv_[A-Za-z0-9_]+" name != null)
  (lib.attrNames configureCache)
) "Autotools configureCache keys must use an Autoconf *_cv_* cache namespace";
assert lib.assertMsg (lib.all lib.isString (
  lib.attrValues configureCache
)) "Autotools configureCache values must all be strings";
assert lib.assertMsg (lib.all lib.isDerivation nativeBuildInputs)
  "iOS Autotools nativeBuildInputs must all be derivations";
assert lib.assertMsg (lib.all lib.isDerivation nativeInstallCheckInputs)
  "iOS Autotools nativeInstallCheckInputs must all be derivations";
assert lib.assertMsg (lib.isAttrs passthru) "iOS Autotools passthru must be an attribute set";
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
      file
      findutils
      gawk
      gnugrep
      gnused
      gnumake
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

    # Static target dependencies must remain in the output closure so an
    # individual package can be cached and consumed without a mutable prefix.
    propagatedBuildInputs = targetDependencies;

    DEVELOPER_DIR = toolchain.developerDir;
    SDKROOT = toolchain.sdkRoot;
    KRITA_IOS_TOOLCHAIN_IDENTITY = toolchain.identity;
    SOURCE_DATE_EPOCH = "1";
    ZERO_AR_DATE = "1";

    # Xcode is the only non-store target build input. Host probes use the pure
    # native stdenv compiler and explicitly discard the iPhoneOS SDKROOT.
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

      # xcodebuild starts IDE frameworks and crashes inside a Nix Darwin
      # sandbox. Read the canonical XML plists instead.
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

      ios_target_flags="-arch ${toolchain.architecture} -isysroot ${toolchain.sdkRoot} -miphoneos-version-min=${toolchain.deploymentTarget}"

      export CC="${toolchain.cc}"
      export CXX="${toolchain.cxx}"
      export CPP="${toolchain.cc} -E $ios_target_flags"
      export AR="${toolchain.ar}"
      export RANLIB="${toolchain.ranlib}"
      export STRIP="${toolchain.strip}"
      export LD="${toolchain.toolchainDir}/ld"
      export NM="${toolchain.toolchainDir}/nm"
      export OBJDUMP="${toolchain.toolchainDir}/objdump"
      export DSYMUTIL="${toolchain.toolchainDir}/dsymutil"
      export NMEDIT="${toolchain.toolchainDir}/nmedit"
      export LIPO="${toolchain.lipo}"
      export OTOOL="${toolchain.otool}"

      # Some Autoconf projects probe build-machine executables even while
      # cross compiling. Keep those probes pure and away from the iPhone SDK.
      export CC_FOR_BUILD="${coreutils}/bin/env -u SDKROOT ${stdenv.cc}/bin/cc"

      export SOURCE_DATE_EPOCH=1
      export CFLAGS="$ios_target_flags -fPIC -ffile-prefix-map=$NIX_BUILD_TOP=/build -fdebug-prefix-map=$NIX_BUILD_TOP=/build"
      export CXXFLAGS="$CFLAGS"
      export CPPFLAGS="${targetIncludeFlags}"
      export LDFLAGS="$ios_target_flags ${targetLibraryFlags}"

      # pkg-config is a host tool, but it may only resolve declared iOS
      # target dependencies. An SDK sysroot must not prefix Nix store paths.
      export PKG_CONFIG="${pkg-config}/bin/pkg-config"
      export PKG_CONFIG_PATH=
      export PKG_CONFIG_DIR=
      mkdir -p "$NIX_BUILD_TOP/empty-pkg-config"
      export PKG_CONFIG_LIBDIR="${targetPkgConfigLibDir}"
      export PKG_CONFIG_SYSROOT_DIR=
    '';

    configurePhase = ''
      ${configureCacheExports}

      runHook preConfigure

      ${lib.escapeShellArg configureScript} \
        --build=${stdenvNoCC.buildPlatform.config} \
        --host=arm-apple-darwin \
        --prefix="$out" \
        --libdir="$out/lib" \
        --disable-shared \
        --enable-static \
        ${lib.escapeShellArgs configureFlags}

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      ${buildCommands}
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      ${installCommands}
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
    "configureCache"
    "configureFlags"
    "configureScript"
    "installTargets"
    "makeTargets"
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

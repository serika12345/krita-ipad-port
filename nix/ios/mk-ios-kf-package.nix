{
  diffutils,
  findutils,
  frameworkDefaults,
  gettext,
  gnugrep,
  kfHostTooling,
  lib,
  mkIOSCMakePackage,
  python3,
  qtbase-ios,
  qtXcrunShim,
  toolchain,
}:

{
  packageSpec,
  sourcePackage,
  targetPackageDependencies ? [ ],
  frameworkDependencies ? [ ],
  patches ? [ ],
  meta ? { },
}:

let
  inherit (packageSpec) artifact_contract configure_locks nix_dependencies;

  hostEcm = kfHostTooling.hostEcm;
  hostQt = kfHostTooling.hostQt;
  hostQtTools = kfHostTooling.hostQtTools;
  hostToolingPrefix = kfHostTooling.kf6HostTooling;

  cmakeBoolean = value: if value then "ON" else "OFF";
  sorted = values: lib.sort builtins.lessThan values;
  sortedUnique = values: sorted (lib.unique values);

  dependencyName =
    dependency:
    if dependency ? iosFrameworkName then
      dependency.iosFrameworkName
    else if dependency ? iosTargetPackageName then
      dependency.iosTargetPackageName
    else if dependency ? pname && lib.hasSuffix "-ios" dependency.pname then
      lib.removeSuffix "-ios" dependency.pname
    else
      null;

  targetPackageDependencyNames = map dependencyName targetPackageDependencies;
  frameworkDependencyNames = map dependencyName frameworkDependencies;

  nativeToolRoots = {
    ecm = hostEcm;
    gettext = gettext;
    kconfig = hostToolingPrefix;
    python3 = python3;
    qtbase = hostQt;
    qttools = hostQtTools;
  };
  nativeToolNames = nix_dependencies.native_tools;
  usesKConfigHostTooling = builtins.elem "kconfig" nativeToolNames;
  selectedNativeTools = map (name: nativeToolRoots.${name}) nativeToolNames;
  explicitPathNativeToolNames = [
    "ecm"
    "kconfig"
    "qtbase"
    "qttools"
  ];
  selectedExplicitPathNativeToolNames = builtins.filter (
    name: builtins.elem name explicitPathNativeToolNames
  ) nativeToolNames;
  selectedNativeSetupToolNames = builtins.filter (
    name: !builtins.elem name explicitPathNativeToolNames
  ) nativeToolNames;
  selectedNativeSetupTools = map (name: nativeToolRoots.${name}) selectedNativeSetupToolNames;

  hostExecutablePath =
    contract:
    let
      components = lib.splitString "/" contract;
      rootName = builtins.head components;
      relativePath = lib.concatStringsSep "/" (builtins.tail components);
    in
    assert lib.assertMsg (builtins.hasAttr rootName nativeToolRoots)
      "KF6 host executable ${contract} names an unsupported native input";
    assert lib.assertMsg (builtins.elem rootName nativeToolNames)
      "KF6 host executable ${contract} is not declared in nix_dependencies.native_tools";
    "${nativeToolRoots.${rootName}}/${relativePath}";
  hostExecutables = map hostExecutablePath packageSpec.host_tools.executables;

  commonCacheStringLocks = frameworkDefaults.cache_string_locks;
  moduleCacheStringLocks = configure_locks.cache_string_locks or { };
  cacheStringLocks = commonCacheStringLocks // moduleCacheStringLocks;
  commonCacheBooleanLocks = frameworkDefaults.cache_boolean_locks;
  moduleCacheBooleanLocks = configure_locks.cache_boolean_locks or { };
  cacheBooleanLocks = commonCacheBooleanLocks // moduleCacheBooleanLocks;

  builderOwnedCacheStrings = [
    "CMAKE_BUILD_TYPE"
    "CMAKE_OSX_ARCHITECTURES"
    "CMAKE_OSX_DEPLOYMENT_TARGET"
    "CMAKE_OSX_SYSROOT"
    "CMAKE_SYSTEM_NAME"
  ];
  kdeInstallDirCacheStrings = [
    "KDE_INSTALL_INCLUDEDIR"
    "KDE_INSTALL_LIBDIR"
    "KDE_INSTALL_LIBEXECDIR"
  ];
  projectCacheStringLocks = removeAttrs cacheStringLocks builderOwnedCacheStrings;
  cacheStringFlags = lib.mapAttrsToList (
    name: value: "-D${name}:STRING=${value}"
  ) projectCacheStringLocks;
  cacheBooleanFlags = lib.mapAttrsToList (
    name: value: "-D${name}:BOOL=${cmakeBoolean value}"
  ) cacheBooleanLocks;
  allLockFlags =
    lib.mapAttrsToList (name: value: "-D${name}=${value}") cacheStringLocks
    ++ lib.mapAttrsToList (name: value: "-D${name}=${cmakeBoolean value}") cacheBooleanLocks;

  cacheStringCheckScript =
    lib.concatStrings (
      lib.mapAttrsToList (name: value: ''
        check_cache_string ${lib.escapeShellArg name} ${lib.escapeShellArg value}
      '') (removeAttrs cacheStringLocks kdeInstallDirCacheStrings)
    )
    + lib.concatStrings (
      lib.mapAttrsToList (name: value: ''
        check_cache_string ${lib.escapeShellArg name} "$out/${value}"
      '') (lib.getAttrs kdeInstallDirCacheStrings cacheStringLocks)
    );
  cacheBooleanCheckScript = lib.concatStrings (
    lib.mapAttrsToList (name: value: ''
      check_cache_boolean ${lib.escapeShellArg name} ${lib.escapeShellArg (cmakeBoolean value)}
    '') cacheBooleanLocks
  );

  requiredQtComponents = configure_locks.required_qt_components;
  optionalQtComponents = configure_locks.optional_qt_components or [ ];
  allQtComponents = lib.unique (requiredQtComponents ++ optionalQtComponents);
  qtComponentFlags = map (
    component: "-DQt6${component}_DIR:PATH=${qtbase-ios}/lib/cmake/Qt6${component}"
  ) allQtComponents;
  qtComponentCheckScript = lib.concatMapStrings (component: ''
    component_config=${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6${component}/Qt6${component}Config.cmake"}
    if ! test -f "$component_config"; then
      echo "error: target Qt omits audited component ${component}" >&2
      exit 1
    fi
    check_cache_string ${lib.escapeShellArg "Qt6${component}_DIR"} \
      ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6${component}"}
  '') allQtComponents;

  hostExecutableCheckScript = lib.concatMapStrings (hostExecutable: ''
    if ! test -x ${lib.escapeShellArg hostExecutable}; then
      echo "error: required native KF6 build tool is missing: ${hostExecutable}" >&2
      exit 1
    fi
  '') hostExecutables;

  staticArchives = artifact_contract.static_archives;
  standaloneObjects = artifact_contract.standalone_objects;
  requiredPaths = lib.unique (
    (packageSpec.required_paths or [ ])
    ++ (artifact_contract.required_paths or [ ])
    ++ (artifact_contract.required_interface_sources or [ ])
    ++ (artifact_contract.required_build_macros or [ ])
    ++ staticArchives
    ++ standaloneObjects
  );
  forbiddenPaths = lib.unique (
    frameworkDefaults.forbidden.paths ++ (artifact_contract.forbidden_paths or [ ])
  );

  installManifest = artifact_contract.install_manifest;
  translationInventory = artifact_contract.translation_inventory;
  translationExtensionCounts = translationInventory.file_counts_by_extension;
  translationExtensionTotal = lib.foldl' (total: count: total + count) 0 (
    builtins.attrValues translationExtensionCounts
  );
  expectedTranslationExtensionScript = lib.concatStrings (
    lib.mapAttrsToList (extension: expectedCount: ''
      actual_extension_count="$(awk -v suffix=${lib.escapeShellArg ".${extension}"} '
        length($0) >= length(suffix) && substr($0, length($0) - length(suffix) + 1) == suffix { count++ }
        END { print count + 0 }
      ' "$translation_inventory")"
      if test "$actual_extension_count" -ne ${toString expectedCount}; then
        echo "error: ${packageSpec.name} translation extension .${extension} count is $actual_extension_count; expected ${toString expectedCount}" >&2
        exit 1
      fi
    '') translationExtensionCounts
  );

  featureLocks = configure_locks.feature_locks or { };
  enabledFeatures = featureLocks.enabled or [ ];
  disabledFeatures = featureLocks.disabled or [ ];
  featureEvidence = featureLocks.evidence or { };
  featureCacheBooleanEvidence = featureEvidence.cache_booleans or { };
  featureDisabledDependencyGateEvidence = featureEvidence.disabled_dependency_gates or { };
  featureArtifactEvidence = featureEvidence.artifact_contract or [ ];
  lockedFeatureNames = enabledFeatures ++ disabledFeatures;
  featureEvidenceNames =
    builtins.attrNames featureCacheBooleanEvidence
    ++ builtins.attrNames featureDisabledDependencyGateEvidence
    ++ featureArtifactEvidence;
  disabledDependencyGateCheckScript = lib.concatStrings (
    lib.mapAttrsToList (
      feature: gate:
      lib.concatMapStrings (dependency: ''
        check_disabled_dependency_gate \
          "$out/${gate.path}" \
          ${lib.escapeShellArg dependency} \
          ${lib.escapeShellArg feature}
      '') gate.dependencies
    ) featureDisabledDependencyGateEvidence
  );

  manifestPatchNames = map builtins.baseNameOf (packageSpec.patches or [ ]);
  suppliedPatchNames = map (patch: builtins.baseNameOf (toString patch)) patches;

  sourceArchive = toString sourcePackage.src;
  expectedSourceArchiveName = "${packageSpec.name}-${packageSpec.version}.tar.xz";

  allTargetDependencies = [ qtbase-ios ] ++ targetPackageDependencies ++ frameworkDependencies;
  dependencyEntry = dependency: {
    key = dependency.outPath;
    value = dependency;
  };
  allowedTargetDependencyClosure = map (entry: entry.value) (
    builtins.genericClosure {
      startSet = map dependencyEntry allTargetDependencies;
      operator = entry: map dependencyEntry (entry.value.propagatedBuildInputs or [ ]);
    }
  );
  allowedTargetStorePaths = map toString allowedTargetDependencyClosure;

  nativeReferencePaths = lib.unique (
    [
      sourceArchive
      (toString qtXcrunShim)
    ]
    ++ lib.optional usesKConfigHostTooling (toString kfHostTooling.kconfigCompiler)
    ++ map toString selectedNativeTools
  );
  forbiddenLiteralPaths = lib.unique (
    frameworkDefaults.forbidden.reference_literals ++ nativeReferencePaths
  );
  forbiddenLiteralCheckScript = lib.concatMapStrings (literal: ''
    if grep -R -a -l -F ${lib.escapeShellArg literal} "$out"; then
      echo "error: ${packageSpec.name} output contains forbidden reference: ${literal}" >&2
      exit 1
    fi
  '') forbiddenLiteralPaths;
  forbiddenPatternCheckScript = lib.concatMapStrings (pattern: ''
    if grep -R -a -l -E ${lib.escapeShellArg pattern} "$out"; then
      echo "error: ${packageSpec.name} output matches forbidden reference pattern: ${pattern}" >&2
      exit 1
    fi
  '') frameworkDefaults.forbidden.reference_patterns;

  writeExpectedLines = fileName: values: ''
    ${fileName}="$NIX_BUILD_TOP/${packageSpec.name}-${fileName}.expected"
    : > "${"$"}${fileName}"
    ${lib.concatMapStrings (value: ''
      printf '%s\n' ${lib.escapeShellArg value} >> "${"$"}${fileName}"
    '') values}
  '';

  isKI18n = packageSpec.name == "ki18n";
  libintlDependencies = builtins.filter (
    dependency: dependencyName dependency == "libintl"
  ) targetPackageDependencies;
  ki18nPostInstallCheck = lib.optionalString isKI18n ''
    ki18n_macros="$out/lib/cmake/KF6I18n/KF6I18nMacros.cmake"
    if test "$(grep -Fxc '    set(KI18N_PYTHON_EXECUTABLE "python3")' "$ki18n_macros" || true)" -ne 1; then
      echo "error: installed KI18n fallback must remain the portable command python3" >&2
      exit 1
    fi

    ki18n_targets="$out/lib/cmake/KF6I18n/KF6I18nTargets.cmake"
    if ! grep -Fq ${lib.escapeShellArg "${builtins.head libintlDependencies}/lib/libintl.a"} "$ki18n_targets"; then
      echo "error: KI18n target metadata omits its pinned target libintl archive" >&2
      exit 1
    fi
  '';
in
assert lib.assertMsg (
  !(packageSpec.host_only or false)
) "mkIOSKFPackage cannot build the host-only ECM manifest entry";
assert lib.assertMsg (
  lib.isAttrs sourcePackage
  && sourcePackage ? src
  && sourcePackage ? version
  && sourcePackage ? meta
  && sourcePackage.meta ? license
) "KF6 sourcePackage must expose the audited src/version/license contract";
assert lib.assertMsg (sourcePackage.version == packageSpec.version)
  "KF6 ${packageSpec.name} source version ${sourcePackage.version} does not match manifest ${packageSpec.version}";
assert lib.assertMsg (
  packageSpec.version == frameworkDefaults.host_inputs.ecm.version
) "KF6 ${packageSpec.name} version does not match the pinned Frameworks version";
assert lib.assertMsg (
  packageSpec.source_flake_attr == packageSpec.source.flake_attr
) "KF6 ${packageSpec.name} legacy and structured source outputs disagree";
assert lib.assertMsg (
  packageSpec.source.flake_attr == "source-${packageSpec.name}"
) "KF6 ${packageSpec.name} source flake output is not canonical";
assert lib.assertMsg (
  packageSpec.source.archive_name == expectedSourceArchiveName
) "KF6 ${packageSpec.name} source archive name does not match its version";
assert lib.assertMsg (
  builtins.match "[0-9a-f]{64}" packageSpec.source.archive_sha256 != null
) "KF6 ${packageSpec.name} source archive must have a flat hexadecimal SHA-256";
assert lib.assertMsg (
  manifestPatchNames == suppliedPatchNames
) "KF6 ${packageSpec.name} supplied patches differ from its manifest";
assert lib.assertMsg (lib.all lib.isDerivation targetPackageDependencies)
  "KF6 targetPackageDependencies must all be derivations";
assert lib.assertMsg (lib.all lib.isDerivation frameworkDependencies)
  "KF6 frameworkDependencies must all be derivations";
assert lib.assertMsg (
  !builtins.elem null targetPackageDependencyNames
) "KF6 target package dependencies must expose an -ios pname or iosTargetPackageName";
assert lib.assertMsg (
  !builtins.elem null frameworkDependencyNames
) "KF6 framework dependencies must expose iosFrameworkName";
assert lib.assertMsg (
  sorted targetPackageDependencyNames == sortedUnique targetPackageDependencyNames
) "KF6 ${packageSpec.name} target package dependencies contain duplicates";
assert lib.assertMsg (
  sorted frameworkDependencyNames == sortedUnique frameworkDependencyNames
) "KF6 ${packageSpec.name} framework dependencies contain duplicates";
assert lib.assertMsg (
  sorted targetPackageDependencyNames == sorted nix_dependencies.target_packages
) "KF6 ${packageSpec.name} target package dependencies differ from the manifest";
assert lib.assertMsg (
  sorted frameworkDependencyNames == sorted nix_dependencies.frameworks
) "KF6 ${packageSpec.name} framework dependencies differ from the manifest";
assert lib.assertMsg (
  nix_dependencies.qt_modules == [ "qtbase" ]
) "KF6 ${packageSpec.name} target Qt dependency must be exactly qtbase";
assert lib.assertMsg (
  packageSpec.dependencies
  == (if nix_dependencies.frameworks == [ ] then [ "ecm" ] else nix_dependencies.frameworks)
) "KF6 ${packageSpec.name} legacy dependency graph differs from its Nix dependency graph";
assert lib.assertMsg (lib.all (dependency: dependency.version == packageSpec.version)
  frameworkDependencies
) "KF6 ${packageSpec.name} framework dependencies must use the same pinned version";
assert lib.assertMsg (
  sorted nativeToolNames == sortedUnique nativeToolNames
) "KF6 ${packageSpec.name} native tool manifest contains duplicates";
assert lib.assertMsg
  (
    sorted (selectedExplicitPathNativeToolNames ++ selectedNativeSetupToolNames)
    == sorted nativeToolNames
    && lib.intersectLists selectedExplicitPathNativeToolNames selectedNativeSetupToolNames == [ ]
  )
  "KF6 ${packageSpec.name} native tools must be partitioned between explicit paths and setup inputs";
assert lib.assertMsg (lib.all
  (
    name:
    builtins.elem name [
      "gettext"
      "python3"
    ]
  )
  selectedNativeSetupToolNames
) "KF6 ${packageSpec.name} may activate setup hooks only for command-line translation tools";
assert lib.assertMsg (usesKConfigHostTooling == builtins.elem "kconfig" nix_dependencies.frameworks)
  "KF6 ${packageSpec.name} must declare native KConfig tooling exactly when it consumes target KConfig";
assert lib.assertMsg (lib.all (
  name: builtins.hasAttr name nativeToolRoots
) nativeToolNames) "KF6 ${packageSpec.name} declares an unsupported native tool";
assert lib.assertMsg (
  builtins.attrNames frameworkDefaults.host_inputs == [
    "ecm"
    "gettext"
    "kconfig"
    "python3"
    "qtbase"
    "qttools"
  ]
) "KF6 host input manifest set changed";
assert lib.assertMsg (
  frameworkDefaults.host_inputs.ecm == {
    flake_attr = "host-ecm";
    version = hostEcm.version;
  }
) "KF6 host ECM lock differs from the injected derivation";
assert lib.assertMsg (
  frameworkDefaults.host_inputs.qtbase == {
    flake_attr = "host-qtbase";
    version = hostQt.version;
  }
) "KF6 host Qt lock differs from the injected derivation";
assert lib.assertMsg (
  frameworkDefaults.host_inputs.qttools == {
    flake_attr = "host-qttools";
    version = hostQtTools.version;
  }
) "KF6 host Qt tools lock differs from the injected derivation";
assert lib.assertMsg (
  frameworkDefaults.host_inputs.gettext == {
    nixpkgs_attr = "gettext";
    version = gettext.version;
  }
) "KF6 host gettext lock differs from nixpkgs";
assert lib.assertMsg (
  frameworkDefaults.host_inputs.kconfig == {
    flake_attr = "kf6-host-tooling";
    version = hostToolingPrefix.version;
  }
) "KF6 host KConfig tooling lock differs from the injected derivation";
assert lib.assertMsg (
  frameworkDefaults.host_inputs.python3 == {
    nixpkgs_attr = "python3";
    version = python3.version;
  }
) "KF6 host Python lock differs from nixpkgs";
assert lib.assertMsg (
  frameworkDefaults.qt_version == qtbase-ios.version
) "KF6 target Qt version differs from qtbase-ios";
assert lib.assertMsg (
  frameworkDefaults.qt_version == hostQt.version
) "KF6 host and target Qt versions differ";
assert lib.assertMsg (
  frameworkDefaults.sdk_lock == {
    allow_absolute_path = false;
    cmake_cache_value = "iphoneos";
    name = "iphoneos";
  }
) "KF6 SDK manifest must preserve the logical iphoneos name";
assert lib.assertMsg (
  frameworkDefaults.languages == [
    "C"
    "CXX"
    "OBJC"
    "OBJCXX"
  ]
) "KF6 target language lock changed";
assert lib.assertMsg (
  lib.getAttrs builderOwnedCacheStrings commonCacheStringLocks == {
    CMAKE_BUILD_TYPE = "Release";
    CMAKE_OSX_ARCHITECTURES = toolchain.architecture;
    CMAKE_OSX_DEPLOYMENT_TARGET = toolchain.deploymentTarget;
    CMAKE_OSX_SYSROOT = frameworkDefaults.sdk_lock.cmake_cache_value;
    CMAKE_SYSTEM_NAME = "iOS";
  }
) "KF6 common cache strings disagree with the common iOS builder";
assert lib.assertMsg (
  lib.getAttrs kdeInstallDirCacheStrings commonCacheStringLocks == {
    KDE_INSTALL_INCLUDEDIR = "include";
    KDE_INSTALL_LIBDIR = "lib";
    KDE_INSTALL_LIBEXECDIR = "libexec";
  }
) "KF6 install directory locks must remain relocatable inputs";
assert lib.assertMsg (lib.all (flag: builtins.elem flag allLockFlags) (
  packageSpec.cmake_args or [ ]
)) "KF6 ${packageSpec.name} legacy CMake arguments are not represented by cache locks";
assert lib.assertMsg (lib.all lib.isString requiredQtComponents)
  "KF6 ${packageSpec.name} required Qt components must be strings";
assert lib.assertMsg (lib.all lib.isString optionalQtComponents)
  "KF6 ${packageSpec.name} optional Qt components must be strings";
assert lib.assertMsg (
  lib.intersectLists requiredQtComponents optionalQtComponents == [ ]
) "KF6 ${packageSpec.name} Qt component cannot be both required and optional";
assert lib.assertMsg (
  artifact_contract.exact_static_archive_set && artifact_contract.exact_standalone_object_set
) "KF6 ${packageSpec.name} Apple object sets must be exact";
assert lib.assertMsg (
  builtins.length staticArchives == artifact_contract.expected_counts.static_archives
) "KF6 ${packageSpec.name} static archive count differs from the manifest";
assert lib.assertMsg (
  builtins.length standaloneObjects == artifact_contract.expected_counts.standalone_objects
) "KF6 ${packageSpec.name} standalone object count differs from the manifest";
assert lib.assertMsg (
  staticArchives == packageSpec.artifacts
) "KF6 ${packageSpec.name} legacy artifact list differs from the static archive contract";
assert lib.assertMsg (
  staticArchives == lib.unique staticArchives
) "KF6 ${packageSpec.name} static archive contract contains duplicates";
assert lib.assertMsg (
  standaloneObjects == lib.unique standaloneObjects
) "KF6 ${packageSpec.name} standalone object contract contains duplicates";
assert lib.assertMsg (
  installManifest.relative_path_count > 0
  && builtins.match "[0-9a-f]{64}" installManifest.sorted_relative_path_sha256 != null
) "KF6 ${packageSpec.name} install manifest inventory is invalid";
assert lib.assertMsg (
  translationInventory.relative_path_count >= 0
  && builtins.match "[0-9a-f]{64}" translationInventory.sorted_relative_path_sha256 != null
) "KF6 ${packageSpec.name} translation inventory is invalid";
assert lib.assertMsg (
  translationExtensionTotal == translationInventory.relative_path_count
) "KF6 ${packageSpec.name} translation extension counts do not cover the exact inventory";
assert lib.assertMsg (
  lib.intersectLists enabledFeatures disabledFeatures == [ ]
) "KF6 ${packageSpec.name} enables and disables the same feature";
assert lib.assertMsg (
  builtins.length lockedFeatureNames == builtins.length (lib.unique lockedFeatureNames)
) "KF6 ${packageSpec.name} feature lock contains duplicates";
assert lib.assertMsg (
  builtins.length featureEvidenceNames == builtins.length (lib.unique featureEvidenceNames)
  && sorted featureEvidenceNames == sorted lockedFeatureNames
) "KF6 ${packageSpec.name} must provide exactly one verification path for every feature lock";
assert lib.assertMsg (lib.all
  (
    feature:
    let
      cacheVariable = featureCacheBooleanEvidence.${feature};
    in
    lib.isString cacheVariable
    && builtins.hasAttr cacheVariable cacheBooleanLocks
    && cacheBooleanLocks.${cacheVariable} == builtins.elem feature enabledFeatures
  )
  (builtins.attrNames featureCacheBooleanEvidence)
) "KF6 ${packageSpec.name} feature cache evidence disagrees with its boolean cache lock";
assert lib.assertMsg (lib.all
  (
    feature:
    let
      gate = featureDisabledDependencyGateEvidence.${feature};
    in
    builtins.elem feature disabledFeatures
    && lib.isAttrs gate
    && gate ? path
    && lib.isString gate.path
    && !lib.hasPrefix "/" gate.path
    && !lib.hasInfix ".." gate.path
    && gate ? dependencies
    && gate.dependencies != [ ]
    && lib.all lib.isString gate.dependencies
    && builtins.length gate.dependencies == builtins.length (lib.unique gate.dependencies)
  )
  (builtins.attrNames featureDisabledDependencyGateEvidence)
) "KF6 ${packageSpec.name} disabled dependency-gate evidence is invalid";
assert lib.assertMsg (lib.all (
  feature:
  builtins.elem feature enabledFeatures
  && builtins.elem feature [
    "libintl"
    "translations"
  ]
) featureArtifactEvidence) "KF6 ${packageSpec.name} artifact-backed feature evidence is invalid";
assert lib.assertMsg (
  !builtins.elem "translations" enabledFeatures || translationInventory.relative_path_count > 0
) "KF6 ${packageSpec.name} enables translations but pins an empty translation inventory";
assert lib.assertMsg (
  !builtins.elem "libintl" enabledFeatures || targetPackageDependencyNames == [ "libintl" ]
) "KF6 ${packageSpec.name} libintl feature does not have the target dependency";
assert lib.assertMsg (
  !isKI18n
  || (
    moduleCacheStringLocks.FALLBACK_KI18N_PYTHON_EXECUTABLE == "python3"
    && builtins.length libintlDependencies == 1
  )
) "KI18n must use portable python3 fallback and exactly one target libintl";
assert lib.assertMsg (
  frameworkDefaults.forbidden.paths == [
    "bin"
    "libexec"
    "qml"
  ]
) "KF6 forbidden top-level path contract changed";
assert lib.assertMsg (
  frameworkDefaults.forbidden.path_globs == [
    "**/*.app"
    "**/*.dylib"
    "**/*.framework"
    "**/*.so"
    "**/*.so.*"
    "doc/**"
    "examples/**"
    "tests/**"
  ]
) "KF6 forbidden output glob contract changed";
assert lib.assertMsg (
  frameworkDefaults.forbidden.reference_environment_values == [ "NIX_BUILD_TOP" ]
) "KF6 forbidden environment-reference contract changed";
mkIOSCMakePackage {
  pname = "${packageSpec.name}-ios";
  inherit (packageSpec) version;
  src = sourcePackage.src;
  inherit patches;

  targetDependencies = allTargetDependencies;

  appleSdkResolver = qtXcrunShim;
  cmakeToolchainFile = "${qtbase-ios}/lib/cmake/Qt6/qt.toolchain.cmake";
  enableFullAppleToolchain = true;
  inspectAllAppleObjects = true;
  tryCompileTargetType = "STATIC_LIBRARY";

  nativeBuildInputs = lib.unique (
    [
      diffutils
      findutils
      gnugrep
    ]
    # Qt host tools are selected only through the absolute CMake paths below.
    # Their setup hooks would add macOS Qt and its closure to target searches.
    ++ selectedNativeSetupTools
  );
  nativeInstallCheckInputs = [ diffutils ];

  cmakeFlags = [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG:BOOL=ON"
    "-DCMAKE_FIND_PACKAGE_TARGETS_GLOBAL:BOOL=ON"
    "-DCMAKE_FIND_USE_PACKAGE_REGISTRY:BOOL=OFF"
    "-DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY:BOOL=OFF"
    "-DCMAKE_IGNORE_PREFIX_PATH:STRING=/opt/homebrew;/usr/local"
    "-DECM_DIR:PATH=${hostEcm}/share/ECM/cmake"
    "-DQT_APPLE_SDK:STRING=${frameworkDefaults.sdk_lock.name}"
    "-DQT_HOST_PATH:PATH=${hostQt}"
    "-DQT_HOST_PATH_CMAKE_DIR:PATH=${hostQt}/lib/cmake"
    "-DQT_XCRUN:FILEPATH=${qtXcrunShim}/bin/xcrun"
    "-DQt6_DIR:PATH=${qtbase-ios}/lib/cmake/Qt6"
    "-DQt6HostInfo_DIR:PATH=${hostQt}/lib/cmake/Qt6HostInfo"
    "-DQt6CoreTools_DIR:PATH=${hostQt}/lib/cmake/Qt6CoreTools"
    "-DQt6GuiTools_DIR:PATH=${hostQt}/lib/cmake/Qt6GuiTools"
    "-DQt6WidgetsTools_DIR:PATH=${hostQt}/lib/cmake/Qt6WidgetsTools"
  ]
  ++ lib.optional usesKConfigHostTooling "-DKF6_HOST_TOOLING:PATH=${hostToolingPrefix}"
  ++ lib.optional (builtins.elem "qttools" nativeToolNames) "-DQt6LinguistTools_DIR:PATH=${hostQtTools}/lib/cmake/Qt6LinguistTools"
  ++ qtComponentFlags
  ++ cacheStringFlags
  ++ cacheBooleanFlags;

  inherit requiredPaths;
  staticArchives = [ ];

  postUnpack = ''
    source_archive=${lib.escapeShellArg sourceArchive}
    if ! test -f "$source_archive" || test -L "$source_archive"; then
      echo "error: KF6 source is not a regular flat-hashed archive: $source_archive" >&2
      exit 1
    fi
    case "$source_archive" in
      *-${packageSpec.source.archive_name}) ;;
      *)
        echo "error: unexpected ${packageSpec.name} source archive: $source_archive" >&2
        exit 1
        ;;
    esac
    actual_source_sha256="$(sha256sum "$source_archive" | cut -d ' ' -f 1)"
    if test "$actual_source_sha256" != ${lib.escapeShellArg packageSpec.source.archive_sha256}; then
      echo "error: ${packageSpec.name} source SHA-256 is $actual_source_sha256; expected ${packageSpec.source.archive_sha256}" >&2
      exit 1
    fi
  '';

  postConfigure = ''
    check_cache_string() {
      name="$1"
      expected="$2"
      count="$(grep -Ec "^$name:[^=]*=" CMakeCache.txt || true)"
      if test "$count" -ne 1; then
        echo "error: expected one ${packageSpec.name} cache entry for $name; found $count" >&2
        exit 1
      fi
      actual="$(sed -n "s/^$name:[^=]*=//p" CMakeCache.txt)"
      if test "$actual" != "$expected"; then
        echo "error: ${packageSpec.name} cache $name is '$actual'; expected '$expected'" >&2
        exit 1
      fi
    }

    check_cache_boolean() {
      name="$1"
      expected="$2"
      count="$(grep -Ec "^$name:[^=]*=" CMakeCache.txt || true)"
      if test "$count" -ne 1; then
        echo "error: expected one ${packageSpec.name} boolean cache entry for $name; found $count" >&2
        exit 1
      fi
      actual="$(sed -n "s/^$name:[^=]*=//p" CMakeCache.txt)"
      case "$actual" in
        1 | ON | TRUE | YES) actual=ON ;;
        0 | OFF | FALSE | NO) actual=OFF ;;
        *)
          echo "error: ${packageSpec.name} cache $name has non-boolean value '$actual'" >&2
          exit 1
          ;;
      esac
      if test "$actual" != "$expected"; then
        echo "error: ${packageSpec.name} cache $name is '$actual'; expected '$expected'" >&2
        exit 1
      fi
    }

    ${cacheStringCheckScript}
    ${cacheBooleanCheckScript}

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
    check_cache_string CMAKE_TOOLCHAIN_FILE \
      ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6/qt.toolchain.cmake"}
    check_cache_boolean CMAKE_FIND_PACKAGE_PREFER_CONFIG ON
    check_cache_boolean CMAKE_FIND_PACKAGE_TARGETS_GLOBAL ON
    check_cache_boolean CMAKE_FIND_USE_PACKAGE_REGISTRY OFF
    check_cache_boolean CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY OFF
    check_cache_string CMAKE_IGNORE_PREFIX_PATH '/opt/homebrew;/usr/local'
    check_cache_string ECM_DIR ${lib.escapeShellArg "${hostEcm}/share/ECM/cmake"}
    ${lib.optionalString usesKConfigHostTooling ''
      check_cache_string KF6_HOST_TOOLING ${lib.escapeShellArg (toString hostToolingPrefix)}
      test -f ${lib.escapeShellArg "${hostToolingPrefix}/KF6Config/KF6ConfigCompilerTargets.cmake"}
      test -x ${lib.escapeShellArg "${kfHostTooling.kconfigCompiler}/libexec/kf6/kconfig_compiler_kf6"}
    ''}
    ${lib.optionalString (!usesKConfigHostTooling) ''
      if grep -Eq '^KF6_HOST_TOOLING:[^=]*=' CMakeCache.txt; then
        echo "error: ${packageSpec.name} received undeclared native KConfig tooling" >&2
        exit 1
      fi
    ''}
    check_cache_string QT_APPLE_SDK ${lib.escapeShellArg frameworkDefaults.sdk_lock.name}
    check_cache_string QT_HOST_PATH ${lib.escapeShellArg (toString hostQt)}
    check_cache_string QT_HOST_PATH_CMAKE_DIR ${lib.escapeShellArg "${hostQt}/lib/cmake"}
    check_cache_string QT_XCRUN ${lib.escapeShellArg "${qtXcrunShim}/bin/xcrun"}
    check_cache_string Qt6_DIR ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6"}
    check_cache_string Qt6HostInfo_DIR ${lib.escapeShellArg "${hostQt}/lib/cmake/Qt6HostInfo"}
    check_cache_string Qt6CoreTools_DIR ${lib.escapeShellArg "${hostQt}/lib/cmake/Qt6CoreTools"}
    check_cache_string Qt6GuiTools_DIR ${lib.escapeShellArg "${hostQt}/lib/cmake/Qt6GuiTools"}
    check_cache_string Qt6WidgetsTools_DIR ${lib.escapeShellArg "${hostQt}/lib/cmake/Qt6WidgetsTools"}
    check_cache_string QT_ADDITIONAL_HOST_PACKAGES_PREFIX_PATH ""
    check_cache_string QT_ADDITIONAL_PACKAGES_PREFIX_PATH ""
    if grep -Eq '^QT_OPTIONAL_TOOLS_PATH:[^=]*=' CMakeCache.txt; then
      echo "error: ${packageSpec.name} inherited QT_OPTIONAL_TOOLS_PATH from native QtTools" >&2
      grep -E '^QT_OPTIONAL_TOOLS_PATH:[^=]*=' CMakeCache.txt >&2
      exit 1
    fi
    ${lib.optionalString (builtins.elem "qttools" nativeToolNames) ''
      check_cache_string Qt6LinguistTools_DIR \
        ${lib.escapeShellArg "${hostQtTools}/lib/cmake/Qt6LinguistTools"}
    ''}

    ${qtComponentCheckScript}
    ${hostExecutableCheckScript}

    for host_cmake_package in Qt6HostInfo Qt6CoreTools Qt6GuiTools Qt6WidgetsTools; do
      if ! test -f "${hostQt}/lib/cmake/$host_cmake_package/$host_cmake_package"Config.cmake; then
        echo "error: pinned host Qt CMake package is missing: $host_cmake_package" >&2
        exit 1
      fi
    done
    ${lib.optionalString (builtins.elem "qttools" nativeToolNames) ''
      if ! test -f "${hostQtTools}/lib/cmake/Qt6LinguistTools/Qt6LinguistToolsConfig.cmake"; then
        echo "error: pinned host Qt LinguistTools CMake package is missing" >&2
        exit 1
      fi
    ''}

    xcrun_log="$NIX_BUILD_TOP/qt-xcrun-shim.log"
    if ! test -s "$xcrun_log" || test -L "$xcrun_log"; then
      echo "error: ${packageSpec.name} did not produce a regular xcrun shim log" >&2
      exit 1
    fi
    if grep -Ev -- '^-sdk iphoneos --show-sdk-path$' "$xcrun_log"; then
      echo "error: ${packageSpec.name} made an unsupported xcrun invocation" >&2
      exit 1
    fi
    expected_xcrun_set="$NIX_BUILD_TOP/${packageSpec.name}-xcrun.expected"
    actual_xcrun_set="$NIX_BUILD_TOP/${packageSpec.name}-xcrun.actual"
    printf '%s\n' \
      '-sdk iphoneos --show-sdk-path' \
      | LC_ALL=C sort > "$expected_xcrun_set"
    LC_ALL=C sort -u "$xcrun_log" > "$actual_xcrun_set"
    if ! cmp -s "$expected_xcrun_set" "$actual_xcrun_set"; then
      echo "error: ${packageSpec.name} xcrun invocation set changed" >&2
      diff -u "$expected_xcrun_set" "$actual_xcrun_set" >&2 || true
      exit 1
    fi

    if sed '/^CMAKE_IGNORE_PREFIX_PATH:/d' CMakeCache.txt \
      | grep -E '(^|[=;])(/usr/local|/opt/homebrew)(;|$)'; then
      echo "error: ${packageSpec.name} configure cache contains a host package prefix" >&2
      exit 1
    fi
  '';

  postInstallCheck = ''
    check_disabled_dependency_gate() {
      config_file="$1"
      dependency="$2"
      feature="$3"

      if ! test -f "$config_file"; then
        echo "error: ${packageSpec.name} feature $feature evidence is missing: $config_file" >&2
        exit 1
      fi
      disabled_match_count="$(awk -v dependency="$dependency" '
        /^[[:space:]]*if[[:space:]]*\([[:space:]]*(OFF)?[[:space:]]*\)[[:space:]]*$/ {
          disabled_block = 1
          next
        }
        disabled_block && index($0, "find_dependency(" dependency) {
          matches++
        }
        disabled_block && /^[[:space:]]*endif[[:space:]]*\(\)[[:space:]]*$/ {
          disabled_block = 0
        }
        END { print matches + 0 }
      ' "$config_file")"
      if test "$disabled_match_count" -ne 1; then
        echo "error: ${packageSpec.name} feature $feature does not keep $dependency behind one disabled installed gate" >&2
        exit 1
      fi
    }

    ${disabledDependencyGateCheckScript}

    ${writeExpectedLines "archives" (sorted staticArchives)}
    actual_archives="$NIX_BUILD_TOP/${packageSpec.name}-archives.actual"
    find "$out" -type f -name '*.a' -print \
      | sed "s#^$out/##" \
      | LC_ALL=C sort > "$actual_archives"
    if ! cmp -s "$archives" "$actual_archives"; then
      echo "error: ${packageSpec.name} static archive set differs from the manifest" >&2
      diff -u "$archives" "$actual_archives" >&2 || true
      exit 1
    fi

    ${writeExpectedLines "objects" (sorted standaloneObjects)}
    actual_objects="$NIX_BUILD_TOP/${packageSpec.name}-objects.actual"
    find "$out" -type f -name '*.o' -print \
      | sed "s#^$out/##" \
      | LC_ALL=C sort > "$actual_objects"
    if ! cmp -s "$objects" "$actual_objects"; then
      echo "error: ${packageSpec.name} standalone object set differs from the manifest" >&2
      diff -u "$objects" "$actual_objects" >&2 || true
      exit 1
    fi

    for relative_path in ${lib.escapeShellArgs forbiddenPaths}; do
      if test -e "$out/$relative_path" || test -L "$out/$relative_path"; then
        echo "error: ${packageSpec.name} output contains forbidden path: $relative_path" >&2
        exit 1
      fi
    done
    for forbidden_root in doc examples tests; do
      if test -e "$out/$forbidden_root" || test -L "$out/$forbidden_root"; then
        echo "error: ${packageSpec.name} output contains forbidden $forbidden_root data" >&2
        exit 1
      fi
    done
    forbidden_dynamic="$(find "$out" \( \
      \( -type d \( -name '*.app' -o -name '*.framework' \) \) -o \
      \( -type f \( -name '*.dylib' -o -name '*.so' -o -name '*.so.*' \) \) \
      \) -print -quit)"
    if test -n "$forbidden_dynamic"; then
      echo "error: ${packageSpec.name} static output contains a dynamic artifact: $forbidden_dynamic" >&2
      exit 1
    fi
    while IFS= read -r -d "" executable; do
      if file "$executable" | grep -Fq 'Mach-O'; then
        echo "error: ${packageSpec.name} output contains a Mach-O tool: $executable" >&2
        exit 1
      fi
    done < <(find "$out" -type f -perm -0100 -print0)
    if find "$out" -type l ! -path "$out/nix-support/*" -print -quit | grep -q .; then
      echo "error: ${packageSpec.name} output contains a symlink outside nix-support" >&2
      exit 1
    fi

    cmake_install_manifest="$PWD/install_manifest.txt"
    if ! test -f "$cmake_install_manifest" || test -L "$cmake_install_manifest"; then
      echo "error: ${packageSpec.name} CMake install_manifest.txt is missing" >&2
      exit 1
    fi
    manifest_unsorted="$NIX_BUILD_TOP/${packageSpec.name}-install-manifest.unsorted"
    manifest_inventory="$NIX_BUILD_TOP/${packageSpec.name}-install-manifest.sorted"
    awk -v prefix="$out/" '
      index($0, prefix) != 1 || length($0) == length(prefix) {
        print "invalid install manifest path: " $0 > "/dev/stderr"
        failed = 1
        next
      }
      { print substr($0, length(prefix) + 1) }
      END { if (failed) exit 1 }
    ' "$cmake_install_manifest" > "$manifest_unsorted"
    LC_ALL=C sort "$manifest_unsorted" > "$manifest_inventory"

    actual_inventory="$NIX_BUILD_TOP/${packageSpec.name}-output-inventory.sorted"
    find "$out" -type f ! -path "$out/nix-support/*" -print \
      | sed "s#^$out/##" \
      | LC_ALL=C sort > "$actual_inventory"
    if ! cmp -s "$manifest_inventory" "$actual_inventory"; then
      echo "error: ${packageSpec.name} output differs from CMake's install manifest" >&2
      diff -u "$manifest_inventory" "$actual_inventory" >&2 || true
      exit 1
    fi

    actual_manifest_count="$(awk 'END { print NR + 0 }' "$manifest_inventory")"
    if test "$actual_manifest_count" -ne ${toString installManifest.relative_path_count}; then
      echo "error: ${packageSpec.name} install path count is $actual_manifest_count; expected ${toString installManifest.relative_path_count}" >&2
      exit 1
    fi
    actual_manifest_sha256="$(sha256sum "$manifest_inventory" | cut -d ' ' -f 1)"
    if test "$actual_manifest_sha256" != ${lib.escapeShellArg installManifest.sorted_relative_path_sha256}; then
      echo "error: ${packageSpec.name} install path SHA-256 is $actual_manifest_sha256; expected ${installManifest.sorted_relative_path_sha256}" >&2
      exit 1
    fi

    translation_inventory="$NIX_BUILD_TOP/${packageSpec.name}-translations.sorted"
    awk '/^share\/locale\// { print }' "$manifest_inventory" > "$translation_inventory"
    actual_translation_count="$(awk 'END { print NR + 0 }' "$translation_inventory")"
    if test "$actual_translation_count" -ne ${toString translationInventory.relative_path_count}; then
      echo "error: ${packageSpec.name} translation path count is $actual_translation_count; expected ${toString translationInventory.relative_path_count}" >&2
      exit 1
    fi
    actual_translation_sha256="$(sha256sum "$translation_inventory" | cut -d ' ' -f 1)"
    if test "$actual_translation_sha256" != ${lib.escapeShellArg translationInventory.sorted_relative_path_sha256}; then
      echo "error: ${packageSpec.name} translation path SHA-256 is $actual_translation_sha256; expected ${translationInventory.sorted_relative_path_sha256}" >&2
      exit 1
    fi
    ${expectedTranslationExtensionScript}

    ${writeExpectedLines "cmake_targets" (sorted artifact_contract.cmake_targets)}
    actual_cmake_targets_unsorted="$NIX_BUILD_TOP/${packageSpec.name}-cmake-targets.unsorted"
    actual_cmake_targets="$NIX_BUILD_TOP/${packageSpec.name}-cmake-targets.actual"
    : > "$actual_cmake_targets_unsorted"
    while IFS= read -r -d "" targets_file; do
      sed -n 's/^add_library(\(KF6::[^ ]*\) \(STATIC\|OBJECT\) IMPORTED)$/\1/p' \
        "$targets_file" >> "$actual_cmake_targets_unsorted"
    done < <(find "$out/lib/cmake" -type f -name 'KF6*Targets.cmake' -print0)
    LC_ALL=C sort "$actual_cmake_targets_unsorted" > "$actual_cmake_targets"
    if ! cmp -s "$cmake_targets" "$actual_cmake_targets"; then
      echo "error: ${packageSpec.name} exported CMake target set differs from the manifest" >&2
      diff -u "$cmake_targets" "$actual_cmake_targets" >&2 || true
      exit 1
    fi

    ${forbiddenLiteralCheckScript}
    ${forbiddenPatternCheckScript}
    if grep -R -a -l -F "$NIX_BUILD_TOP" "$out"; then
      echo "error: ${packageSpec.name} output contains its Nix build directory" >&2
      exit 1
    fi

    ${ki18nPostInstallCheck}

    store_references="$NIX_BUILD_TOP/${packageSpec.name}-store-references"
    grep -R -a -h -o -E \
      '/nix/store/[0-9a-z]{32}-[^][:space:][:cntrl:]";:,)>}]+' \
      "$out" | LC_ALL=C sort -u > "$store_references" || true
    while IFS= read -r store_reference; do
      test -n "$store_reference" || continue
      reference_allowed=false
      case "$store_reference" in
        "$out" | "$out"/*) reference_allowed=true ;;
      esac
      if test "$reference_allowed" = false; then
        for target_store_path in ${lib.escapeShellArgs allowedTargetStorePaths}; do
          case "$store_reference" in
            "$target_store_path" | "$target_store_path"/*)
              reference_allowed=true
              break
              ;;
          esac
        done
      fi
      if test "$reference_allowed" = false; then
        echo "error: ${packageSpec.name} output contains a non-target Nix store reference: $store_reference" >&2
        exit 1
      fi
    done < "$store_references"
  '';

  passthru = {
    iosFrameworkName = packageSpec.name;
    iosFrameworkSpec = packageSpec;
    iosFrameworkDependencies = frameworkDependencies;
    iosTargetPackageDependencies = targetPackageDependencies;
    iosExplicitPathNativeToolNames = selectedExplicitPathNativeToolNames;
    iosNativeSetupToolNames = selectedNativeSetupToolNames;
    iosSourceArchiveName = packageSpec.source.archive_name;
    iosSourceArchiveSha256 = packageSpec.source.archive_sha256;
  };

  meta = {
    description = "Static ${packageSpec.name} from KDE Frameworks for Krita on iPadOS";
    inherit (sourcePackage.meta) license;
  }
  // meta;
}

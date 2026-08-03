{
  freetype-ios,
  gettext,
  gnugrep,
  harfbuzz-ios,
  hostEcm,
  hostQt,
  hostQtTools,
  kcodecs-ios,
  kcolorscheme-ios,
  kcompletion-ios,
  kconfig-ios,
  kcoreaddons-ios,
  kf6HostTooling,
  kguiaddons-ios,
  ki18n-ios,
  kitemviews-ios,
  kwidgetsaddons-ios,
  lib,
  libpng-ios,
  mkIOSCMakePackage,
  python3,
  qtbase-ios,
  qtXcrunShim,
  toolchain,
  zlib-ios,
}:

let
  frameworkTargets = [
    kconfig-ios
    kwidgetsaddons-ios
    kcodecs-ios
    kcompletion-ios
    kcoreaddons-ios
    kguiaddons-ios
    ki18n-ios
    kitemviews-ios
    kcolorscheme-ios
  ];
  expectedFrameworkNames = [
    "kconfig"
    "kwidgetsaddons"
    "kcodecs"
    "kcompletion"
    "kcoreaddons"
    "kguiaddons"
    "ki18n"
    "kitemviews"
    "kcolorscheme"
  ];
  frameworkVersion = kconfig-ios.version;
  qtbaseTargetDependencies = qtbase-ios.propagatedBuildInputs or [ ];
  ki18nTargetPackageDependencies = ki18n-ios.iosTargetPackageDependencies or [ ];
  libintlTarget = builtins.head ki18nTargetPackageDependencies;

  # Every public static framework archive, including both KConfig and KI18n
  # targets, must reach the final application link through its installed export.
  linkedFrameworkArtifacts = [
    "${kconfig-ios}/lib/libKF6ConfigCore.a"
    "${kconfig-ios}/lib/libKF6ConfigGui.a"
    "${kwidgetsaddons-ios}/lib/libKF6WidgetsAddons.a"
    "${kcodecs-ios}/lib/libKF6Codecs.a"
    "${kcompletion-ios}/lib/libKF6Completion.a"
    "${kcoreaddons-ios}/lib/libKF6CoreAddons.a"
    "${kguiaddons-ios}/lib/libKF6GuiAddons.a"
    "${ki18n-ios}/lib/libKF6I18n.a"
    "${ki18n-ios}/lib/libKF6I18nLocaleData.a"
    "${kitemviews-ios}/lib/libKF6ItemViews.a"
    "${kcolorscheme-ios}/lib/libKF6ColorScheme.a"
  ];
  linkedFrameworkObjects = [
    "${kwidgetsaddons-ios}/lib/objects-Release/KF6WidgetsAddons_resources_1/.qt/rcc/qrc_kcharselect-data_init.cpp.o"
    "${kcolorscheme-ios}/lib/objects-Release/KF6ColorScheme_resources_1/.qt/rcc/qrc_color_schemes_init.cpp.o"
  ];
  linkedClosureArtifacts = [
    "${libintlTarget}/lib/libintl.a"
    "${harfbuzz-ios}/lib/libharfbuzz.a"
    "${freetype-ios}/lib/libfreetype.a"
    "${libpng-ios}/lib/libpng16.a"
    "${zlib-ios}/lib/libz.a"
    "${qtbase-ios}/lib/libQt6Core.a"
    "${qtbase-ios}/lib/libQt6Gui.a"
    "${qtbase-ios}/lib/libQt6OpenGL.a"
    "${qtbase-ios}/lib/libQt6Widgets.a"
  ];
  nativeInputs = [ gnugrep ];
  nativeReferenceRoots = nativeInputs ++ [
    gettext
    hostEcm
    hostQt
    hostQtTools
    kf6HostTooling
    kf6HostTooling.kconfigCompiler
    python3
    qtXcrunShim
  ];
in
assert lib.assertMsg (
  map (framework: framework.iosFrameworkName or null) frameworkTargets == expectedFrameworkNames
) "KF6 consumer must receive exactly the nine pinned target frameworks";
assert lib.assertMsg (lib.all (
  framework: framework.version == frameworkVersion
) frameworkTargets) "KF6 consumer target frameworks must all use one pinned version";
assert lib.assertMsg (
  hostEcm.version == frameworkVersion
) "KF6 consumer host ECM must match the target Frameworks version";
assert lib.assertMsg (
  hostQt.version == qtbase-ios.version
) "KF6 consumer host Qt must match the target Qt version";
assert lib.assertMsg (
  hostQtTools.version == qtbase-ios.version
) "KF6 consumer host Qt tools must match the target Qt version";
assert lib.assertMsg
  (
    qtbaseTargetDependencies == [
      zlib-ios
      libpng-ios
      freetype-ios
      harfbuzz-ios
    ]
  )
  "KF6 consumer Qtbase closure must contain exactly the pinned target text and compression libraries";
assert lib.assertMsg (
  kf6HostTooling ? kconfigCompiler
) "KF6 consumer host tooling must expose its pinned KConfig compiler";
assert lib.assertMsg (
  builtins.length ki18nTargetPackageDependencies == 1
) "KF6 consumer KI18n must propagate exactly the pinned target libintl";
mkIOSCMakePackage {
  pname = "kf6-consumer-check";
  version = frameworkVersion;
  src = ../../../packaging/ios/frameworks/probe;

  # Keep all nine frameworks direct here.  This is an integration check for
  # independently cached outputs, not a minimal application dependency list.
  targetDependencies = frameworkTargets;

  appleSdkResolver = qtXcrunShim;
  cmakeToolchainFile = "${qtbase-ios}/lib/cmake/Qt6/qt.toolchain.cmake";
  enableFullAppleToolchain = true;
  tryCompileTargetType = null;
  nativeBuildInputs = nativeInputs;

  cmakeFlags = [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG:BOOL=ON"
    "-DCMAKE_FIND_PACKAGE_TARGETS_GLOBAL:BOOL=ON"
    "-DCMAKE_FIND_USE_PACKAGE_REGISTRY:BOOL=OFF"
    "-DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY:BOOL=OFF"
    "-DCMAKE_IGNORE_PREFIX_PATH:STRING=/opt/homebrew;/usr/local"
    "-DECM_DIR:PATH=${hostEcm}/share/ECM/cmake"
    "-DGETTEXT_MSGFMT_EXECUTABLE:FILEPATH=${gettext}/bin/msgfmt"
    "-DGETTEXT_MSGMERGE_EXECUTABLE:FILEPATH=${gettext}/bin/msgmerge"
    "-DKF6_HOST_TOOLING:PATH=${kf6HostTooling}"
    "-DKF6Config_DIR:PATH=${kconfig-ios}/lib/cmake/KF6Config"
    "-DKF6WidgetsAddons_DIR:PATH=${kwidgetsaddons-ios}/lib/cmake/KF6WidgetsAddons"
    "-DKF6Codecs_DIR:PATH=${kcodecs-ios}/lib/cmake/KF6Codecs"
    "-DKF6Completion_DIR:PATH=${kcompletion-ios}/lib/cmake/KF6Completion"
    "-DKF6CoreAddons_DIR:PATH=${kcoreaddons-ios}/lib/cmake/KF6CoreAddons"
    "-DKF6GuiAddons_DIR:PATH=${kguiaddons-ios}/lib/cmake/KF6GuiAddons"
    "-DKF6I18n_DIR:PATH=${ki18n-ios}/lib/cmake/KF6I18n"
    "-DKF6ItemViews_DIR:PATH=${kitemviews-ios}/lib/cmake/KF6ItemViews"
    "-DKF6ColorScheme_DIR:PATH=${kcolorscheme-ios}/lib/cmake/KF6ColorScheme"
    "-DKF_IGNORE_PLATFORM_CHECK:BOOL=ON"
    "-DKI18N_PYTHON_EXECUTABLE:FILEPATH=${python3}/bin/python3"
    "-DPython3_EXECUTABLE:FILEPATH=${python3}/bin/python3"
    "-DQT_APPLE_SDK:STRING=iphoneos"
    "-DQT_HOST_PATH:PATH=${hostQt}"
    "-DQT_HOST_PATH_CMAKE_DIR:PATH=${hostQt}/lib/cmake"
    "-DQT_XCRUN:FILEPATH=${qtXcrunShim}/bin/xcrun"
    "-DQt6_DIR:PATH=${qtbase-ios}/lib/cmake/Qt6"
    "-DQt6Core_DIR:PATH=${qtbase-ios}/lib/cmake/Qt6Core"
    "-DQt6Gui_DIR:PATH=${qtbase-ios}/lib/cmake/Qt6Gui"
    "-DQt6GuiPrivate_DIR:PATH=${qtbase-ios}/lib/cmake/Qt6GuiPrivate"
    "-DQt6Widgets_DIR:PATH=${qtbase-ios}/lib/cmake/Qt6Widgets"
    "-DQt6Xml_DIR:PATH=${qtbase-ios}/lib/cmake/Qt6Xml"
    "-DQt6HostInfo_DIR:PATH=${hostQt}/lib/cmake/Qt6HostInfo"
    "-DQt6CoreTools_DIR:PATH=${hostQt}/lib/cmake/Qt6CoreTools"
    "-DQt6GuiTools_DIR:PATH=${hostQt}/lib/cmake/Qt6GuiTools"
    "-DQt6WidgetsTools_DIR:PATH=${hostQt}/lib/cmake/Qt6WidgetsTools"
    "-DQt6LinguistTools_DIR:PATH=${hostQtTools}/lib/cmake/Qt6LinguistTools"
  ];

  requiredPaths = [
    "bin/KritaIOSFrameworksProbe.app/Info.plist"
    "bin/KritaIOSFrameworksProbe.app/KritaIOSFrameworksProbe"
  ];

  postConfigure = ''
    check_cache_value() {
      name="$1"
      expected="$2"
      count="$(grep -Ec "^$name:[^=]*=" CMakeCache.txt || true)"
      if test "$count" -ne 1; then
        echo "error: expected one KF6 consumer cache entry for $name; found $count" >&2
        exit 1
      fi
      actual="$(sed -n "s/^$name:[^=]*=//p" CMakeCache.txt)"
      if test "$actual" != "$expected"; then
        echo "error: KF6 consumer cache $name is '$actual'; expected '$expected'" >&2
        exit 1
      fi
    }

    check_cache_value CMAKE_TOOLCHAIN_FILE \
      ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6/qt.toolchain.cmake"}
    check_cache_value CMAKE_SYSTEM_NAME iOS
    check_cache_value CMAKE_OSX_ARCHITECTURES ${lib.escapeShellArg toolchain.architecture}
    check_cache_value CMAKE_OSX_DEPLOYMENT_TARGET ${lib.escapeShellArg toolchain.deploymentTarget}
    check_cache_value CMAKE_OSX_SYSROOT iphoneos
    check_cache_value ECM_DIR ${lib.escapeShellArg "${hostEcm}/share/ECM/cmake"}
    check_cache_value KF6_HOST_TOOLING ${lib.escapeShellArg (toString kf6HostTooling)}
    check_cache_value QT_HOST_PATH ${lib.escapeShellArg (toString hostQt)}
    check_cache_value QT_HOST_PATH_CMAKE_DIR ${lib.escapeShellArg "${hostQt}/lib/cmake"}
    check_cache_value QT_XCRUN ${lib.escapeShellArg "${qtXcrunShim}/bin/xcrun"}
    check_cache_value QT_ADDITIONAL_HOST_PACKAGES_PREFIX_PATH ""
    check_cache_value QT_ADDITIONAL_PACKAGES_PREFIX_PATH ""
    if grep -Eq '^QT_OPTIONAL_TOOLS_PATH:[^=]*=' CMakeCache.txt; then
      echo "error: KF6 consumer inherited QT_OPTIONAL_TOOLS_PATH from native QtTools" >&2
      grep -E '^QT_OPTIONAL_TOOLS_PATH:[^=]*=' CMakeCache.txt >&2
      exit 1
    fi
    check_cache_value Qt6GuiPrivate_DIR \
      ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6GuiPrivate"}
    check_cache_value Qt6OpenGL_DIR \
      ${lib.escapeShellArg "${qtbase-ios}/lib/cmake/Qt6OpenGL"}
    check_cache_value Qt6LinguistTools_DIR \
      ${lib.escapeShellArg "${hostQtTools}/lib/cmake/Qt6LinguistTools"}
    check_cache_value harfbuzz_DIR \
      ${lib.escapeShellArg "${harfbuzz-ios}/lib/cmake/harfbuzz"}
    check_cache_value KI18N_PYTHON_EXECUTABLE \
      ${lib.escapeShellArg "${python3}/bin/python3"}
    check_cache_value GETTEXT_MSGFMT_EXECUTABLE \
      ${lib.escapeShellArg "${gettext}/bin/msgfmt"}

    test -x ${lib.escapeShellArg "${kf6HostTooling.kconfigCompiler}/libexec/kf6/kconfig_compiler_kf6"}
    test -f ${lib.escapeShellArg "${kf6HostTooling}/KF6Config/KF6ConfigCompilerTargets.cmake"}
  '';

  postBuild = ''
    generated_source="$PWD/probe.cpp"
    generated_header="$PWD/probe.h"
    test -f "$generated_source"
    test -f "$generated_header"
    grep -Fq 'ProbeSettings::ProbeSettings' "$generated_source"
    grep -Fq 'class ProbeSettings' "$generated_header"

    all_commands="$(ninja -t commands KritaIOSFrameworksProbe)"
    kconfig_compiler=${lib.escapeShellArg "${kf6HostTooling.kconfigCompiler}/libexec/kf6/kconfig_compiler_kf6"}
    if ! grep -Fq -- "$kconfig_compiler" <<<"$all_commands"; then
      echo "error: KF6 consumer did not run the pinned native KConfig compiler" >&2
      exit 1
    fi
    if ! grep -Fq -- "$PWD/probe.cpp" <<<"$all_commands"; then
      echo "error: KF6 consumer did not compile the generated KConfig source" >&2
      exit 1
    fi
    if ! grep -Fq -- \
      ${lib.escapeShellArg "${kconfig-ios}/include/KF6/KConfigGui/kconfigguistaticinitializer.cpp"} \
      <<<"$all_commands"; then
      echo "error: KF6 consumer did not compile KConfigGui's static initializer" >&2
      exit 1
    fi

    link_command="$(tail -n 1 <<<"$all_commands")"
    if ! grep -Fq -- 'KritaIOSFrameworksProbe.app/KritaIOSFrameworksProbe' \
      <<<"$link_command"; then
      echo "error: final KF6 consumer command is not the application link" >&2
      exit 1
    fi
    for target_artifact in ${
      lib.escapeShellArgs (linkedFrameworkArtifacts ++ linkedFrameworkObjects ++ linkedClosureArtifacts)
    }; do
      if ! grep -Fq -- "$target_artifact" <<<"$link_command"; then
        echo "error: KF6 consumer link omits target artifact: $target_artifact" >&2
        exit 1
      fi
    done
    for native_root in ${lib.escapeShellArgs (map toString nativeReferenceRoots)}; do
      if grep -Fq -- "$native_root" <<<"$link_command"; then
        echo "error: KF6 consumer linked a native build input: $native_root" >&2
        exit 1
      fi
    done
  '';

  postInstallCheck = ''
    bundle="$out/bin/KritaIOSFrameworksProbe.app"
    consumer="$bundle/KritaIOSFrameworksProbe"

    consumer_description="$(file -b "$consumer")"
    for required_marker in 'Mach-O' '64-bit' 'arm64' 'executable'; do
      case "$consumer_description" in
        *"$required_marker"*) ;;
        *)
          echo "error: consumer is not an arm64 Mach-O executable: $consumer_description" >&2
          exit 1
          ;;
      esac
    done
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"

    if ${toolchain.otool} -l "$consumer" | grep -Fq LC_CODE_SIGNATURE; then
      echo "error: KF6 consumer application was unexpectedly code signed" >&2
      exit 1
    fi
    if test -e "$bundle/_CodeSignature" || test -e "$bundle/embedded.mobileprovision"; then
      echo "error: KF6 consumer output contains signing material" >&2
      exit 1
    fi
    if ${toolchain.otool} -L "$consumer" | tail -n +2 | grep -Fq /nix/store/; then
      echo "error: KF6 consumer has a dynamic dependency in the Nix store" >&2
      ${toolchain.otool} -L "$consumer" >&2
      exit 1
    fi

    for native_root in ${lib.escapeShellArgs (map toString nativeReferenceRoots)}; do
      if grep -R -a -l -F "$native_root" "$bundle"; then
        echo "error: KF6 consumer output refers to native build input: $native_root" >&2
        exit 1
      fi
    done
    if grep -R -a -l -E \
      '(/Users/[^/]+/|/private/tmp/nix-build-[^/]+/|/tmp/nix-build-[^/]+/|build-ios/)' \
      "$bundle"; then
      echo "error: KF6 consumer output contains a host or legacy build path" >&2
      exit 1
    fi
  '';

  meta.description = "Complete KF6 iOS link and native KConfig code-generation check";
}

{
  pkgs,
  versions,
  frameworkManifest,
  mkIOSKFPackage,
  libintl-ios,
}:

let
  lib = pkgs.lib;
  frameworkVersion = versions.KRITA_IOS_KF_VERSION;

  expectedPackageLocks = [
    {
      name = "ecm";
      sourceFlakeAttr = "source-ecm";
      hostOnly = true;
      dependencies = [ ];
      targetPackages = [ ];
      qtModules = [ ];
      frameworks = [ ];
      nativeTools = [ ];
      patches = [ ];
    }
    {
      name = "kconfig";
      sourceFlakeAttr = "source-kconfig";
      hostOnly = false;
      dependencies = [ "ecm" ];
      targetPackages = [ ];
      qtModules = [ "qtbase" ];
      frameworks = [ ];
      nativeTools = [
        "ecm"
        "qtbase"
        "qttools"
      ];
      patches = [ "packaging/ios/frameworks/patches/kconfig-ios-no-tools.patch" ];
    }
    {
      name = "kwidgetsaddons";
      sourceFlakeAttr = "source-kwidgetsaddons";
      hostOnly = false;
      dependencies = [ "ecm" ];
      targetPackages = [ ];
      qtModules = [ "qtbase" ];
      frameworks = [ ];
      nativeTools = [
        "ecm"
        "qtbase"
        "qttools"
      ];
      patches = [ ];
    }
    {
      name = "kcodecs";
      sourceFlakeAttr = "source-kcodecs";
      hostOnly = false;
      dependencies = [ "ecm" ];
      targetPackages = [ ];
      qtModules = [ "qtbase" ];
      frameworks = [ ];
      nativeTools = [
        "ecm"
        "qtbase"
        "qttools"
      ];
      patches = [ ];
    }
    {
      name = "kcompletion";
      sourceFlakeAttr = "source-kcompletion";
      hostOnly = false;
      dependencies = [
        "kcodecs"
        "kconfig"
        "kwidgetsaddons"
      ];
      targetPackages = [ ];
      qtModules = [ "qtbase" ];
      frameworks = [
        "kcodecs"
        "kconfig"
        "kwidgetsaddons"
      ];
      nativeTools = [
        "ecm"
        "kconfig"
        "qtbase"
        "qttools"
      ];
      patches = [ ];
    }
    {
      name = "kcoreaddons";
      sourceFlakeAttr = "source-kcoreaddons";
      hostOnly = false;
      dependencies = [ "ecm" ];
      targetPackages = [ ];
      qtModules = [ "qtbase" ];
      frameworks = [ ];
      nativeTools = [
        "ecm"
        "qtbase"
        "qttools"
      ];
      patches = [ ];
    }
    {
      name = "kguiaddons";
      sourceFlakeAttr = "source-kguiaddons";
      hostOnly = false;
      dependencies = [ "ecm" ];
      targetPackages = [ ];
      qtModules = [ "qtbase" ];
      frameworks = [ ];
      nativeTools = [
        "ecm"
        "qtbase"
      ];
      patches = [ ];
    }
    {
      name = "ki18n";
      sourceFlakeAttr = "source-ki18n";
      hostOnly = false;
      dependencies = [ "ecm" ];
      targetPackages = [ "libintl" ];
      qtModules = [ "qtbase" ];
      frameworks = [ ];
      nativeTools = [
        "ecm"
        "gettext"
        "python3"
        "qtbase"
      ];
      patches = [ ];
    }
    {
      name = "kitemviews";
      sourceFlakeAttr = "source-kitemviews";
      hostOnly = false;
      dependencies = [ "ecm" ];
      targetPackages = [ ];
      qtModules = [ "qtbase" ];
      frameworks = [ ];
      nativeTools = [
        "ecm"
        "qtbase"
        "qttools"
      ];
      patches = [ ];
    }
    {
      name = "kcolorscheme";
      sourceFlakeAttr = "source-kcolorscheme";
      hostOnly = false;
      dependencies = [
        "kconfig"
        "kguiaddons"
        "ki18n"
      ];
      targetPackages = [ ];
      qtModules = [ "qtbase" ];
      frameworks = [
        "kconfig"
        "kguiaddons"
        "ki18n"
      ];
      nativeTools = [
        "ecm"
        "gettext"
        "kconfig"
        "python3"
        "qtbase"
      ];
      patches = [ ];
    }
  ];

  packageNames = map (package: package.name) frameworkManifest.packages;
  expectedPackageNames = map (package: package.name) expectedPackageLocks;

  normalizePackageLock = package: {
    inherit (package) name dependencies;
    sourceFlakeAttr = package.source_flake_attr;
    hostOnly = package.host_only or false;
    targetPackages = lib.attrByPath [ "nix_dependencies" "target_packages" ] [ ] package;
    qtModules = lib.attrByPath [ "nix_dependencies" "qt_modules" ] [ ] package;
    frameworks = lib.attrByPath [ "nix_dependencies" "frameworks" ] [ ] package;
    nativeTools = lib.attrByPath [ "nix_dependencies" "native_tools" ] [ ] package;
    patches = package.patches or [ ];
  };

  packageByName = builtins.listToAttrs (
    map (package: {
      name = package.name;
      value = package;
    }) frameworkManifest.packages
  );

  targetSpec =
    name:
    let
      package = packageByName.${name};
    in
    assert lib.assertMsg (!(package.host_only or false)) "${name} must remain an iOS target framework";
    package;

  frameworks = rec {
    kconfig-ios = mkIOSKFPackage {
      packageSpec = targetSpec "kconfig";
      sourcePackage = pkgs.kdePackages.kconfig;
      patches = [ ../../packaging/ios/frameworks/patches/kconfig-ios-no-tools.patch ];
    };

    kwidgetsaddons-ios = mkIOSKFPackage {
      packageSpec = targetSpec "kwidgetsaddons";
      sourcePackage = pkgs.kdePackages.kwidgetsaddons;
    };

    kcodecs-ios = mkIOSKFPackage {
      packageSpec = targetSpec "kcodecs";
      sourcePackage = pkgs.kdePackages.kcodecs;
    };

    kcompletion-ios = mkIOSKFPackage {
      packageSpec = targetSpec "kcompletion";
      sourcePackage = pkgs.kdePackages.kcompletion;
      frameworkDependencies = [
        kcodecs-ios
        kconfig-ios
        kwidgetsaddons-ios
      ];
    };

    kcoreaddons-ios = mkIOSKFPackage {
      packageSpec = targetSpec "kcoreaddons";
      sourcePackage = pkgs.kdePackages.kcoreaddons;
    };

    kguiaddons-ios = mkIOSKFPackage {
      packageSpec = targetSpec "kguiaddons";
      sourcePackage = pkgs.kdePackages.kguiaddons;
    };

    ki18n-ios = mkIOSKFPackage {
      packageSpec = targetSpec "ki18n";
      sourcePackage = pkgs.kdePackages.ki18n;
      targetPackageDependencies = [ libintl-ios ];
    };

    kitemviews-ios = mkIOSKFPackage {
      packageSpec = targetSpec "kitemviews";
      sourcePackage = pkgs.kdePackages.kitemviews;
    };

    kcolorscheme-ios = mkIOSKFPackage {
      packageSpec = targetSpec "kcolorscheme";
      sourcePackage = pkgs.kdePackages.kcolorscheme;
      frameworkDependencies = [
        kconfig-ios
        kguiaddons-ios
        ki18n-ios
      ];
    };
  };
in
assert lib.assertMsg (frameworkManifest.schema == 1) "unsupported iOS KF6 manifest schema";
assert lib.assertMsg (
  frameworkManifest.frameworks_version == frameworkVersion
) "iOS KF6 manifest version does not match versions.env";
assert lib.assertMsg (
  frameworkManifest.target_defaults.qt_version == versions.KRITA_IOS_QT_VERSION
) "iOS KF6 manifest Qt version does not match versions.env";
assert lib.assertMsg (
  packageNames == expectedPackageNames
) "iOS KF6 manifest must contain exactly the pinned package sequence";
assert lib.assertMsg (lib.all (package: package.version == frameworkVersion)
  frameworkManifest.packages
) "every iOS KF6 manifest package must use the pinned Frameworks version";
assert lib.assertMsg (
  map normalizePackageLock frameworkManifest.packages == expectedPackageLocks
) "iOS KF6 manifest package dependencies or source/patch locks changed";
frameworks

{
  description = "Reproducible host tools for the Krita iPadOS port";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      kritaBuildSource = pkgs.lib.cleanSourceWith {
        name = "krita-ios-source";
        src = ./.;
        filter =
          path: _type:
          let
            relativePath = pkgs.lib.removePrefix "${toString ./.}/" (toString path);
            topLevel = builtins.head (pkgs.lib.splitString "/" relativePath);
          in
          !(builtins.elem topLevel [
            ".cache"
            ".git"
            ".github"
            ".gitlab"
            "AGENTS.md"
            "TODO.md"
            "build-ios"
            "docs"
            "flake.lock"
            "flake.nix"
            "logs"
            "nix"
          ]);
      };
      iosPackages = import ./nix/ios {
        inherit pkgs;
        versionsFile = ./packaging/ios/versions.env;
        dependencyManifestFile = ./packaging/ios/deps/dependencies.json;
        qtManifestFile = ./packaging/ios/qt/modules.json;
        frameworkManifestFile = ./packaging/ios/frameworks/frameworks.json;
        pluginProfileFile = ./packaging/ios/manifests/initial-plugin-profile.json;
        kritaSource = kritaBuildSource;
      };
    in
    {
      # Source outputs retain the legacy script-driven build. New iOS package
      # outputs cross-compile inside individual Nix derivations while using the
      # validated external Xcode SDK as a narrowly defined host dependency.
      packages.${system} = {
        source-zlib = pkgs.zlib.src;
        source-libpng = pkgs.libpng.src;
        source-libjpeg-turbo = pkgs.libjpeg_turbo.src;
        source-expat = pkgs.expat.src;
        source-boost = pkgs.boost.src;
        source-immer = pkgs.immer.src;
        source-zug = pkgs.zug.src;
        source-lager = pkgs.lager.src;
        source-eigen = pkgs.eigen.src;
        source-exiv2 = pkgs.exiv2.src;
        source-lcms2 = pkgs.lcms2.src;
        source-xsimd = pkgs.xsimd.src;
        source-quazip = pkgs.qt6Packages.quazip.src;
        source-freetype = pkgs.freetype.src;
        source-harfbuzz = pkgs.harfbuzz.src;
        source-fontconfig = pkgs.fontconfig.src;
        source-fribidi = pkgs.fribidi.src;
        source-gettext = pkgs.gettext.src;
        source-libunibreak = pkgs.libunibreak.src;
        source-qtbase = pkgs.qt6Packages.qtbase.src;
        source-qtsvg = pkgs.qt6Packages.qtsvg.src;
        source-qt5compat = pkgs.qt6Packages.qt5compat.src;
        source-ecm = pkgs.kdePackages.extra-cmake-modules.src;
        source-kconfig = pkgs.kdePackages.kconfig.src;
        source-kcodecs = pkgs.kdePackages.kcodecs.src;
        source-kwidgetsaddons = pkgs.kdePackages.kwidgetsaddons.src;
        source-kcompletion = pkgs.kdePackages.kcompletion.src;
        source-kcoreaddons = pkgs.kdePackages.kcoreaddons.src;
        source-kguiaddons = pkgs.kdePackages.kguiaddons.src;
        source-ki18n = pkgs.kdePackages.ki18n.src;
        source-kitemviews = pkgs.kdePackages.kitemviews.src;
        source-kcolorscheme = pkgs.kdePackages.kcolorscheme.src;

        host-qtbase = pkgs.qt6Packages.qtbase;
        host-qttools = pkgs.qt6Packages.qttools;
        host-ecm = pkgs.kdePackages.extra-cmake-modules;

        inherit (iosPackages)
          boost-ios
          eigen-ios
          exiv2-ios
          expat-ios
          fribidi-ios
          fontconfig-ios
          freetype-ios
          harfbuzz-ios
          host-kconfig-compiler
          immer-ios
          ios-base-dependencies
          ios-dependencies
          kcodecs-ios
          kcolorscheme-ios
          kcompletion-ios
          kconfig-ios
          kcoreaddons-ios
          kf6-consumer-check
          kf6-ios-dependencies
          kguiaddons-ios
          ki18n-ios
          kitemviews-ios
          krita-ios-app
          krita-ios-ipa
          lager-ios
          lcms2-ios
          kf6-host-tooling
          libintl-ios
          libjpeg-turbo-ios
          libunibreak-ios
          libpng-ios
          qt5compat-ios
          qt-ios-dependencies
          qtbase-ios
          qtsvg-ios
          qt-xcrun-shim
          qttools-host-contract-check
          quazip-ios
          xsimd-ios
          zlib-ios
          zug-ios
          kwidgetsaddons-ios
          ;
      };

      checks.${system} = {
        inherit (iosPackages)
          boost-consumer-check
          boost-ios
          eigen-ios
          exiv2-consumer-check
          exiv2-ios
          expat-ios
          fribidi-consumer-check
          fribidi-ios
          fontconfig-consumer-check
          fontconfig-ios
          freetype-consumer-check
          freetype-ios
          harfbuzz-consumer-check
          harfbuzz-ios
          host-kconfig-compiler
          immer-consumer-check
          immer-ios
          ios-base-dependencies
          ios-dependencies
          kcodecs-ios
          kcolorscheme-ios
          kcompletion-ios
          kconfig-ios
          kcoreaddons-ios
          kf6-consumer-check
          kf6-ios-dependencies
          kguiaddons-ios
          ki18n-ios
          kitemviews-ios
          lager-consumer-check
          lager-ios
          lcms2-ios
          kf6-host-tooling
          libintl-consumer-check
          libintl-ios
          libjpeg-turbo-consumer-check
          libjpeg-turbo-ios
          libunibreak-consumer-check
          libunibreak-ios
          libpng-ios
          qt5compat-ios
          qt-ios-dependencies
          qtbase-ios
          qtsvg-ios
          qttools-host-contract-check
          quazip-ios
          xsimd-consumer-check
          xsimd-ios
          zlib-ios
          zug-consumer-check
          zug-ios
          kwidgetsaddons-ios
          ;
      };

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          bash
          cmake
          coreutils
          file
          git
          gnugrep
          gnused
          gnumake
          gperf
          gettext
          jq
          meson
          ninja
          nixfmt
          pkg-config
          python3
          xz
        ];

        shellHook = ''
          export KRITA_IOS_REPO_ROOT="$PWD"
          export KRITA_IOS_BUILD_ROOT="$PWD/build-ios"
          export KRITA_IOS_LOG_ROOT="$PWD/logs/ios"
          echo "Krita iPadOS development shell"
          echo "  host check: packaging/ios/scripts/check-host.sh"
          echo "  smoke test: packaging/ios/scripts/build-smoke.sh device"
        '';
      };

      formatter.${system} = pkgs.nixfmt;
    };
}

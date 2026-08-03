{
  description = "Reproducible host tools for the Krita iPadOS port";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      iosPackages = import ./nix/ios {
        inherit pkgs;
        versionsFile = ./packaging/ios/versions.env;
        dependencyManifestFile = ./packaging/ios/deps/dependencies.json;
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
          fontconfig-ios
          freetype-ios
          harfbuzz-ios
          immer-ios
          ios-dependencies
          lcms2-ios
          libjpeg-turbo-ios
          libunibreak-ios
          libpng-ios
          xsimd-ios
          zlib-ios
          zug-ios
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
          fontconfig-consumer-check
          fontconfig-ios
          freetype-consumer-check
          freetype-ios
          harfbuzz-consumer-check
          harfbuzz-ios
          immer-consumer-check
          immer-ios
          lcms2-ios
          libjpeg-turbo-consumer-check
          libjpeg-turbo-ios
          libunibreak-consumer-check
          libunibreak-ios
          libpng-ios
          xsimd-consumer-check
          xsimd-ios
          zlib-ios
          zug-consumer-check
          zug-ios
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

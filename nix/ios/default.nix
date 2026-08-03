{
  pkgs,
  versionsFile,
  dependencyManifestFile,
}:

let
  lib = pkgs.lib;

  parseEnv =
    file:
    builtins.listToAttrs (
      map
        (
          line:
          let
            match = builtins.match "([A-Za-z_][A-Za-z0-9_]*)=(.*)" line;
          in
          {
            name = builtins.elemAt match 0;
            value = builtins.elemAt match 1;
          }
        )
        (
          builtins.filter (line: line != "" && builtins.match "[[:space:]]*#.*" line == null) (
            lib.splitString "\n" (builtins.readFile versionsFile)
          )
        )
    );

  versions = parseEnv versionsFile;
  dependencyManifest = builtins.fromJSON (builtins.readFile dependencyManifestFile);
  dependencyByName = builtins.listToAttrs (
    map (package: {
      name = package.name;
      value = package;
    }) dependencyManifest.packages
  );

  toolchain = import ./toolchain.nix {
    inherit lib versions;
  };

  mkIOSCMakePackage = pkgs.callPackage ./mk-ios-cmake-package.nix {
    inherit toolchain;
  };

  mkIOSAutotoolsPackage = pkgs.callPackage ./mk-ios-autotools-package.nix {
    inherit toolchain;
  };

  zlib-ios = pkgs.callPackage ./packages/zlib.nix {
    inherit mkIOSCMakePackage;
    packageSpec = dependencyByName.zlib;
  };

  expat-ios = pkgs.callPackage ./packages/expat.nix {
    inherit mkIOSCMakePackage toolchain;
    packageSpec = dependencyByName.expat;
  };

  libpng-ios = pkgs.callPackage ./packages/libpng.nix {
    inherit mkIOSCMakePackage toolchain zlib-ios;
    packageSpec = dependencyByName.libpng;
  };

  eigen-ios = pkgs.callPackage ./packages/eigen.nix {
    inherit mkIOSCMakePackage toolchain;
    packageSpec = dependencyByName.eigen;
  };

  xsimd-ios = pkgs.callPackage ./packages/xsimd.nix {
    inherit mkIOSCMakePackage toolchain;
    packageSpec = dependencyByName.xsimd;
  };

  xsimd-consumer-check = pkgs.callPackage ./tests/xsimd-consumer.nix {
    inherit mkIOSCMakePackage toolchain xsimd-ios;
  };

  libunibreak-ios = pkgs.callPackage ./packages/libunibreak.nix {
    inherit mkIOSCMakePackage toolchain;
    packageSpec = dependencyByName.libunibreak;
  };

  libunibreak-consumer-check = pkgs.callPackage ./tests/libunibreak-consumer.nix {
    inherit libunibreak-ios mkIOSCMakePackage toolchain;
  };

  freetype-ios = pkgs.callPackage ./packages/freetype.nix {
    inherit
      libpng-ios
      mkIOSCMakePackage
      zlib-ios
      ;
    packageSpec = dependencyByName.freetype;
  };

  freetype-consumer-check = pkgs.callPackage ./tests/freetype-consumer.nix {
    inherit
      freetype-ios
      libpng-ios
      mkIOSCMakePackage
      toolchain
      zlib-ios
      ;
  };

  harfbuzz-ios = pkgs.callPackage ./packages/harfbuzz.nix {
    inherit freetype-ios mkIOSCMakePackage toolchain;
    packageSpec = dependencyByName.harfbuzz;
  };

  harfbuzz-consumer-check = pkgs.callPackage ./tests/harfbuzz-consumer.nix {
    inherit
      freetype-ios
      harfbuzz-ios
      libpng-ios
      mkIOSCMakePackage
      toolchain
      zlib-ios
      ;
  };

  fontconfig-ios = pkgs.callPackage ./packages/fontconfig.nix {
    inherit
      expat-ios
      freetype-ios
      libpng-ios
      mkIOSAutotoolsPackage
      toolchain
      zlib-ios
      ;
    packageSpec = dependencyByName.fontconfig;
  };

  fontconfig-consumer-check = pkgs.callPackage ./tests/fontconfig-consumer.nix {
    inherit
      expat-ios
      fontconfig-ios
      freetype-ios
      libpng-ios
      mkIOSCMakePackage
      toolchain
      zlib-ios
      ;
  };

  lcms2-ios = pkgs.callPackage ./packages/lcms2.nix {
    inherit mkIOSCMakePackage toolchain;
    packageSpec = dependencyByName.lcms2;
  };

  ios-dependencies = pkgs.symlinkJoin {
    name = "krita-ios-dependencies-bootstrap";
    paths = [
      zlib-ios
      expat-ios
      libpng-ios
      freetype-ios
      harfbuzz-ios
      fontconfig-ios
      lcms2-ios
      eigen-ios
      xsimd-ios
      libunibreak-ios
    ];
    postBuild = ''
      mkdir -p "$out/nix-support"
      rm -f "$out/nix-support/propagated-build-inputs"
      echo ${zlib-ios} ${expat-ios} ${libpng-ios} ${freetype-ios} ${harfbuzz-ios} ${fontconfig-ios} ${lcms2-ios} ${eigen-ios} ${xsimd-ios} ${libunibreak-ios} > "$out/nix-support/propagated-build-inputs"
    '';
  };
in
{
  inherit
    eigen-ios
    expat-ios
    fontconfig-consumer-check
    fontconfig-ios
    freetype-consumer-check
    ios-dependencies
    freetype-ios
    harfbuzz-consumer-check
    harfbuzz-ios
    lcms2-ios
    libunibreak-consumer-check
    libunibreak-ios
    libpng-ios
    toolchain
    xsimd-consumer-check
    xsimd-ios
    zlib-ios
    ;
}

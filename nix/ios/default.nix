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
      lcms2-ios
      eigen-ios
    ];
    postBuild = ''
      mkdir -p "$out/nix-support"
      rm -f "$out/nix-support/propagated-build-inputs"
      echo ${zlib-ios} ${expat-ios} ${libpng-ios} ${freetype-ios} ${harfbuzz-ios} ${lcms2-ios} ${eigen-ios} > "$out/nix-support/propagated-build-inputs"
    '';
  };
in
{
  inherit
    eigen-ios
    expat-ios
    freetype-consumer-check
    ios-dependencies
    freetype-ios
    harfbuzz-consumer-check
    harfbuzz-ios
    lcms2-ios
    libpng-ios
    toolchain
    zlib-ios
    ;
}

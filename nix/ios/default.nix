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

  libpng-ios = pkgs.callPackage ./packages/libpng.nix {
    inherit mkIOSCMakePackage toolchain zlib-ios;
    packageSpec = dependencyByName.libpng;
  };

  ios-dependencies = pkgs.symlinkJoin {
    name = "krita-ios-dependencies-bootstrap";
    paths = [
      zlib-ios
      libpng-ios
    ];
  };
in
{
  inherit
    ios-dependencies
    libpng-ios
    toolchain
    zlib-ios
    ;
}

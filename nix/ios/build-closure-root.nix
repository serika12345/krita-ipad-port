let
  pathsFile = builtins.getEnv "KRITA_IOS_BUILD_CLOSURE_PATHS";
  paths = builtins.filter (path: builtins.isString path && path != "") (
    builtins.split "\n" (builtins.readFile pathsFile)
  );
  storePaths = map builtins.storePath paths;
in
assert pathsFile != "";
assert storePaths != [ ];
builtins.toFile "krita-ios-build-closure-root" (builtins.concatStringsSep "\n" storePaths + "\n")

let
  # This impure root is only for retaining the reproducible build closure
  # during normal deployment. Dependency pinning and the final clean bootstrap
  # must not use it.
  cachePhase = builtins.getEnv "KRITA_IOS_CACHE_PHASE";
  pathsFile = builtins.getEnv "KRITA_IOS_BUILD_CLOSURE_PATHS";
  paths = builtins.filter (path: builtins.isString path && path != "") (
    builtins.split "\n" (builtins.readFile pathsFile)
  );
  storePaths = map builtins.storePath paths;
in
assert cachePhase == "deployment";
assert pathsFile != "";
assert storePaths != [ ];
builtins.toFile "krita-ios-build-closure-root" (builtins.concatStringsSep "\n" storePaths + "\n")

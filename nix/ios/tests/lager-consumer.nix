{
  boost-ios,
  lager-ios,
  mkIOSCMakePackage,
  toolchain,
  zug-ios,
}:

mkIOSCMakePackage {
  pname = "lager-consumer-check";
  inherit (lager-ios) version;
  src = ./lager-consumer;

  # Lager must carry its own complete pure dependency closure. Neither this
  # derivation nor its CMake project names those dependencies as build inputs.
  targetDependencies = [ lager-ios ];

  cmakeFlags = [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE"
    "-DKRITA_IOS_LAGER_PREFIX=${lager-ios}"
    "-DKRITA_IOS_LAGER_VERSION=${lager-ios.version}"
  ];

  requiredPaths = [ "bin/krita-ios-lager-consumer.app/krita-ios-lager-consumer" ];

  postBuild = ''
    build_commands="$(ninja -t commands krita-ios-lager-consumer)"
    for include_root in \
      ${lager-ios}/include \
      ${boost-ios}/include \
      ${zug-ios}/include; do
      if ! grep -Fq -- "$include_root" <<<"$build_commands"; then
        echo "error: Lager consumer did not use transitive headers from $include_root" >&2
        exit 1
      fi
    done
  '';

  postInstallCheck = ''
    consumer="$out/bin/krita-ios-lager-consumer.app/krita-ios-lager-consumer"
    test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
    consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
    grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
    grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
  '';

  meta.description = "Apple Clang iOS compile check for Lager's complete exported dependency contract";
}

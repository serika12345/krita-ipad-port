{
  libjpeg-turbo-ios,
  mkIOSCMakePackage,
  toolchain,
}:

mkIOSCMakePackage {
  pname = "libjpeg-turbo-consumer-check";
  inherit (libjpeg-turbo-ios) version;
  src = ./libjpeg-turbo-consumer;

  targetDependencies = [ libjpeg-turbo-ios ];

  cmakeFlags = [
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=TRUE"
    "-DKRITA_IOS_LIBJPEG_TURBO_PREFIX=${libjpeg-turbo-ios}"
    "-DKRITA_IOS_LIBJPEG_TURBO_VERSION=${libjpeg-turbo-ios.version}"
  ];

  requiredPaths = [
    "bin/krita-ios-libjpeg-consumer.app/krita-ios-libjpeg-consumer"
    "bin/krita-ios-turbojpeg-consumer.app/krita-ios-turbojpeg-consumer"
  ];

  postBuild = ''
    jpeg_commands="$(ninja -t commands krita-ios-libjpeg-consumer)"
    turbojpeg_commands="$(ninja -t commands krita-ios-turbojpeg-consumer)"

    if ! grep -Fq -- "${libjpeg-turbo-ios}/include" <<<"$jpeg_commands"; then
      echo "error: jpeg-static consumer did not use the target package headers" >&2
      exit 1
    fi
    if ! grep -Fq -- "${libjpeg-turbo-ios}/lib/libjpeg.a" <<<"$jpeg_commands"; then
      echo "error: jpeg-static consumer did not link libjpeg.a" >&2
      exit 1
    fi
    if ! grep -Fq -- "${libjpeg-turbo-ios}/include" <<<"$turbojpeg_commands"; then
      echo "error: turbojpeg-static consumer did not use the target package headers" >&2
      exit 1
    fi
    if ! grep -Fq -- "${libjpeg-turbo-ios}/lib/libturbojpeg.a" <<<"$turbojpeg_commands"; then
      echo "error: turbojpeg-static consumer did not link libturbojpeg.a" >&2
      exit 1
    fi
  '';

  postInstallCheck = ''
    for name in krita-ios-libjpeg-consumer krita-ios-turbojpeg-consumer; do
      consumer="$out/bin/$name.app/$name"
      test "$(${toolchain.lipo} -archs "$consumer")" = "${toolchain.architecture}"
      consumer_metadata="$(${toolchain.vtool} -show-build "$consumer")"
      grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$consumer_metadata"
      grep -Eq 'minos[[:space:]]+${toolchain.deploymentTarget}([[:space:]]|$)' <<<"$consumer_metadata"
      grep -Eq 'sdk[[:space:]]+${toolchain.sdkVersion}([[:space:]]|$)' <<<"$consumer_metadata"
    done
  '';

  meta.description = "iOS link checks for libjpeg-turbo's two installed static targets";
}

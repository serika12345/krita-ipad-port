#!/usr/bin/env bash
set -euo pipefail

if (( $# != 1 )); then
    echo "usage: $0 <device|simulator>" >&2
    exit 2
fi

mode="$1"
case "$mode" in
    device)
        platform=DEVICE
        ;;
    simulator)
        platform=SIMULATOR
        ;;
    *)
        echo "error: mode must be device or simulator" >&2
        exit 2
        ;;
esac

repo_root="$(git rev-parse --show-toplevel)"
ios_dir="$repo_root/packaging/ios"
framework_prefix="$repo_root/build-ios/frameworks/$mode/prefix"
qt_prefix="$repo_root/build-ios/qt/$mode/prefix"
dependency_prefix="$repo_root/build-ios/deps/$mode/prefix"
host_tooling="$repo_root/build-ios/frameworks/host-tools/cmake"
build_dir="$repo_root/build-ios/frameworks/$mode/probe"

"$ios_dir/scripts/check-host.sh"
if [[ ! -f "$framework_prefix/lib/cmake/KF6Config/KF6ConfigConfig.cmake" ]]; then
    echo "error: target frameworks are missing; run build-frameworks.sh $mode first" >&2
    exit 1
fi
if [[ ! -f "$host_tooling/KF6Config/KF6ConfigCompilerTargets.cmake" ]]; then
    echo "error: host KConfig tooling is missing; run build-frameworks.sh $mode first" >&2
    exit 1
fi

cmake -S "$ios_dir/frameworks/probe" -B "$build_dir" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ios_dir/cmake/KritaIOSPlatform.cmake" \
    -DKRITA_IOS_PLATFORM="$platform" \
    -DCMAKE_PREFIX_PATH="$framework_prefix;$qt_prefix;$dependency_prefix" \
    -DCMAKE_FIND_ROOT_PATH="$framework_prefix;$qt_prefix;$dependency_prefix" \
    -DKF6_HOST_TOOLING="$host_tooling" \
    -DKF_IGNORE_PLATFORM_CHECK=ON \
    '-DCMAKE_IGNORE_PREFIX_PATH=/usr/local;/opt/homebrew' \
    -DCMAKE_BUILD_TYPE=Release
cmake --build "$build_dir" --parallel

binary="$(find "$build_dir" -type f -name KritaIOSFrameworksProbe -perm -111 -print -quit)"
if [[ -z "$binary" ]]; then
    echo "error: framework probe executable was not generated" >&2
    exit 1
fi
"$ios_dir/scripts/inspect-apple-binary.sh" "$mode" "$binary"

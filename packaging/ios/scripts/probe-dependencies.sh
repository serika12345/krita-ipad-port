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
prefix="$repo_root/build-ios/deps/$mode/prefix"
build_dir="$repo_root/build-ios/deps/$mode/probe"

"$ios_dir/scripts/check-host.sh"

cmake -S "$ios_dir/deps/probe" -B "$build_dir" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ios_dir/cmake/KritaIOSPlatform.cmake" \
    -DKRITA_IOS_PLATFORM="$platform" \
    -DKRITA_SOURCE_DIR="$repo_root" \
    -DCMAKE_PREFIX_PATH="$prefix" \
    -DCMAKE_FIND_ROOT_PATH="$prefix" \
    -DCMAKE_IGNORE_PREFIX_PATH='/usr/local;/opt/homebrew' \
    -DCMAKE_BUILD_TYPE=Release
cmake --build "$build_dir" --parallel

binary="$(find "$build_dir" -type f -name KritaIOSDependenciesProbe -perm -111 -print -quit)"
if [[ -z "$binary" ]]; then
    echo "error: dependency probe executable was not generated" >&2
    exit 1
fi
"$ios_dir/scripts/inspect-apple-binary.sh" "$mode" "$binary"

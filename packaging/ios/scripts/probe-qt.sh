#!/usr/bin/env bash
set -euo pipefail

if (( $# != 1 )); then
    echo "usage: $0 <device|simulator>" >&2
    exit 2
fi

mode="$1"
case "$mode" in
    device|simulator) ;;
    *)
        echo "error: mode must be device or simulator" >&2
        exit 2
        ;;
esac

repo_root="$(git rev-parse --show-toplevel)"
ios_dir="$repo_root/packaging/ios"
qt_prefix="$repo_root/build-ios/qt/$mode/prefix"
dependency_prefix="$repo_root/build-ios/deps/$mode/prefix"
build_dir="$repo_root/build-ios/qt/$mode/probe"

"$ios_dir/scripts/check-host.sh"
if [[ ! -x "$qt_prefix/bin/qt-cmake" ]]; then
    echo "error: target Qt is missing; run build-qt.sh first" >&2
    exit 1
fi

"$qt_prefix/bin/qt-cmake" \
    -S "$ios_dir/qt/probe" \
    -B "$build_dir" \
    -G Ninja \
    -DCMAKE_PREFIX_PATH="$qt_prefix;$dependency_prefix" \
    -DCMAKE_FIND_ROOT_PATH="$qt_prefix;$dependency_prefix" \
    '-DCMAKE_IGNORE_PREFIX_PATH=/usr/local;/opt/homebrew' \
    -DCMAKE_BUILD_TYPE=Release
cmake --build "$build_dir" --parallel

binary="$(find "$build_dir" -type f -name KritaIOSQtProbe -perm -111 -print -quit)"
if [[ -z "$binary" ]]; then
    echo "error: Qt probe executable was not generated" >&2
    exit 1
fi
"$ios_dir/scripts/inspect-apple-binary.sh" "$mode" "$binary"

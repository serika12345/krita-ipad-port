#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "usage: $0 <device|simulator> [--build]" >&2
    exit 2
}

if (( $# < 1 || $# > 2 )); then
    usage
fi

mode="$1"
build=0
if (( $# == 2 )); then
    [[ "$2" == "--build" ]] || usage
    build=1
fi

case "$mode" in
    device|simulator) ;;
    *) usage ;;
esac

repo_root="$(git rev-parse --show-toplevel)"
ios_dir="$repo_root/packaging/ios"
dependency_prefix="$repo_root/build-ios/deps/$mode/prefix"
qt_prefix="$repo_root/build-ios/qt/$mode/prefix"
framework_prefix="$repo_root/build-ios/frameworks/$mode/prefix"
kf6_host_tooling="$repo_root/build-ios/frameworks/host-tools/cmake"

"$ios_dir/scripts/check-host.sh"

require_file() {
    if [[ ! -f "$1" ]]; then
        echo "error: required build input is missing: $1" >&2
        exit 1
    fi
}

require_file "$dependency_prefix/lib/libz.a"
require_file "$qt_prefix/lib/cmake/Qt6/Qt6Config.cmake"
require_file "$framework_prefix/lib/cmake/KF6Config/KF6ConfigConfig.cmake"
require_file "$kf6_host_tooling/KF6Config/KF6ConfigCompilerTargets.cmake"

host_qttools="$(
    cd "$repo_root"
    nix build --no-link --print-out-paths .#host-qttools | tail -n 1
)"
linguist_tools_dir="$host_qttools/lib/cmake/Qt6LinguistTools"
require_file "$linguist_tools_dir/Qt6LinguistToolsConfig.cmake"

export KRITA_IOS_PREFIX_PATH="$framework_prefix;$qt_prefix;$dependency_prefix"
export KRITA_IOS_KF6_HOST_TOOLING="$kf6_host_tooling"
export KRITA_IOS_LINGUIST_TOOLS_DIR="$linguist_tools_dir"

cmake --preset "ios-$mode"
if (( build )); then
    cmake --build --preset "ios-$mode" --parallel
fi

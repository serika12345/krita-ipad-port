#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
    echo "usage: $0 <device|simulator> <Mach-O binary>" >&2
    exit 2
fi

mode="$1"
binary="$2"

if [[ ! -f "$binary" ]]; then
    echo "error: binary does not exist: $binary" >&2
    exit 1
fi

file_output="$(file "$binary")"
arch_output="$(xcrun lipo -archs "$binary")"
build_output="$(xcrun vtool -show-build "$binary")"

echo "$file_output"
echo "architectures: $arch_output"
echo "$build_output"

if [[ " $arch_output " != *" arm64 "* ]]; then
    echo "error: expected arm64 slice" >&2
    exit 1
fi

case "$mode" in
    device)
        expected="platform IOS"
        ;;
    simulator)
        expected="platform IOSSIMULATOR"
        ;;
    *)
        echo "error: mode must be device or simulator" >&2
        exit 2
        ;;
esac

if ! grep -q "$expected" <<<"$build_output"; then
    echo "error: expected '$expected'; refusing a host/platform-mismatched binary" >&2
    exit 1
fi

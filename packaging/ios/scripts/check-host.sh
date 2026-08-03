#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
ios_dir="$(cd "$script_dir/.." && pwd)"

# shellcheck disable=SC1091
source "$ios_dir/versions.env"

failures=0
policy_failures=0

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "error: required command not found: $1" >&2
        failures=$((failures + 1))
    fi
}

for command in nix cmake ninja python3 pkg-config xcodebuild xcrun file; do
    require_command "$command"
done

if (( failures > 0 )); then
    exit 1
fi

xcode_version="$(xcodebuild -version | awk 'NR == 1 { print $2 }')"
xcode_build_version="$(xcodebuild -version | awk 'NR == 2 { print $3 }')"
sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
sdk_build_version="$(xcrun --sdk iphoneos --show-sdk-build-version)"
simulator_sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
nix_version="$(nix --version | awk '{ print $3 }')"
nix_config="$(nix config show)"
nix_sandbox="$(awk -F ' = ' '$1 == "sandbox" { print $2; exit }' <<<"$nix_config")"
nix_sandbox_fallback="$(awk -F ' = ' '$1 == "sandbox-fallback" { print $2; exit }' <<<"$nix_config")"
nix_allowed_impure_host_deps="$(awk -F ' = ' '$1 == "allowed-impure-host-deps" { print $2; exit }' <<<"$nix_config")"
nix_sandbox_paths="$(awk -F ' = ' '$1 == "sandbox-paths" { print $2; exit }' <<<"$nix_config")"
cmake_version="$(cmake --version | awk 'NR == 1 { print $3 }')"
clang_version="$(xcrun --sdk iphoneos clang --version | awk 'NR == 1 { print $0 }')"
clang_marketing_version="$(sed -E 's/^Apple clang version ([^ ]+).*/\1/' <<<"$clang_version")"
clang_build_version="$(sed -E 's/^.*\(clang-([^\)]+)\).*$/\1/' <<<"$clang_version")"

check_equal() {
    local name="$1"
    local actual="$2"
    local expected="$3"
    if [[ "$actual" != "$expected" ]]; then
        echo "error: $name is $actual; expected $expected" >&2
        failures=$((failures + 1))
    fi
}

check_policy_equal() {
    local name="$1"
    local actual="$2"
    local expected="$3"
    if [[ "$actual" != "$expected" ]]; then
        echo "error: $name is $actual; expected $expected" >&2
        policy_failures=$((policy_failures + 1))
    fi
}

check_equal "Xcode" "$xcode_version" "$KRITA_IOS_XCODE_VERSION"
check_equal "Xcode build" "$xcode_build_version" "$KRITA_IOS_XCODE_BUILD_VERSION"
check_equal "iPhoneOS SDK" "$sdk_version" "$KRITA_IOS_SDK_VERSION"
check_equal "iPhoneOS SDK build" "$sdk_build_version" "$KRITA_IOS_SDK_BUILD_VERSION"
check_equal "iPhoneSimulator SDK" "$simulator_sdk_version" "$KRITA_IOS_SDK_VERSION"
check_equal "Apple Clang" "$clang_marketing_version" "$KRITA_IOS_CLANG_VERSION"
check_equal "Apple Clang build" "$clang_build_version" "$KRITA_IOS_CLANG_BUILD_VERSION"
check_policy_equal "Nix sandbox" "$nix_sandbox" "true"
check_policy_equal "Nix sandbox fallback" "$nix_sandbox_fallback" "false"

if [[ " $nix_allowed_impure_host_deps " != *" /Applications/Xcode.app "* ]]; then
    echo "error: Xcode is absent from allowed-impure-host-deps" >&2
    policy_failures=$((policy_failures + 1))
fi

if [[ "$nix_sandbox_paths" == *"/Applications/Xcode.app"* ]]; then
    echo "error: Xcode must not be exposed globally through sandbox-paths" >&2
    policy_failures=$((policy_failures + 1))
fi

nix_major="${nix_version%%.*}"
nix_remainder="${nix_version#*.}"
nix_minor="${nix_remainder%%.*}"
minimum_major="${KRITA_IOS_NIX_MIN_VERSION%%.*}"
minimum_remainder="${KRITA_IOS_NIX_MIN_VERSION#*.}"
minimum_minor="${minimum_remainder%%.*}"
if (( nix_major < minimum_major || (nix_major == minimum_major && nix_minor < minimum_minor) )); then
    echo "error: Nix is $nix_version; minimum is $KRITA_IOS_NIX_MIN_VERSION" >&2
    failures=$((failures + 1))
fi

if [[ "${KRITA_IOS_ALLOW_UNVALIDATED_HOST:-0}" == "1" ]]; then
    failures=0
    echo "warning: version mismatches were allowed by KRITA_IOS_ALLOW_UNVALIDATED_HOST=1" >&2
fi

echo "Krita iPadOS host"
echo "  Xcode:       $xcode_version ($xcode_build_version)"
echo "  iPhoneOS:    $sdk_version ($sdk_build_version)"
echo "  Simulator:   $simulator_sdk_version"
echo "  SDK path:    $sdk_path"
echo "  Nix:         $nix_version (minimum $KRITA_IOS_NIX_MIN_VERSION)"
echo "  Sandbox:     $nix_sandbox (fallback $nix_sandbox_fallback)"
echo "  Xcode scope: explicit impure host dependency only"
echo "  CMake:       $cmake_version"
echo "  Compiler:    $clang_version"
echo "  Deployment:  iPadOS $KRITA_IOS_DEPLOYMENT_TARGET"
echo "  Architecture:$KRITA_IOS_ARCHITECTURE"

if (( failures > 0 || policy_failures > 0 )); then
    exit 1
fi

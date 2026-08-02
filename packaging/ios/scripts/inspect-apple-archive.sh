#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
    echo "usage: $0 <device|simulator> <static archive>" >&2
    exit 2
fi

mode="$1"
archive="$2"

if [[ ! -f "$archive" ]]; then
    echo "error: archive does not exist: $archive" >&2
    exit 1
fi
archive="$(cd "$(dirname "$archive")" && pwd)/$(basename "$archive")"

case "$mode" in
    device)
        expected_platform="IOS"
        ;;
    simulator)
        expected_platform="IOSSIMULATOR"
        ;;
    *)
        echo "error: mode must be device or simulator" >&2
        exit 2
        ;;
esac

file "$archive"
architectures="$(xcrun lipo -archs "$archive")"
echo "architectures: $architectures"
if [[ " $architectures " != *" arm64 "* ]] || [[ "$architectures" == *" "* ]]; then
    echo "error: expected exactly one arm64 slice" >&2
    exit 1
fi

member_count="$(xcrun ar -t "$archive" | grep -v '^__.SYMDEF' | wc -l | tr -d ' ')"
if [[ "$member_count" == "0" ]]; then
    echo "error: archive has no object members" >&2
    exit 1
fi

inspection_dir="$(mktemp -d "${TMPDIR:-/tmp}/krita-ios-archive.XXXXXX")"
trap 'rm -rf "$inspection_dir"' EXIT
(
    cd "$inspection_dir"
    xcrun ar -x "$archive"
)

extracted_count=0
while IFS= read -r -d '' member; do
    extracted_count=$((extracted_count + 1))
    member_architectures="$(xcrun lipo -archs "$member")"
    if [[ "$member_architectures" != "arm64" ]]; then
        echo "error: archive member is not arm64: $member ($member_architectures)" >&2
        exit 1
    fi
    if ! xcrun otool -l "$member" >/dev/null; then
        echo "error: otool could not read archive member load commands: $member" >&2
        exit 1
    fi
    build_output="$(xcrun vtool -show-build "$member")"
    if ! grep -Eq "platform[[:space:]]+$expected_platform([[:space:]]|$)" <<<"$build_output"; then
        echo "$build_output" >&2
        echo "error: archive member does not target $expected_platform: $member" >&2
        exit 1
    fi
done < <(find "$inspection_dir" -type f ! -name '__.SYMDEF*' -print0)

# Duplicate member names are overwritten by ar during extraction. Reject them so
# an uninspected object cannot hide behind a duplicate filename.
if [[ "$extracted_count" != "$member_count" ]]; then
    echo "error: inspected $extracted_count of $member_count members; duplicate names are not allowed" >&2
    exit 1
fi

echo "members: $member_count; all arm64/$expected_platform"

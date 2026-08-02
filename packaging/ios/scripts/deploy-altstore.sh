#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "usage: $0 [--skip-build] [CoreDevice identifier]" >&2
    exit 2
}

skip_build=0
if (( $# > 0 )) && [[ "$1" == "--skip-build" ]]; then
    skip_build=1
    shift
fi
if (( $# > 1 )); then
    usage
fi

repo_root="$(git rev-parse --show-toplevel)"
scripts_dir="$repo_root/packaging/ios/scripts"
build_dir="$repo_root/build-ios/krita/device-ninja"
app_path="$build_dir/bin/krita.app"
binary="$app_path/krita"
archive_dir="$build_dir/lib"
device_id="${1:-${KRITA_IOS_DEVICE:-}}"

if [[ -z "$device_id" ]]; then
    device_id="$(xcrun devicectl list devices | awk '
        /(connected|available)/ {
            for (field = 1; field <= NF; field++) {
                if (length($field) == 36 && $field ~ /^[[:xdigit:]-]+$/) {
                    print $field
                    exit
                }
            }
        }
    ')"
fi
if [[ -z "$device_id" ]]; then
    echo "error: no available CoreDevice found" >&2
    exit 1
fi

if (( ! skip_build )); then
    (
        cd "$repo_root"
        nix develop --command "$scripts_dir/configure-krita.sh" device --build
    )
fi

"$scripts_dir/inspect-apple-binary.sh" device "$binary"
"$scripts_dir/inspect-static-resources.sh" "$binary" "$archive_dir"
plutil -lint "$app_path/Info.plist"

if ! pgrep -x AltServer >/dev/null; then
    echo "error: AltServer is not running" >&2
    exit 1
fi

apps_output="$(xcrun devicectl device info apps --device "$device_id")"
altstore_bundle_id="$(awk '$1 == "AltStore" { print $2; exit }' <<<"$apps_output")"
if [[ -z "$altstore_bundle_id" ]]; then
    echo "error: AltStore is not installed on the selected device" >&2
    exit 1
fi

stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/krita-altstore.XXXXXX")"
server_pid=""
cleanup() {
    if [[ -n "$server_pid" ]]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf "$stage_dir"
}
trap cleanup EXIT

mkdir -p "$stage_dir/Payload"
ditto "$app_path" "$stage_dir/Payload/krita.app"

cmake_command="$(awk -F= '$1 == "CMAKE_COMMAND:INTERNAL" { print $2; exit }' "$build_dir/CMakeCache.txt")"
if [[ -z "$cmake_command" || ! -x "$cmake_command" ]]; then
    echo "error: could not find the CMake executable used to configure the build" >&2
    exit 1
fi

runtime_prefix="$stage_dir/runtime"
runtime_install_log="$stage_dir/runtime-install.log"
if ! "$cmake_command" -DCMAKE_INSTALL_PREFIX="$runtime_prefix" \
    -P "$build_dir/krita/data/cmake_install.cmake" >"$runtime_install_log" 2>&1; then
    cat "$runtime_install_log" >&2
    exit 1
fi
if ! "$cmake_command" -DCMAKE_INSTALL_PREFIX="$runtime_prefix" \
    -P "$build_dir/plugins/cmake_install.cmake" >>"$runtime_install_log" 2>&1; then
    cat "$runtime_install_log" >&2
    exit 1
fi

# These core action registries are installed by krita/CMakeLists.txt rather
# than the krita/data subtree. Stage them without running the complete Krita
# install script, which would also duplicate and mutate the application bundle.
core_actions_dir="$runtime_prefix/share/krita/actions"
"$cmake_command" -E make_directory "$core_actions_dir"
"$cmake_command" -E copy_if_different \
    "$repo_root/krita/krita.action" \
    "$repo_root/krita/kritamenu.action" \
    "$core_actions_dir"

if [[ ! -d "$runtime_prefix/share" ]]; then
    echo "error: the iPadOS runtime data install produced no share directory" >&2
    exit 1
fi
ditto "$runtime_prefix/share" "$stage_dir/Payload/krita.app/share"
"$scripts_dir/inspect-runtime-data.sh" \
    "$stage_dir/Payload/krita.app" "$runtime_prefix"

bundle_version="${KRITA_IOS_BUNDLE_VERSION:-$(date -u +%Y%m%d%H%M%S)}"
plutil -replace CFBundleVersion -string "$bundle_version" "$stage_dir/Payload/krita.app/Info.plist"

output_dir="$repo_root/build-ios/deploy"
mkdir -p "$output_dir"
ipa_name="Krita-iPad-${bundle_version}.ipa"
ipa_path="$output_dir/$ipa_name"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$stage_dir/Payload" "$ipa_path"
unzip -tq "$ipa_path"

network_interface="$(route -n get default | awk '$1 == "interface:" { print $2; exit }')"
host_ip="$(ipconfig getifaddr "$network_interface" 2>/dev/null || true)"
if [[ -z "$host_ip" ]]; then
    echo "error: could not determine the Mac's default-route IPv4 address" >&2
    exit 1
fi

port="${KRITA_IOS_DEPLOY_PORT:-8765}"
while lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; do
    port="$((port + 1))"
done

server_log="$stage_dir/http-server.log"
python3 -m http.server "$port" --bind "$host_ip" --directory "$output_dir" >"$server_log" 2>&1 &
server_pid="$!"
sleep 1
if ! kill -0 "$server_pid" 2>/dev/null; then
    echo "error: failed to start local IPA server" >&2
    cat "$server_log" >&2
    exit 1
fi

download_url="http://${host_ip}:${port}/${ipa_name}"
encoded_url="http%3A%2F%2F${host_ip}%3A${port}%2F${ipa_name}"
install_url="altstore-classic://install?url=${encoded_url}"

echo "device:         $device_id"
echo "AltStore:       $altstore_bundle_id"
echo "bundle version: $bundle_version"
echo "IPA:            $ipa_path"
echo "download URL:   $download_url"
echo "Opening AltStore installation deep link..."

xcrun devicectl device process launch \
    --device "$device_id" \
    --terminate-existing \
    --payload-url "$install_url" \
    "$altstore_bundle_id"

echo "Waiting for AltStore to download the IPA..."
downloaded=0
for _ in {1..300}; do
    if grep -Fq "GET /${ipa_name} HTTP/1.1\" 200" "$server_log"; then
        downloaded=1
        break
    fi
    sleep 1
done
if (( ! downloaded )); then
    echo "error: AltStore did not download the IPA within 5 minutes" >&2
    cat "$server_log" >&2
    exit 1
fi

echo "IPA downloaded; waiting for the signed app to be installed..."
installed_bundle_id=""
for _ in {1..300}; do
    installed_line="$(xcrun devicectl device info apps --device "$device_id" \
        | awk '$2 ~ /^org\.krita\.ipad\.port/ { print; exit }')"
    installed_version="$(awk '{ print $4 }' <<<"$installed_line")"
    if [[ "$installed_version" == "$bundle_version" ]]; then
        installed_bundle_id="$(awk '{ print $2 }' <<<"$installed_line")"
        break
    fi
    sleep 1
done
if [[ -z "$installed_bundle_id" ]]; then
    echo "error: the signed app was not installed within 5 minutes" >&2
    exit 1
fi

echo "installed: $installed_bundle_id ($bundle_version)"
xcrun devicectl device process launch --device "$device_id" --terminate-existing "$installed_bundle_id"

launch_log="$output_dir/Krita-iPad-${bundle_version}-krita.log"
sleep "${KRITA_IOS_LAUNCH_SETTLE_SECONDS:-5}"
if xcrun devicectl device copy from \
    --device "$device_id" \
    --domain-type appDataContainer \
    --domain-identifier "$installed_bundle_id" \
    --source "Library/Application Support/krita.log" \
    --destination "$launch_log" >/dev/null; then
    echo "startup log:    $launch_log"
else
    echo "warning: could not collect the Krita startup log" >&2
fi

"$scripts_dir/maintain-build-cache.sh"

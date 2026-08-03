#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
usage: restore-nix-cache.sh [flake-installable ...]

Environment:
  KRITA_IOS_NIX_CACHE_URI  source store URI

The default source is the ignored local cache at
build-ios/nix-binary-cache. Local file-cache objects are allowed to be
unsigned; remote caches must be configured with a trusted public key.
EOF
    exit 2
}

if (( $# > 0 )) && [[ "$1" == "--help" ]]; then
    usage
fi

repo_root="$(git rev-parse --show-toplevel)"
default_cache_dir="$repo_root/build-ios/nix-binary-cache"
cache_uri="${KRITA_IOS_NIX_CACHE_URI:-file://$default_cache_dir}"

if (( $# == 0 )); then
    installables=(.#ios-dependencies)
else
    installables=("$@")
fi

copy_options=()
if [[ "$cache_uri" == file://* ]]; then
    copy_options+=(--no-check-sigs)
fi

for installable in "${installables[@]}"; do
    output="$(nix eval --raw "${installable}.outPath")"
    nix copy --from "$cache_uri" "${copy_options[@]}" "$output"
    nix store verify --recursive --no-trust "$output"
    echo "restored: $output"
done

echo "cache: $cache_uri"

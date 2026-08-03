#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
usage: publish-nix-cache.sh [flake-installable ...]

Environment:
  KRITA_IOS_NIX_CACHE_URI          destination store URI
  KRITA_IOS_NIX_CACHE_SIGNING_KEY optional Nix cache private key

The default destination is the ignored local cache at
build-ios/nix-binary-cache. A non-file cache requires a signing key.
EOF
    exit 2
}

if (( $# > 0 )) && [[ "$1" == "--help" ]]; then
    usage
fi

repo_root="$(git rev-parse --show-toplevel)"
default_cache_dir="$repo_root/build-ios/nix-binary-cache"
cache_uri="${KRITA_IOS_NIX_CACHE_URI:-file://$default_cache_dir}"
signing_key="${KRITA_IOS_NIX_CACHE_SIGNING_KEY:-}"

if (( $# == 0 )); then
    installables=(.#ios-dependencies)
else
    installables=("$@")
fi

if [[ "$cache_uri" == "file://$default_cache_dir" ]]; then
    mkdir -p "$default_cache_dir"
elif [[ "$cache_uri" != file://* && -z "$signing_key" ]]; then
    echo "error: a non-file cache requires KRITA_IOS_NIX_CACHE_SIGNING_KEY" >&2
    exit 2
fi

outputs=()
for installable in "${installables[@]}"; do
    while IFS= read -r output; do
        [[ -n "$output" ]] && outputs+=("$output")
    done < <(nix build --no-link --print-out-paths "$installable")
done

if (( ${#outputs[@]} == 0 )); then
    echo "error: no Nix output was produced" >&2
    exit 1
fi

if [[ -n "$signing_key" ]]; then
    if [[ ! -f "$signing_key" ]]; then
        echo "error: Nix cache signing key does not exist: $signing_key" >&2
        exit 1
    fi
    nix store sign --recursive --key-file "$signing_key" "${outputs[@]}"
fi

nix copy --to "$cache_uri" "${outputs[@]}"
for output in "${outputs[@]}"; do
    nix store verify --store "$cache_uri" --recursive --no-trust "$output"
    echo "cached: $output"
done

echo "cache: $cache_uri"

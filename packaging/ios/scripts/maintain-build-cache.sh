#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "usage: $0 [--force-nix-gc]" >&2
    exit 2
}

force_nix_gc=0
if (( $# > 1 )); then
    usage
fi
if (( $# == 1 )); then
    [[ "$1" == "--force-nix-gc" ]] || usage
    force_nix_gc=1
fi

repo_root="$(git rev-parse --show-toplevel)"
deploy_dir="$repo_root/build-ios/deploy"
keep_ipas="${KRITA_IOS_KEEP_IPAS:-3}"
minimum_free_gib="${KRITA_IOS_GC_MIN_FREE_GIB:-20}"

if ! [[ "$keep_ipas" =~ ^[1-9][0-9]*$ ]]; then
    echo "error: KRITA_IOS_KEEP_IPAS must be a positive integer" >&2
    exit 2
fi
if ! [[ "$minimum_free_gib" =~ ^[1-9][0-9]*$ ]]; then
    echo "error: KRITA_IOS_GC_MIN_FREE_GIB must be a positive integer" >&2
    exit 2
fi

# IPA files are reproducible deployment artifacts. Keep the newest few, while
# retaining logs and screenshots used for device debugging.
ipa_files=()
if [[ -d "$deploy_dir" ]]; then
    while IFS= read -r ipa; do
        ipa_files+=("$ipa")
    done < <(find "$deploy_dir" -maxdepth 1 -type f -name 'Krita-iPad-*.ipa' -print | sort)
fi

prune_count=$((${#ipa_files[@]} - keep_ipas))
if (( prune_count > 0 )); then
    for ((index = 0; index < prune_count; ++index)); do
        echo "removing old IPA: ${ipa_files[index]}"
        rm -- "${ipa_files[index]}"
    done
fi

# Protect everything needed by the normal iPad build before collecting dead
# Nix store paths. This prevents a cleanup from turning the next build into a
# dependency download/rebuild.
nix_roots="$repo_root/build-ios/nix-roots"
mkdir -p "$nix_roots"
if [[ ! -e "$nix_roots/dev-shell" ]]; then
    nix develop --profile "$nix_roots/dev-shell" --command true
fi
if [[ ! -e "$nix_roots/host-qttools" ]]; then
    nix build --out-link "$nix_roots/host-qttools" .#host-qttools
fi
current_ios_dependencies="$(nix eval --raw .#ios-dependencies.outPath)"
if nix-store --check-validity "$current_ios_dependencies" 2>/dev/null; then
    # Refresh a stale out-link only when the new aggregate is already built.
    # Cache maintenance must not trigger a target dependency compilation.
    nix build --out-link "$nix_roots/ios-dependencies" .#ios-dependencies
elif [[ ! -e "$nix_roots/ios-dependencies" ]]; then
    echo "Nix GC root deferred: build .#ios-dependencies before collecting target dependencies"
fi

available_kib="$(df -Pk "$repo_root" | awk 'NR == 2 { print $4 }')"
minimum_free_kib=$((minimum_free_gib * 1024 * 1024))
if (( ! force_nix_gc && available_kib >= minimum_free_kib )); then
    echo "Nix GC skipped: free space is above ${minimum_free_gib} GiB"
    exit 0
fi

echo "collecting unreachable Nix store paths..."
nix-store --gc

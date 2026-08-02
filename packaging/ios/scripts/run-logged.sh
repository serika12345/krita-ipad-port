#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 )); then
    echo "usage: $0 <log-name> <command> [args ...]" >&2
    exit 2
fi

log_name="$1"
shift

repo_root="$(git rev-parse --show-toplevel)"
log_root="${KRITA_IOS_LOG_ROOT:-$repo_root/logs/ios}"
mkdir -p "$log_root"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_root/${timestamp}-${log_name}.log"

echo "log: $log_file"
"$@" 2>&1 | tee "$log_file"

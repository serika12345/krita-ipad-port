#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
exec python3 "$repo_root/packaging/ios/scripts/build-frameworks.py" "$@"

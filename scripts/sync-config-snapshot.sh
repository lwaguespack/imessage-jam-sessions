#!/usr/bin/env bash
# Usage: scripts/sync-config-snapshot.sh [--check]   Regenerates the tunables snapshot the Python tools read.
# With --check, fails if the committed snapshot differs from what the engine prints.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
snapshot="$repo_root/tools/riff_tools/data/gameconfig.json"
fresh="$(mktemp)"
trap 'rm -f "$fresh"' EXIT

"$repo_root/scripts/swiftw" run --package-path "$repo_root/Packages/RiffCore" riffcli config >"$fresh"

if [[ "${1:-}" == "--check" ]]; then
    if ! diff -u "$snapshot" "$fresh"; then
        echo "sync-config-snapshot: the snapshot is stale. Run scripts/sync-config-snapshot.sh and commit." >&2
        exit 1
    fi
    echo "sync-config-snapshot: snapshot matches the engine"
else
    cp "$fresh" "$snapshot"
    echo "sync-config-snapshot: wrote ${snapshot#"$repo_root"/}"
fi

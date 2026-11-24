#!/usr/bin/env bash
# Usage: scripts/test-simulate-cli.sh   Verify the seeded simulator output and argument handling.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"
fixtures=Packages/iMessageRiffCore/Tests/iMessageRiffCoreTests/Fixtures
chart="$fixtures/example-medium.json"
output="$(scripts/swiftw run --package-path Packages/iMessageRiffCore imessageriffcli simulate "$chart" --seed 42 --runs 3)"
if [[ "$output" != "$(< "$fixtures/simulate-seed-42.txt")" ]]; then
    echo "simulator output did not match the seeded golden run:" >&2
    diff -u "$fixtures/simulate-seed-42.txt" <(printf '%s\n' "$output") >&2 || true
    exit 1
fi
if scripts/swiftw run --package-path Packages/iMessageRiffCore imessageriffcli simulate "$chart" --seed 42 --runs 0 >/dev/null 2>&1; then
    echo "simulator accepted zero runs" >&2
    exit 1
fi
echo "simulator matches the seeded golden run"

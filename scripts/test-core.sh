#!/usr/bin/env bash
# Usage: scripts/test-core.sh [swift test arguments...]   Runs every RiffCore test, e.g. with --filter LevelCurve.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

exec "$repo_root/scripts/swiftw" test --package-path "$repo_root/Packages/RiffCore" "$@"

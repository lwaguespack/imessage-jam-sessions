#!/usr/bin/env bash
# Usage: scripts/lint.sh   Checks Swift formatting (swift format) and Python style (ruff).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

scripts/swiftw format lint --strict --recursive Packages iMessageRiffMessages
(cd tools && ruff check . && ruff format --check .)
echo "lint: ok"

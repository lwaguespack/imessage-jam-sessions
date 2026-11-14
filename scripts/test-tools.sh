#!/usr/bin/env bash
# Usage: scripts/test-tools.sh [pytest arguments...]   Lints and tests the Python tools.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root/tools"

ruff check .
ruff format --check .
# pytest may live outside the default interpreter's site-packages (pipx, uv), so prefer the command.
if command -v pytest >/dev/null 2>&1; then
    pytest -q "$@"
else
    python3 -m pytest -q "$@"
fi

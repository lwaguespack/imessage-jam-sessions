#!/usr/bin/env bash
# Usage: scripts/check.sh   Runs every check that works without Xcode. Run it before pushing.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

failed=0
step() {
    local name="$1"
    shift
    if "$@" >/tmp/riff-check.log 2>&1; then
        echo "PASS  $name"
    else
        echo "FAIL  $name"
        sed 's/^/      /' /tmp/riff-check.log | tail -40
        failed=1
    fi
}

step "Swift formatting" scripts/swiftw format lint --strict --recursive Packages RiffMessages
step "RiffCore tests" scripts/test-core.sh
step "Tunables snapshot is current" scripts/sync-config-snapshot.sh --check
step "Example chart is valid" scripts/swiftw run --package-path Packages/RiffCore riffcli chart check \
    Packages/RiffCore/Tests/RiffCoreTests/Fixtures/example-medium.json
step "Python tools" scripts/test-tools.sh
step "Icon set is complete" python3 scripts/make-placeholder-icons.py --check

echo
echo "Not run here (CI runs them on macOS): xcodegen generate, the iOS Simulator build."
exit "$failed"

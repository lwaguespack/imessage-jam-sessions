#!/usr/bin/env bash
# Usage: scripts/bootstrap.sh   One-time setup on a Mac: installs XcodeGen if needed and generates Riff.xcodeproj.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

if [[ "$(uname -s)" != Darwin ]]; then
    echo "bootstrap: the Xcode project can only be generated on macOS." >&2
    echo "bootstrap: on Linux, use scripts/check.sh; CI builds the iOS targets on every push." >&2
    exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
    echo "bootstrap: Xcode is not installed or not selected. Install Xcode, open it once, then run:" >&2
    echo "    sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "bootstrap: XcodeGen is missing and Homebrew is not installed." >&2
        echo "bootstrap: install Homebrew from https://brew.sh, then run this script again." >&2
        exit 1
    fi
    echo "bootstrap: installing XcodeGen with Homebrew"
    # Otherwise the install can run Homebrew's periodic cleanup, which removes unrelated packages.
    HOMEBREW_NO_INSTALL_CLEANUP=1 brew install xcodegen
fi

if [[ ! -f Config/Local.xcconfig ]]; then
    cp Config/Local.xcconfig.example Config/Local.xcconfig
    echo "bootstrap: created Config/Local.xcconfig. Set RIFF_BUNDLE_PREFIX and DEVELOPMENT_TEAM in it."
fi

xcodegen generate

cat <<'NEXT'

Next steps
  1. Edit Config/Local.xcconfig (your bundle prefix and Team ID), then run scripts/bootstrap.sh again.
  2. open Riff.xcodeproj
  3. Choose the Riff scheme and an iPhone simulator or your iPhone, then Run.
     If Xcode asks which app to run, pick Messages.
  4. In Messages, open a conversation, tap +, then More, and choose Riff.
NEXT

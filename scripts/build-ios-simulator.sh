#!/usr/bin/env bash
# Usage: scripts/build-ios-simulator.sh   Generate the Xcode project and build Riff for the iOS Simulator.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

if [[ "$(uname -s)" != Darwin ]]; then
    echo "build-ios-simulator: an iOS Simulator build requires macOS and Xcode." >&2
    exit 1
fi

for tool in xcodebuild xcodegen; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "build-ios-simulator: $tool is required. Run scripts/bootstrap.sh first." >&2
        exit 1
    fi
done

xcodegen generate

set -o pipefail
xcodebuild -project Riff.xcodeproj -scheme Riff -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO build 2>&1 | tee xcodebuild.log

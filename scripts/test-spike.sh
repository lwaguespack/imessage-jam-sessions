#!/usr/bin/env bash
# Usage: scripts/test-spike.sh   Run the spike's diagnostic tests on macOS.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

if [[ "$(uname -s)" != Darwin ]]; then
    echo "test-spike: the iOS spike tests require the macOS Xcode toolchain." >&2
    exit 1
fi

test_binary="$(mktemp -t riff-spike-tests)"
trap 'rm -f "$test_binary"' EXIT

xcrun swiftc -swift-version 6 -parse-as-library RiffMessages/Spike/SpikePayload.swift \
    RiffMessages/Spike/SpikeStatistics.swift \
    Tests/SpikePayloadTests.swift -o "$test_binary"
"$test_binary"

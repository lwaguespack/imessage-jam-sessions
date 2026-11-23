#!/usr/bin/env bash
# Usage: scripts/test-payload-cli.sh   Verify payload inspect against the versioned golden vectors.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"
fixtures=Packages/RiffCore/Tests/RiffCoreTests/Fixtures

for version in 1 2; do
    IFS= read -r payload < "$fixtures/payload-v$version.txt"
    if [[ "$version" == 1 ]]; then
        IFS= read -r expected < "$fixtures/payload-v1-upgraded-v2.txt"
    else
        expected="$payload"
    fi
    output="$(scripts/swiftw run --package-path Packages/RiffCore riffcli payload inspect "data:text/plain,$payload")"
    if ! grep -Fxq "wireVersion: $version" <<< "$output" \
        || ! grep -Fxq "canonicalV2: $expected" <<< "$output"; then
        echo "payload inspect did not round-trip the version-$version vector:" >&2
        printf '%s\n' "$output" >&2
        exit 1
    fi
done
echo "payload inspect matches both golden vectors"

#!/usr/bin/env bash
# Usage: scripts/coverage-core.sh [--min PERCENT DIR...]
# Runs the iMessageRiffCore tests with coverage and prints line coverage for each file under Sources/iMessageRiffCore.
# With --min, fails unless each DIR (relative to Sources/iMessageRiffCore, for example Engine) has at least PERCENT of its
# lines covered, counted over the whole directory. A directory with no measured lines fails.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
package="$repo_root/Packages/iMessageRiffCore"

if [[ $# -gt 0 ]] && { [[ "$1" != "--min" || $# -lt 3 ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; }; then
    echo "usage: scripts/coverage-core.sh [--min PERCENT DIR...]" >&2
    exit 64
fi

# Test output goes to stderr so that stdout carries only the report.
"$repo_root/scripts/swiftw" test --package-path "$package" --enable-code-coverage >&2
export_path="$("$repo_root/scripts/swiftw" test --package-path "$package" --show-codecov-path)"

python3 - "$export_path" "$@" <<'PY'
import json
import sys

export_path, options = sys.argv[1], sys.argv[2:]
minimum = int(options[1]) if options else None
directories = [name.strip("/") for name in options[2:]]

with open(export_path, encoding="utf-8") as handle:
    export = json.load(handle)

marker = "/Sources/iMessageRiffCore/"
files = {}
for entry in export["data"][0]["files"]:
    if marker in entry["filename"]:
        lines = entry["summary"]["lines"]
        files[entry["filename"].split(marker, 1)[1]] = (lines["covered"], lines["count"])
if not files:
    sys.exit("coverage-core: the coverage export lists no file under Sources/iMessageRiffCore")


def row(name, covered, count):
    share = f"{covered * 100 / count:5.1f}%" if count else "  none"
    return f"{share}  {covered:>5}/{count:<5}  {name}"


for name in sorted(files):
    print(row(name, *files[name]))
print(row("all of Sources/iMessageRiffCore", sum(c for c, _ in files.values()), sum(n for _, n in files.values())))
print("Files with no executable lines are not listed.")

failed = False
for directory in directories:
    inside = [counts for name, counts in files.items() if name.startswith(directory + "/")]
    covered, count = sum(c for c, _ in inside), sum(n for _, n in inside)
    passed = count > 0 and covered * 100 >= minimum * count
    print(("PASS  " if passed else "FAIL  ") + row(directory + "/", covered, count) + f"  (needs {minimum}%)")
    failed = failed or not passed
sys.exit(1 if failed else 0)
PY

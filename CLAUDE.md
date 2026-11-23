# Working notes for coding agents

Riff (code name) is an iPhone-first iMessage app extension: an async, turn-based, 4-lane rhythm game with
duels, group rounds and an XP meta, no server. Every game rule lives in the pure-Swift package
`Packages/RiffCore`; the Messages extension (`RiffMessages`) holds screens, audio and rendering.

## Read first

- `docs/DECISIONS.md`: what the plan review changed. It overrides `docs/PLAN.md` where they differ.
- `docs/plan/README.md`: the phase-by-phase outline and what to build next.
- `docs/specs/`: exact rules. Implement from these, not from memory of the plan.

## Commands

| Command | When |
| --- | --- |
| `scripts/check.sh` | Before every push. Runs local checks and, on macOS, the iOS Simulator build. |
| `scripts/build-ios-simulator.sh` | On macOS: generates `Riff.xcodeproj` and builds the unsigned Riff scheme for the iOS Simulator. |
| `scripts/test-core.sh [--filter Name]` | While working on `RiffCore`. |
| `scripts/test-tools.sh` | While working on `tools/`. |
| `scripts/swiftw format --in-place --recursive Packages RiffMessages` | Before committing Swift. |
| `scripts/sync-config-snapshot.sh` | After any change to `GameConfig`. Commit the result. |
| `RIFF_WRITE_FIXTURES=1 scripts/test-core.sh --filter fileMatchesTheBuilder` | After a change to the example chart or to `rulesVersion`: rewrites the chart fixture. Commit the result. |
| `scripts/coverage-core.sh [--min N Dir...]` | Line coverage of `RiffCore`, file by file; `--min` enforces it per directory. |
| `scripts/bootstrap.sh` | macOS only: generates `Riff.xcodeproj`. |

## Building with or without a Mac

On macOS with Xcode and XcodeGen, run `scripts/bootstrap.sh` once to generate the project, then
`scripts/build-ios-simulator.sh` to build the unsigned Riff scheme for the iOS Simulator.
`scripts/check.sh` runs this build automatically on macOS.

Cloud sessions run Linux, where there is no Xcode. `scripts/swiftw` runs Swift natively or in Docker
(`swift:6.2-noble`; it starts `dockerd` itself if needed), which covers `RiffCore`. The `ios` job in
`.github/workflows/ci.yml` generates the project and builds the simulator target on a macOS runner.
Extension code cannot be compiled locally on Linux, so check every Apple API signature against the
documentation before pushing.

## Hard rules

- `RiffCore` imports only `Foundation`. It must build on Linux, where CryptoKit, Compression and zlib do
  not exist. No third-party Swift packages anywhere.
- No `Double` in anything that affects a score, a ranking, XP or bytes on the wire. Time is `Int64`
  microseconds; chart positions are integer ticks; ratios are integers.
- `RiffCore` never reads a clock or a random source, and never lets `Dictionary` or `Set` order reach
  output.
- Every tunable number is a `GameConfig` property. Changing one that affects scoring bumps the rules
  version.
- A change to the payload or chart format bumps its schema version and adds a decode test for the
  previous version.
- Tests land in the same commit as the code they cover. Files stay under about 400 lines.
- `Riff.xcodeproj` and `Config/Local.xcconfig` are never committed.
- No names, terms or assets from other rhythm games.
- Log every decision in `docs/DECISIONS.md` with its reason.
- Anything that only a real device can confirm is listed in `docs/plan/phase-s-device-spike.md`; do not
  present a guess about device behaviour as fact.

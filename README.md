# Riff

A rhythm game that lives inside iMessage: friends take turns playing a short 4-lane note highway, and
each turn's score bubble dares the next player to beat it. "Riff" is a code name.

## Status

Nothing is playable yet. Phase 1 has configuration, chart validation, judging, scoring, hold and
Hype components with tests; the Messages extension has a temporary device-diagnostics build. The
device spike needs signed builds and real-device reports before the audio and gameplay phases can be
validated. The current order is in [docs/plan/](docs/plan/README.md).

## Documentation

| Document | What it is |
| --- | --- |
| [docs/PLAN.md](docs/PLAN.md) | The implementation plan (revision 1, as written before review) |
| [docs/PLAN_REVIEW.md](docs/PLAN_REVIEW.md) | The review of that plan: every finding, its evidence and outcome |
| [docs/DECISIONS.md](docs/DECISIONS.md) | What changed because of the review, and the decisions still open for the owner |
| [docs/plan/](docs/plan/README.md) | The detailed implementation outline, phase by phase |
| [docs/specs/](docs/specs/) | Exact rules the code is built from |

Where these disagree, DECISIONS.md and the specs win over PLAN.md.

## What you need

- A Mac with a current Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (the bootstrap script installs it).
- An Apple ID. A paid Apple Developer Program membership is needed once TestFlight is.
- Two iPhones on two Apple IDs for the device spike; Messages features cannot be signed off in the simulator.

## Quick start on a Mac

```sh
scripts/bootstrap.sh          # installs XcodeGen if needed, creates Config/Local.xcconfig, generates Riff.xcodeproj
# edit Config/Local.xcconfig: set RIFF_BUNDLE_PREFIX and DEVELOPMENT_TEAM, then run bootstrap again
scripts/build-ios-simulator.sh # generate the project and build the unsigned simulator app
open Riff.xcodeproj
```

Run the `Riff` scheme on a simulator or your iPhone (if Xcode asks which app to run, pick Messages).
In Messages, open a conversation, tap **+**, then **More**, and choose Riff. You should see a
placeholder screen showing the core version and whether the view is compact or expanded. The
**Device spike** entry opens the temporary diagnostics described in
[phase-s-device-spike.md](docs/plan/phase-s-device-spike.md).

`Riff.xcodeproj` is generated from `project.yml` and is never committed.

## Checks

```sh
scripts/check.sh              # everything that runs without Xcode
scripts/test-core.sh          # RiffCore tests only
scripts/test-tools.sh         # Python tools: ruff and pytest
scripts/test-spike.sh         # spike payload and measurement tests (macOS)
scripts/lint.sh               # formatting
scripts/coverage-core.sh      # RiffCore line coverage, file by file
```

`scripts/swiftw` runs `swift` from a local toolchain, or in Docker (`swift:6.2-noble`) when there is none,
so the core package builds and tests on Linux as well as macOS.

CI (GitHub Actions) runs on pushes to `main` and `claude/**`, on pull requests, and when manually
dispatched. It checks RiffCore on Linux, the Python tools, and on a macOS runner generates the Xcode
project, builds the unsigned iOS Simulator app, and tests RiffCore. `scripts/check.sh` also runs the
simulator build automatically on macOS.

## Layout

```text
project.yml            XcodeGen spec for the Xcode project
Config/                Build settings; Local.xcconfig (yours, gitignored) overrides Base.xcconfig
Packages/RiffCore/     Pure Swift: every game rule, plus the riffcli command-line tool and tests
RiffApp/               The iMessage app stub: Info.plist and store icon only, no code
RiffMessages/          The Messages extension: screens, audio, rendering
tools/                 Python content tools
scripts/               Developer scripts
docs/                  Plan, review, decisions, specs, phase outlines
LICENSES/              One licence file per song
```

## Conventions

- `RiffCore` imports nothing from UIKit, SpriteKit, AVFoundation or Messages, and builds on Linux.
- Time is integer microseconds and ratios are integers, so a run scores identically on every device.
- Every tunable number lives in `GameConfig`; after changing it, run `scripts/sync-config-snapshot.sh`.
- Tests land with the code they cover. Files stay under about 400 lines.
- No third-party Swift code. No names, terms or assets from other rhythm games.
- Decisions are logged in `docs/DECISIONS.md`.

## Licence

No source licence has been chosen yet, so all rights are reserved. Music licences are recorded per song
in [LICENSES/](LICENSES/README.md).

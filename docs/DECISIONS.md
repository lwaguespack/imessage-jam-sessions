# Decisions

Every decision that changes or pins down the plan, with its reason. Finding ids such as `MSG-1`
point into [PLAN_REVIEW.md](PLAN_REVIEW.md), where the evidence lives. Where this file and
[PLAN.md](PLAN.md) revision 1 disagree, this file wins.

Not everything here has been challenged equally: only the Messages findings had a skeptic pass, and
two review areas (build and content/UX/legal) did not run. PLAN_REVIEW.md says which is which.

**Status values**

- **Decided**: an engineering call made during the plan review. Reversible; say so and it changes.
- **Owner**: needs your call. The default shown is what the work assumes until you answer.
- **Device**: a real device has to confirm it. The device spike (Phase S) lists the test.

## Open decisions for the owner

| ID | Question | Default in use | Needed by |
| --- | --- | --- | --- |
| D-100 | Your Grok and Opus notes | Not received; plan reconciled against them when shared | Before Phase 1 ends |
| D-101 | Music source for the 5 launch songs | Commission originals with stems; placeholders until then | Phase 0 (long lead) |
| D-102 | Product name | "Riff" stays a code name until a name clears App Store and trademark searches | Phase 8 |
| D-103 | Bundle id prefix and Apple Developer Team | Placeholder prefix in `Config/Base.xcconfig`; yours go in `Config/Local.xcconfig` | Phase S |
| D-104 | Fallback web domain | `riff.invalid` placeholder (never resolves) | Phase 4 |
| D-052 | Ghost taps (a touch that matches no note) | Reset the streak; not counted as a Miss | Phase 1 |
| D-058 | Retries on a challenge run | Allowed, counted, and shown on the card ("try 3") | Phase 1 (payload) |
| D-062 | Song length | 60 to 90 seconds everywhere | Phase 5 |
| D-090 | Slow songs: the Hype rules need about 107 beats, so a 60-second song needs about 107 BPM | Keep the rules; choose songs that fit | Phase 5 (and D-101) |
| D-030 | Should the game play sound when the phone is on silent | Yes, once the player taps Play | Phase 2 |
| D-034 | Wireless audio (AirPods) in duels | Allowed, with a calibration prompt and a "best on speaker or wired" note | Phase 2 |
| D-070 | Sync progress through iCloud | No: device-only in v1, stated on the Profile screen | Phase 6 |
| D-012 | How long a group round stays open | 24 hours, or until the starter closes it | Phase 1 (payload) |
| D-105 | Business model | Free, no ads, no purchases in v1 (unchanged) | Phase 8 |
| D-106 | Source licence for this public repository | None chosen (all rights reserved by default) | Any time |

## Process and tooling

### D-001 The repository root is the project root; "Riff" is a code name
**Decided.** The plan's `riff/` folder is this repository. Every user-visible use of the name sits
behind one build setting so renaming is one edit.

### D-002 The build loop is CI plus a Swift container; your Mac is needed only for devices
**Decided.** Replaces plan section 12. The repository is public, so GitHub Actions macOS runners are
free: every push runs `xcodegen`, an unsigned simulator build and the test suites, and the logs are
readable from a cloud session. `RiffCore` also builds and tests on Linux (Swift 6.2 in Docker), so
rules work no longer waits on a Mac. What still needs you: running on real iPhones, TestFlight, and
pasting Diagnostics reports back.

### D-003 Formatting uses the toolchain's `swift format`
**Decided.** It ships inside Xcode and the Linux toolchain, so XcodeGen stays the only extra tool.
Replaces the plan's SwiftFormat config.

### D-004 Swift 6 language mode everywhere, from the first commit
**Decided.** The plan kept the extension in Swift 5 mode because of audio callbacks; the audio
design needs no render-thread code (player nodes only), so strict concurrency is cheap now and
expensive to retrofit. The extension target defaults to main-actor isolation.

### D-005 No App Group in v1
**Decided.** The wrapper is a stub with no code and never runs, so a shared container buys nothing
and adds a provisioning step (MSG-15). Data lives in the extension's Application Support directory;
stores take a base URL so a later companion app can move them into a group container.

### D-006 Bundle ids and the team come from xcconfig; nothing personal is committed
**Decided.** `Config/Base.xcconfig` holds placeholders; `Config/Local.xcconfig` (gitignored) holds
yours.

### D-007 One Swift command-line tool, built from the engine, validates charts
**Decided.** `riffcli` (in the `RiffCore` package) validates charts, writes their computed fields
(base score, score ceiling, star cut-offs, hash), runs the bot simulator and inspects payloads. A
Python re-implementation of scoring would drift from the engine. Python keeps what it is good at:
converting `.chart` files, drafting lower difficulties, generating audio.

### D-008 `GameConfig` is the single source of tunables and carries a `rulesVersion`
**Decided.** Python tools read a JSON snapshot of it that CI checks against the engine. Any change
to a value that affects scoring bumps `rulesVersion`; a test pins a digest of the scoring values so
a silent change fails. `rulesVersion` is part of the chart hash and the match payload, so two app
versions with different rules get "Update needed" instead of a quietly unfair duel (GAME-8).

### D-009 Determinism rules for the engine
**Decided.** `RiffCore` never reads a clock, a random source, or iterates a `Dictionary`/`Set`
where order reaches output. Bots use a seeded generator that ships in the package. Time is integer
microseconds, chart positions are integer ticks, ratios are integers (GAME-2, GAME-3, GAME-17).

## Messages platform

### D-010 Player identity is generated by the app, never taken from Messages
**Decided.** Apple documents participant UUIDs as scoped to one device, so a UUID written into a
payload means nothing on another phone (MSG-2, MATCH-2). Each install creates a random `playerId`
on first launch, stored with the profile. Messages UUIDs are used only locally: counting the roster
and recognising "this message was sent from my Apple ID". Identity and progress are per device in
v1: the same person on an iPhone and an iPad is two players. If the spike shows a message sent from
your other device arrives marked as sent by you, the app says "You played this on your other
device" instead of "Your turn".

### D-011 Match state is mergeable, and each device keeps its own copy
**Decided.** As planned, two people who play from the same bubble each send a state that omits the
other, and Messages keeps only the later message: a score silently disappears (MSG-1, MATCH-1).
Now: entries form a grow-only set keyed by round and player; merging two states is commutative,
associative and idempotent; every device keeps a `MatchStore` holding the merge of everything it has
decoded or sent; an outgoing message always carries the merged state; and if a tapped bubble lacks
an entry the device knows about, the match screen offers "Re-post" to repair the bubble without
replaying. Exact rules: [specs/MATCH_PROTOCOL.md](specs/MATCH_PROTOCOL.md).

### D-012 A group round ends when closed, when everyone counted at the start has played, or after 24 hours
**Owner (duration).** "Everyone has submitted" never happens in a real group chat: members without
the app count too (MSG-13, MATCH-3). The roster size at the start and the deadline travel in the
payload, so every device reaches the same verdict without another message. Entries stamped after
the end are shown as late and do not change the podium.

### D-013 Simultaneous rematches resolve deterministically
**Decided.** If both players start "round N+1" at once, the proposal with the earlier start time
wins (ties: lower player id). If both proposals are the same song and difficulty there is no
conflict: the two runs complete the round at once. The losing run is kept as a personal best and
its finish XP stands (MATCH-5).

### D-014 Bonus XP is paid once, from a ledger
**Decided.** Duel-win and podium XP are paid the first time a device sees a final round that
contains its own entry, recorded per match and round so reopening a bubble never pays twice. A duel
payload carries a summary of the previous round, because the bubble that showed it is replaced as
soon as the rematch is sent (MATCH-4).

### D-015 The payload is a small versioned binary layout, base64url, with the version readable first
**Decided.** Replaces "JSON, deflate, base64url" (MATCH-10, MATCH-13). Reasons: a provable size
bound (deflate's output depends on the text), no Compression/CryptoKit dependency (neither exists
on Linux, where the core is tested), and a version marker a future client can read before
anything else, so an old app can say "Update needed" instead of "Couldn't read this challenge".
Encoding is canonical: equal states give equal bytes.

### D-016 The integrity tag is a keyed checksum, not a secret
**Decided.** HMAC-SHA256 truncated to 8 bytes with a documented per-version constant key. Only this
extension can create its messages, and anyone able to run modified code has the key anyway, so the
tag detects corruption and casual edits and nothing more (MATCH-11). No build-time secret plumbing,
which also suits a public repository. SHA-256 is implemented in `RiffCore` (CryptoKit does not exist
on Linux) and cross-checked against CryptoKit in the macOS test run.

### D-017 The payload must never reach a web server; the spike picks the URL form
**Device.** With the payload in an https query string, opening the link on a Mac sends every
nickname and score to the web host, which contradicts "Data Not Collected" (MSG-11, MATCH-7). Three
forms are tested for a byte-exact round trip, in order of preference: a `data:` URL (allowed by
`MSMessage.url`; no server contact, no domain decision, and not sent as text to SMS recipients), an
https URL with the payload in the fragment (never sent to the server), and an https query on a
static, log-free page as the last resort. The decoder accepts all three.

### D-018 Nicknames are limited in bytes as well as characters
**Decided.** NFC-normalised, at most 16 grapheme clusters and 32 UTF-8 bytes, no control or
bidirectional-override characters; enforced on input and again on decode (MATCH-6). One emoji
sequence can be 40 bytes, so "16 characters" alone does not bound the payload.

### D-019 Decoding is an ordered pipeline with a distinct outcome per failure
**Decided.** Length, version, tag, structure, known song, content revision and chart hash, then
per-entry bounds. A bad entry is dropped, not the whole match. A content revision number lets a
mismatch say who must update (MATCH-14).

### D-020 A turn is submitted through a small state machine; the run is saved the moment the song ends
**Decided, send method Device.** `insert` only stages a draft the player can delete (MSG-8,
MATCH-8). States: played, staged, sending, confirmed. The finished run is persisted before the
results screen, and "Send your score" is offered again whenever the stored run is missing from the
bubble. The plan's insert-then-tap-Send flow stays; the spike compares it with an in-app "Send
score" button using `send`.

### D-021 Routing is a pure function of extension state
**Decided.** Selection in Messages is sticky and re-tapping the same bubble fires no callback
(MSG-5). The router is re-evaluated on every lifecycle callback from explicit inputs, lives in
`RiffCore` so it is unit-tested, and every match screen has a Home action.

### D-022 Bubble text comes from the payload; each message sets summary and accessibility text
**Decided.** Names in captions use the players' nicknames. The undocumented participant-name
placeholder is dropped unless the spike shows it renders real contact names. Each message sets
`summaryText` and `accessibilityLabel`. The card shows the top three and the sender's place; the
app shows yours (MSG-12, MATCH-19).

### D-023 Nothing depends on opening an external link
**Decided.** An iMessage-only extension cannot open URLs (MSG-6). "Update needed" shows
instructions (and an in-app App Store sheet if the spike confirms it works). Privacy policy,
licences and credits are rendered inside the app.

### D-024 Non-iMessage conversations are tested, then handled explicitly
**Device.** SMS, RCS and mixed groups cannot carry interactive message data (MSG-4). The spike
records what each recipient sees; the send screen warns when the result would be degraded.

### D-025 Touch input comes from a UIKit layer with its own gesture recognizer
**Device.** Since iOS 17 the expanded sheet's drag-to-collapse gesture competes with raw touch
handling, which is how SpriteKit scenes receive input (MSG-3). A dedicated view records
`UITouch.timestamp` and blocks competing recognizers during a song. A cancelled touch is a release,
never a miss. Spike task S5 gates Phase 3.

### D-026 Layout adapts; "portrait only" is not enforceable
**Decided.** Messages owns orientation (MSG-7). If the game view becomes wider than tall, or too
short, the song pauses and asks the player to rotate back. Layout is computed from the game view's
safe-area rectangle, never the device model.

### D-027 Runs pause on a defined list of signals and are discarded if the extension is killed
**Decided.** The signals are listed in the timing spec. There are no partial scores (MSG-9).

### D-028 TestFlight prerequisites move to Phase 0 and Phase S
**Decided.** The device spike needs TestFlight, which needs the App Store Connect record, a complete
icon set, a privacy manifest and the export-compliance answer (MSG-10). The scaffold already
contains the icon set and the manifest.

### D-029 Compact view is vertical lists with no text entry; live message layouts are not used in v1
**Decided.** The compact view replaces the keyboard (MSG-14). `MSMessageLiveLayout` would need a
template fallback anyway and adds a second view-controller instance under tight memory.

## Audio and timing

### D-030 Audio session: `.playback`, activated only when the player taps Play
**Owner (silent switch).** With the default category the Ring/Silent switch mutes the game
(AUD-1). `.playback` plays through silent but interrupts the player's own music, so the session is
activated lazily at Play and released (notifying other audio) on finish, pause and collapse.

### D-031 The song clock is anchored to rendered audio samples
**Decided.** The plan's clock was dead reckoning on the host clock from a requested start time, and
its "under 2 ms drift" gate was not measurable (AUD-2). Now the clock is derived each frame from the
player node's rendered sample position with a slew-limited filter. The Phase 2 gate is restated in
terms that hardware cannot fail for us.

### D-032 Latency term: the output latency only, read after start and on every route change
**Device.** Scheduled playback already accounts for the I/O buffer; adding it double-counts 5 to
21 ms (AUD-3).

### D-033 Calibration: 32 scored taps after 4 warm-ups, median, with rejection rules
**Decided.** Sixteen taps give a standard error near the ±10 ms gate, so a correct build would
fail the gate a third of the time (AUD-4). The estimator is pure code in `RiffCore` with tests.
The visual offset comes from the display's presentation time plus a trim slider, not a tap-to-flash
test (AUD-7).

### D-034 Routes are classed; offsets are stored per route; some routes are unsupported
**Owner (wireless in duels).** Built-in, wired, wireless, unsupported (AirPlay, HDMI, CarPlay).
Bluetooth latency moves by tens of milliseconds within a session (AUD-6), so wireless routes get a
prompt to calibrate and a note that speaker or wired gives the best scores.

### D-035 One suspend path, one resume path
**Decided.** Every pause signal calls the same routine; resume re-anchors and pre-rolls three beats
(AUD-9, GAME-10).

### D-036 A compatibility shim isolates audio calls deprecated in the iOS 27 SDK
**Decided, pending the skeptic's check of the deprecations.** (AUD-10)

### D-037 Shipped audio is 48 kHz AAC-LC produced by one scripted encoder path, and checked
**Decided.** A test asserts stems have equal length and the expected alignment (AUD-11). The
timing-test click is synthesised in the app as PCM, not shipped as a compressed file.

### D-038 Reactive feedback accounts for output latency
**Decided.** The miss duck holds until the next hit (120 to 600 ms) instead of a fixed 300 ms; the
tap-click is offered only on low-latency routes (AUD-12).

### D-039 The host clock is read through `CACurrentMediaTime`
**Decided.** `mach_absolute_time` and `systemUptime` are required-reason APIs (AUD-13).

### D-040 Chart sync is checked with an assist tick scheduled on the audio timeline
**Decided.** Autoplay is silent, so "check sync by ear" had nothing to hear (AUD-14).

### D-041 Spike S1 is a checklist with thresholds
**Decided.** It tests what is genuinely unknown: whether the extension may run a playback session
for 90 seconds and what Messages does to it on collapse, lock and calls (AUD-5).

## Gameplay rules

Exact rules: [specs/GAME_RULES.md](specs/GAME_RULES.md).

### D-050 The engine has an explicit time and ordering contract
**Decided.** Events (`touchDown`, `touchUp`, `activateHype`) carry integer-microsecond timestamps;
`advance(to:)` processes scheduled events in one total order; the driver advances a guard interval
behind real time so a late-delivered touch is never swept as a miss first (GAME-2, AUD-8). A
property test replays one input log under random `advance` subdivisions and requires identical
results.

### D-051 Tick-domain integer arithmetic
**Decided.** Tempo is integer milli-BPM. Sustain points and the Hype meter are accumulated in
ticks with one rounding rule, so the score does not depend on frame rate and the stored base score
is reproducible (GAME-3).

### D-052 A ghost tap resets the streak
**Owner.** With free stray touches, blind mashing earns a Full Combo and about 80% of base score
(GAME-1). A touch that matches no note resets the streak; it is not a Miss for accuracy or Hype. A
short bounce grace after a hit in the same lane is ignored. Full Combo means the longest streak
equals the note count. The penalty is a per-difficulty setting so Easy can be softened after
playtests.

### D-053 Star cut-offs are per-chart data computed by the chart tool
**Decided.** One miss costs a fixed 6,400 points whatever the chart length, so fixed percentages
punish short Easy charts hardest (GAME-4). Starting shares of base score are 10/25/45/65/85%,
re-derived with the bot simulator before any screen shows stars. The streak needed per multiplier
step is per difficulty (4, 6, 8, 10) so the ramp lasts a similar number of seconds.

### D-054 Same-lane minimum gaps exceed the hit window
**Decided.** 400, 250, 180, 180 ms. With the planned 90 and 150 ms a skipped note captured the tap
meant for the next one and downgraded every hit after it (GAME-5).

### D-055 Hype rules are pinned down
**Decided.** Phrase membership, completion, overflow, activation, extension while active, and what
a Miss does, as rules R1 to R7 (GAME-6).

### D-056 Hold rules are pinned down
**Decided.** A hold is one note. The touch that hits the head owns it; lifting ends the sustain for
good with no penalty; a missed head kills the hold, as rules H1 to H8 (GAME-7).

### D-057 Streak counts before the note; windows are inclusive; equal timestamps have a fixed order
**Decided.** (GAME-12)

### D-058 Challenge retries are allowed, counted and shown
**Owner.** The responder sees the score to beat and could replay until they win (GAME-9, MATCH-8).
An attempt is recorded when a challenge run starts; the entry carries the count; the card shows it;
fewer tries wins a tie. The stricter option is one attempt per round.

### D-059 Run lifecycle
**Decided.** Scroll time is the approach time to the strike line. The lead-in is a whole number of
beats. A run is final when every note is judged and every hold has ended (GAME-10).

### D-060 The difficulty table becomes rules a tool can check
**Decided.** Density windows, chord shares, cross-lane gaps and simultaneous-contact limits are
defined numerically (GAME-11).

### D-061 Accuracy and ranking are integer functions of transmitted values
**Decided.** Ranking: score, accuracy, longest streak, fewer tries, earlier time, lower player id
(GAME-14, MATCH-19).

### D-062 Songs are 60 to 90 seconds
**Owner.** The plan said 60 to 90 in two places and 60 to 120 in two others; 120 breaks the
"under two minutes" pillar (GAME-13).

### D-063 The score ceiling is tightened
**Decided.** The ceiling used to reject impossible scores assumed Hype for the whole song. It now
allows Hype only for as many beats as the chart's phrases can fund (GAME-15). The plan's example
score, 412,300, exceeded its own chart's ceiling and is corrected.

### D-064 Touch geometry is defined against the game view and settled in the spike
**Device.** The plan put the strike line inside the touch zone while claiming thumbs never cover
the gems (GAME-16). Columns follow the lane edges; whether thumbs tap on or below the line is
decided on a phone.

## Match and progression

### D-070 Progress is device-only in v1, stored so it can merge later
**Owner.** Level 50 is several hundred runs held in one local file (MATCH-9). v1 keeps the plan's
"no accounts, no network" and says so on the Profile screen. The stored model is merge-safe (XP as
a per-install counter, unlocks as a grow-only set) so iCloud sync can be added without a migration.

### D-071 Payload schema v1 field list
**Decided.** Adds roster size, deadline, attempt count, equipped title and frame, content revision,
rules version and the previous-round summary; drops stars and Full Combo, which are derived
(MATCH-12).

### D-072 XP is one integer formula
**Decided.** Events are summed, then streak, featured and practice multipliers apply as integer
percentages with one floor. Day one of a streak is +0%, day two +10%, capped at +50% (MATCH-15).

### D-073 Daily streak survives travel and ignores clock tricks
**Decided.** Stores the last run time in UTC, the local day, and a high-water mark (MATCH-16).

### D-074 Featured song rotates on a fixed-epoch week index over an explicit schedule
**Decided.** ISO week numbers restart every January and skip or repeat songs (MATCH-17).

### D-075 Unlocks: defaults are outside the counts; rewards are an explicit level table
**Decided.** Level is derived from XP, not stored (MATCH-18).

### D-076 Match and progression rules get a randomised convergence test and shared golden vectors
**Decided.** A simulator inside the `RiffCore` tests runs several devices through random message
orderings, duplicates, reinstalls and second devices, asserting convergence, no lost entry and
exactly-once XP (MATCH-20, adapted: written in Swift, since Swift now runs in every session).

## Carried into the first tasks

### D-080 `GameConfig` still holds revision-1 values where a decision changed them
**Decided; applied in task P1.0.** The scaffold's `GameConfig` was written from PLAN.md revision 1.
Task P1.0 applied the decided values (same-lane gaps, star shares, per-difficulty streak steps,
ghost-tap rule, song length, payload limits and miss-duck settings) and added `rulesVersion`, before
any engine code was written. The calibration settings first listed here wait for Phase 2 (D-083).
The list is in [plan/phase-1-core-rules.md](plan/phase-1-core-rules.md).

### D-081 The group-round concurrency test needs three Apple IDs
**Decided.** The plan budgeted two test devices; the race in D-011 only shows with three members
(MSG-1). Phase S asks for a third tester for one session.

### D-082 The two unfinished review areas are scheduled, not skipped
**Decided (by the owner).** The build/architecture and content/UX/legal reviews did not run. The
build and architecture review runs once Phase 1 exists, so that there is real code to judge. Content,
UX and legal wait for Phase 5 planning, which is not trusted before then.

## Phase 1

### D-083 Audio and timing tunables join `GameConfig` with the Phase 2 timing code
**Decided.** D-080 listed calibration settings among the values for task P1.0, but neither spec table
contains them, and `playback.driftCheckIntervalMicros` and `driftCorrectionThresholdMicros` still
describe the clock that D-031 replaced. Phase 2 starts only after spike S1, which decides several of
its rules, and nothing in Phase 1 reads these values. Task P2.0 adds the calibration, clock-filter and
route settings and removes the two drift values.

### D-084 The integrity key is the SHA-256 of a published label
**Decided.** D-016 asks for a documented constant key per wire version. `payload.integrityKeyV1` is
the SHA-256 of the ASCII text `riff-match-integrity-key-v1`, so its 32 bytes can be re-derived instead
of trusted, and a test does that. A later wire version takes its own label.

### D-085 The rules digest covers the judging, scoring, Hype and star values
**Decided.** The test that pins scoring values to `rulesVersion` (D-008) takes SHA-256 over the
canonical JSON of `rulesVersion` and the `judging`, `scoring`, `hype` and `stars` groups of
`GameConfig`: the values the engine reads to judge and score a run (GAME_RULES sections 3 to 7).
Chart limits, payload limits, XP and playback settings are outside it, so tuning them does not force
a rules bump. `playback.inputGuardMicros` is outside because it only sets when the driver calls
`advance`, which must not change a result (GAME_RULES section 2, rule 5). To keep `hype` to scoring
values, the phrase-count limits (4 to 6 per chart) moved from `hype` to `charts`. A rule change that
is not a config value is invisible to the digest and still needs the bump.

### D-086 Tick-to-time conversion rounds up; time-to-tick rounds down
**Decided.** GAME_RULES section 1.1 rounded both conversions down, so they disagreed: at 128 BPM and
resolution 192, tick 48 converted to 117,187 µs, and that time converted back to tick 47. Read with
the hold rules, a hold released at exactly its end time would have lost a tick of sustain. Now
`time(tick)` rounds up and `tick(time)` rounds down, which makes `tick(t) >= k` hold exactly when
`t >= time(k)`. Two ticks must never share a time, so a tempo map needs at least one microsecond per
tick, and the chart validator limits `resolution` to 1 to 960: five times the default of 192, and
still about 208 µs per tick at 300 BPM. A note's time can move by one microsecond, so `rulesVersion`
becomes 2.

### D-087 Manifest times are whole milliseconds
**Decided.** PLAN.md appendix B gave `durationSec` and `previewStartSec` as decimal numbers beside an
integer `audioOffsetMs`. They become `durationMs` and `previewStartMs`, so the chart validator
compares a song's length in integers and no manifest value needs floating point. No manifest file
exists yet, so nothing has to be converted.

### D-088 Chart validation has two passes, and each rule has one stated measurement
**Decided.** CHART_FORMAT.md section 4 gave limits without saying how to measure them, and several
could be read two ways. The validator checks structure first (ranges, ordering, the tempo list) and
reports only those issues when any fails: the other rules are stated in milliseconds, and times mean
nothing while ticks or tempos are out of range. No tick may pass 456,000, where a 95-second song ends
at 300 BPM and resolution 960, which also keeps the tick-to-time arithmetic inside `Int64`. The
readings chosen:

- Peak density counts a window that starts at a note and stops short of 1,000 ms later, so a steady
  four notes a second peaks at 4, not 5.
- The same-lane gap runs from a note's end, so after a hold it starts when the hold ends.
- A hold is not a contact on the tick it ends on.
- The song's beats, for the Hype capacity share, run from tick 0 to the latest end of any note.
- A song id is 1 to 24 characters from `a` to `z`, `0` to `9` and `-`. MATCH_PROTOCOL.md allows 24
  ASCII bytes; the narrower set keeps an id safe in a file name and in a URL.
- A manifest passed to the validator must state a duration of 55,000 to 95,000 ms, the range
  CHART_FORMAT.md section 5 already gave.

Nine limits that were prose became `GameConfig` properties in `charts` and `songs`. They are outside
the rules digest (D-085), so `rulesVersion` stays 2.

### D-089 Chart files are read strictly and written canonically
**Decided.** `ChartDecoder` refuses a file with a missing field, a wrong type, a field the format
does not define, an explicit `null`, or a number that is not whole. Swift's decoder ignores unknown
keys, so a misspelt `length` would have turned a hold into a tap, and changed the chart's hash,
without a word. `riffcli chart compute` rewrites the whole file as canonical JSON, so a chart has one
byte form and a diff shows only real changes; a file that fails validation is left untouched. The
hash's `rules=` line is the engine's `rulesVersion`, not the number stored in the file, so a chart
computed under older rules is reported as out of date instead of passing.

### D-090 Slow songs cannot pass the Hype rules
**Owner.** A chart needs 4 to 6 Hype phrases, and their capacity (8 beats each) may be at most 30% of
the song's beats, so a chart needs at least 106 2/3 beats: a song whose notes end at 60 seconds must
average about 107 BPM, and one at 90 seconds about 71 BPM. Tempos down to 40 BPM are allowed, so a
slow song passes the tempo rule and can never pass the Hype rules. Both numbers come from the gameplay
review, which had no skeptic pass. The default keeps them and chooses launch songs that fit (D-101).
The alternatives are fewer phrases for short or slow songs, or a larger share.

### D-091 The device spike is available in TestFlight and saves its report locally
**Decided.** The spike document called its entry point debug-only, but the Xcode scheme archives
Release for TestFlight. The temporary diagnostics are available in both configurations and append
their report locally as events happen, so a process termination does not discard the earlier
measurements. Test messages contain synthetic data only. Device observations remain unconfirmed until
the owner runs the protocols.

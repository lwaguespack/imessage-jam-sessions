# iMessage Rhythm Game — Implementation Plan

> **Revision 1, as written before review.** This text is unchanged from the original plan. A review on
> 2026-11-14 found problems that change parts of sections 3 to 9, 11, 12 and the appendix. Where this
> document disagrees with [DECISIONS.md](DECISIONS.md) or the specs in [specs/](specs/), those win.
> The evidence is in [PLAN_REVIEW.md](PLAN_REVIEW.md); the amended phase outlines are in
> [plan/](plan/README.md). The three diagrams did not survive the export and are marked
> "embedded content" below.

Nov 12, 2026 · @Lo

## 1. Overview

Friends take turns playing a short, Guitar Hero–style note highway inside an iMessage chat, and each turn's score bubble dares the next player to beat it. Version 1 is an iPhone-first Messages app extension with async duels, group-chat rounds, in-song scoring and an XP/level meta, and it needs no server.

**How a turn works.** Open the app from the Messages "+" drawer, pick a song and difficulty, and play a 60–90 second run on a 4-lane highway. The result posts as a bubble ("Beat 412,300 on Neon Nights · Expert"). Your friend taps it, plays the same chart, and the bubble updates with the winner and the running series score.

**Design pillars**

- **Snackable:** a full turn takes under 2 minutes, menus included.
- **Fair timing:** the audio clock drives everything, and latency calibration is part of setup, not a buried setting.
- **Social by default:** every run ends in a bubble that reads well even for people who don't have the app yet.
- **Original:** our own name, art, music and terms. No Guitar Hero or Fortnite names, assets, songs or look-alike UI.

**Built from your goal, not the notes.** The Grok and Opus notes you mentioned didn't come through; nothing was attached to your message. Share them and I'll reconcile this plan and mark every change. Until then it assumes:

- An iMessage-only app for v1: iPhone first, iPad works in the expanded view.
- Asynchronous play, one turn per bubble; no real-time multiplayer.
- No backend in v1: match state rides inside the message, and progression is stored on the device.
- Original or properly licensed music only.
- A free app with no ads or purchases in v1.

Items marked **\[DECIDE\]** need your call; section 14 collects them.

## 2. Scope: v1.0 and after

Version 1.0 ships the whole loop (play, send, beat it, level up) with 5 songs; band mode, ghost replays and global leaderboards follow launch. Change any Release cell to move a feature.

| Feature | Release | Notes |
| --- | --- | --- |
| 4-lane highway with taps, chords and holds | v1.0 (MVP) | Core feel; spec in section 4 |
| Easy, Medium, Hard and Expert | v1.0 (MVP) | Same 4 lanes; density and chords scale up |
| Judgements, streak multiplier, Hype meter, stars | v1.0 (MVP) | Formulas in section 4 |
| Latency calibration and a first-run tutorial | v1.0 (MVP) | Without these the timing feels unfair |
| 1:1 duels with series score and rematch | v1.0 (MVP) | Section 5 |
| Group-chat rounds with a leaderboard bubble | v1.0 (MVP) | Same match engine as duels |
| Solo practice (nothing sent) | v1.0 (MVP) | Earns reduced XP \[DECIDE\] |
| XP, levels 1–50, cosmetic unlocks, daily streak, featured song | v1.0 (MVP) | Stored on device; section 6 |
| 5 launch songs, 60–120 s each, with an instrument stem | v1.0 (MVP) | Blocked on the music source \[DECIDE\] |
| Band mode: friends play different parts of one song | v1.1 | Charts per part, combined band score |
| Ghost replays of a rival's run | v1.2 | Needs storage beyond the message (CloudKit or a server) |
| Global leaderboards | v1.2 | Check Game Center support inside a Messages extension first |
| Song packs and in-app purchases | Later | StoreKit 2 with on-demand resources |
| Companion iPhone app with practice tools | Later | Section looping, slow-down, chart preview |
| 5-lane Expert and lift notes | Later | Only if playtests ask for more depth |
| Real-time simultaneous multiplayer | Not planned | Messages extensions aren't built for live sessions |
| Popular licensed songs | Not planned | Only with a licensing deal |

## 3. Platform constraints

Messages app extensions are still a live platform: iOS 27 shipped a new first-party Drawing iMessage app ([9to5Mac](https://9to5mac.com/2026/09/17/heres-everything-new-for-messages-in-ios-27/)). The catch is that extensions force async play, small message payloads and tight memory, so the design is built around those limits.

| Constraint | Design response |
| --- | --- |
| Gameplay needs the expanded view; the compact view is keyboard-height | Menus work in compact; Play requests expanded; collapsing mid-song pauses |
| No live connection between players | Turn-based: each turn is a message, and an `MSSession` makes every turn update one bubble |
| Match state travels inside the message URL | Compact, versioned, signed payload: under 1 KB for a duel, capped at 4 KB; scores only, no replays |
| No access to contact names | Players set a nickname; captions use Messages' participant-name placeholder (verify on device) |
| Participant IDs are opaque UUIDs | Used only to tell "me" from "them" within a conversation; scoping verified in the Phase 4 spike |
| Extensions get less memory than full apps | One small texture atlas, streamed AAC audio, pooled note sprites, a measured budget |
| Audio latency differs by output: speaker, wired, Bluetooth | Audio-clock timing, touch timestamps, per-route calibration, a Bluetooth warning |
| Recipients may not have the app yet | The bubble image and caption explain the challenge; the message URL falls back to a web page |
| Screen sizes vary: iPad, and the foldable iPhone Duo announced in September ([9to5Mac](https://9to5mac.com/2026/09/17/heres-everything-new-for-messages-in-ios-27/)) | Layout from available size, never the device model; highway width capped |
| Bubble-tap callbacks can differ between iPhone and iPad | Read the selected message on every activation, not only in the tap callback; test iPad explicitly |
| Recipient-side testing needs two real Apple IDs on two devices ([Apple Developer Forums](https://developer.apple.com/forums/tags/messages)) | Recruit one test partner with their own Apple ID and iPhone early, via TestFlight |
| My sandbox has no macOS or Xcode | I can write all the code here but can't compile it; section 12 covers the build loop |

## 4. Gameplay spec

A run is one 60–90 second song on a 4-lane highway. Each note scores judgement points times a streak multiplier (up to ×4), doubled to ×8 while Hype is active; stars compare the final score with a perfect run that uses no Hype. Every number below is a starting value kept in one config file and tuned in playtests.

### 4.1 Highway and input

- Four lanes on a pseudo-3D highway that recedes to a vanishing point; notes travel toward a strike line about 18% above the bottom edge. Portrait only.
- Touch zones are the bottom 35% of the screen split into 4 equal columns. A touch anywhere in a column counts, so thumbs never cover the gem. Multi-touch handles chords.
- Two-thumb layout: lanes 1–2 for the left thumb, 3–4 for the right.
- Scroll speed is the time a note spends on screen: 1.6 s on Easy down to 1.1 s on Expert by default, adjustable from 0.7 to 2.0 s.
- An original palette with a distinct gem shape per lane, so colorblind players can read lanes by shape.

### 4.2 Note types (v1)

| Type | Input | Rule |
| --- | --- | --- |
| Tap | Touch the lane | Judged on touch-down |
| Chord | Touch 2 lanes together | Each note judged on its own; max 2 notes per chord |
| Hold | Touch and keep holding | Head judged like a tap; sustain points accrue while held; releasing early ends the sustain without a miss |
| Hype phrase | Normal notes drawn with a glow | Hit every note in the phrase at Good or better to charge Hype |

### 4.3 Timing windows

| Judgement | Window (± ms) | Points | Accuracy weight |
| --- | --- | --- | --- |
| Perfect | 45 | 100 | 1.0 |
| Great | 90 | 80 | 0.8 |
| Good | 130 | 50 | 0.5 |
| Miss | beyond 130, or no touch | 0 | 0 |

- Easy widens every window by 20%.
- A touch matches the earliest unjudged note in its lane whose window contains the touch time. A note still unhit 130 ms after its time becomes a Miss.
- A touch that matches no note (a ghost tap) costs nothing in v1. **\[DECIDE\]**
- Great and Good show a small early or late tag so players can correct their timing.

### 4.4 Scoring

Each note's points depend on its judgement j, the current streak s (consecutive notes without a miss, every chord note counted) and h, which is 2 while Hype is active and 1 otherwise:

```latex
\text{points} = \text{base}(j) \times m, \qquad m = \min\!\left(4,\; 1 + \left\lfloor s / 10 \right\rfloor\right) \times h
```

Holds add sustain points continuously while held, capped at the hold's length:

```latex
\text{sustain points} = 25 \times \text{beats held} \times m
```

A miss resets the streak to 0, so the multiplier falls back to ×1, and briefly ducks the instrument stem (section 4.8).

### 4.5 Hype meter

Hype is our own take on a power-up meter, named and styled to stay clear of other games' terms.

- Each completed Hype phrase adds 25% to the meter, up to 100%. Charts carry 4–6 phrases per song.
- At 50% or more, the player taps the Hype button just above the right-hand touch zone.
- While active, the multiplier doubles (max ×8) and the meter drains 1/32 per beat, so a full meter lasts 32 beats (8 bars of 4/4).

### 4.6 Results, accuracy and stars

- Accuracy = (Perfects + 0.8 × Greats + 0.5 × Goods) ÷ total notes.
- Full Combo means zero misses.
- Base score is a perfect run with no Hype. The chart tool computes it offline and stores it in each chart.
- Duel tie-breakers, in order: score, accuracy, longest streak, then whoever played first.

| Stars | Score as a share of base score |
| --- | --- |
| 1 | 20% or more |
| 2 | 40% or more |
| 3 | 60% or more |
| 4 | 80% or more |
| 5 | 95% or more |
| Gold 5 | 5 stars plus a Full Combo |

Thresholds get tuned with the bot simulator (task P1.9) so a capable player lands 3–4 stars at their usual difficulty.

### 4.7 No-fail, pause and restart

- No fail state: the song always plays to the end. A crowd-energy meter is purely cosmetic.
- Lead-in: the music starts after the first notes have had their full scroll time (at least 2 s), with a 3-2-1 count on the beat.
- Collapsing the view, a call, Siri or leaving Messages pauses at once. Resume shows a 3-beat countdown and restarts audio in sync.
- Restarting is allowed until you submit; only the submitted run counts for the round.

### 4.8 Audio feel

- Each song ships as a backing track plus an instrument stem. A miss ducks the instrument stem for about 300 ms, the classic "you dropped the part" cue.
- Songs without stems fall back to a single track plus a miss sound.
- No hit sounds by default because they fight the music; an optional tap-click helps in practice.
- A light haptic on Perfect, on by default with an off switch (verify haptics work inside the extension).

## 5. Social and Messages design

Every turn is a message. A duel is two players trading turns in one bubble that updates in place; a group round is the same mechanism with a leaderboard instead of a head-to-head.

### 5.1 Modes

- **Duel (1:1 chats):** player A plays and sends; player B plays the same chart; the bubble updates with the winner and the series score. Either player taps Rematch (same song or a new one) to start the next round in the same bubble.
- **Round (group chats):** anyone starts a round on a song and difficulty. Each member submits one score, and the bubble shows a ranked leaderboard (top 3 plus your own place). The starter can close the round early, which locks standings and awards podium XP.
- **Practice (solo):** play without sending. It records personal bests and earns reduced XP.

&#91;embedded content: duel round flow · 2 players, 1 bubble, rematch loop\]

Either player can start the rematch, with the same song or a new one. Group rounds follow the same path, with more players submitting before the round completes.

### 5.2 Turn rules

- One submitted score per player per round; restarts before submitting are fine.
- Everyone plays the identical chart. The payload carries a chart hash, and a mismatch (different app versions) asks the player to update.
- A duel round completes when both players have submitted. A group round completes when every member has submitted or the starter closes it.
- Rematch can come from either player. It starts a new round number, and the series score carries over.

### 5.3 The bubble

- The bubble uses Messages' template layout. Its image is a rendered score card: song art, title, difficulty, the two scores (or the top 3), a crown on the leader and the series score ("3–2").
- Captions read the same for everyone in the chat, so they state facts, not "your turn": "Sam scored 412,300", "Neon Nights · Expert", "Beat 412,300", "2 of 5 played".
- The sender's name comes from Messages' participant-name placeholder; verify on device.
- The app inserts the message into the compose field and the player taps Send. Nothing sends automatically.
- The card image stays under 300 KB.

### 5.4 What opens when a bubble is tapped

| Bubble state | Screen shown |
| --- | --- |
| No bubble selected (opened from the app drawer) | Home: song picker, Practice, Profile |
| Open round, you haven't submitted | Your turn: the score to beat, song, difficulty, Play |
| Open round, you've submitted | Waiting: current standings, with Practice while you wait |
| Round complete | Results: winner, scores, series score; Rematch or New song |
| Payload from a newer app version or a different chart | Update needed, with an App Store link |
| Payload fails its signature or sanity checks | "Couldn't read this challenge", with Start new |

### 5.5 Payload

- Compact JSON, deflate-compressed and base64url-encoded into one query item of an https URL on a domain we control. That URL doubles as the web fallback for people without the app. **\[DECIDE\]** the domain.
- It carries: schema version, match id, mode, song, part, difficulty, chart hash, round number, one entry per submitted player (id, nickname, score, accuracy, longest streak, stars, Full Combo, level, time), the series tally, a closed flag and a signature. The full schema is in the appendix.
- The signature is an HMAC-SHA256 with a key compiled into the app, truncated to 16 bytes. It stops casual URL edits, not a determined cheater, which is fine among friends.
- Decoding rejects unknown versions, bad signatures, scores above the chart's theoretical maximum, more than 32 entries and anything over 4 KB.

## 6. Points and progression

Every finished run earns XP, roughly 200–300 for a typical duel turn, which levels players from 1 to 50 and unlocks cosmetics only. Nothing earned or bought ever changes scoring, so a duel is always decided by the run itself.

### 6.1 XP per run

| Event | XP |
| --- | --- |
| Finish a song | 100 |
| Each star earned | +20 (Gold 5 counts as 6 stars) |
| Full Combo | +50 |
| Win a duel round | +75 |
| Group round podium: 1st / 2nd / 3rd | +75 / +50 / +25 |
| First run of the day | +100 |
| Daily streak | +10% per consecutive day, max +50% |
| Featured song of the week | ×1.5 on that song |

- Order of operations: add the events, apply the streak bonus, apply the featured multiplier, round down.
- Practice runs earn half XP. **\[DECIDE\]**
- Duel and podium XP land when the round completes, on whichever device opens the final bubble.

### 6.2 Levels

```latex
\text{XP to go from level } L \text{ to } L+1 = 400 + 100L
```

Level 2 takes 500 XP, level 10 takes 8,100 in total (about 35 typical runs) and level 50 takes 142,100, a long-term goal. The level shows on the score card next to the player's nickname.

### 6.3 Unlocks (cosmetic only)

| Unlock type | Count in v1 | Where it shows |
| --- | --- | --- |
| Titles | 15 | In the bubble, next to the nickname |
| Score-card frames | 6 | In the bubble, so friends see them |
| Note skins | 8 | On the highway |
| Highway themes | 6 | On the highway |
| Strike-line effects | 5 | On the highway |

- About one reward per level, front-loaded so levels 2–10 each unlock something.
- The unlock table lives in a data file (`progression.json`) so it can be retuned without code changes.
- Bubble-visible unlocks matter most: every bubble is an ad for the game.

### 6.4 Streaks, featured song and records

- **Daily streak:** at least one finished run on consecutive local calendar days; a missed day resets it. No streak freezes in v1.
- **Featured song:** rotates every Monday by ISO week number (week mod song count). It's the same for everyone without a server, gets a badge in the song picker and earns ×1.5 XP.
- **Personal bests** per song and difficulty: score, stars, accuracy, Full Combo.
- **Series records** per friend, keyed by conversation participant.
- **Lifetime stats:** runs, notes hit, Perfects, Full Combos, wins, longest streak, days played.

Progression lives on the device, so editing it only affects yourself. Scores sent to friends are signed and sanity-checked (section 5.5).

## 7. Technical architecture

One Messages extension holds the screens, audio and rendering, while every game rule lives in a pure-Swift package, RiffCore, that imports nothing from UIKit, SpriteKit or AVFoundation. That split lets the rules be unit-tested and reviewed apart from the device-only code. "Riff" is a placeholder code name until the product name is set. **\[DECIDE\]**

&#91;embedded content: architecture · Messages app, extension layers, RiffCore\]

The extension's six parts handle screens, rendering, audio, storage and Messages traffic. Anything that decides a score, a turn or a level lives in RiffCore, which is why it can be tested without a device.

### 7.1 Stack

| Layer | Choice | Why |
| --- | --- | --- |
| Language | Swift 6 toolchain: Swift 6 mode in RiffCore, Swift 5 mode in the extension at first | Strict concurrency is cheap in pure logic and costly around audio callbacks and SpriteKit |
| Minimum iOS | 17.0 | Observation and modern SwiftUI; covers iPhone XS/XR and later |
| Screens | SwiftUI | Fast to build, Dynamic Type, accessibility |
| Highway | SpriteKit inside SwiftUI | Pooled 2D sprites are enough for a faked-3D highway; SceneKit was deprecated in 2025 |
| Audio | AVAudioEngine, one player node per stem | Sample-accurate synchronized start of backing and stem |
| Messages | `MSMessagesAppViewController`, `MSSession`, template layout | The platform |
| Score-card image | SwiftUI `ImageRenderer` | Same view as the in-app results card |
| Signing | CryptoKit HMAC | Built in |
| Project file | XcodeGen (`project.yml`) | The .xcodeproj is generated, never hand-edited, so changes stay reviewable |
| Tests | Swift Testing and XCTest | Unit and simulation tests |
| Tools | Python 3 with numpy | Chart conversion, validation, click-track generation |

### 7.2 Repo layout

```text
riff/
  project.yml                 XcodeGen spec: wrapper app, Messages extension, tests
  README.md                   Build steps and tool usage
  docs/                       PLAN.md (this plan), DECISIONS.md, CHART_FORMAT.md
  Packages/RiffCore/          Pure Swift: rules, scoring, payload, progression
    Sources/RiffCore/
      Model/                  Song, Chart, Note, TempoMap, Difficulty, Part
      Chart/                  ChartDecoder, ChartValidator, ChartCompiler (ticks to seconds)
      Engine/                 Judge, ScoreKeeper, HypeMeter, GameSession (state machine)
      Results/                Accuracy, StarRating, RunSummary
      Progression/            XPRules, Levels, Unlocks, DailyStreak, FeaturedRotation
      Match/                  MatchState, MatchRules, PayloadCodec, Signer
      Config/                 GameConfig: every tunable number in one place
    Tests/RiffCoreTests/
  RiffApp/                    iMessage app wrapper (no Home Screen app)
  RiffMessages/               The Messages extension
    MessagesViewController.swift
    Routing/                  AppRouter, ConversationContext
    Audio/                    AudioEngine, SongClock, StemMixer, LatencyCalibrator, AudioRoute
    Game/                     HighwayScene, Projection, NoteNode, NotePool, InputController, HitFX, HUD
    UI/                       Home, SongPicker, Match, Game, Results, Calibration, Settings, Profile, Tutorial
    Messaging/                MessageComposer, ScoreCardView, Captions
    Persistence/              ProfileStore, SettingsStore (JSON in the App Group container)
    Debug/                    DiagnosticsView (copyable report), Autoplay
    Resources/                Songs/<id>/ (manifest, audio, charts), Art.xcassets, FX.atlas
  tools/                      chartconv.py, chartcheck.py, reduce.py, clicktrack.py, payload.py
  LICENSES/                   One file per song with its license terms
```

### 7.3 Timing model

The audio hardware clock is the single source of truth; frames and touches are converted onto it.

1. The backing track and the stem are scheduled to start together at a future host time T0 (now plus the lead-in).
2. The song time the player hears at host time t subtracts the output latency L (hardware latency plus I/O buffer, read from the audio session) and the player's calibrated audio offset for the current output route:

   ```latex
   t_{\text{song}}(t) = (t - T_0) - L - \delta_{\text{audio}}
   ```
3. Each frame places notes using the song time plus a visual offset from calibration.
4. Each touch is judged at the song time of its hardware timestamp, not the frame that processed it, which removes up to a frame (8–16 ms) of error.
5. Once per second, the clock estimate is compared with the player node's rendered sample time; drift over 3 ms is corrected gradually.
6. Pause and resume re-anchor T0.

### 7.4 Performance budgets

| Budget | Target |
| --- | --- |
| Frame rate | 60 fps on every device; 120 fps on ProMotion iPhones (Info.plist opt-in, verify in the extension) |
| Dropped frames during a song | Under 1% |
| Touch to judgement | Same frame |
| Extension memory | Measured in Phase 3, then budgeted with headroom under the system limit |
| Open to Home screen | Under 1 s |
| Song load | Under 500 ms |
| Score-card image | Under 300 KB |
| App download with 5 songs | Under 60 MB |

### 7.5 Persistence

- An App Group container is shared by the wrapper app and the extension.
- Three Codable JSON files: `profile.json` (nickname, XP, level, unlocks, equipped cosmetics, streak), `records.json` (bests, series, lifetime stats) and `settings.json` (per-route offsets, scroll speed, haptics, accessibility).
- Writes are atomic, and each file carries a schema version for migrations.
- No network, analytics or accounts in v1.

## 8. Content pipeline

Music is the long pole: v1 needs 5 songs with stems and 4 charts each (20 charts), and none of it can be a popular song without a license. The music source is the first decision to make; placeholder songs keep development moving until it's settled.

### 8.1 Music sourcing **\[DECIDE\]**

| Option | Upside | Watch out for |
| --- | --- | --- |
| Commission original tracks with stems | Full rights, stems by design, a unique sound | Cost and lead time |
| Royalty-free library tracks | Fast and cheap | License must allow use inside apps and games; stems often missing; other apps may use the same tracks |
| Your own music | Free and personal | Needs separate stems |
| AI-generated music | Fast | Only if the service's terms grant commercial rights; check stem export |

Ruled out: popular songs without a license, and anything taken from other rhythm games, including community charts of commercial songs. Every song gets a license file in `LICENSES/` before it ships.

### 8.2 Song spec

- A 60–120 second edit with a strong opening; steady tempo preferred, tempo changes supported.
- WAV at 44.1 or 48 kHz: the full mix, a backing track (everything except the lead part) and the lead stem, all the same length and start point.
- Loudness matched across songs, around −14 LUFS integrated.
- Encoded to AAC (.m4a) on the Mac with `afconvert` for the app.
- Metadata: title, artist credit, BPM and square artwork at 1024 px.

### 8.3 Charting workflow

1. Chart Expert in Moonscraper Chart Editor, a free editor that saves the Clone Hero `.chart` text format, using the first 4 fret lanes.
2. `chartconv.py` converts the `.chart` file to our JSON: lanes 1–4, holds, Hype phrases from its phrase markers, and the tempo map.
3. `reduce.py` drafts Hard, Medium and Easy by thinning Expert to each difficulty's rules; a person then hand-tunes them.
4. `chartcheck.py` validates every chart against the table below and writes base score and theoretical maximum into the file.
5. Autoplay in a debug build plays the chart perfectly against the audio to check sync by eye and ear.
6. Playtest each difficulty and log feedback against the chart version.

### 8.4 Difficulty rules enforced by chartcheck

| Difficulty | Notes per second, average / peak | Chords | Min gap on one lane | Shortest hold |
| --- | --- | --- | --- | --- |
| Easy | 1–2 / 3 | None | 400 ms | 1 beat |
| Medium | 2–3.5 / 5 | Rare | 250 ms | 1/2 beat |
| Hard | 3.5–5 / 7 | Yes | 150 ms | 1/2 beat |
| Expert | 5–7 / 10 | Yes | 90 ms | 1/4 beat |

### 8.5 Placeholder content I can make now

- **Click track:** a generated metronome song with a perfectly grid-aligned chart, used for timing and calibration tests.
- **Two practice songs:** simple generated drum-and-synth loops with procedural charts, so the whole loop can be built and tested before real music arrives.
- **Placeholder art:** flat generated covers, clearly marked as temporary.

## 9. Implementation phases and tasks

The build runs in 10 phases, and the riskiest ones come first: a device spike proves timing, Messages behavior and rendering before any polish. Each phase ends with a "done when" check that has to pass before the next phase builds on it. Tasks P5.1 and P5.2 (tools and placeholder songs) run alongside Phase 1 because the audio and gameplay work needs them.

### Phase 0: Foundations

- [ ] P0.1 Lock the decisions needed to start (section 14): code name, bundle ID prefix, Apple Developer Team ID.
- [ ] P0.2 Scaffold the repo and `project.yml`: wrapper app, Messages extension, RiffCore package, test targets, App Group, Info.plist keys.
- [ ] P0.3 README with build steps, a SwiftFormat config and one script that runs every RiffCore test.

**Done when:** `xcodegen` then `xcodebuild build` succeeds on your Mac, and the empty extension opens inside Messages.

### Phase S: Device spike

- [ ] S1 Audio sync: start backing and stem at one host time, log drift for 3 minutes, and run a tap-along test on speaker, wired and AirPods.
- [ ] S2 Messages: send session messages with a test payload and a participant-name caption; confirm participant IDs and bubble-tap behavior on two iPhones and an iPad.
- [ ] S3 Rendering: 200 pooled sprites on a perspective highway at the device's top refresh rate, with memory recorded in Instruments.
- [ ] S4 Confirm haptics and 120 Hz work inside the extension.

**Done when:** you paste the Diagnostics report from each test device back to me. Any blocker changes the plan before Phase 3.

### Phase 1: Core rules (RiffCore)

- [ ] P1.1 Models: song manifest, chart, note, tempo map (ticks to seconds across tempo changes), difficulty, part.
- [ ] P1.2 Chart decoder and validator: schema, ordering, lane bounds, overlaps, difficulty limits.
- [ ] P1.3 Judge: windows per difficulty, earliest-note matching per lane, miss sweep, early/late.
- [ ] P1.4 Score keeper and Hype meter: streak tiers, sustain points, phrases, activation, drain.
- [ ] P1.5 Game session state machine: ready, lead-in, playing, paused, finished, emitting events for effects and the HUD.
- [ ] P1.6 Results: accuracy, stars, Gold, Full Combo, base score and theoretical maximum per chart.
- [ ] P1.7 Progression: XP rules, levels, unlock table, daily streak, featured rotation.
- [ ] P1.8 Match: match state, turn and completion rules, winner and tie-breaks, series, payload codec, signer.
- [ ] P1.9 Tests: golden scoring runs, codec round-trips and tamper cases, payload size limits, and a bot simulator that reports star distributions by skill level.

**Done when:** all RiffCore tests pass, with at least 90% line coverage on the engine, match and progression code.

### Phase 2: Audio and clock

- [ ] P2.1 Audio engine: one player node per stem plus effects, audio session setup, interruption and route-change handling.
- [ ] P2.2 Synchronized start at a host time, lead-in, and pause and resume with re-sync.
- [ ] P2.3 Song clock as specified in section 7.3, with the drift monitor.
- [ ] P2.4 Stem ducking on a miss.
- [ ] P2.5 Latency calibrator: tap-along audio test (16 taps, trimmed mean), visual flash test, per-route storage, Bluetooth defaults and warning.
- [ ] P2.6 Debug HUD: song time, drift, latency, frame rate.

**Done when:** on a real iPhone after calibration, the mean tap offset on the click track is within ±10 ms on speaker and wired, and drift stays under 2 ms over 3 minutes.

### Phase 3: Playable slice

- [ ] P3.1 Game screen: SpriteKit view hosted in SwiftUI, with an expanded-view guard.
- [ ] P3.2 Highway scene: perspective projection, lanes, strike line, beat lines from the tempo map, pooled notes, hold trails.
- [ ] P3.3 Input controller: multitouch columns, hardware timestamps fed into the game session.
- [ ] P3.4 Effects and HUD: hit sparks, judgement and early/late text, streak, multiplier, score, Hype meter and button, progress bar.
- [ ] P3.5 Results screen.
- [ ] P3.6 Autoplay debug mode for chart QA.

**Done when:** the click track and one placeholder song play start to finish on a real iPhone at 60 fps (120 on ProMotion), with under 1% dropped frames and memory inside the budget set from S3.

### Phase 4: Messages integration

- [ ] P4.1 Extension lifecycle and router: compact versus expanded, selected-message decoding on every activation.
- [ ] P4.2 Message composer: session messages, payload URL, template layout, score-card renderer, captions.
- [ ] P4.3 Duel flow: start, respond, result, rematch, waiting state.
- [ ] P4.4 Group round flow with the leaderboard card and close-round.
- [ ] P4.5 Edge cases: version or chart mismatch, invalid payload, an old bubble tapped after newer ones, collapse mid-song, recipient without the app.

**Done when:** 3 duel rounds between two real iPhones and one 3-person group round finish with correct winners, series scores and bubble updates, on iPhone and iPad.

### Phase 5: Content

- [ ] P5.1 Tools: chartconv, chartcheck, reduce, clicktrack and the payload inspector.
- [ ] P5.2 Placeholder songs (section 8.5).
- [ ] P5.3 Real songs: ingest 5, chart Expert, derive and tune the 3 lower difficulties, place Hype phrases.
- [ ] P5.4 QA per chart: autoplay sync check, a playtest per difficulty, star thresholds checked with the simulator.

**Done when:** all 20 charts pass chartcheck and each has at least one playtest note.

### Phase 6: Progression and profile

- [ ] P6.1 Profile store with migrations.
- [ ] P6.2 XP awards on the results screen, a level-up moment, unlock grants and an equip screen.
- [ ] P6.3 Records: bests, series per friend, lifetime stats, and the Profile screen.
- [ ] P6.4 Daily streak and featured song in the UI.

**Done when:** XP and unlocks match the section 6 tables in tests and on device.

### Phase 7: Polish, onboarding and accessibility

- [ ] P7.1 First-run tutorial chart plus the calibration prompt.
- [ ] P7.2 Settings: scroll speed, offsets, haptics, reduced motion, high-contrast gems.
- [ ] P7.3 VoiceOver and Dynamic Type on every menu. Gameplay itself is visual, and the App Store description will say so.
- [ ] P7.4 Visual polish: highway themes, Hype effects, transitions, UI sounds.
- [ ] P7.5 Instruments pass: time profiler, allocations, energy and leaks over a 30-minute session.

**Done when:** a 30-minute session shows no leaks and stays inside the frame and memory budgets, and every menu works with VoiceOver.

### Phase 8: Beta and launch

- [ ] P8.1 Messages app icons (4:3 sizes), score-card art and App Store screenshots.
- [ ] P8.2 Privacy manifest, a "Data Not Collected" privacy label and the age rating.
- [ ] P8.3 TestFlight with 10–20 friends in real group chats, then feedback triage.
- [ ] P8.4 App Review notes explaining two-device testing, then submission.

**Done when:** the app is approved and live on the App Store.

## 10. Milestones

About 10 weeks part-time from approval to App Store submission, if the music lands by week 5. M3 is the milestone most likely to stretch, because timing only counts as done when it feels right on a real phone.

&#91;embedded content: milestones · 6 stages, each closed by a gate\]

Each milestone closes at its gate before the next builds on it; tools and placeholder songs are the exception and run alongside M2.

## 11. Testing and QA

Unit tests prove the rules, real iPhones prove timing and feel, and two real Apple IDs prove the Messages flows. The simulator can't sign off timing or the recipient side, so device checks are built into the phases rather than saved for the end.

| Layer | What is checked | How | When |
| --- | --- | --- | --- |
| Rules | Judgement, scoring, Hype, stars, XP, match rules | Golden tests: scripted hit sequences with expected scores | Every change, from Phase 1 |
| Payload | Encoding, signature, size | Round-trip and tamper tests; size check at 32 entries | Every change |
| Determinism | Same inputs give the same score | Record an input log, replay it through the game session, compare | Every change |
| Balance | Star thresholds per chart | Bot simulator at 5 skill levels, varying timing noise and miss rate | Each new chart |
| Timing | Sync and latency | Click track, tap-along test and drift log on speaker, wired and AirPods | Phases S and 2, then each release |
| Performance | Frame rate, memory, energy | Instruments on the oldest supported iPhone and a ProMotion iPhone | Phases S, 3 and 7 |
| Messages | Duel, group round, the edge cases in 5.4 | Two iPhones on two Apple IDs plus an iPad; a 3-person group chat | Phases S and 4, then each release |
| Fun | Difficulty, chart feel, clarity | 5 or more playtesters; per-judgement stats from Diagnostics | Phases 3, 5 and 8 |

**Device matrix:** the oldest iPhone that runs iOS 17, a current ProMotion iPhone, an iPad, and a foldable iPhone if a tester has one. Audio routes: built-in speaker, wired headphones and AirPods.

**Diagnostics report:** a debug screen copies one text block with device, iOS version, audio route, output latency, buffer size, calibrated offsets, measured drift, frame stats, peak memory and participant-ID checks. Pasting it back to me is how device results reach the build loop.

## 12. How I'll build it

My sandbox in this chat can write the whole codebase and run the Python tools, but it has no Swift toolchain, macOS or Xcode (I checked), so nothing iOS compiles here. The fastest real loop is Claude Code on your Mac, where I can build, run the tests and read the errors myself. **\[DECIDE\]**

| Capability | Claude Code on your Mac | This chat |
| --- | --- | --- |
| Write every source file, config and doc | Yes | Yes, delivered as a zip |
| Compile the iOS targets and run RiffCore tests | Yes, with Xcode installed | No; you build and paste errors back |
| Run the simulator and read build logs | Yes | No |
| Run the Python chart and audio tools | Yes | Yes |
| Test on a real iPhone | You, using the Diagnostics report | You, using the Diagnostics report |

**What you need either way:** a Mac with current Xcode and XcodeGen, a paid Apple Developer Program membership (for App Groups and TestFlight), and two iPhones on two Apple IDs by Phase S.

### 12.1 Work order once you approve

1. Scaffold the repo (P0.2–P0.3) and write the spike build (Phase S), so you can run it on your phone first.
2. RiffCore and its tests (Phase 1), alongside the tools and placeholder songs (P5.1–P5.2).
3. Audio and clock (Phase 2), then the playable slice (Phase 3).
4. Messages integration (Phase 4).
5. Progression (Phase 6), polish (Phase 7), real songs as they arrive (P5.3–P5.4), then launch prep (Phase 8).

After each step I report back briefly: what changed, which files, how to verify it, and what I need from you (a build log, a Diagnostics report or a decision).

### 12.2 Conventions I'll hold to

- RiffCore never imports UIKit, SpriteKit or AVFoundation.
- Every tunable number lives in `GameConfig` or a JSON data file, never inline in code.
- Any payload change bumps the schema version and adds a decode test for the previous version.
- Tests land in the same step as the code they cover.
- Files stay under about 400 lines, one main type per file.
- No third-party code in v1; XcodeGen is the only extra build tool.
- No names, assets, songs or terms from other rhythm games.
- `docs/DECISIONS.md` logs every decision with its date and reason.

## 13. Risks and mitigations

The two risks that could sink the project are timing that feels unfair and having no licensed music, so both get handled first: the device spike in Phase S and the music decision in Phase 0.

| Risk | Mitigation | Checked in phase |
| --- | --- | --- |
| Timing feels off or unfair | Audio-clock master, hardware touch timestamps, per-route calibration, a device spike before any UI work | S, 2 |
| No licensed music in time | Decide the source first; placeholder songs keep work unblocked; launch can go with 3 songs if needed | 0, 5 |
| Extension runs out of memory | Small texture atlas, streamed audio, sprite pooling, a budget measured on the oldest iPhone | S, 3, 7 |
| Participant IDs or bubble taps behave unexpectedly, notably on iPad | Spike S2 on two iPhones and an iPad; read the selected message on every activation | S, 4 |
| Trademark or trade-dress complaint | Original name, art, palette and terms; nothing taken from other games | 0, 8 |
| Payload outgrows a safe size | Scores only, compact keys, size tests at 32 entries; replays stay out of the message | 1, 4 |
| Forged scores through edited URLs | Signature plus sanity checks, enough among friends; server checks only if global leaderboards arrive | 1 |
| Bluetooth latency complaints | Detect the route, apply a default offset, prompt to calibrate, suggest speaker or wired for best scores | 2, 7 |
| Recipient side is hard to test | Recruit a test partner with their own iPhone and Apple ID in the first week | S |
| Low discoverability inside Messages | A striking score card, titles and frames friends can see, and a fallback web page | 4, 8 |
| App Review sees an iMessage-only app as incomplete | Review notes with a two-device test script; iPad verified | 8 |
| Slow build loop because my sandbox can't compile iOS | Build in Claude Code on your Mac, or keep a tight paste-the-error loop | All |

## 14. Decisions needed from you

Five decisions gate the start: your Grok/Opus notes, the music source, where the build runs, the bundle ID and Team ID, and the code name. The rest can wait for their phase. Mark each row Agreed or Changed, or reply in a comment.

| Decision | My recommendation | Needed by | Status |
| --- | --- | --- | --- |
| Your Grok and Opus notes | Share them; I'll reconcile this plan and log every change | Before approval | Open |
| Music source for launch | Commission 5 originals with stems; placeholders until they arrive | Phase 0 | Open |
| Where the build runs | Claude Code on your Mac | Phase 0 | Open |
| Bundle ID prefix and Apple Developer Team ID | `com.<yourname>.riff` style, under your membership | Phase 0 | Open |
| Product name and code name | Keep "Riff" as the code name until a name clears an App Store and trademark search | Phase 0 | Open |
| iMessage-only or a companion iPhone app too | iMessage-only for v1 | Phase 0 | Open |
| Lane count | 4 lanes on every difficulty | Phase 1 | Open |
| Ghost-tap penalty | None in v1 | Phase 1 | Open |
| Hype activation | On-screen button | Phase 3 | Open |
| Fallback web domain | A one-page site on a domain you own; any https placeholder for TestFlight | Phase 4 | Open |
| Practice XP | Half XP | Phase 6 | Open |
| Business model | Free, no ads, no purchases in v1 | Phase 8 | Open |

## 15. Appendix: data schemas, glossary and sources

These are the v1 file and message formats I'll implement against. `GameConfig.swift` will hold every starting value from sections 4–7 (lanes, windows, points, multiplier steps, Hype, stars, travel times, lead-in, drift threshold, payload caps, XP curve). This doc is the source of truth until that file exists; after that, the code is.

### A. Chart file (one per song, part and difficulty)

```json
{
  "format": "riff-chart",
  "version": 1,
  "songId": "neon-nights",
  "part": "lead",
  "difficulty": "expert",
  "lanes": 4,
  "resolution": 192,
  "tempo": [{ "tick": 0, "bpm": 128.0 }],
  "timeSignatures": [{ "tick": 0, "num": 4, "den": 4 }],
  "notes": [
    { "tick": 768, "lane": 0 },
    { "tick": 960, "lane": 2, "length": 192 },
    { "tick": 1152, "lane": 1 },
    { "tick": 1152, "lane": 3 }
  ],
  "hype": [{ "start": 3072, "end": 4608 }],
  "sections": [{ "tick": 0, "name": "Intro" }],
  "computed": { "noteCount": 412, "baseScore": 162800, "maxScore": 337600, "hash": "9f2c41ab" }
}
```

Lanes are 0–3 in the file and 1–4 on screen. `resolution` is ticks per quarter note, matching the charting editor. Two notes on one tick form a chord, and `length` marks a hold. `computed` is written by chartcheck: `maxScore` is the every-note-at-×8 ceiling used to reject impossible scores.

### B. Song manifest

```json
{
  "id": "neon-nights",
  "title": "Neon Nights",
  "artist": "Placeholder Artist",
  "durationSec": 92.0,
  "previewStartSec": 31.0,
  "audioOffsetMs": 0,
  "stems": { "backing": "backing.m4a", "lead": "lead.m4a" },
  "charts": {
    "lead": {
      "easy": "lead_easy.json",
      "medium": "lead_medium.json",
      "hard": "lead_hard.json",
      "expert": "lead_expert.json"
    }
  },
  "intensity": { "lead": { "easy": 1, "medium": 3, "hard": 5, "expert": 7 } },
  "artwork": "art.png",
  "license": "LICENSES/neon-nights.md"
}
```

### C. Match payload

```swift
struct MatchPayload: Codable {
    var v: Int              // schema version, 1
    var id: String          // match id, 10 characters
    var mode: Mode          // .duel or .round
    var by: String          // starter's player id (can close a round)
    var song: String        // song id
    var part: Part          // .lead in v1
    var diff: Difficulty
    var ch: String          // chart hash, 8 hex characters
    var r: Int              // round number
    var e: [Entry]          // submitted runs this round
    var sr: [String: Int]   // series wins by player id
    var closed: Bool        // round locked by its starter
    var sig: String         // base64url HMAC-SHA256, truncated to 16 bytes
}

struct Entry: Codable {
    var p: String           // player id: first 8 hex characters of the participant UUID
    var n: String           // nickname, max 16 characters
    var s: Int              // score
    var a: Int              // accuracy in basis points, 0–10,000
    var c: Int              // longest streak
    var st: Int             // stars 0–5, 6 = Gold
    var fc: Bool            // Full Combo
    var lv: Int             // level when played
    var t: Int              // Unix time in seconds
}
```

The JSON is deflate-compressed, then base64url-encoded into one query item: `https://<domain>/m?p=<payload>`. A duel encodes to under 1 KB, and a full 32-player round stays inside the 4 KB cap; task P1.9 tests both.

### D. Profile file

```json
{
  "version": 1,
  "nickname": "Sam",
  "xp": 8240,
  "level": 10,
  "unlocked": ["title.opener", "skin.neon", "theme.club"],
  "equipped": { "title": "title.opener", "skin": "skin.neon", "theme": "theme.club", "frame": "frame.basic", "fx": "fx.sparks" },
  "streak": { "days": 4, "lastPlayed": "2026-11-12" }
}
```

### E. Glossary

- **Chart:** the note map for one song, part and difficulty.
- **Stem:** one isolated instrument track; the backing track is everything else.
- **Strike line:** where notes should be hit.
- **Judgement:** Perfect, Great, Good or Miss for a single note.
- **Streak:** consecutive notes without a miss; it drives the multiplier.
- **Hype:** our power-up meter, charged by phrases and spent for double points.
- **Base score:** a perfect run with no Hype; stars are measured against it.
- **NPS:** notes per second, the main measure of chart difficulty.
- **Session:** the Messages mechanism that makes each new turn replace the previous bubble.
- **Compact and expanded:** the two sizes of an iMessage app's view.
- **Tick and resolution:** chart time units; resolution is ticks per quarter note.

### F. Sources

- [Here's everything new for Messages in iOS 27](https://9to5mac.com/2026/09/17/heres-everything-new-for-messages-in-ios-27/), 9to5Mac, September 17, 2026.
- [Apple Developer Forums, Messages tag](https://developer.apple.com/forums/tags/messages), including the thread on testing an iMessage extension from the recipient's side.

Everything else comes from my own knowledge as of mid-2026. Anything marked "verify on device" gets confirmed in the Phase S spike.

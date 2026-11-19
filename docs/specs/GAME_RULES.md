# Game rules

The exact rules the engine in `RiffCore` implements: time, judging, streaks, holds, Hype, scoring and
results. Two engineers working from this document must produce identical scores for identical input.

**Status: draft 1.** Built from PLAN.md section 4 and the gameplay review (GAME-1 to GAME-17,
AUD-8). The gameplay findings have not had a skeptic pass; section 13 lists what is still open.
Decisions are referenced as `D-0xx` (see [../DECISIONS.md](../DECISIONS.md)).

## 1. Units

1. **Song time** is `Int64` microseconds, signed. It is negative during the lead-in. (D-009, D-050)
2. **Chart position** is an integer **tick**. `resolution` is ticks per quarter note (192 by default).
   A **beat** is always `resolution` ticks, whatever the time signature. (D-051)
3. **Tempo** is integer milli-BPM (`mbpm`): 128 BPM is `128000`.
4. No floating point anywhere in the engine. Every division states its rounding.

### 1.1 Converting ticks and time

The tempo map is a list of segments `(startTick, mbpm)`, sorted, the first at tick 0. Let `S_i` be
the start time of segment `i` in microseconds, with `S_0 = 0`.

```text
time(tick)  = S_i + ceil((tick - startTick_i) * 60_000_000_000 / (mbpm_i * resolution))
S_(i+1)     = time(startTick_(i+1)) evaluated in segment i
tick(time)  = startTick_i + floor((time - S_i) * mbpm_i * resolution / 60_000_000_000)
```

`i` is the last segment whose start, as a tick or as a time, is at or before the argument. For ticks
and times before 0, segment 0 is extended backwards. `ceil` and `floor` round toward plus and minus
infinity, for negative values too.

`time` rounds up and `tick` rounds down so that the two agree: `tick(t) >= k` exactly when
`t >= time(k)`. So `tick(t)` is the last tick whose time is at or before `t`. As long as every tick
lasts at least one microsecond (`mbpm * resolution <= 60_000_000_000`; the tempo map refuses
anything else), no two ticks share a time and `tick(time(k)) = k`: an event scheduled at a tick's
time is at that tick. Rounding both down, as this section first did, breaks that: at 128 BPM and
resolution 192, `time(48)` was 117,187 µs and `tick(117187)` was 47. (D-086)

The chart validator's limits ([CHART_FORMAT.md](CHART_FORMAT.md) section 4: tempo at most 300 BPM,
resolution at most 960) keep every intermediate product inside `Int64` for more than 8 hours either
side of zero.

The chart compiler converts every note to `(lane, time, tick, endTick?)` once, when a song loads.

## 2. Engine contract

The engine is a pure state machine. It never reads a clock or a random source. (D-050)

```swift
enum InputEvent {
    case touchDown(id: Int, lane: Int, time: Int64)
    case touchUp(id: Int, time: Int64)        // also sent for a cancelled touch
    case activateHype(time: Int64)
}
mutating func apply(_ event: InputEvent)
mutating func advance(to time: Int64)          // processes every scheduled event up to and including time
```

1. Internally the engine keeps scheduled events: a **miss deadline** per note, a **hold end** per
   live hold, and **Hype expiry**.
2. Everything is processed in one total order: by time, then by class in this order: `activateHype`,
   `touchDown`, `touchUp`, `holdEnd`, `missDeadline`, `hypeExpiry`; then by lane, lowest first.
   Consequences: a touch exactly on a window edge is a hit, and a touch exactly at Hype expiry is
   doubled.
3. Engine time never moves backwards. An input older than the engine's current time is clamped to the
   current time and counted (`lateInputCount`, shown in Diagnostics).
4. **Driver rule.** The app applies inputs as they arrive and, each frame, calls
   `advance(to: songTimeNow - inputGuard)`. `inputGuard` starts at 50,000 µs. A touch is always
   delivered after its timestamp, so without the guard a valid late hit could be swept as a miss
   first. Miss feedback therefore appears `inputGuard` after the window closes; hit feedback is
   immediate. (GAME-2, AUD-8)
5. **Partition invariance.** Replaying one input log with any subdivision of `advance` calls must
   give an identical result and event list. This is a required property test.
6. The engine emits output events (hit with judgement and offset, miss, ghost tap, streak change,
   multiplier change, Hype charged, activated and expired, hold started, released and completed, run
   finished) for the HUD, effects and audio. Output never feeds back into scoring.

## 3. Judging

1. Windows per judgement come from `GameConfig.judging`, scaled per difficulty and rounded down:
   `window(d) = floor(base * windowScalePercent[d] / 100)`.

   | Judgement | Base (µs) | Easy (µs) | Points | Accuracy weight (basis points) |
   | --- | --- | --- | --- | --- |
   | Perfect | 45,000 | 54,000 | 100 | 10,000 |
   | Great | 90,000 | 108,000 | 80 | 8,000 |
   | Good | 130,000 | 156,000 | 50 | 5,000 |

2. Windows are inclusive: a touch at offset `o` scores the first judgement with `|o| <= window`.
3. A `touchDown` in a lane matches the **earliest unjudged note in that lane** whose Good window
   contains the touch time. The offset `touchTime - noteTime` is reported (negative is early).
4. Each note has a miss deadline at `noteTime + goodWindow(d)`. A note still unjudged when its
   deadline is processed becomes a **Miss**. Only an expired window produces a Miss.
5. Chords are two notes on one tick. Each is judged on its own by its own touch.
6. A touch stays bound to the lane it began in until it ends; finger movement is ignored.

### 3.1 Ghost taps

A `touchDown` that matches no note is a **ghost tap**. (D-052, owner decision)

1. It is ignored if it lands within `bounceGrace` (80,000 µs) after a hit in the same lane, or
   before the first note's window opens, or after the last note has been judged.
2. Otherwise the difficulty's `ghostTapPenalty` applies: `resetStreak` (the default on every
   difficulty), `dropTier`, or `none`.
3. A ghost tap is never a Miss: it does not affect accuracy or Hype phrases.

## 4. Streak and multiplier

1. The **streak** `s` counts consecutive notes hit. A Miss sets it to 0. A penalised ghost tap sets
   it to 0 under `resetStreak`.
2. A note scores with the streak **before** it is counted:
   `m = min(maxStreakMultiplier, 1 + floor(s / streakPerMultiplierStep[d]))`, then `s += 1`.
3. `streakPerMultiplierStep` is per difficulty: 4, 6, 8, 10 for Easy to Expert, so the climb to the
   top multiplier lasts a similar number of seconds at every difficulty. `maxStreakMultiplier` is 4.
   (D-053)
4. While Hype is active the multiplier is doubled: `h = 2`, otherwise `h = 1`.
5. A hit note scores `points(judgement) * m * h`.
6. **Full Combo** means `longestStreak == noteCount`. A run with a penalised ghost tap cannot be one.

## 5. Holds

A hold is a note with an `endTick`. (D-056)

- **H1.** A hold is one note (its head) for streak, accuracy, note count and Hype phrases.
- **H2.** The touch that hits the head owns the hold.
- **H3.** Sustain accrues over ticks `[max(headTick, tick(touchTime)), min(endTick, tick(releaseTime)))`
  at the live multiplier `m * h`.
- **H4.** A missed head kills the whole hold. Later touches in that lane are ordinary touches.
- **H5.** Lifting the owning touch, or a cancelled touch, ends the sustain for good: no re-press, no
  Miss, no effect on streak, phrases or Full Combo.
- **H6.** Any other `touchDown` in the lane during a hold is judged as a normal touch.
- **H7.** Chart rules: no note in a lane between a hold's head and end; the next same-lane note
  starts at least the same-lane minimum gap after the hold's end; a hold is at least the larger of
  the difficulty's beat fraction and 250,000 µs.
- **H8.** The tail of a dead or released hold is drawn dimmed.

### 5.1 Sustain arithmetic

The engine keeps one integer accumulator `U` for the whole run. While a hold is live it adds
`(m * h) * deltaTicks`, splitting the interval at every event that changes `m` or `h`. Sustain points
are `floor(sustainPointsPerBeat * U / resolution)` with `sustainPointsPerBeat = 25`: **one floor for
the whole run**, applied when the score is read. (D-051, GAME-3)

## 6. Hype

The meter is an integer in ticks. With `R = resolution`: capacity `32R`, phrase gain `8R`, activation
minimum `16R`. (D-055)

- **R1.** A phrase is the half-open tick range `[start, end)`. Its members are the notes whose head
  tick is inside. A hold belongs by its head only.
- **R2.** A phrase fails at its first member Miss. It completes the moment its last member is hit.
  Sustains do not matter.
- **R3.** Completion adds `8R` to the meter, clamped at `32R`; overflow is discarded. This also
  applies while Hype is active, which extends it.
- **R4.** `activateHype` is accepted only when Hype is inactive and the meter is at least `16R`. It
  takes effect at the event's timestamp. Otherwise it is ignored at no cost. Hype cannot be cancelled.
- **R5.** While active the meter drains one unit per tick, so `expiryTick = activationTick + meter`,
  recomputed when R3 adds meter. A note is doubled if `activationTime <= touchTime <= time(expiryTick)`.
  Sustain is doubled tick by tick over `[activationTick, expiryTick)`.
- **R6.** A Miss does not affect the meter or an active Hype. A pause freezes it. Unused meter at the
  end of the song is lost.
- **R7.** Chart rules: phrases sorted and non-overlapping; at least 4 member notes; both notes of a
  chord in the same phrase; the last phrase ends at least 16 beats before the final note; total
  capacity (`8` beats times the phrase count) at most 30% of the song's beats.

## 7. Score and results

1. `score = notePoints + floor(25 * U / resolution)`.
2. **Accuracy** in basis points:
   `floor((10000 * perfects + 8000 * greats + 5000 * goods) / noteCount)`. (D-061)
3. **Base score** is the score of the perfect run: every note Perfect at offset 0, every hold held to
   its end, no Hype, no ghost taps. Notes on one tick are scored in lane order, and sustain from that
   tick uses the new streak. `riffcli` computes it and stores it in the chart; a golden test requires
   the engine's perfect-run bot to equal it exactly.
4. **Score ceiling** (`maxScore`), used to reject impossible scores: every note Perfect at the top
   multiplier with Hype, plus every hold tick doubled:
   `100 * maxStreakMultiplier * 2 * noteCount + floor(25 * maxStreakMultiplier * 2 * totalHoldTicks / resolution)`.
   A tighter bound is an open question (section 13).
5. **Stars.** Each chart stores five absolute cut-off scores, computed by `riffcli` as shares of base
   score from `GameConfig.stars.sharesPercent[d]` (starting at 10, 25, 45, 65, 85 for every
   difficulty). Stars are the number of cut-offs the score reaches, compared in integers:
   `score * 100 >= baseScore * share`. Hype can push a score above 100% of base. (D-053)
6. **Gold** is 5 stars plus a Full Combo.
7. `RunSummary` holds: score, accuracy, counts per judgement, longest streak, note count, Full Combo,
   stars, Hype activations, ghost-tap count, late-input count, chart hash, rules version, difficulty.

## 8. Run lifecycle

1. **Scroll time** is the approach time from spawn to the strike line (not time on screen).
2. **Lead-in** is the smallest whole number of beats at the opening tempo that is at least
   `max(minLeadIn, scrollTime - firstNoteTime)`, with the count on its last three beats. Song time
   starts at minus the lead-in.
3. **Pause.** The driver sends `touchUp` for every active touch (holds end under H5) and stops calling
   `advance`.
4. **Resume.** Audio pre-rolls from three beats before the pause point while the highway shows
   already-judged notes dimmed; the engine resumes at the pause point.
5. A run is **final** when every note is judged and every hold has ended or been released. Leaving
   after that point keeps the result. A run interrupted before then is discarded. (D-027, D-059)

## 9. Rules version

`GameConfig.rulesVersion` is an integer. Any change to a value or rule in this document that can
change a score bumps it. It is part of the chart hash and of the match payload, and a test pins a
digest of the scoring values to the current version so a silent change fails. (D-008)

The digest is SHA-256 over the canonical JSON of `rulesVersion` and the `judging`, `scoring`, `hype`
and `stars` groups of `GameConfig`. It cannot see a rule that is not a config value: changing such a
rule still needs the bump. (D-085)

| Version | What changed |
| --- | --- |
| 1 | The rules as first written, with the values applied in task P1.0. |
| 2 | Tick-to-time conversion rounds up (section 1.1, D-086). |

## 10. Bots and the simulator

`RiffCore` ships a seeded generator (SplitMix64); every bot takes a seed and reports it. `riffcli
simulate` runs bots over a chart and prints the star distribution. (D-007, D-009)

| Bot | Behaviour |
| --- | --- |
| Perfect | Every note at offset 0, every hold complete |
| Skilled, good, casual, beginner | Gaussian timing error and independent miss probability per level |
| Clustered | Misses arrive in bursts, as real misses do |
| Masher | Taps every lane on a fixed period (200 and 250 ms) with random phase |

Acceptance rule for every shipped chart: the masher never earns a Full Combo and scores below the
casual bot's median.

## 11. Required tests (Phase 1)

- Tick and time conversion: round trips, tempo changes, the lead-in (negative time).
- Window edges: offsets of exactly 45,000, 90,000, 130,000 and 130,001 µs; the Easy scale.
- Matching: earliest unjudged note; a skipped note with the minimum same-lane gap does not capture
  the next tap inside its Perfect window.
- Streak: the first `step` notes score at 1x, the next `step` at 2x; chord notes in lane order.
- Ghost taps: bounce grace, before the first note, each penalty setting, never a Miss.
- Holds: H1 to H6, early and late head, release mid-hold, multiplier change mid-hold, one floor.
- Hype: R1 to R6, activation at exactly the threshold, extension while active, touch at expiry.
- Golden runs: scripted input logs with expected `RunSummary` values, stored as JSON fixtures.
- Partition invariance (section 2, rule 5) with random subdivisions from the seeded generator.
- Perfect-run bot equals the stored base score for every bundled chart.
- Masher acceptance rule (section 10).

## 12. GameConfig changes required

Applied in task P1.0. The table is kept as the record of what changed from PLAN.md revision 1.

- The chart-rule row covers the three limits it names. The other limits in
  [CHART_FORMAT.md](CHART_FORMAT.md) section 4 that have no `GameConfig` property yet (tempo bounds,
  phrase membership and placement, chord spacing on Medium, the peak window's length, the manifest's
  duration slack) are added with the validator in task P1.2.
- The phrase-count limits (4 to 6 per chart) moved from `hype` to `charts`, so `hype` holds scoring
  values only (D-085).

| Property | Revision 1 | Set in P1.0 | Why |
| --- | --- | --- | --- |
| `rulesVersion` | absent | `1` (section 9 lists the versions since) | D-008 |
| `scoring.streakPerMultiplierStep` | `10` | per difficulty `4, 6, 8, 10` | D-053 |
| `judging.ghostTapPenaltyPoints` | `0` | replace with `ghostTapPenalty` per difficulty, `resetStreak` | D-052 |
| `judging.bounceGraceMicros` | absent | `80000` | D-052 |
| `stars.thresholdsPercent` | `[20, 40, 60, 80, 95]` | `sharesPercent` per difficulty, `[10, 25, 45, 65, 85]` | D-053 |
| `playback.inputGuardMicros` | absent | `50000` | D-050 |
| `charts.rules.*` same-lane minimum gap | `400, 250, 150, 90` ms | `400, 250, 180, 180` ms | D-054 |
| `charts.rules.*` chord share, cross-lane gap, contacts | loose labels | numeric limits from [CHART_FORMAT.md](CHART_FORMAT.md) | D-060 |
| `charts.minHoldMicros` | absent | `250000` | D-056 |
| `songs.maxDurationMicros` | `120000000` | `90000000` | D-062 |
| `playback.missDuckMicros` | `300000` | `missDuckMinMicros 120000`, `missDuckMaxMicros 600000` | D-038 |

## 13. Open questions

1. **Ghost-tap penalty (D-052)** and whether Easy should be softer: owner decision, then playtests.
2. **Tighter score ceiling.** GAME-15 proposed base score plus the best `8 * phraseCount` beats of the
   perfect run as one sliding window. That is not a valid upper bound: Hype can be active in several
   separate stretches, and a note just outside a stretch can be hit inside it. A correct tighter
   bound must allow one stretch per phrase and widen each by the Good window. Until that is specified
   and proved, the ceiling in section 7 stands.
3. **Star shares** are starting values; they are re-derived with the simulator before any screen
   shows stars.
4. **Strike-line geometry (D-064)**: whether thumbs tap on or below the line is decided in the spike.
5. **Same-lane repeats faster than 180 ms** on Expert would need midpoint-clipped windows instead of
   the chart rule in D-054. Not planned for v1.

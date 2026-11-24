# Phase 2: audio and clock

Play a backing track and a stem in sync inside the extension, and know, to a few milliseconds, which
moment of the song the player is hearing. This phase starts after the device spike: tasks S1.1 to
S1.6 decide several of the rules below.

**Status of the rules.** They come from the audio review (AUD-1 to AUD-14), which has not had a
skeptic pass. Every row marked Device is confirmed or changed by the spike.

## Rules

### Audio session (D-030, Device)

1. Category `.playback`, mode `.default`, no options. This plays through the Ring/Silent switch and
   interrupts the player's own music, so:
2. The engine is created and the session activated only when the player taps Play (or explicitly
   previews a song). Never on activation of the extension or in compact view.
3. On finish, pause, collapse or resign-active: stop the players, stop the engine, and deactivate
   with `notifyOthersOnDeactivation` so the player's music resumes.

### Graph and start

Three player nodes on one engine (backing, stem, assist tick) into the main mixer; the stem's volume
is the miss duck. Both files are scheduled, then started with one `AVAudioTime` host time, the lead-in
from now. Audio is streamed from disk (decoding two 90 s stems to memory would cost about 64 MB).

### Song clock (D-031)

Each frame:

```text
n  = player.lastRenderTime
p  = player.playerTime(forNodeTime: n)
o  = segmentStart + p.sampleTime / p.sampleRate - seconds(forHostTime: n.hostTime)
ô  moves toward o by at most 0.2 ms per frame; if |o - ô| > 50 ms it snaps and a glitch is counted
heardSongTime(t) = t + ô - L - routeOffset
```

Before the start time, when the player has no valid player time, the requested start time is used.
The filter is pure integer code in `iMessageRiffCore` (`Timing/ClockFilter.swift`) so it is unit-tested; the
extension only feeds it samples. The host clock is read with `CACurrentMediaTime()`, never
`mach_absolute_time` (D-039).

### Latency (D-032, Device)

`L` is the output presentation latency, falling back to the session's `outputLatency`, read after the
engine starts and again on every route or configuration change. The I/O buffer duration is **not**
added: a scheduled start already accounts for it.

### Routes (D-034)

| Class | Ports | Behaviour |
| --- | --- | --- |
| Built-in | Speaker | Offset keyed by port type |
| Wired | Headphones, USB audio | Offset keyed by port type and device id |
| Wireless | Bluetooth | Same keying; prompt to calibrate; note that speaker or wired gives the best scores |
| Unsupported | AirPlay, HDMI, CarPlay, anything unrecognised | Practice only, with an explanation |

### Calibration (D-033)

The estimator is pure code in `iMessageRiffCore` (`Timing/CalibrationEstimator.swift`):

1. Clicks at least 600 ms apart, so a tap is never ambiguous between two clicks.
2. 4 warm-up clicks are discarded, then 32 are scored. Each tap is matched to its nearest click.
3. The estimate is the median offset, clamped to ±300 ms.
4. Reject and ask again if fewer than 24 taps matched, or the robust spread (1.4826 times the median
   absolute deviation) is above 40 ms.
5. The visual side is not tap-tested. Notes are drawn for the display's presentation time, and a
   trim slider (±50 ms) covers the rest.

### Suspend and resume (D-035)

One routine, `suspendRun(reason)`, is called from: transition to compact, resign-active, the
extension-host resign notification, interruption began, route change, engine configuration change,
media-services reset, the too-wide or too-short layout rule (D-026), and a clock stall. It records the
heard song time and stops the players. Resume re-schedules both files from that frame, pre-rolls three
beats, and re-anchors the clock (GAME_RULES section 8).

### Feedback (D-038)

- **Miss duck.** Ramp the stem to about 15% over 15 ms and hold until the next hit (at least 120 ms,
  at most 600 ms), then ramp back over 30 ms.
- **Tap click.** Offered only on built-in and wired routes when latency plus buffer is under 40 ms.
- **Haptic.** One generator, prepared ahead; on by default. Device: confirm it works (S4).
- **Assist tick.** A short PCM tick scheduled at each note's exact sample time on the same anchor as
  the stems, for chart QA (D-040). It is independent of display and touch.

## Tasks

| Task | Files (under `iMessageRiffMessages/Audio/` unless noted) | Tests or checks |
| --- | --- | --- |
| P2.0 Pure timing code | `iMessageRiffCore`: `Timing/ClockFilter.swift`, `Timing/CalibrationEstimator.swift`, `Timing/RouteClass.swift` | Unit tests on Linux: slew, snap, median, rejection, clamping |
| P2.1 Engine | `AudioEngine.swift`, `AudioSessionPolicy.swift`, `AudioCompat.swift` (wrappers for calls deprecated in the iOS 27 SDK, D-036: verify each against the SDK first) | CI build with no deprecation warnings on Xcode 26 and 27 |
| P2.2 Start, pause, resume | `SongPlayer.swift` | Device: resume lands within one frame of the pause point |
| P2.3 Song clock | `SongClock.swift` feeding `ClockFilter` | Device: see the gate |
| P2.4 Miss duck and assist tick | `StemMixer.swift`, `AssistTick.swift` | Device: tick lands on the click track's clicks |
| P2.5 Calibration | `LatencyCalibrator.swift`, `UI/Calibration/` | Unit tests in P2.0; device run |
| P2.6 Debug HUD and Diagnostics | `Debug/DiagnosticsView.swift` | Report includes route, latency values, filter offset, glitch count, frame stats |

The click track is synthesised in the app as PCM (D-037), so no audio asset is needed for this phase.

## Done when

On a real iPhone, on the speaker and on wired headphones:

1. **Clock.** Over 3 minutes the filter's residual `|o - ô|` stays under 1 ms for 99% of frames, with
   zero snaps.
2. **Calibration.** Calibrate with three tap-along runs (96 taps), then run three more. The two pooled
   medians differ by at most 15 ms. A correct build passes this at least 93% of the time even for a
   noisy tapper (45 ms spread), where PLAN.md revision 1's gate (16 taps, ±10 ms) would fail about
   half the time.
3. **Session.** Play, pause by collapsing, resume, finish: the player's music stops at Play and
   resumes after the song.

The revision 1 gate "drift under 2 ms over 3 minutes" is dropped: a device's audio clock can
legitimately differ from the host clock by more than that, and the sample-anchored clock follows it.

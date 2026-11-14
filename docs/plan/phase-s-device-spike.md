# Phase S: device spike

A throwaway build that answers the questions only real devices can answer, before anything is built
on top of the guesses. Each task has a protocol and a pass rule. The results change the specs, so
this phase gates Phases 2, 3 and 4.

**Owner time:** about two evenings with the devices, plus one session with a third tester.

## What you need

- A paid Apple Developer Program membership, an App Store Connect record for the app, and one
  TestFlight build (the scaffold already has the icon set and privacy manifest this requires). (D-028)
- Two iPhones on two Apple IDs. An iPad. For S2.5 only, a third Apple ID. (D-081)
- If available: the oldest iPhone that runs iOS 17, and a ProMotion iPhone.
- Wired headphones (or a USB-C adapter) and AirPods.

## The spike build

A debug-only "Spike" list in the extension, one screen per task, each with a **Copy report** button
that puts a text block on the clipboard. Paste each report back; those reports are the deliverable.

| File (under `RiffMessages/Spike/`) | Purpose |
| --- | --- |
| `SpikeMenuView.swift` | List of the tasks below |
| `SpikeReport.swift` | Collects lines; adds device model, iOS version, app version, date |
| `AudioSpike.swift`, `AudioSpikeView.swift` | S1 |
| `MessagesSpike.swift`, `MessagesSpikeView.swift` | S2 |
| `RenderSpikeScene.swift`, `RenderSpikeView.swift` | S3, S4, S6 |
| `TouchSpikeView.swift` | S5 |

The spike code is deleted when Phase 3 starts. Nothing in it is reused without review.

## S1 Audio session and clock

Runs inside the extension, not a test app. (D-030, D-031, D-032, D-041)

| Step | Protocol | Pass rule or what to record |
| --- | --- | --- |
| S1.1 Session | Activate a `.playback` session and play a 90 s tone, in expanded and in compact | Plays for the full 90 s. Record: does it play with the Ring/Silent switch on silent; does the player's music stop; does it resume after we deactivate with `notifyOthersOnDeactivation` |
| S1.2 Interruptions | During playback: collapse the sheet, switch apps, lock, receive a call (banner and full screen), invoke Siri, let an alarm fire | Record which notifications arrive in which order (interruption began and ended, route change, engine configuration change, extension host resign and background) and whether audio stops by itself |
| S1.3 Latency values | On speaker, wired and AirPods, log the session's `outputLatency`, the player node's output presentation latency, and the I/O buffer duration | Record the numbers per route |
| S1.4 Clock skew | Start two player nodes at one host time. Once per second for 3 minutes log host time and rendered sample position | Stem-to-stem offset is 0 samples. Record host-versus-sample skew in parts per million per route |
| S1.5 Tap-along | Click at 100 BPM; 4 warm-up clicks then 32 taps; three runs per route, latency applied as in D-032 | Record median and spread per run. If the median is within ±15 ms on the speaker on every phone, calibration can be optional on the speaker |
| S1.6 Encoded stems | Two stems encoded with `afconvert` | Both open with the same length in frames, and stay aligned |

## S2 Messages behaviour

| Step | Protocol | Pass rule or what to record |
| --- | --- | --- |
| S2.1 URL forms | Send a 300-character and a 4,000-character payload as a `data:` URL, an https fragment and an https query; open on iPhone, iPad and a Mac | Which forms arrive byte-exact; what the Mac does on click (D-017) |
| S2.2 Participant ids | Log local and remote participant ids in two conversations; send from one device and read on the user's own second device | Is the local id the same across conversations; does `senderParticipantIdentifier` equal the local id on the second device (D-010) |
| S2.3 Selection | Tap a bubble; collapse; tap the same bubble; go Home in the app; reopen from the drawer. Then ten alternating turns between two devices | Which callbacks fire and what `selectedMessage` is each time; count taps that fail to open the extension, on iPhone and iPad (D-021) |
| S2.4 Drafts | Insert then Send; insert then delete the draft; insert then tap the staged bubble; and `send` behind an in-app button | Values of `isPending`; whether `didStartSending` and `didCancelSending` arrive; which flow needs fewer taps (D-020) |
| S2.5 Concurrency | Three members. A posts a round. B and C both open it before either sends, both finish, B sends, C sends within 5 s. Repeat reversed, and once with C offline | Log every decoded payload with the callback that delivered it. Expect the revision-1 design to lose an entry; this confirms the merge design is needed and shows what `didReceive` delivers (D-011) |
| S2.6 Other transports | Send a session message in an SMS or RCS chat and in a group with a non-iMessage member | What each recipient sees; whether the extension can tell (D-024) |
| S2.7 Bubble text | Captions with nicknames and with the undocumented participant-name placeholder; `summaryText`; `accessibilityLabel` with VoiceOver | What renders for contacts and non-contacts (D-022) |
| S2.8 Store sheet | Present the in-app App Store product sheet from the extension | Works or not (D-023) |

## S3 Rendering and layout

200 pooled sprites on a perspective highway. Record frame time statistics at the device's top
refresh rate, and the view size and safe-area insets in compact, expanded, rotated, and iPad split
view. Try the strike line both at the top of the touch zone and inside it, and note which lets you
read the gems while tapping (D-026, D-064).

**Pass:** under 1% dropped frames over 60 s on the oldest test phone.

## S4 Haptics and refresh rate

Fire an impact haptic on each tap; request 120 Hz. Record whether haptics play inside the extension
and the frame interval actually granted.

## S5 Touch input against the sheet gesture

(D-025) Expanded view, spike highway running. 200 two-thumb taps and 20 holds per column with
deliberate vertical drift of a finger-width; 20 quick swipes that start inside the touch zone. Run
once with scene touch handling and once with the UIKit input view that blocks competing recognizers.
Log every cancelled touch and every presentation change.

**Pass:** zero cancelled touches and zero unintended collapses from in-zone touches with the UIKit
input view, on the oldest and the newest iOS version you have. If it fails, the fallback (taps only,
no holds) is decided before any chart is written.

## S6 Memory

Record the extension's memory footprint with the highway running and two 90 s stems streaming, and
the level at which the system ends the extension if you can reach it. This sets the memory budget in
the plan's performance table.

## Done when

Every row above has a pasted report, each Device decision in [DECISIONS.md](../DECISIONS.md) is
marked confirmed or overturned, and the specs are updated to match. A failed S1.1 or S5 changes the
plan before Phase 2 or 3 starts.

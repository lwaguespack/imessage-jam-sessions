# Plan review

Reviewed 2026-11-14 against revision 1 of [PLAN.md](PLAN.md). What changed as a result is logged in
[DECISIONS.md](DECISIONS.md); this document is the evidence.

The historical findings retain the former Riff code name; the project is now iMessageRiff (D-121).

## How it was done

Each area of the plan went to a separate reviewer told to check claims against primary sources (Apple's
documentation, recomputed arithmetic) rather than memory, and to give a concrete fix for every problem.
A second, independent skeptic then tried to refute each finding before it was allowed to change the plan.

## Coverage, stated plainly

| Area | Reviewed | Skeptic pass |
| --- | --- | --- |
| Messages platform | Yes | Yes: 10 confirmed, 5 corrected, none refuted |
| Match protocol, payload and progression | Yes | Not run |
| Gameplay rules, scoring and determinism | Yes | Not run |
| Audio, clock and latency | Yes | Not run |
| Architecture, toolchain and build loop | Phase 1 follow-up below | Not run |
| Content, UX, legal, schedule and dated claims | **Not run** | Not run |

The last two original reviews and three skeptic passes were cut off by a usage limit. Treat findings
without a skeptic pass as well-evidenced but unchallenged. Two checks from the missing reviews were done by hand
while setting up the repository: the build loop (Swift runs on Linux in Docker; GitHub Actions builds the
iOS targets, see D-002) and two dated claims (Xcode 27 is current, and an "iPhone Duo" simulator ships
with it). Still unreviewed: the content pipeline (chart source format, music licensing), accessibility,
App Review and trademark exposure, and the 10-week schedule.

## Phase 1 build and architecture follow-up

A direct implementation review on 2026-11-23 checked the Swift package boundary, generated Xcode
targets, local and CI build paths, match routing, finality, storage and settlement. It is not an
independent skeptic pass.

- **ARCH-1, major: Phase 4 needed a store scheduled for Phase 6.** Settling a match requires the
  profile, ledger, joined fragments and first-final descriptor to survive together. The Phase 4
  outline now includes the minimal atomic store and restart/crash tests; Phase 6 extends it (D-119).
- **ARCH-2, major: an already-paid round masked a changed final proposal.** The settlement result
  now reports the conflict before checking the ledger, without changing the prior award (D-118).
- **ARCH-3, major: the device gate overstated agreement.** A no-server merge can converge while
  different devices have already paid different first-observed standings. The Phase 4 gate now
  requires converged standings and at-most-once local awards, not globally identical past payouts.
  Future profile sync must reconcile settlement records as well as XP counters (D-119).
- **BUILD-1: the Swift Linux container lacks Python.** Its new coverage step needs `python3`, so CI
  installs that reporting tool explicitly. Linux Swift tests and the local unsigned iOS Simulator
  build exercise the same core; signing, TestFlight delivery and all device behavior remain unverified.

The core has no platform-framework imports or clock/random-source reads; the extension supplies
platform behavior and timestamps. The payload tag is an integrity check, not a secret. The device
spike, production persistence, content, accessibility and legal reviews remain separate work.

## The findings that matter most

1. **Group rounds lose scores as designed (MSG-1, MATCH-1, blocker).** Two people who play from the same
   bubble each send a state that omits the other, and Messages keeps only the later message. Apple's own
   documentation describes this race. The fix keeps "no server" but makes match state mergeable, with a
   per-device store and a re-post repair (D-011).
2. **Player ids cannot come from Messages (MSG-2, MATCH-2).** Participant UUIDs are scoped to one device.
   Each install now generates its own id (D-010).
3. **Mashing wins (GAME-1).** With free stray touches, tapping every lane on a timer earns a Full Combo and
   about 80% of a perfect score. A touch that matches no note now resets the streak (D-052, your call).
4. **Scores were not reproducible (GAME-2, GAME-3).** Sustain points and the Hype meter were continuous
   quantities with no rounding rule, and judging depended on frame timing. The engine now has an explicit
   event-ordering contract and integer tick arithmetic (D-050, D-051).
5. **The song clock was not anchored to the audio (AUD-2, AUD-3, AUD-4).** It dead-reckoned from a
   requested start time, double-counted the I/O buffer, and its calibration gate would fail a correct
   build about a third of the time (D-031 to D-033).
6. **Touch input would fight Messages' drag-to-collapse gesture (MSG-3)** on every supported iOS version
   (D-025, tested in the device spike).
7. **The audio session was never specified (AUD-1).** With the default, the Ring/Silent switch mutes the
   game (D-030, your call).
8. **The responder can retry until they win (GAME-9, MATCH-8).** Retries are now counted and shown
   (D-058, your call).
9. **Bonus XP could be paid on every reopen, and the first player might never see a finished round
   (MATCH-4)** (D-014).
10. **Several stated numbers contradicted each other**: song length (60 to 90 s or 60 to 120 s), the
    example score (above its own chart's maximum), same-lane note gaps (shorter than the hit window), and
    star thresholds (which mostly counted misses on short charts).

Each area below has a table of findings, then the full text behind a fold, then the claims that were
checked and held up.


## Numbers

- Findings: 66 (0 of them added by the skeptics).
- By severity after the skeptic pass: blocker 2, major 28, minor 32, nit 4.
- By check result: Confirmed 11, Not re-checked 51, Partly correct 4.

## Messages platform (MSG)

| ID | Severity | Finding | Check | Outcome |
| --- | --- | --- | --- | --- |
| MSG-1 | blocker | Shared-session match state has an Apple-documented race: group rounds silently drop scores, and the payload is not mergeable | Confirmed | Adopted: D-011, D-013, D-014 |
| MSG-2 | major | Participant UUIDs are device-scoped and unstable, so they cannot be the player id in the payload | Partly correct | Adopted: D-010 |
| MSG-3 | major | Since iOS 17 Messages' resize pan gesture competes with manual touch handling; the plan's SpriteKit touch input is the affected pattern and nothing tests it | Confirmed | Device spike decides: D-025 |
| MSG-4 | major | Conversations that are not pure iMessage (SMS, RCS, any group with an Android member) are not handled at all | Partly correct | Device spike decides: D-024 |
| MSG-5 | major | Selection is sticky and didSelect fires only for a different message; the 5.4 routing table and the iPad mitigation do not cover this | Partly correct | Adopted: D-021 |
| MSG-10 | minor | Phase S depends on TestFlight, but every TestFlight prerequisite is scheduled in Phase 8 | Confirmed | Adopted: D-028 |
| MSG-11 | minor | Payload in the query string of an https URL sends match data to the web server, which undercuts 'no network' and 'Data Not Collected' | Partly correct | Device spike decides: D-017 |
| MSG-12 | minor | Bubble spec gaps: no summaryText or accessibilityLabel, an undocumented name placeholder, and a per-viewer element that a sender-rendered image cannot show | Confirmed | Adopted: D-022 |
| MSG-13 | minor | A group round 'completes when every member has submitted', but the member count includes people who cannot or will not play | Confirmed | Owner decision: D-012 |
| MSG-6 | minor | An iMessage-only extension cannot open URLs, so the 'App Store link' and any external link cannot work as written | Confirmed | Adopted: D-023 |
| MSG-7 | minor | 'Portrait only' cannot be enforced by a Messages extension | Confirmed | Adopted: D-026 |
| MSG-8 | minor | 'Submitted' is undefined between insert and Send: the draft can be deleted or never sent, and the run is lost | Confirmed | Adopted: D-020 |
| MSG-9 | minor | Pause/resume assumes the extension survives; pause triggers, termination and conversation switches are unspecified | Confirmed | Adopted: D-027 |
| MSG-14 | nit | Compact view cannot show a keyboard and should not scroll horizontally; nickname entry and the song picker need a rule | Confirmed | Adopted: D-029 |
| MSG-15 | nit | The wrapper app has no code, so 'App Group shared by the wrapper app and the extension' describes nothing in v1 | Confirmed | Adopted: D-005 |

<details>
<summary>Full text of the MSG findings</summary>

### MSG-1: Shared-session match state has an Apple-documented race: group rounds silently drop scores, and the payload is not mergeable

Severity blocker · design-flaw · plan sections: 3 (row: No live connection between players), 5.1 Round, 5.2, 5.5, 6.1 (XP lands on whichever device opens the final bubble), P4.1, P4.4, P4.5, 13, Appendix C

**The plan says.** "each turn is a message, and an MSSession makes every turn update one bubble"; a group round accumulates one entry per member in that single bubble (`e: [Entry]`, `sr: [String: Int]`, `closed: Bool`), with no server. P4.1 decodes "selected-message ... on every activation". The only ordering edge case listed is "an old bubble tapped after newer ones".

**Problem.** Every responder builds the next message from the bubble they tapped. In a group chat several members tap the same open-round bubble and play for 60-90 s at the same time, so they all extend the same base state. B sends {A,B}; C sends {A,C}. Each device keeps only whichever session message arrived last, order differs per device, and the other entry disappears from the bubble. Leaderboards then differ per device, the starter's close can be undone by a late submission carrying closed=false, podium XP is awarded from different 'final' bubbles, and two simultaneous Rematch taps create two different round r+1. Even without true simultaneity, a message that arrives while a player is mid-song is lost unless didReceive is handled, because selectedMessage is never refreshed. The schema makes this unrecoverable: `sr` is a counter map and `closed` a plain flag, neither can be merged. This is the normal usage pattern for Round mode, not a corner case. Duels are mostly safe (strict alternation) except simultaneous rematch.

**Evidence.** didReceive(_:conversation:) doc: "There is an inherent race condition when multiple participants send messages using the same session object. You cannot guarantee the order in which the messages are received. To ensure that your app always has the latest data, save your data to a server (for example, using CloudKit) and have your messages just carry an ID for that data." selectedMessage doc: "If this message belongs to a session, then the selected message might not contain the most current data. The selected message is not updated when you receive new messages. Instead, override ... didReceive(_:conversation:)". MSSession doc: "If a later message is sent using the same session, the previous message is removed from the transcript." didReceive is only called "while your extension is active". Forum thread 51728 (2016) reports the same symptom: "chances are you will only end up opening the response that comes in second."

**Reviewer's recommendation.** Decide this before Phase 1, because it changes Appendix C. Keep no-server, but make state convergent: (1) Entries become a grow-only set keyed by (round, player id); merge = union; same-key conflict resolved deterministically (earliest `t`, then lowest id). `closed` becomes sticky (once seen true, stays true). Replace the `sr` counter map with per-round results (round -> winner id) and derive the series score, so merging is idempotent. (2) Add a per-device MatchStore (one small JSON per match id) holding the merge of every payload this device has decoded or sent. (3) Route didReceive (including mid-song) into MatchStore; MessageComposer always sends merge(MatchStore, selected payload) + own entry, never the selected payload alone. (4) Fork repair: if the tapped bubble lacks the local player's stored entry, show "Your score isn't in this bubble - Re-post", which inserts the merged state without replaying. (5) Award duel/podium XP from MatchStore through an idempotent ledger keyed (match id, round, award kind). (6) Define the concurrent-rematch rule (the round present in the tapped bubble wins; a locally played conflicting round is kept only as a personal best). (7) Add the three-device concurrency test to Phase S2 and to the Phase 4 gate, and add a risk row. (8) Record the fallback in DECISIONS.md if the spike shows too many forks: per-player bubbles for Round mode (no shared leaderboard bubble), or move Round mode to v1.1 on CloudKit as Apple's note suggests.

**Device test.** Three iPhones on three Apple IDs in one iMessage group. A posts a round bubble. B and C both tap it before either sends, both finish, B sends, C sends within about 5 s. Repeat with the order reversed, and once with C offline while B sends. On every device log each decoded payload with the callback that delivered it (willBecomeActive / didSelect / didReceive), arrival time and entry ids, and screenshot the transcript. Current design: expect at least one device whose bubble is missing B or C. Amended design passes when, after at most one Re-post, all three devices show all three entries and award the same podium once.

**Skeptic: Confirmed.** Tried to refute on three fronts and failed. (1) Facts: the didReceive page carries the race note verbatim, selectedMessage says it "is not updated when you receive new messages", and MSSession says a later message on the session removes the previous one. The WWDC 2016 session 224 transcript (a primary source the reviewer did not have) describes this exact group case: two replies sent at once, one becomes a summary line, "only the tapped message is available to your iMessage app", and Apple's advice is to keep state in the cloud. (2) Plan: PLAN.md never mentions didReceive, merging, or concurrency; the only ordering case in P4.5 is "an old bubble tapped after newer ones"; the section 13 risk table has no row for it. (3) Frequency: I simulated the plan as written (compose from the tapped bubble, about 2 minutes from tap to send). With 3 responders answering inside 30 minutes, at least two overlap in 35% of rounds; with 4 responders inside 10 minutes, 97%. This is normal use of Round mode, not a corner case. Blocker stands because Round mode is v1.0 scope and the fix changes Appendix C, which Phase 1 (P1.8) implements. The recommended direction (mergeable payload, per-device MatchStore, didReceive routed into it, re-post repair, idempotent XP ledger) is right and mostly pure RiffCore logic. Refinements for the outline, none of which change the verdict: bound the per-round results list (about 3.5 URL characters per round by my recomputation, so it needs a compaction rule for very long series); the duel `sr` counter alone is not at risk under strict alternation, only concurrent rematch is; the per-player-bubble design in item 8 deserves equal weight with the shared bubble because nothing is ever removed from the transcript; the three-device test needs three Apple IDs while section 12 lists two.

**Outcome: Adopted (D-011, D-013, D-014).**

Sources: <https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/didreceive(_:conversation:)>, <https://developer.apple.com/documentation/messages/msconversation/selectedmessage>, <https://developer.apple.com/documentation/messages/mssession>, <https://developer.apple.com/forums/thread/51728>, <https://raw.githubusercontent.com/ASCIIwwdc/wwdc-session-transcripts/master/en/2016/224.vtt>

### MSG-2: Participant UUIDs are device-scoped and unstable, so they cannot be the player id in the payload

Severity major · factual-error · plan sections: 3 (row: Participant IDs are opaque UUIDs), 5.4, 5.5, 6.4 (Series records per friend, keyed by conversation participant), S2, 13, Appendix C (Entry.p, by, sr)

**The plan says.** Appendix C: `p` is the "player id: first 8 hex characters of the participant UUID"; `by` is the "starter's player id"; `sr` is "series wins by player id". Section 3 says the scoping will be "verified in the Phase 4 spike" (the spike is Phase S, task S2). 6.4 keys series records "by conversation participant".

**Problem.** The scoping is already documented, not an open question. A UUID that device A writes into the payload is A's private name for that participant; device B has a different UUID for the same person and cannot map `p` to anyone in its own remoteParticipantIdentifiers. On B only one correlation exists: message.senderParticipantIdentifier (B's UUID for whoever sent this version of the bubble), so only the newest entry's author is attributable. As written, `p` works only as a self-asserted id compared against the same device's own local UUID, and that breaks when: (a) the same person opens the bubble on their iPad (different UUID, so the app shows "Your turn" again and accepts a second entry, or a third 'player' in a duel); (b) the user disables and re-enables the app in Messages, or reinstalls (UUID changes mid-match: they can replay, `by` can no longer close the round, `sr` tallies are orphaned); (c) anything tries to key local records by a remote participant from payload data (6.4), which is impossible.

**Evidence.** localParticipantIdentifier doc: "This UUID is scoped to this device. It remains stable as long as the extension is enabled. If the extension is disabled and reenabled, or if the containing app is removed and reinstalled, the UUID for the local participant changes." remoteParticipantIdentifiers doc: "These UUIDs are scoped to this device." senderParticipantIdentifier doc: "The value of this UUID is scoped to the current device. Each device participating in the conversation will have a different UUID for the message's sender." MSConversation exposes nothing else about participants (members: selectedMessage, the two identifier properties, insert/send methods).

**Reviewer's recommendation.** Change Appendix C now (schema v1 should not ship with this): replace `p` with an app-generated random player id (for example 6-8 random bytes, base64url) created on first launch and stored in profile.json; use it for `by` and for the series data. "Me" = the entry whose id equals my stored id. Key 6.4 series records by the opponent's payload id, not by a participant UUID. Use participant UUIDs only locally and only for two things: (1) `selectedMessage.senderParticipantIdentifier == conversation.localParticipantIdentifier` as the 'did I send the latest version' check; (2) a device-local key for the conversation (hash of the sorted local+remote UUIDs) to bind pending runs to a chat. State the multi-device limit explicitly in 5.2 (identity and progress are per device in v1; a third id in a duel is shown read-only) or add iCloud key-value sync later. Fix section 3: the scoping is documented; S2 only needs to confirm cross-conversation stability and same-Apple-ID behaviour.

**Device test.** Two iPhones on different Apple IDs plus an iPad signed in to iPhone A's Apple ID. Send one session message from A in a 1:1 chat and in a group chat with the same people. On every device log localParticipantIdentifier, remoteParticipantIdentifiers and selectedMessage.senderParticipantIdentifier. Then switch the app off and on in Messages' iMessage-apps list on A and log again. Record: A's local UUID vs the UUID B reports for A (expected different); whether a device's local UUID is the same in both conversations; whether on A's iPad the sender UUID equals the iPad's local UUID; whether the UUIDs change after off/on.

**Skeptic: Partly correct.** The scoping facts are right and I re-read all three pages: local, remote and sender UUIDs are "scoped to this device" and change if the extension is disabled and re-enabled or the app is reinstalled. WWDC 2016 session 224 says the same ("unique on each device", "scoped to the install of the iMessage app"). Section 3 does defer a documented fact to a spike and names the wrong phase. But the title overstates: a prefix of your own localParticipantIdentifier does work as a self-asserted id for telling me from them on one device, which is all section 3 claims to use it for. The finding itself concedes this. The real defects are narrower: the id is lost on disable/re-enable, reinstall and very likely device replacement, which orphans `by`, `sr` and friend records while a restored profile keeps its XP; it can never be matched against the receiver's remoteParticipantIdentifiers, and the 6.4 wording ("keyed by conversation participant") invites exactly that bug; and Phase 1 would implement the schema before S2 reports. The proposed app-generated id is cheap and right, but it does not fix the same person on iPhone and iPad, which is the case the plan's own iPad test will hit. I keep major because it is a schema decision due before Phase 1, not because of user-visible breakage in the common path.

**Corrected problem.** Participant UUIDs are device- and install-scoped (documented, no spike needed). As a self-asserted id they work for me-versus-them on one device, but they are the wrong persistent player id: they change on extension disable/re-enable, reinstall and probably device replacement, orphaning `by`, `sr` and per-friend records; they cannot be mapped to the receiver's remoteParticipantIdentifiers, which the 6.4 wording invites; and neither they nor a local random id recognise the same person on a second device.

**Corrected recommendation.** Adopt the app-generated random player id (6-8 random bytes, stored in profile.json so it travels with the profile in a backup) for `p`, `by` and series data, and key 6.4 records by the opponent's payload id. Keep participant UUIDs local only: sender == local as the 'I sent the latest version' check, and a device-local conversation key. Fix the section 3 row (scoping is documented; the spike is Phase S). Add two checks to S2: whether the local UUID is the same across conversations on one device, and whether a message sent from the user's other device arrives with senderParticipantIdentifier equal to this device's local UUID. If the second holds, use it to show 'You played this on your other device' instead of 'Your turn'. State in 5.2 that identity and progress are per device in v1 and that a third id in a duel is read-only. Note in the privacy policy that the id is a stable identifier visible to chat members.

**Outcome: Adopted (D-010).**

Sources: <https://developer.apple.com/documentation/messages/msconversation/localparticipantidentifier>, <https://developer.apple.com/documentation/messages/msconversation/remoteparticipantidentifiers>, <https://developer.apple.com/documentation/messages/msmessage/senderparticipantidentifier>, <https://developer.apple.com/documentation/messages/msconversation>, <https://raw.githubusercontent.com/ASCIIwwdc/wwdc-session-transcripts/master/en/2016/224.vtt>

### MSG-3: Since iOS 17 Messages' resize pan gesture competes with manual touch handling; the plan's SpriteKit touch input is the affected pattern and nothing tests it

Severity major · gap · plan sections: 3 (row: Gameplay needs the expanded view), 4.1, 4.2 (holds), 4.7, 7.1 (SpriteKit inside SwiftUI), Phase S, P3.3, 13

**The plan says.** Minimum iOS is 17.0. Input is "multitouch columns, hardware timestamps fed into the game session" in a SpriteKit view; "Touch zones are the bottom 35% of the screen"; holds are touch-and-keep-holding. The only collapse handling is "collapsing mid-song pauses". Phase S and the risk table do not mention gesture conflicts.

**Problem.** On every OS the app supports, the expanded sheet can be dragged down with a vertical pan anywhere in it. Touches delivered through touchesBegan/Moved/Ended (how SKScene/SKView input works) lose to that pan: a thumb that drifts vertically during a hold or a fast tap gets cancelled and the sheet starts to collapse, which pauses the song. A shipping SpriteKit iMessage game reported exactly this on iOS 17, and a later report says even gesture recognizers were overridden. Separately, the bottom 35% touch zone sits on the home-indicator edge: a full app can defer system edge gestures, but an extension's view controller is not the window's root, so that preference is probably ignored (unverified). If this cannot be tamed the core game is unplayable inside Messages, so it belongs in the first spike, not Phase 3.

**Evidence.** Messages framework overview: "In iOS 17, Messages allows you to interactively resize iMessage apps with a vertical pan gesture. Messages handles any conflicts between resize gestures and your custom gestures. If your app uses manual touch handling such as touchesBegan(_:with:), touchesMoved(_:with:), and touchesEnded(_:with:), you can do either of the following: Change your manual touch handling code to use a gesture recognizer instead. Use your UIView to override gestureRecognizerShouldBegin(_:) and return NO when your iMessage app doesn't own the gesture." The same note is on UIView.gestureRecognizerShouldBegin(_:). Forum thread 731127 (Jun 2023): "touches are not being captured inside SpriteKit. Instead, vertical touches are interpreted as attempts to drag the sheet from expanded down to compact mode ... This breaks the app utterly." Apple Frameworks Engineer reply: "If you're using manual touch handling methods, you need to implement UIView.gestureRecognizerShouldBegin to prevent any UIPanGestureRecognizer from beginning." Dec 2023 follow-up in the same thread: "our UIGestureRecognizers are getting overridden by the iMessage Extension container's pan gestures" (unanswered).

**Reviewer's recommendation.** (1) Specify P3.3 differently: input comes from a dedicated UIKit view layered over the highway, not from SKScene touch methods or SwiftUI gestures. That view owns a custom UIGestureRecognizer subclass that records UITouch.timestamp for began/ended/cancelled, and overrides gestureRecognizerShouldBegin(_:) to return false for recognizers it does not own while a song is playing. (2) Treat touchesCancelled as a hold release, never as a miss. (3) Keep the touch columns above the bottom safe-area inset plus a margin, and keep the top strip of the sheet free of game input so the player can still collapse deliberately. (4) Add spike task S5 with a pass/fail gate before Phase 3 and a row in the section 13 risk table. (5) If the spike fails on some OS version, the fallback is a non-drag design decision to record (for example taps only, no holds) before charts are authored.

**Device test.** iPhones on iOS 17, 18, 26 and 27, extension expanded, spike highway running. Perform 200 two-thumb taps and 20 holds per column with deliberate 30-60 pt vertical drift, then 20 quick swipes that start inside the touch zone and move up from the home indicator and down toward the bottom edge. Log every touchesCancelled, every willTransition(to:) and willResignActive, and (now - UITouch.timestamp) per touch. Pass: zero cancels and zero unintended presentation changes from in-zone touches. Run once with SKScene touch methods (expected to fail) and once with the recognizer + gestureRecognizerShouldBegin design. Also record whether preferredScreenEdgesDeferringSystemGestures = .bottom changes the home-indicator behaviour.

**Skeptic: Confirmed.** Verified verbatim on the Messages framework overview and on UIView.gestureRecognizerShouldBegin(_:): since iOS 17 Messages resizes iMessage apps with a vertical pan, and apps using touchesBegan/Moved/Ended must either switch to a gesture recognizer or override gestureRecognizerShouldBegin. Forum thread 731127 matches the quotes: a SpriteKit iMessage app reported vertical touches being taken as sheet drags ("This breaks the app utterly"), an Apple Frameworks Engineer gave the same remedy, and a December 2023 follow-up reports recognizers still being overridden, unanswered. The plan's minimum OS is 17.0, input is SpriteKit touch handling hosted in SwiftUI (where the underlying SKView cannot be subclassed to add the override), holds require a thumb held down, and a grep of PLAN.md finds no mention of gesture, pan or swipe in section 3, Phase S, P3.3 or the risk table. Taps judged on touch-down would mostly survive, but holds and drifting thumbs would move the sheet and trigger the collapse pause, so the core loop is at risk on every supported OS. Major, not blocker, because Apple documents the fix; the right response is the spike task and the P3.3 respecification the reviewer proposes. Proportionality notes: the minimum design is a UIKit input view that overrides gestureRecognizerShouldBegin (Apple's second option), with the custom recognizer as a second layer; four OS versions is more than one owner can cover, so test the oldest and newest devices actually available. The home-indicator and preferredScreenEdgesDeferringSystemGestures point is unverified and correctly left to the device test.

**Outcome: Device spike decides (D-025).**

Sources: <https://developer.apple.com/documentation/messages>, <https://developer.apple.com/documentation/uikit/uiview/gesturerecognizershouldbegin(_:)>, <https://developer.apple.com/forums/thread/731127>, <https://developer.apple.com/documentation/uikit/uiviewcontroller/preferredscreenedgesdeferringsystemgestures>

### MSG-4: Conversations that are not pure iMessage (SMS, RCS, any group with an Android member) are not handled at all

Severity major · gap · plan sections: 1 (Social by default), 3 (row: Recipients may not have the app yet), 5.1, 5.3, 5.5 (URL doubles as the web fallback for people without the app), S2, P4.5, 11, 13

**The plan says.** "every run ends in a bubble that reads well even for people who don't have the app yet"; "The bubble image and caption explain the challenge; the message URL falls back to a web page". The only non-happy recipient case listed in P4.5 is "recipient without the app".

**Problem.** Three different audiences are folded into 'recipient without the app'. (a) iPhone on iMessage without the app: sees the template bubble and a store prompt; the web URL is not what opens. (b) Mac: clicking loads the URL in a browser (the only documented use of the web fallback). (c) SMS/RCS conversations: Apple says only that the template layout 'provides support' for SMS devices; interactive message data cannot travel over SMS/MMS/RCS, so nobody in such a chat, including other iPhone users in a mixed group, can tap to play. The extension has no API to tell which kind of conversation it is in, so the app will happily let a player finish a run and post a challenge that no one can answer, and a 400-4,000 character payload URL may land in the chat as text. Mixed iPhone/Android groups are common, and Round mode targets group chats. There is no spike task, no UX and no test for this.

**Evidence.** MSMessageLiveLayout doc: "The template layout automatically provides support for devices that do not support iMessage apps (macOS, iOS 9 and earlier, and SMS devices)." MSMessage.url doc: "If the message is selected on macOS, the system loads the URL in a web browser." HIG, iMessage apps: "Not supported in macOS, tvOS, visionOS, or watchOS." MSConversation has no transport or capability property (only selectedMessage, participant identifiers, insert/send). Forum thread 62331 (2016): "On non iOS 10 devices and macOS I see an ugly http URL alongside the iMessage image." I found no primary source describing exactly what an SMS/RCS recipient receives, so that part is unverified.

**Reviewer's recommendation.** Add to S2 an explicit non-iMessage test (below) and write the outcome into 5.3/5.4 before Phase 4. Then: (1) split the 'recipient without the app' row into the three audiences above with the expected behaviour for each; (2) if a non-iMessage chat produces a degraded message, show a one-line notice on the send screen ("Friends need iMessage to play back") whenever the spike identifies a usable signal (for example an insert/send error), and otherwise make the score-card image self-explanatory without interactivity; (3) make the fallback web page explain 'this needs iMessage on iPhone' rather than assuming the reader can install the app; (4) note in section 3 that the web fallback is primarily for Mac; (5) add a risk row.

**Device test.** From an iPhone with the spike build: (a) a 1:1 chat with an Android phone (RCS and, with RCS off, SMS) or an iPhone with iMessage switched off; (b) a group containing that phone plus a second iPhone that has the app. In each, open the extension, insert and send a session message with a ~400-character URL and one with a ~3,500-character URL, then send a second message on the same session. Record: whether the app is offered in the + drawer; any error from insert/send; exactly what each recipient sees (image, captions, raw URL text, tappable or not); whether the second iPhone's bubble is interactive; whether the second message replaces the first. Also view one normal iMessage bubble on a Mac and an Apple Watch and note what is shown and what a click opens.

**Skeptic: Partly correct.** The gap is real: PLAN.md contains no mention of SMS, RCS, Android or green-bubble chats, MSConversation exposes no transport property, and MSMessageErrorCode has no code for a non-iMessage conversation. The reviewer said no primary source describes what fallback recipients get. One exists: the WWDC 2016 session 224 transcript says fallback platforms receive "two separate messages. The first one will be the image as provided in the template layout. The second one will be a URL", and that only http/https URLs are sent, "If it's a data URL, we won't". The MSMessageLiveLayout page puts SMS devices in the same fallback class as macOS and iOS 9. So the likely outcome in an SMS/RCS or mixed chat is the score card plus the whole payload URL as text, 376 to about 3,600 characters by my recomputation of the plan's schema. That makes the concern stronger than the reviewer stated, and it gives a design lever the recommendation lacks. The SMS/RCS-specific behaviour on current iOS is still unconfirmed and needs the device test. Major holds: mixed groups are common, Round mode targets groups, and the URL scheme is part of the Phase 1 codec.

**Corrected problem.** Per WWDC 2016 session 224, recipients on platforms without iMessage-app support get the template image and then the https URL as a separate message; Apple's docs class SMS devices with those platforms. In a non-iMessage or mixed chat the likely result is a score card nobody can tap plus a 376-3,600 character payload URL as text, and the extension has no API to detect such a chat. Exact SMS/RCS behaviour on iOS 17-27 is unverified.

**Corrected recommendation.** Keep the reviewer's S2 test and the three-audience split in 5.3/5.4. Add a `data:` URL variant to that test (documented as allowed; per WWDC it is not sent in the fallback). Decide the URL form before PayloadCodec is frozen: if the `data:` form round-trips on the supported OS range, prefer it for v1, since fallback recipients then get only the score card, nothing reaches a server and the domain decision disappears; the cost is no click-through page on Mac. If https is kept, the fallback page must say 'needs iMessage on iPhone'. Show a sender-side notice only if S2 finds a usable signal; otherwise make the card self-explanatory. Add the risk row.

**Outcome: Device spike decides (D-024).**

Sources: <https://developer.apple.com/documentation/messages/msmessagelivelayout>, <https://developer.apple.com/documentation/messages/msmessage/url>, <https://developer.apple.com/design/human-interface-guidelines/imessage-apps-and-stickers>, <https://developer.apple.com/documentation/messages/msconversation>, <https://developer.apple.com/forums/thread/62331>, <https://raw.githubusercontent.com/ASCIIwwdc/wwdc-session-transcripts/master/en/2016/224.vtt>, <https://developer.apple.com/documentation/messages/msmessageerrorcode>

### MSG-5: Selection is sticky and didSelect fires only for a different message; the 5.4 routing table and the iPad mitigation do not cover this

Severity major · risk · plan sections: 3 (row: Bubble-tap callbacks can differ between iPhone and iPad), 5.4, S2, P4.1, Phase 4 done-when (iPhone and iPad), 13

**The plan says.** 5.4 routes "No bubble selected (opened from the app drawer)" to Home and every other row from the selected bubble's state. The iPad mitigation is "Read the selected message on every activation, not only in the tap callback". Phase 4 is done only when the flows work "on iPhone and iPad".

**Problem.** (1) Once a bubble has been tapped, conversation.selectedMessage stays set for the life of the extension and there is no API to clear it. Re-tapping the same bubble produces no willSelect/didSelect, and collapsing does not deselect. So 'no bubble selected' is not a reliable signal for 'opened from the drawer': after viewing any match, expanding again or coming back from Home re-routes into the stale match, and a re-tap of the current bubble cannot be told apart from pressing the expand control. The table has no rule for this. (2) The plan's iPad mitigation is what a 2026 reporter already tried: on iPad (iOS 18 and 26), after taking a turn and sending, tapping the opponent's new bubble often does not open the extension at all, and reading selectedMessage in willBecomeActive/didBecomeActive/didReceive did not help. If that reproduces, the Phase 4 iPad gate cannot be met by code changes.

**Evidence.** Apple staff, forum thread 53167: "If you tap on a single message I would only expect to get the will/didSelect if you select a different message. This is similar to how a table view works ... The selected message and the presentation mode are orthogonal." Same thread, developers: no programmatic deselect; "we have no way to detect that tap versus a tap on the expand [control]". Forum thread 816190 (Feb 2026, iPad Pro M4 and iPad Air, iOS 18 and 26): "When the opponent sends their response and the player taps on the new message bubble, the extension often does not open. The didSelect(_:conversation:) method is not called ... This works perfectly on iPhone"; attempted fixes included checking conversation.selectedMessage in willBecomeActive, didBecomeActive and didReceive; no resolution, Apple DTS asked for a test project. presentationStyle doc: selecting a message launches the extension expanded; the drawer launches it compact.

**Reviewer's recommendation.** Specify the router in P4.1 as a pure function re-evaluated on willBecomeActive, didBecomeActive, didSelect, didReceive and didTransition(to:), with inputs (presentationStyle, key of selectedMessage, isPending, last-handled message key, a 'user left this match' flag). Add to 5.4: every match screen has an explicit Home action that sets the flag for that message key; the flag clears only when a different message is selected; expanding with a flagged selection goes Home. Add the reproduction below to S2. Decide from its result whether iPad is a supported target or 'best effort', and change the Phase 4 gate and section 1 wording ("iPad works in the expanded view") accordingly. Test whether calling dismiss() once the send has started (so the next tap is a cold activation) avoids the iPad failure; adopt it only if it does.

**Device test.** iPhone and iPad on the newest and oldest supported OS. (1) Tap a bubble, collapse to compact, tap the same bubble: log which of willBecomeActive / willSelect / didSelect / willTransition fire and the value of selectedMessage. (2) Go Home inside the app, collapse, reopen from the + drawer: log whether selectedMessage is nil or still the old bubble. (3) Ten alternating turns between two devices: tap bubble, play, insert, send, let the extension collapse, other side replies, tap the new bubble. Count taps that fail to open the extension, once with requestPresentationStyle(.compact) after insert and once with dismiss() after didStartSending.

**Skeptic: Partly correct.** Both forum threads say what the reviewer reports. Thread 53167: Apple staff state will/didSelect fire only for a different message and that selection and presentation style are orthogonal; developers found no way to deselect. Thread 816190 (Feb 2026, iPad Pro M4 and iPad Air, iOS 18 and 26): after a turn is sent and the extension collapses, tapping the opponent's new bubble often does not open the extension, and reading selectedMessage in willBecomeActive/didBecomeActive/didReceive, which is the plan's stated iPad mitigation, did not help. Apple DTS did not confirm a bug and asked for a sample; the poster published one (github.com/abassey/test-project-ipad-issue). The plan already carries an iPad risk row and S2, so this is a sharpening of a known risk, but the sticky-selection ambiguity in the 5.4 table is new and the router spec is cheap and testable. One part of the fix is wrong: treating iPad as 'best effort' is not an exit. The same thread says App Review flagged the iPad behaviour as incomplete functionality and that it blocked submission, and guideline 2.4.1 says iPhone apps should run on iPad whenever possible. Whether sticky selection still behaves this way on iPhone on current iOS is unverified.

**Corrected recommendation.** Keep the router as a pure function re-evaluated on every lifecycle callback, the explicit Home action with a per-message 'left this match' flag, and the S2 reproduction. Run the public sample from thread 816190 on the test iPad first; it is a quick check of whether the failure reproduces on current iPadOS. Do not plan on downgrading iPad to best effort: App Review tests there. If the failure reproduces, find the workaround in the spike (compare requestPresentationStyle(.compact) with dismiss() after the send starts) before Phase 4, and record the result in the risk table and the review notes.

**Outcome: Adopted (D-021).**

Sources: <https://developer.apple.com/forums/thread/53167>, <https://developer.apple.com/forums/thread/816190>, <https://developer.apple.com/documentation/messages/msconversation/selectedmessage>, <https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/presentationstyle>, <https://raw.githubusercontent.com/abassey/test-project-ipad-issue/master/README.md>, <https://developer.apple.com/app-store/review/guidelines/>

### MSG-10: Phase S depends on TestFlight, but every TestFlight prerequisite is scheduled in Phase 8

Severity minor · inconsistency · plan sections: 3 (row: Recipient-side testing ... via TestFlight), 12 (two iPhones on two Apple IDs by Phase S), 13 (Recruit a test partner ... in the first week), P0.2, P8.1, P8.2, P8.3

**The plan says.** "Recruit one test partner with their own Apple ID and iPhone early, via TestFlight" for Phase S, while icons are P8.1, the privacy manifest P8.2 and TestFlight P8.3. P8.1 says "Messages app icons (4:3 sizes)".

**Problem.** A build cannot be uploaded for TestFlight without the pieces the plan leaves to the last phase: the App Store Connect record, the complete iMessage icon set (not only the wide sizes), a privacy manifest covering required-reason APIs, and the export-compliance answer. External testers also need a first Beta App Review. The privacy manifest must sit in the extension bundle, since the wrapper has no code, and the timing code will likely touch a required-reason category.

**Evidence.** Required-reason API article: "Starting May 1, 2024, apps that don't describe their use of required reason API in their privacy manifest file aren't accepted by App Store Connect" and "For each executable or dynamic library in an app that uses a required reason API, the bundle that includes the executable or dynamic library needs to include a privacy manifest file". The System Boot Time category lists systemUptime and mach_absolute_time(); reason 35F9.1 covers measuring elapsed time between in-app events; File Timestamp reason C617.1 covers files in the app or App Group container; User Defaults reasons are CA92.1 (app only) and 1C8F.1 (App Group). HIG icon table for iMessage apps: Messages sizes 148x110, 143x100, 120x90, 180x135, 64x48, 96x72, 54x40, 81x60, plus Settings 58x58 and 87x87 and App Store 1024x1024. Developer forum reports of upload rejections for a missing iMessage App Icon (ITMS-90649, ITMS-90644, 1024x768 large icon) were seen only as search summaries.

**Reviewer's recommendation.** Move into P0.2/P0.3: App Store Connect app record and bundle ids; a placeholder 'iMessage App Icon' set with every slot filled (wide Messages sizes, the 1024x768 Messages store icon, the square Settings sizes and 1024x1024); PrivacyInfo.xcprivacy in the RiffMessages target with only the categories the code really uses (expected: SystemBootTime 35F9.1 if mach_absolute_time or systemUptime is called directly; FileTimestamp C617.1 if file dates are read; a UserDefaults reason only if UserDefaults is used); the export-compliance key after confirming HMAC-only use is exempt. Add a P0 gate: 'an archive uploads to App Store Connect with no errors'. Keep P8 for final art, the privacy label, age rating, the hosted privacy policy and review notes. Alternatively state that Phase S uses a second device with a second Apple ID installed straight from Xcode, and TestFlight starts in Phase 4.

**Skeptic: Confirmed.** The inconsistency is in the plan's own text: section 3 recruits the Phase S partner "via TestFlight" while icons, privacy manifest and TestFlight are P8.1-P8.3. The required-reason article says, verbatim, that from May 1, 2024 apps that do not declare required-reason API use "aren't accepted by App Store Connect" and that the manifest belongs in the bundle containing the executable, which here is the extension. The HIG icon table matches the sizes quoted, including the square Settings and App Store sizes that P8.1's "4:3 sizes" omits. The 1024x768 slot and the ITMS error codes were not verified here. Either remedy works: move the upload prerequisites into Phase 0, or state that Phase S installs straight from Xcode and TestFlight starts in Phase 4. A schedule problem, not a design one, so minor.

**Outcome: Adopted (D-028).**

Sources: <https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api>, <https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons>, <https://developer.apple.com/design/human-interface-guidelines/imessage-apps-and-stickers>, <https://developer.apple.com/imessage/>

### MSG-11: Payload in the query string of an https URL sends match data to the web server, which undercuts 'no network' and 'Data Not Collected'

Severity minor · risk · plan sections: 5.5, 7.5 (No network, analytics or accounts in v1), P8.2 (Data Not Collected), 14 (Fallback web domain), Appendix C

**The plan says.** `https://&lt;domain>/m?p=&lt;payload>` "on a domain we control. That URL doubles as the web fallback"; "any https placeholder for TestFlight"; privacy label "Data Not Collected".

**Problem.** Whenever the URL is opened outside the app (documented for Mac; possibly also wherever it degrades to a plain link), the browser sends the whole payload (nicknames, scores, player ids, timestamps) to that server together with the visitor's IP address. With default access logs the developer then holds that data, which is hard to square with a 'Data Not Collected' label. A placeholder domain owned by someone else would leak it to a third party. Separately, if the decoder checks the host, changing the domain between TestFlight and release breaks every old bubble. A 2016 report says Mac showed the raw URL next to the image, which would be thousands of base64 characters.

**Evidence.** MSMessage.url doc: "If the message is selected on macOS, the system loads the URL in a web browser. The URL should point to a web service that returns a meaningful result based on the encoded data." Apple, App privacy details: "'Collect' refers to transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time"; "Your app includes game saves, multiplayer matching, or gameplay logic. Declare Gameplay Content on your label"; User ID includes "screen name, handle". Review Guideline 2.1(a): submissions need "fully functional URLs"; "empty websites ... should be scrubbed". Forum thread 62331 for the raw-URL report and Apple staff's suggestion of a data: URL to hide it.

**Reviewer's recommendation.** In 5.5 and Appendix C: (1) carry the payload in the URL fragment (`https://&lt;domain>/m#p=&lt;payload>`), which browsers never send to the server, and let a static page decode it client-side; verify in S2 that the fragment survives the round trip, and if it does not, keep the query form but host the page statically with access logging off and say so in the privacy policy. (2) The decoder reads the payload item and ignores scheme, host and path, so the domain can change. (3) Never use a domain you do not control, even in TestFlight. (4) The 4 KB cap is defined on the full URL string length and stays under the documented 5,000 characters. (5) The fallback page must be live with real content before submission. (6) Note the Mac raw-URL question as a spike check.

**Device test.** Send a session message whose URL is https://&lt;test-domain>/m#p=&lt;payload>. On the receiving iPhone log message.url.absoluteString and compare byte for byte. On a Mac running current macOS, note what the bubble shows (is the raw URL visible?) and click it; check the server log for what was requested. Repeat with the ?p= form.

**Skeptic: Partly correct.** The mechanics are right: MSMessage.url says macOS loads the URL in a browser, a query string reaches the server, and Apple's definition of 'collect' and the Gameplay Content and User ID categories read as quoted. Guideline 2.1(a) does require functional URLs and no empty websites, and the plan's "any https placeholder for TestFlight" would send payloads to a host the owner may not control. The label risk is a conservative reading, since the app itself transmits nothing, which is why minor is right. Two corrections. Fragment survival through MSMessage is unverified, as the reviewer notes. And the recommendation omits the option Apple staff gave in the cited thread 62331 and that WWDC 2016 session 224 backs: a `data:` URL is never sent in the fallback message and never contacts a server.

**Corrected recommendation.** Test three URL forms in S2 for byte-exact round trip: `data:`, https with the payload in the fragment, https with the payload in the query. Prefer `data:` for v1 if it round-trips across the supported OS range (no server contact, no raw URL in fallbacks, no domain decision); otherwise the fragment form with a static page; the query form only with access logging off and a line in the privacy policy. In every case the decoder reads only the payload and ignores scheme, host and path, the cap applies to the whole URL string under 5,000 characters, and no domain outside the owner's control is used, including in TestFlight. A hosted privacy policy URL is still needed for App Store Connect.

**Outcome: Device spike decides (D-017).**

Sources: <https://developer.apple.com/documentation/messages/msmessage/url>, <https://developer.apple.com/app-store/app-privacy-details/>, <https://developer.apple.com/app-store/review/guidelines/>, <https://developer.apple.com/forums/thread/62331>, <https://raw.githubusercontent.com/ASCIIwwdc/wwdc-session-transcripts/master/en/2016/224.vtt>

### MSG-12: Bubble spec gaps: no summaryText or accessibilityLabel, an undocumented name placeholder, and a per-viewer element that a sender-rendered image cannot show

Severity minor · gap · plan sections: 3 (row: No access to contact names), 5.1 (top 3 plus your own place), 5.3, P4.2, P7.3, S2

**The plan says.** "captions use Messages' participant-name placeholder (verify on device)"; captions such as "Sam scored 412,300"; the round bubble shows "top 3 plus your own place"; VoiceOver work is scoped to "every menu".

**Problem.** (1) summaryText is never mentioned. Each superseded turn is replaced in the transcript by that text, or by a system default if nil, so the visible history of a match is whatever Messages chooses. (2) accessibilityLabel is not set, so VoiceOver has nothing meaningful to read for a score-card image. (3) The '$' + UUID name substitution is not in Apple's current documentation; it rests on a WWDC 2016 session that is no longer published and on developer reports, some of which show a phone number or email when the participant is not in the viewer's Contacts. It also cannot appear in the rendered image, so the caption would say a contact name while the card says a nickname. (4) The image is rendered once by the sender and is identical for everyone, so 'your own place' can only be the sender's place. (5) Two layout facts the card design must respect are missing: the image is cropped 6 points left and right with rounded corners, and a received message has no layout, so nothing can be read back from captions or image.

**Evidence.** summaryText doc: "Set the summary text when you create a message that is associated with a session. When a subsequent message is sent using the same session, the Messages app uses this text to create a summary in the transcript. If the summary text is nil, the system provides a default description". accessibilityLabel doc: "VoiceOver reads this property when describing the message." The caption, trailingCaption and localParticipantIdentifier pages contain no mention of name substitution. Forum thread 52130 cites WWDC16 session 224 for the '$uuid' trick and shows an unreplaced "$E0712CEB-... won!" on one beta; the WWDC16 224 video page now returns no video. A Stack Overflow title found by search reads "iMessage identifiers converted to phone number instead of name" (page not reachable from here). image doc: "The system crops the left and right edges of the image by 6 points, and rounds the image's corners." Apple staff, forum thread 53174: "Received messages won't have a layout object filled in ... Information that needs to be conveyed in the message needs to be encoded in the URL".

**Reviewer's recommendation.** In 5.3: set summaryText on every message (for example "Sam scored 412,300 on Neon Nights") and accessibilityLabel (a full sentence with scores and standing); use the payload nickname everywhere in captions and summary, and drop the placeholder unless S2 shows it renders a real name for contacts and you accept a phone number for non-contacts; change 5.1 to "top 3 plus the sender's place" (the viewer's own place is shown after tapping); give the score card a safe margin of at least 12 pt and no essential content at the corners; note that all state is read from the URL only. Add VoiceOver for the bubble to P7.3.

**Device test.** Send messages whose caption and summaryText contain "$" + localParticipantIdentifier.uuidString. Record the rendered text on: the sender's device; a receiver who has the sender in Contacts; a receiver who does not; a third member of a group. Then send a second message on the session and record what the summary line for the first looks like with summaryText set and with it nil. Turn on VoiceOver and note what is read for the bubble with and without accessibilityLabel.

**Skeptic: Confirmed.** summaryText and accessibilityLabel are documented as quoted and appear nowhere in PLAN.md; the MSSession page lists summaryText in its own workflow. The image page confirms the 6-point crop and rounded corners. Apple staff in thread 53174 confirm received messages have no layout. The 'your own place' point is sound: the card is rendered once by the sender, so it can only show the sender's place. One correction to the evidence: the '$' + UUID placeholder is absent from current docs but was official; the WWDC 2016 session 224 transcript says Messages "will replace the identifiers with the contact name" in template text and summaryText, and thread 52130 ends with it working after a beta update. The plan already marks it verify-on-device, so that sub-point is partly handled; the phone-number fallback for non-contacts rests on search summaries only. Using the payload nickname as the default and the placeholder only if S2 passes is a reasonable call.

**Outcome: Adopted (D-022).**

Sources: <https://developer.apple.com/documentation/messages/msmessage/summarytext>, <https://developer.apple.com/documentation/messages/msmessage/accessibilitylabel>, <https://developer.apple.com/documentation/messages/msmessagetemplatelayout/caption>, <https://developer.apple.com/documentation/messages/msmessagetemplatelayout/image>, <https://developer.apple.com/forums/thread/52130>, <https://developer.apple.com/forums/thread/53174>, <https://raw.githubusercontent.com/ASCIIwwdc/wwdc-session-transcripts/master/en/2016/224.vtt>

### MSG-13: A group round 'completes when every member has submitted', but the member count includes people who cannot or will not play

Severity minor · design-flaw · plan sections: 5.1, 5.2, 5.3 (2 of 5 played), 6.1 (podium XP lands when the round completes)

**The plan says.** "A group round completes when every member has submitted or the starter closes it." Podium XP lands "when the round completes".

**Problem.** The only member count available is remoteParticipantIdentifiers.count + 1 on the viewing device. It counts members without the app, members who ignore the challenge, and it changes when people join or leave. In practice 'everyone submitted' will almost never be reached, so standings stay provisional and podium XP is never paid unless the starter remembers to close, and only the starter's original device can close (see MSG-2).

**Evidence.** MSConversation offers only remoteParticipantIdentifiers ("An array of UUIDs representing the remote participants in this conversation"); there is no information about who has the app, and the UUIDs change if the extension is disabled and re-enabled. The rest is reasoning from the plan's own rules.

**Reviewer's recommendation.** Add a deterministic expiry to 5.2: a round is final when closed, when every member counted at start has submitted, or 24 hours after the starter's timestamp carried in the payload, whichever comes first (the duration lives in GameConfig). Finality is computed locally from the payload so all devices agree without a new message; a submission arriving after expiry is shown as late and does not change the podium. Let any participant, not only the starter, close a round after a shorter grace period. Store the member count at start in the payload so 'N of M played' is stable.

**Skeptic: Confirmed.** PLAN.md 5.2 completes a group round when "every member has submitted or the starter closes it" and 6.1 pays podium XP on completion. The only member count the API offers is remoteParticipantIdentifiers.count + 1, which includes people without the app. So completion depends on the starter remembering to close, from the same device and install that started the round. The reasoning needs no further source. A payload-carried start time, a member count fixed at start and a locally computed expiry are small RiffCore rules. Letting any participant close after a grace period is optional; the expiry alone fixes the stuck-round case. Devices can still disagree on contents until MSG-1 is addressed, which the finding does not claim to solve.

**Outcome: Owner decision (D-012).**

Sources: <https://developer.apple.com/documentation/messages/msconversation/remoteparticipantidentifiers>

### MSG-6: An iMessage-only extension cannot open URLs, so the 'App Store link' and any external link cannot work as written

Severity minor · factual-error · plan sections: 5.4 (Update needed, with an App Store link), 7.2 (Settings, Profile, LICENSES), P8.2, 14 (iMessage-only for v1)

**The plan says.** "Payload from a newer app version or a different chart | Update needed, with an App Store link". The app is iMessage-only with "no Home Screen app".

**Problem.** The only sanctioned way for an extension to open a URL is NSExtensionContext.open, and for iMessage apps it is limited to opening the parent app, and only when that parent is on the Home Screen. This app has no such parent. There is no UIApplication in an extension, so SwiftUI Link/openURL will not open Safari or the App Store either. The same limit hits the privacy policy link that Review requires inside the app, song licence/credit links, and any support link.

**Evidence.** NSExtensionContext.open(_:completionHandler:) doc: "In iOS, the Today and iMessage app extension points support this method. An iMessage app extension can use this method only to open its parent app, and only if the parent app is shown on the iOS home screen." Apple staff, forum thread 54410: "The expected behavior is that the iMessage extension can only open URLs in their parent apps." App Extension Programming Guide: an extension cannot "Access a sharedApplication object". Review Guideline 5.1.1(i): "All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner." SKStoreProductViewController doc: it "doesn't support subclassing or embedding" and throws SKUnsupportedPresentationException if embedded (the 2016 forum workaround embedded it).

**Reviewer's recommendation.** Change 5.4 to: "Update needed: plain instructions ('Update Riff in the App Store') plus, if the spike confirms it works, a modally presented SKStoreProductViewController". Add a rule to 12.2: no feature may depend on opening an external URL; privacy policy, licences and credits are rendered as in-app text (with the web address shown as selectable text). Add the in-app privacy policy screen to P7.2 and the hosted policy URL to P8.2.

**Device test.** In the spike build, from the expanded extension: (1) call extensionContext.open with an https URL and with an App Store URL and log the Bool; (2) load and modally present SKStoreProductViewController for any live app id and record whether the page appears, whether anything is clipped, and whether dismissal returns cleanly to the extension. Run on the oldest and newest supported iOS.

**Skeptic: Confirmed.** NSExtensionContext.open's page says an iMessage extension can use it "only to open its parent app, and only if the parent app is shown on the iOS home screen"; this app has no such parent. Apple staff in thread 54410 say the same. Guideline 5.1.1(i) does require the privacy policy link "within the app in an easily accessible manner". The SKStoreProductViewController page confirms embedding throws; note the 2016 thread shows both a modal presentation (top of the page clipped) and an embedded one, so the modal route is plausible but untested on current iOS. Whether SwiftUI Link silently fails in the extension is unverified and is covered by the proposed device test. Minor is right: the fix is copy plus an in-app text screen.

**Outcome: Adopted (D-023).**

Sources: <https://developer.apple.com/documentation/foundation/nsextensioncontext/open(_:completionhandler:)>, <https://developer.apple.com/forums/thread/54410?page=2>, <https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html>, <https://developer.apple.com/app-store/review/guidelines/>, <https://developer.apple.com/documentation/storekit/skstoreproductviewcontroller>

### MSG-7: 'Portrait only' cannot be enforced by a Messages extension

Severity minor · factual-error · plan sections: 4.1 (Portrait only), 3 (row: Screen sizes vary), 4.7, P3.1

**The plan says.** "notes travel toward a strike line about 18% above the bottom edge. Portrait only."

**Problem.** Orientation belongs to the host app. Messages rotates on iPhone when rotation lock is off and in every orientation on iPad (plus Split View / Stage Manager widths), and the extension's view is simply resized. Declaring portrait in Info.plist or overriding supportedInterfaceOrientations has no effect. The plan's 'layout from available size' covers widths but there is no rule for a short, wide view in the middle of a song.

**Evidence.** UIViewController.supportedInterfaceOrientations doc: "the system calls this method on the root view controller or the topmost modal view controller that fills the window" (an extension's controller is neither). Forum thread 53981: a developer set UISupportedInterfaceOrientations to portrait and overrode supportedInterfaceOrientations, "But I am still able to rotate the device and see my layout in landscape"; the accepted reply relays Apple Support: extensions "must follow the constraints and behaviors of iMessage". Other threads report UIDevice orientation as unknown inside Messages extensions.

**Reviewer's recommendation.** Replace "Portrait only" in 4.1 with: "Designed for a tall view. If the game view becomes wider than tall, or shorter than a stated minimum height, the song pauses and an overlay asks the player to rotate back; menus stay usable (scrolling) at any size." Detect it from the view's bounds in layout, not from UIDevice. Add the pause trigger to 4.7 and a rotation case to the P3.1 expanded-view guard and to the iPad test list.

**Device test.** Rotation lock off: rotate an iPhone to landscape while the expanded extension shows the spike highway; log view bounds and safe-area insets before and after, with and without a supportedInterfaceOrientations override. On iPad repeat in both orientations, in Split View at each width, and in a Stage Manager window.

**Skeptic: Confirmed.** supportedInterfaceOrientations is consulted only on "the root view controller or the topmost modal view controller that fills the window", which an extension's controller is not. Thread 53981 matches the quote: Info.plist and the override were both tried and the layout still rotated; the reply relaying Apple's position is second-hand, as the reviewer says. PLAN.md 4.1 says "Portrait only" and nothing in the plan covers a wide, short view mid-song (no mention of landscape or rotation anywhere). The pause-and-overlay rule driven by view bounds is the proportionate fix.

**Outcome: Adopted (D-026).**

Sources: <https://developer.apple.com/documentation/uikit/uiviewcontroller/supportedinterfaceorientations>, <https://developer.apple.com/forums/thread/53981>

### MSG-8: 'Submitted' is undefined between insert and Send: the draft can be deleted or never sent, and the run is lost

Severity minor · gap · plan sections: 4.7 (Restarting is allowed until you submit), 5.2, 5.3 (inserts the message into the compose field and the player taps Send), 5.4, P4.2, P4.3

**The plan says.** "The app inserts the message into the compose field and the player taps Send. Nothing sends automatically." "One submitted score per player per round; restarts before submitting are fine."

**Problem.** Insert only stages a draft. The plan does not say (a) that the expanded view must give way so the player can reach the Send button, (b) what state the app is in while the draft is staged, (c) what happens if the player deletes the draft, taps the staged draft bubble, inserts something else (which replaces it), or leaves. Because 'have I submitted' is read from the tapped bubble's payload, a player whose draft was deleted is sent back to 'Your turn' and has to replay; a good run is gone. didStartSending does not confirm delivery, and insert's completion handler runs on a background queue.

**Evidence.** insert(_:completionHandler:) doc: "This method does not send the message ... The message is not sent until the user taps Send. Subsequent calls to this method replace any existing message in the input field" and "the system calls the completion block on a background queue." isPending doc: true after insert, false once didStartSending is called; lets you tell "whether the conversation's selectedMessage property refers to a message in the transcript (false) or to a message in the Messages app's input field (true)". didStartSending doc: "It does not guarantee that the message will be successfully sent or delivered." didCancelSending doc: called when "the user subsequently deletes the message object." dismiss() doc: "marks the extension as eligible for termination". send(_:completionHandler:) exists (iOS 11+) and may be called "only in response to a user action".

**Reviewer's recommendation.** Add a small state machine to 5.3 / P4.2: played -> staged -> sending -> confirmed. Persist the finished run (RunSummary + match id + round) synchronously when the song ends. After insert succeeds (hop to the main actor), call requestPresentationStyle(.compact) rather than dismiss() so the callbacks keep arriving, and show "Tap Send to post your score". On didCancelSending, or on any later activation where the tapped bubble lacks the stored entry, offer "Send your score" again without replaying. Treat a selectedMessage with isPending == true as 'not sent yet', never as Waiting. Mark confirmed only when the entry is seen in a non-pending message. Record in DECISIONS.md whether to keep insert or use send(_:) behind an explicit in-app 'Send score' button (fewer states, one less tap).

**Device test.** Log isPending, didStartSending and didCancelSending in four flows: insert then requestPresentationStyle(.compact) then Send; insert, compact, delete the draft from the field; insert then dismiss() then Send; insert, then tap the staged draft bubble. Note in each whether the compose field and Send button are reachable without extra taps, and which callbacks arrive.

**Skeptic: Confirmed.** All six doc quotes check out: insert only stages a draft and its completion runs on a background queue; isPending distinguishes a staged draft from a sent message; didStartSending does not guarantee delivery; didCancelSending fires when the draft is deleted; dismiss() marks the extension for termination. The plan defines neither 'submitted' nor what happens between insert and Send. Impact is limited because the plan allows restarts before submitting, so a deleted draft is a lost run, not a rules hole; that is why minor is right. The small state machine and synchronous persistence at song end are proportionate and also feed MSG-1's MatchStore.

**Outcome: Adopted (D-020).**

Sources: <https://developer.apple.com/documentation/messages/msconversation/insert(_:completionhandler:)-3g248>, <https://developer.apple.com/documentation/messages/msmessage/ispending>, <https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/didstartsending(_:conversation:)>, <https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/didcancelsending(_:conversation:)>, <https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/dismiss()>, <https://developer.apple.com/documentation/messages/msconversation/send(_:completionhandler:)-9krz>

### MSG-9: Pause/resume assumes the extension survives; pause triggers, termination and conversation switches are unspecified

Severity minor · gap · plan sections: 4.7, 7.2 (Routing/ConversationContext), 7.5, P2.1, P4.1

**The plan says.** "Collapsing the view, a call, Siri or leaving Messages pauses at once. Resume shows a 3-beat countdown and restarts audio in sync." "Writes are atomic".

**Problem.** (1) An extension has no UIApplication lifecycle notifications; the plan names the events but not the signals that carry them. (2) Messages may terminate the extension shortly after it resigns active, and warns that asynchronous work may not finish, so a 'paused' run can simply be gone and a result not yet written is lost. (3) MSConversation has no identifier. If the player switches to another chat while a run is paused or a result is pending, nothing ties that run to the original conversation, and the result could be inserted into the wrong chat with another chat's session.

**Evidence.** willResignActive(with:) doc: "Avoid doing any time-consuming tasks ... Also, avoid making asynchronous calls, because the extension might terminate before the asynchronous tasks have completed." Foundation: NSExtensionHostWillResignActive ("Posted when the extension's host app moves from the active to the inactive state") and NSExtensionHostDidEnterBackground ("Extensions receive only a short amount of time to perform any background work"). MSConversation's members are selectedMessage, the participant identifiers and insert/send only.

**Reviewer's recommendation.** In 4.7 list the pause signals: willTransition(to: .compact), willResignActive(with:), NSExtensionHostWillResignActive, NSExtensionHostDidEnterBackground, AVAudioSession interruption, and the size change from MSG-7. State that a run interrupted by termination is discarded (no partial scores) and that a completed run is written synchronously at song end, before the results screen. Give ConversationContext a device-local conversation key (hash of the sorted local and remote participant UUIDs); bind paused and pending runs to (conversation key, match id, round) and drop or park them when willBecomeActive arrives with a different key.

**Device test.** With a song paused in the spike build: switch to another conversation and back; send Messages to the background for 10 s and for 5 min; lock the screen; take a phone call; invoke Siri. For each, log willResignActive/didResignActive, the two NSExtensionHost notifications, the audio interruption notification, the process id and the view controller's object id on return, and whether in-memory state survived.

**Skeptic: Confirmed.** willResignActive's page warns against asynchronous work "because the extension might terminate before the asynchronous tasks have completed"; the two NSExtensionHost notifications exist as described; MSConversation's member list has no identifier. PLAN.md 4.7 names the pause events but not their signals, and assumes the process survives a pause. Listing the signals, discarding runs lost to termination, writing a finished run synchronously and binding pending runs to a device-local conversation key are all small and correct. The wrong-chat insert is an edge case, so minor.

**Outcome: Adopted (D-027).**

Sources: <https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/willresignactive(with:)>, <https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nsextensionhostwillresignactive>, <https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nsextensionhostdidenterbackground>, <https://developer.apple.com/documentation/messages/msconversation>

### MSG-14: Compact view cannot show a keyboard and should not scroll horizontally; nickname entry and the song picker need a rule

Severity nit · gap · plan sections: 3 (row: Gameplay needs the expanded view ... Menus work in compact), P6.3, P7.1, P7.2

**The plan says.** "Menus work in compact; Play requests expanded"; "Players set a nickname".

**Problem.** The compact view replaces the keyboard, so the nickname field cannot be edited there, and Apple's guidance excludes horizontally scrolling content in compact, which rules out a carousel-style song picker in that size.

**Evidence.** MSMessagesAppPresentationStyle.compact doc: "Because the keyboard is not available, adding text fields or text views to your compact layout is not recommended. If you have a control that requires input from the keyboard (for example, a text field), you must call requestPresentationStyle(_:) to expand the extension as soon as the user selects that control ... Additionally, do not include horizontally scrolling elements in a compact layout." HIG: "In general, let people edit text only in the expanded view."

**Reviewer's recommendation.** Add to the UI spec: compact screens are vertical lists with no text input; focusing the nickname field (first run and Profile) requests expanded first; the song picker in compact is a vertical list.

**Skeptic: Confirmed.** The compact-style page says the keyboard is unavailable, that a control needing it "must" request expanded first, and that compact layouts must not include horizontally scrolling elements; the HIG says to let people edit text only in the expanded view. The plan's "Menus work in compact" and "Players set a nickname" need the one-line rule proposed. Nit is right.

**Outcome: Adopted (D-029).**

Sources: <https://developer.apple.com/documentation/messages/msmessagesapppresentationstyle/compact>, <https://developer.apple.com/design/human-interface-guidelines/imessage-apps-and-stickers>

### MSG-15: The wrapper app has no code, so 'App Group shared by the wrapper app and the extension' describes nothing in v1

Severity nit · factual-error · plan sections: 7.2 (RiffApp/), 7.5, P0.2, 12 (paid membership for App Groups and TestFlight)

**The plan says.** "An App Group container is shared by the wrapper app and the extension." "a paid Apple Developer Program membership (for App Groups and TestFlight)".

**Problem.** An iMessage-only wrapper is a stub product with no source files and never launches, so it cannot read or write the container. The App Group adds an entitlement and provisioning step to two targets for no v1 benefit; its only value is forward compatibility with the 'Later' companion app. If the entitlement is misconfigured the container lookup returns nil, and the plan has no fallback. RiffApp can hold only an Info.plist and an asset catalog.

**Evidence.** XcodeGen ProjectSpec lists `application.messages` and `app-extension.messages`; its source says "simple messages applications without sources should not include a compile sources build phase"; its own test fixture pairs an `application.messages` target with an `app-extension.messages` dependency. XcodeGen ships an icon-name preset ("iMessage App Icon") for the extension product type only. IceCreamBuilder sample: all logic lives in the extension target.

**Reviewer's recommendation.** Reword 7.5: "Data lives in an App Group container owned by the extension, chosen so a future companion app can read it; if the group container is unavailable, fall back to the extension's Application Support directory." In 7.2 state that RiffApp contains only Info.plist and Assets.xcassets (icon set), and set the icon build setting for that target explicitly in project.yml. Correct section 12: the paid membership is needed for TestFlight and distribution.

**Skeptic: Confirmed.** XcodeGen's spec lists application.messages and app-extension.messages, its source comment says simple messages applications without sources get no compile phase, and the icon-name preset exists only for the extension product type; I checked the copies in the scratchpad. The wrapper never runs, so 7.5's "shared by the wrapper app and the extension" describes forward compatibility only, and a nil-container fallback is a fair robustness addition. One part I could not verify: that App Groups do not need the paid membership. Apple's capabilities table did not load here and search results were inconclusive, so treat the section 12 correction as probable, not established.

**Outcome: Adopted (D-005).**

Sources: <https://raw.githubusercontent.com/yonaskolb/XcodeGen/master/Docs/ProjectSpec.md>, <https://raw.githubusercontent.com/yonaskolb/XcodeGen/master/Sources/ProjectSpec/XCProjExtensions.swift>, <https://raw.githubusercontent.com/yonaskolb/XcodeGen/master/Tests/Fixtures/TestProject/project.yml>, <https://developer.apple.com/documentation/messages/icecreambuilder-building-an-imessage-extension>

</details>

**Checked and found sound (MSG).**

- MSSession behaviour matches the plan: a later message on the same session removes the previous bubble and appears at the bottom; an update is made with MSMessage(session: selectedMessage.session). MSSession has no properties, so the payload's own match id is needed and is present.
- All state must ride in MSMessage.url: Apple staff confirm a received message has a nil layout, so nothing can be read back from the image or captions. The plan already carries everything in the URL.
- URL limits: http, https or data scheme only, at most 5,000 characters (MSMessage.url doc and MSMessageErrorCode.urlExceedsMaxSize). The plan's 4 KB cap is inside that. Recomputed with realistic data (compact JSON, raw deflate, base64url): a 2-entry duel is about 410-540 URL characters; a 32-entry round is about 2,100-3,700 characters depending on nicknames (ASCII about 2,300; random CJK about 3,600; 16 emoji clusters about 3,700). Both of the plan's size claims hold.
- An https URL is the right scheme for the fallback: Apple documents that selecting the message on macOS loads the URL in a browser. The HIG states iMessage apps are not supported on macOS, tvOS, visionOS or watchOS.
- MSMessageTemplateLayout has exactly the fields the plan needs: image, imageTitle, imageSubtitle, caption, subcaption, trailingCaption, trailingSubcaption. The four caption strings in 5.3 map one to one.
- Insert-then-user-taps-Send is the documented default flow, and insert on an existing session updates the bubble only when the user sends.
- Presentation: the + drawer launches the extension compact (keyboard area), tapping a bubble launches it expanded, requestPresentationStyle(.expanded) is available, and the user can always collapse. This matches 'menus in compact, Play requests expanded, collapse pauses'.
- There is no API for contact names or anything about participants beyond opaque UUIDs, as section 3 says.
- Not using MSMessageLiveLayout in v1 is the right call and should be recorded in DECISIONS.md: it still needs a template fallback, it creates one extra view-controller instance per transcript bubble inside a memory-limited extension, selection and receive callbacks are not delivered in transcript style, and developers report live bubbles stuck on 'Loading...' from iOS 17.1 through a July 2026 report on iOS 26 and 27 with no fix.
- A standalone iMessage app is a supported App Store product type and can be distributed through TestFlight (Apple's iMessage developer page). XcodeGen supports the wrapper/extension target pair (application.messages plus app-extension.messages).
- Review Guideline 4.4 asks extensions to include 'help screens and settings interfaces where possible'; the plan's tutorial, Settings and Profile screens cover this.
- The section 3 claim that iOS 27 shipped a first-party Drawing iMessage app is corroborated by web search results (9to5Mac and others); I saw search summaries, not the article itself.

## Match protocol, payload and progression (MATCH)

| ID | Severity | Finding | Check | Outcome |
| --- | --- | --- | --- | --- |
| MATCH-1 | blocker | Concurrent turns on one session bubble silently drop scores; the plan has no merge rule and no local match ledger | Not re-checked | Adopted: D-011 |
| MATCH-2 | major | Player id taken from the participant UUID: those UUIDs are device-scoped and change when the extension is toggled or reinstalled | Not re-checked | Adopted: D-010 |
| MATCH-3 | major | 'Round completes when every member has submitted' cannot be decided: no roster in the payload, non-players never submit, membership changes | Not re-checked | Owner decision: D-012 |
| MATCH-4 | major | Duel-win and podium XP have no settlement rule: double-award on every open, and the first player can never see the completed round | Not re-checked | Adopted: D-014 |
| MATCH-5 | major | Simultaneous rematch by both duel players creates two different 'round N+1' states with no resolution rule | Not re-checked | Adopted: D-013 |
| MATCH-6 | major | Nickname limit of '16 characters' does not bound the payload: the '32 players inside 4 KB' claim fails and one nickname can make a round undecodable | Not re-checked | Adopted: D-018 |
| MATCH-7 | major | Web-fallback URL carries the whole match payload in the query string, so the web host receives nicknames, ids and scores; this conflicts with 'Data Not Collected' | Not re-checked | Device spike decides: D-017 |
| MATCH-8 | major | 'Restart until you submit' lets the responder grind against a known target, and 'submitted' is never defined (draft in the input field, cancelled or failed sends) | Not re-checked | Owner decision: D-058, D-020 |
| MATCH-9 | major | Progress lives in one App Group container with no recovery path: app deletion, a new phone without restore, or iPhone versus iPad all lose or split it | Not re-checked | Owner decision: D-070 |
| MATCH-10 | minor | Envelope and versioning: version sits inside the compressed, signed blob; signed bytes are undefined; no rule for mixed app versions in one match | Not re-checked | Adopted: D-015 |
| MATCH-11 | minor | The embedded HMAC key is not a secret and stops almost nobody; treat it as an integrity check and do not build secret handling around it | Not re-checked | Adopted: D-016 |
| MATCH-12 | minor | Schema v1 lacks fields the design depends on and carries fields that can only be wrong | Not re-checked | Adopted: D-071 |
| MATCH-13 | minor | JSON plus deflate works but has data-dependent size and little headroom; a fixed binary layout gives a provable bound and no compression dependency | Not re-checked | Adopted: D-015 |
| MATCH-14 | minor | Decode checks are incomplete, unordered, and a chart mismatch cannot tell who must update | Not re-checked | Adopted: D-019 |
| MATCH-15 | minor | XP rules are not yet a single computable formula: floating-point rounding, practice halving, streak percentage and bonus scope are ambiguous | Not re-checked | Adopted: D-072 |
| MATCH-16 | minor | Daily streak and 'first run of the day' are undefined under time-zone travel and clock changes | Not re-checked | Adopted: D-073 |
| MATCH-17 | minor | Featured song by 'ISO week mod song count' is uneven at year boundaries, repeats with 3 or 4 songs, and is not 'the same for everyone' | Not re-checked | Adopted: D-074 |
| MATCH-20 | minor | Build the match and progression rules first as an executable Python reference with shared golden vectors, since Python runs here and Swift does not | Not re-checked | Adopted with changes: D-076 |
| MATCH-18 | nit | Unlock counts, defaults and the sample profile do not agree with each other | Not re-checked | Adopted: D-075 |
| MATCH-19 | nit | Ranking details left open: 'whoever played first', 'top 3 plus your own place', and conversations with no remote participant | Not re-checked | Adopted: D-061, D-022 |

<details>
<summary>Full text of the MATCH findings</summary>

### MATCH-1: Concurrent turns on one session bubble silently drop scores; the plan has no merge rule and no local match ledger

Severity blocker · design-flaw · plan sections: 3 (row 'No live connection between players'), 5.1, 5.2, 5.4, 5.5, P1.8, P4.4, P4.5, Phase 4 done-when, Appendix C

**The plan says.** 'an MSSession makes every turn update one bubble'. Every turn re-sends the whole match state ('e: submitted runs this round') built from the bubble the player tapped. P4.5 names 'an old bubble tapped after newer ones' as an edge case but gives no rule. Phase 4 is done after 'one 3-person group round'.

**Problem.** Each submission is a full-state overwrite computed from the state the player loaded before a 60-90 s run. In a group, B and C both open state {A}, play, and send {A,B} and {A,C}. Messages keeps only the later message of a session, so one score vanishes from the bubble; the next player builds on the survivor and the loss becomes permanent. Arrival order is not guaranteed, so devices can disagree about which state survived. The dropped player's device believes it has submitted ('one submitted score per player per round') while the bubble says it has not; section 5.4 has no screen for that state. The extension only sees messages through selectedMessage or didReceive while it is active, so nothing repairs the fork. The same mechanism breaks 'starter closes while someone is submitting' and a stale selectedMessage while the app is open. Several friends answering a fresh challenge within the same two minutes is the normal usage pattern of a group round, and the Phase 4 gate (one round, played in sequence) would pass with the bug present.

**Evidence.** Apple, didReceive(_:conversation:): 'There is an inherent race condition when multiple participants send messages using the same session object. You cannot guarantee the order in which the messages are received. To ensure that your app always has the latest data, save your data to a server (for example, using CloudKit) and have your messages just carry an ID for that data.' Same page: the method is for 'messages that arrive while your extension is active'. MSSession: 'If a later message is sent using the same session, the previous message is removed from the transcript.' selectedMessage: 'the selected message might not contain the most current data. The selected message is not updated when you receive new messages.' Apple's forum answer to exactly this group scenario (thread 54536) is the WWDC16-224 advice to store state in the cloud.

**Reviewer's recommendation.** Keep 'no server', but make MatchState a state-based CRDT in RiffCore and specify merge(a,b) in section 5: same match id required; higher round r wins; same r and same round descriptor: entries = union keyed by player id, duplicate player keeps the entry with the smaller t (then byte order), closed = a.closed OR b.closed, and a closed state freezes its entry set. Add a per-device ledger file (matches.json: per match id the merged state of everything this device has decoded, plus own submission status and settled awards). Rules: (1) on every activation and every didReceive, state = merge(ledger, decoded bubble) and the UI renders the merged state, never the raw bubble; (2) the outgoing payload is composed at send time from the merged state, not from the bubble tapped before the run; (3) if the merged state holds entries the current bubble lacks (above all the local player's), show 'Your score isn't on the board yet - Re-post' which re-inserts the merged state; (4) add that row to the 5.4 table. In P1.8/P1.9 add property tests (merge is commutative, associative, idempotent) and an N-device conversation simulator that reorders, drops and duplicates messages and asserts that all devices converge with no entry lost. Extend the Phase 4 gate with a forced race.

**Device test.** Three devices in one group chat. A starts a round. B and C both open the bubble, both finish a run, and both tap Send within a few seconds (repeat with C in airplane mode during B's send, then reconnect). On each of the three devices record: which bubble remains, whether the other was replaced by its summary text, the URL of selectedMessage after tapping the survivor, and whether didReceive fired for the other player's message while the extension was open. Repeat with 'starter closes' racing 'member submits'.

**Outcome: Adopted (D-011).**

Sources: <https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/didreceive(_:conversation:)>, <https://developer.apple.com/documentation/messages/mssession>, <https://developer.apple.com/documentation/messages/msconversation/selectedmessage>, <https://developer.apple.com/forums/thread/54536>

### MATCH-2: Player id taken from the participant UUID: those UUIDs are device-scoped and change when the extension is toggled or reinstalled

Severity major · factual-error · plan sections: 3 (rows 'No access to contact names', 'Participant IDs are opaque UUIDs'), 5.5, 6.4 ('Series records per friend, keyed by conversation participant'), Appendix C (by, sr, Entry.p), S2, 13 (participant-ID risk row)

**The plan says.** Entry.p is 'first 8 hex characters of the participant UUID'; 'by' is the 'starter's player id (can close a round)'; 'sr' is 'series wins by player id'; scoping is to be 'verified in the Phase 4 spike'.

**Problem.** Apple's documentation already answers the scoping question, and the answer breaks several uses. A participant's UUID on device X is unrelated to the UUID the same person has on any other device, so a payload id can never be matched against remoteParticipantIdentifiers or senderParticipantIdentifier on a receiving device; it only works as a self-chosen token that the same device recognises again. Consequences: (1) the same person on iPhone and iPad (iPad is in v1 scope and in the test matrix) has two ids: the iPad shows 'Your turn' for the player's own challenge, the player can complete a duel against themselves, submit twice in a group round, and the starter cannot close the round from the other device; (2) the id changes when the extension is disabled and re-enabled in Messages or the app is reinstalled, so a mid-series player becomes a stranger, 'sr' gains a third key in a duel and the '3-2' tally is orphaned; (3) 'series records keyed by conversation participant' invites keying by an id that cannot be related to the payload ids; (4) if the local UUID is the same in every conversation (undocumented), its prefix is a stable device identifier published into every chat and, with the query-string fallback URL, to the web host. Also a plan inconsistency: the spike that checks ids is Phase S (S2), not Phase 4.

**Evidence.** localParticipantIdentifier: 'This UUID is scoped to this device. It remains stable as long as the extension is enabled. If the extension is disabled and reenabled, or if the containing app is removed and reinstalled, the UUID for the local participant changes.' remoteParticipantIdentifiers: 'These UUIDs are scoped to this device.' senderParticipantIdentifier: 'Each device participating in the conversation will have a different UUID for the message's sender.' 32-bit truncation itself is fine: collision chance among 32 players is 1.2e-7 (computed).

**Reviewer's recommendation.** Stop deriving the payload id from Messages. Generate a random 6-byte playerId once, store it in profile.json (and in iCloud key-value storage if sync is adopted, see MATCH-9) and use it for Entry.p, by and sr. Use MSConversation UUIDs only for device-local purposes: the caption name placeholder, the roster count, a local head-to-head key for 1:1 chats, and a 'this message was sent by me' guard (selectedMessage.senderParticipantIdentifier == conversation.localParticipantIdentifier). When that guard is true but the newest entry's id is not the local playerId, alias that id to the local player for this match instead of offering 'Your turn'. A completed duel whose two entries are both foreign shows a spectator result. Rewrite the constraint row in section 3 to state the documented scoping, and move the id checks into S2 with the tests below.

**Device test.** In the S2 diagnostics log, on two iPhones and an iPad signed into one of the two Apple IDs: (a) localParticipantIdentifier in two different conversations on the same device; (b) for a message sent by this device, and for a message sent by the same Apple ID's other device, whether senderParticipantIdentifier equals localParticipantIdentifier; (c) all identifiers before and after switching the app off and on in the Messages app list, and after delete and reinstall; (d) whether remoteParticipantIdentifiers for the same contact match between a 1:1 chat and a group.

**Outcome: Adopted (D-010).**

Sources: <https://developer.apple.com/documentation/messages/msconversation/localparticipantidentifier>, <https://developer.apple.com/documentation/messages/msconversation/remoteparticipantidentifiers>, <https://developer.apple.com/documentation/messages/msmessage/senderparticipantidentifier>

### MATCH-3: 'Round completes when every member has submitted' cannot be decided: no roster in the payload, non-players never submit, membership changes

Severity major · gap · plan sections: 5.1, 5.2, 5.3 ('2 of 5 played'), 6.1 (podium XP), P4.4, Appendix C (by, closed)

**The plan says.** 'A group round completes when every member has submitted or the starter closes it.' 'The starter can close the round early, which locks standings and awards podium XP.' The payload has no member count, roster or deadline.

**Problem.** Completion is computed by each device from its own participant count, which is not shared state. (1) Any member without the app, or who simply does not play, means 'every member has submitted' never happens; in a real group chat that is nearly every round, so podium XP depends entirely on the starter coming back to send a close message. (2) A starter who goes quiet, leaves the group, reinstalls or uses another device (MATCH-2) leaves the round open forever. (3) Members joining or leaving change the count per device, so devices disagree on whether the round is complete, and a late joiner can submit after others already treated the round as complete and took podium XP. (4) 'Who may close' is enforced only by the local UI: every copy of the app holds the same HMAC key and a receiver cannot map 'by' to a sender, so the rule is an honour system and the plan should say so.

**Evidence.** remoteParticipantIdentifiers is documented only as 'An array of UUIDs representing the remote participants in this conversation'; there is no API that tells which participants have the app. Appendix C contains no roster or deadline field. The HMAC key is 'compiled into the app' (5.5), so it authenticates the app, not a player.

**Reviewer's recommendation.** Make finality an explicit, monotonic fact in the payload. Add n (member count snapshot taken by the starter, used for the 'k of n played' caption only) and dl (deadline, round start + 24 h [DECIDE]). A group round is final when closed is set or the local clock is past dl; the device that submits the n-th entry sets closed in the same message so no extra close message is needed. Entries with t after dl, or absent from a closed state, are rejected by merge. Podium XP and the Results screen key off 'final', never off a locally computed member count. Keep 'starter can close early' as a UI affordance and document that it is not cryptographically enforced. Add rows to 5.4 for 'round final, you never played' and 'deadline passed'.

**Device test.** In a 3-person group where one member does not have the app, log remoteParticipantIdentifiers.count on the two devices that do; then add a fourth member and log it again on every device.

**Outcome: Owner decision (D-012).**

Sources: <https://developer.apple.com/documentation/messages/msconversation/remoteparticipantidentifiers>

### MATCH-4: Duel-win and podium XP have no settlement rule: double-award on every open, and the first player can never see the completed round

Severity major · gap · plan sections: 6.1 ('Duel and podium XP land when the round completes, on whichever device opens the final bubble'), 6.1 order of operations, 5.1 (Rematch), 7.5, P6.2, Appendix C, Appendix D

**The plan says.** 'Duel and podium XP land when the round completes, on whichever device opens the final bubble.' P6.2: 'XP awards on the results screen'. The payload carries only 'submitted runs this round' plus the series tally.

**Problem.** (1) Nothing records that a round's bonus has been paid, so every re-open of a final bubble can pay +75 again; records.json has no such structure and Appendix D has no schema for it. (2) The completed-round bubble may never be visible to the first player: B completes round r, taps Rematch, and sends round r+1; the session replaces the round-r bubble, the new payload contains only round r+1's entries, so A's device never sees round r's final state and cannot pay A's +75 or show A the result. (3) The 'order of operations' cannot apply to an award that lands on a later day: which streak bonus and featured multiplier apply to a deferred +75 is undefined. (4) The second player knows the result before sending; if the win bonus is paid on the results screen, it is paid even when the message is never sent or the draft is deleted. (5) In groups, standings can still change after a device has paid podium XP unless payment waits for a final round (MATCH-3).

**Evidence.** MSSession: 'If a later message is sent using the same session, the previous message is removed from the transcript.' didStartSending: 'It does not guarantee that the message will be successfully sent or delivered.' Appendix C comment on e: 'submitted runs this round'.

**Reviewer's recommendation.** Specify settlement in section 6.1 and implement it in RiffCore: the ledger from MATCH-1 stores settled[(matchId, round)]; a device pays the local player's duel or podium bonus exactly once, the first time it observes a final state for that round containing the local player's entry. Add a previous-round summary to the duel payload (pr: round number, both scores, winner id, about 30 bytes) so the first player's device can show and settle round r from the round r+1 bubble. Deferred bonuses are flat XP with no streak or featured multiplier (state this next to the order of operations). The submitting player's own bonus is paid in didStartSending, not on the results screen. Add tests: open the same final bubble 3 times gives one award; rematch-before-open still settles round r.

**Outcome: Adopted (D-014).**

Sources: <https://developer.apple.com/documentation/messages/mssession>, <https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/didstartsending(_:conversation:)>

### MATCH-5: Simultaneous rematch by both duel players creates two different 'round N+1' states with no resolution rule

Severity major · gap · plan sections: 5.1, 5.2 ('Rematch can come from either player'), P4.3, Appendix C (r, by, sr)

**The plan says.** 'Either player taps Rematch (same song or a new one) to start the next round in the same bubble.' 'It starts a new round number, and the series score carries over.'

**Problem.** After a close round both players see Results with a Rematch button. If both tap it, each plays (possibly a different song or difficulty) and sends a state with the same r, a different 'by', and one entry. One message replaces the other. Each device's local state says 'I have submitted round N+1' while the surviving bubble shows only the opponent's entry on a possibly different chart; with the 5.4 table as written both can land on Waiting, or one is asked to play a round it believes it already played. The plan defines no tie-break between competing rounds and no fate for the losing run.

**Evidence.** Reasoning from 5.1/5.2 and the session replacement semantics (MSSession doc). Same race class Apple warns about on the didReceive page.

**Reviewer's recommendation.** Add to MatchRules.merge: two states with the same match id and r but different round descriptors (song, difficulty, chart hash, starter) are a conflict; the winner is the one whose first entry has the smaller t, then the smaller starter id. If both proposals are the same song, difficulty and chart, there is no conflict: union the two entries and the round is complete at once. The device whose proposal lost keeps the run as a personal best (run XP already paid, no duel bonus) and shows 'Sam's rematch on &lt;song> got there first - play it'. Both proposals carry the same sr because sr is defined as the tally through round r-1 (state that definition in Appendix C). Add the case to the simulator tests and to P4.3.

**Outcome: Adopted (D-013).**

### MATCH-6: Nickname limit of '16 characters' does not bound the payload: the '32 players inside 4 KB' claim fails and one nickname can make a round undecodable

Severity major · factual-error · plan sections: 5.5, Appendix C (Entry.n 'nickname, max 16 characters'; 'a full 32-player round stays inside the 4 KB cap'), P1.9, 11 (Payload row), 13 (payload size risk)

**The plan says.** 'nickname, max 16 characters'; 'A duel encodes to under 1 KB, and a full 32-player round stays inside the 4 KB cap'; decoding rejects 'anything over 4 KB'.

**Problem.** In Swift, a 16-'character' limit counts grapheme clusters, and one cluster can be arbitrarily many bytes (emoji joined sequences are 25-41 bytes; a letter with stacked combining marks is unbounded). The size claim holds for plain text but not for the limit as written, and because the payload is rejected above the cap, a single player with a decorated nickname makes the bubble unreadable for everyone ('Couldn't read this challenge'). The cap itself is ambiguous: 4 KB of what? The uncompressed JSON of a legitimate 32-entry round is already 3.7-5.6 KB, so a cap applied after inflating would reject valid rounds. The nickname is also untrusted text rendered into other people's score cards with no stated filtering (newlines, control and bidirectional-override characters).

**Evidence.** Recomputed with python3 zlib (raw deflate level 5, the format Apple's COMPRESSION_ZLIB produces), plan schema, random ids, 32 entries plus a 32-key sr, worst of 50 samples, base64url length: realistic names 1,791; 16 random ASCII 2,298; 16 emoji 3,134; 16 CJK 3,602; 16 joined-family emoji graphemes 6,011 (over the plan's cap and over Apple's 5,000-character URL limit). Duel: 371-531 (740 with the joined-emoji case). One grapheme with 200 combining marks is 401 bytes. Apple, MSMessage.url: 'the URL cannot be longer than 5,000 characters.'

**Reviewer's recommendation.** Define the nickname limit as: NFC-normalised, at most 16 grapheme clusters AND at most 32 UTF-8 bytes (48 if 16 CJK characters must fit), no control, newline or bidirectional-override scalars; enforce it at input and again at decode (truncate or reject the entry, not the whole payload). Define the cap as 'whole URL at most 4,096 characters' and add a separate decoded-size cap (16 KB). Make the P1.9 size test adversarial: 32 entries, every nickname at the byte cap with incompressible content, every numeric field at its maximum, random ids. Make the encoder refuse to produce an over-cap payload so the sender gets the error, not the group.

**Outcome: Adopted (D-018).**

Sources: <https://developer.apple.com/documentation/messages/msmessage/url>, <https://developer.apple.com/documentation/compression/compression_zlib>

### MATCH-7: Web-fallback URL carries the whole match payload in the query string, so the web host receives nicknames, ids and scores; this conflicts with 'Data Not Collected'

Severity major · risk · plan sections: 3 (row 'Recipients may not have the app yet'), 5.5, 7.5 ('No network, analytics or accounts in v1'), P8.2, 14 (Fallback web domain), Appendix C ('https://&lt;domain>/m?p=&lt;payload>')

**The plan says.** 'one query item of an https URL on a domain we control. That URL doubles as the web fallback'; P8.2: 'a "Data Not Collected" privacy label'.

**Problem.** When a participant selects the bubble on a Mac, Messages loads the URL in a browser; older systems and SMS recipients receive the URL as visible text. Every such open sends the full payload (every player's nickname, player id, score, level and play timestamps) to the fallback host together with the opener's IP address, and static hosts keep request logs including query strings. A nickname is a 'screen name' (Apple's User ID data type) and the rest is Gameplay Content; data retained by you or your host beyond serving the request is 'collected' under Apple's definition, so the planned label would be inaccurate, and the players whose data is sent are not the person who clicked. The long URL also shows as raw text on those clients (about 400 characters for a duel, up to about 3,600 for a large round).

**Evidence.** Apple, MSMessage.url: 'If the message is selected on macOS, the system loads the URL in a web browser.' MSMessageLiveLayout doc: template layouts serve 'devices that do not support iMessage apps (macOS, iOS 9 and earlier, and SMS devices)'. Apple privacy details: 'Collect refers to transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time'; User ID: 'Such as screen name, handle, account ID'; 'Data collected via web traffic must be declared'. Forum thread 62331: a developer sees 'an ugly http URL alongside the iMessage image' on Macs and older iOS; Apple's documentation engineer answers 'Use a "data:..." URI instead of an HTTP one.'

**Reviewer's recommendation.** Never put the payload where a server can see it. Preferred: https://&lt;domain>/m#&lt;payload> (a fragment is not sent in the HTTP request) with a static page that says what the game is and links to the App Store; the page needs no payload at all. Alternative if fragments do not survive transport: a data: URL (permitted by the MSMessage.url documentation), which removes the domain decision and the web host entirely. Whichever is chosen, record in DECISIONS.md that the fallback host must not log or receive match data, and keep the label claim only on that basis.

**Device test.** In S2 send three session messages whose URLs are (a) https with ?p=, (b) https with #fragment, (c) data:. On the receiving iPhone log selectedMessage.url verbatim and confirm the fragment or data body is intact; click each bubble in Messages on a Mac and note what opens and what the server access log shows; note what an iPhone without the app shows on tap.

**Outcome: Device spike decides (D-017).**

Sources: <https://developer.apple.com/documentation/messages/msmessage/url>, <https://developer.apple.com/documentation/messages/msmessagelivelayout>, <https://developer.apple.com/app-store/app-privacy-details/>, <https://developer.apple.com/forums/thread/62331>

### MATCH-8: 'Restart until you submit' lets the responder grind against a known target, and 'submitted' is never defined (draft in the input field, cancelled or failed sends)

Severity major · design-flaw · plan sections: 4.7 ('Restarting is allowed until you submit; only the submitted run counts'), 5.2 ('One submitted score per player per round; restarts before submitting are fine'), 5.3 ('player taps Send. Nothing sends automatically'), 5.4, 6 ('a duel is always decided by the run itself')

**The plan says.** 'Restarting is allowed until you submit; only the submitted run counts for the round.'

**Problem.** The challenger plays blind; the responder sees the score to beat and may replay until it is beaten, then send. The finished run reaches the bubble only when the player taps Send in Messages, so a responder can also finish, look at the result, delete the draft and play again. The duel is then decided by patience, not by 'the run itself', and the tie-break 'whoever played first' does not offset it. Separately, 'submitted' has at least four distinct moments (run finished, message inserted, Send tapped, delivered) and the 5.4 table ('Open round, you've submitted') does not say which one counts. selectedMessage can be the player's own pending draft, a draft can be cancelled, and a send can fail, so the screen state can be wrong in each case.

**Evidence.** isPending: true 'when your app calls the insert(_:completionHandler:) method', used 'to determine whether the conversation's selectedMessage property refers to a message in the transcript (false) or to a message in the Messages app's input field (true)'. didCancelSending is called when 'the user subsequently deletes the message object'. didStartSending 'does not guarantee that the message will be successfully sent or delivered'. send(_:completionHandler:) exists and is allowed 'only in response to a user action'.

**Reviewer's recommendation.** Raise a [DECIDE] before Phase 1 because it changes the payload and the ledger: (a) one counted attempt per round for the responder (the attempt is committed in the ledger when the song starts; restart is offered only in Practice and for the challenger's opening run), or (b) keep unlimited restarts but add an attempt count to Entry and print it on the card ('3rd try'). In both cases define the submission states in RiffCore (played, staged, sent, confirmed-in-bubble), drive them from insert, didStartSending, didCancelSending and 'own entry seen in a non-pending message', ignore pending messages when routing, and map each state to a 5.4 row. Consider sending with conversation.send from the 'Submit score' tap so that staging and sending are one user action.

**Outcome: Owner decision (D-058, D-020).**

Sources: <https://developer.apple.com/documentation/messages/msmessage/ispending>, <https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/didcancelsending(_:conversation:)>, <https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/didstartsending(_:conversation:)>, <https://developer.apple.com/documentation/messages/msconversation/send(_:completionhandler:)-9krz>

### MATCH-9: Progress lives in one App Group container with no recovery path: app deletion, a new phone without restore, or iPhone versus iPad all lose or split it

Severity major · risk · plan sections: 1 (assumption 'progression is stored on the device'), 6.2 ('level 50 ... a long-term goal'), 6.4, 7.5, P6.1, 13 (no matching risk row), Appendix D

**The plan says.** 'Three Codable JSON files' in an App Group container; 'No network, analytics or accounts in v1'; level 50 is 'a long-term goal'.

**Problem.** Level 50 is roughly 525-685 runs (87-130 days at five runs a day, computed), yet all of it sits in one local file. Deleting the iMessage app removes it; a new phone set up without a backup restore starts at level 1; iPhone and iPad (both in v1 scope) hold separate XP, levels, unlocks and streaks, so the same person shows different levels on their cards depending on the device. The risk table has no row for this. The profile is modelled as mutable totals ('xp', 'level', 'streak'), which cannot be merged later without loss, so adding sync after launch would need a lossy migration. Read-modify-write on the three files is also unprotected if two instances of the extension run at once; atomic writes prevent corruption, not lost updates.

**Evidence.** Level totals recomputed: 142,100 XP at 207-272 XP per run. Apple forum thread 821222 (March-April 2026): a developer reports App Group containers recreated empty during ordinary app updates, mostly on iOS 26; Apple DTS replies that containers are 'expected' to persist, that no known issue matches, and recommends canary files to detect loss. NSUbiquitousKeyValueStore: 'store ... app-specific data in a person's iCloud account and share it among instances of your app running on all of the person's devices', 1 MB and 1,024 keys, requires the iCloud key-value store entitlement.

**Reviewer's recommendation.** Add a [DECIDE] in section 14: sync the profile through iCloud key-value storage (no server of ours, the data stays in the player's iCloud, and it also carries the playerId from MATCH-2 across devices and reinstalls), or ship device-only and say so on the Profile screen. In either case make the stored model merge-safe now: XP as a per-install counter map (total = sum), unlocks as a grow-only set, bests and lifetime stats merged by max, level always derived from XP and never stored, streak merged by latest lastPlayed. Keep a last-known-good backup of profile.json and a canary file, and serialise all store access through one actor that re-reads before writing. Add the risk to section 13.

**Device test.** If sync is chosen: add the iCloud key-value entitlement to the extension target, write a value from the Messages extension on the iPhone, and confirm it appears in the extension on the iPad and after deleting and reinstalling the app.

**Outcome: Owner decision (D-070).**

Sources: <https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestore>, <https://developer.apple.com/forums/thread/821222>

### MATCH-10: Envelope and versioning: version sits inside the compressed, signed blob; signed bytes are undefined; no rule for mixed app versions in one match

Severity minor · design-flaw · plan sections: 5.4 (rows 'newer app version' and 'fails its signature'), 5.5, 12.2 ('Any payload change bumps the schema version'), Appendix C (v, sig)

**The plan says.** 'v' and 'sig' are fields of the same Codable struct that is deflated and base64url-encoded; 'Decoding rejects unknown versions, bad signatures ...'.

**Problem.** (1) A 1.0 client can only read 'v' after inflating and parsing with the 1.0 format. If a later version changes compression, encoding or the key, 1.0 clients see garbage or a bad signature and show 'Couldn't read this challenge - Start new' instead of 'Update needed'. This cannot be fixed after 1.0 ships. (2) 'sig' is inside the object it signs and the signed byte string is not defined. A verifier that re-encodes the struct is fragile: Swift dictionary order (sr) is not stable and JSONEncoder does not sort keys unless told to, and tools/payload.py must reproduce the bytes exactly. (3) No rule says which schema version a newer app writes when it answers an older match; if it writes the new one, the 1.0 player is locked out of a match they started.

**Evidence.** Appendix C struct. Swift's Dictionary iteration order is not guaranteed and JSONEncoder needs the sortedKeys option for deterministic output (language and Foundation behaviour).

**Reviewer's recommendation.** Fix the envelope before any code: URL carries v as its own plain item (for example ...#v=1&p=&lt;body>&s=&lt;mac>); the decoder checks v first, then verifies the MAC over the exact received body bytes prefixed with a context string ('riff-match' + v), then inflates and parses. sig leaves the struct. Add the rule 'a client writes in the match's version v; new fields only appear in matches started at the new version' and a decode test per old version (already in 12.2). Publish golden vectors (hex body, MAC, decoded JSON) in the repo that both the Swift tests and payload.py must reproduce.

**Outcome: Adopted (D-015).**

### MATCH-11: The embedded HMAC key is not a secret and stops almost nobody; treat it as an integrity check and do not build secret handling around it

Severity minor · design-flaw · plan sections: 5.5, 6.4 ('Scores sent to friends are signed and sanity-checked'), 7.1 (Signing: CryptoKit HMAC), 13 (forged scores row), Appendix C (sig)

**The plan says.** 'HMAC-SHA256 with a key compiled into the app, truncated to 16 bytes. It stops casual URL edits, not a determined cheater'.

**Problem.** The truncation is fine (128-bit tag). The threat model is off: on iOS a player has no way to hand-edit a message URL and put it back into a bubble; only code running as this extension can create its messages, and anyone able to run modified code has the key. So the MAC protects against corruption and little else, yet it adds a canonicalisation problem (MATCH-10) and a 'secret' that has to live somewhere: committed to the repository it is public, injected at build time it complicates Phase 0, CI and the Python tools. It also gives no per-player authenticity, so it does not stop one player rewriting another's entry, replaying an older state, or closing a round. Section 6.4's 'signed' overstates what players get.

**Evidence.** didReceive doc: 'You receive notifications about messages sent using your extension only. You cannot interact with messages from other extensions.' RFC 2104 section 5 accepts truncation to at least half the hash length (128 bits for SHA-256). Per-player signatures were sized: Curve25519 needs 32-byte key plus 64-byte signature per entry, about 3 KB for 32 players, which does not fit.

**Reviewer's recommendation.** Keep a keyed checksum but simplify: a fixed, documented, non-secret key constant in GameConfig (per schema version), tag truncated to 8 bytes, described in the plan as tamper-evidence and corruption detection only. No build-time secret plumbing. State in 5.5 that rollback and replay protection among honest clients comes from the monotonic merge and ledger (MATCH-1), not from the MAC, and reword 6.4. Revisit real authentication only with the server planned for global leaderboards.

**Outcome: Adopted (D-016).**

Sources: <https://developer.apple.com/documentation/messages/msmessagesappviewcontroller/didreceive(_:conversation:)>

### MATCH-12: Schema v1 lacks fields the design depends on and carries fields that can only be wrong

Severity minor · gap · plan sections: 5.3, 5.5, 6.3 ('Titles ... In the bubble, next to the nickname'; 'Score-card frames ... In the bubble'), Appendix C

**The plan says.** Entry = p, n, s, a, c, st, fc, lv, t. Titles and frames are 'bubble-visible unlocks' that 'matter most'.

**Problem.** Missing: (1) the equipped title and frame ids; the device rendering a two-player result card or a leaderboard cannot draw other players' titles or frames, and in-app standings cannot show them either; (2) member count and deadline (MATCH-3); (3) previous-round result for duels (MATCH-4); (4) attempt count if that option is chosen (MATCH-8); (5) a content revision, so a chart-hash mismatch can say who is out of date (MATCH-14). Redundant: st and fc are functions of s and c plus the chart (Full Combo is exactly longest streak == note count; stars follow from score over base score), so they can only disagree with the truth; sr is undefined for group rounds yet would add up to 32 keys there; 'by' does not say whether it is the match starter or the current round's starter.

**Evidence.** Appendix C versus 6.3 and 4.4 ('streak s (consecutive notes without a miss, every chord note counted)'). Adding title, frame, attempts, 12-hex ids, n and dl to the plan's JSON takes a 32-entry round with 16-CJK nicknames from 3,602 to 3,959 base64url characters (computed), 137 under a 4,096 cap.

**Reviewer's recommendation.** Freeze schema v1 as: v, id, mode, r, round descriptor (song, part, diff, ch, content revision, by = starter of this round, t0, n, dl), e[] with p, n, s, a, c, lv, t, ti (title id), fr (frame id) and optionally k (attempts); sr and pr only in duel mode; closed. Drop st and fc and derive them at decode. Unknown cosmetic ids render as the default. Recompute the size table with the final schema before coding.

**Outcome: Adopted (D-071).**

### MATCH-13: JSON plus deflate works but has data-dependent size and little headroom; a fixed binary layout gives a provable bound and no compression dependency

Severity minor · opportunity · plan sections: 5.5, 7.1, 7.2 (Match/PayloadCodec, Signer; tools/payload.py), 12.2 ('RiffCore never imports UIKit, SpriteKit or AVFoundation'), Appendix C

**The plan says.** 'Compact JSON, deflate-compressed and base64url-encoded'.

**Problem.** The size of a deflated payload depends on how compressible user text is, so 'fits in 4 KB' is a statistical statement; with the fields the design still needs (MATCH-12) the worst realistic case is within 4% of the cap. For duels deflate is unnecessary (raw JSON is 574-731 base64url characters). The codec also needs the Compression framework and CryptoKit, which exist only on Apple platforms, so the Match module cannot be built or tested on a Linux runner or in the Linux sandbox where the Python tools run; and 'deflate' must be pinned to raw RFC 1951, otherwise Swift, Python and any web page will disagree.

**Evidence.** Computed: a hand-laid binary layout (1-byte version, 8-byte match id, packed enums, varint numbers, 6-byte ids, length-prefixed nickname, title, frame, attempts, n, dl) is 149 bytes (199 characters) for a duel and, for 32 entries, 1,839 characters with 16-byte nicknames, 2,522 with a 32-byte nickname cap and 3,204 with a 48-byte cap, all exact upper bounds without compression. The plan's JSON plus deflate measures 2,298 (ASCII) to 3,602 (CJK) before the added fields and 2,658 to 3,959 after. Apple: COMPRESSION_ZLIB 'is the raw DEFLATE format as described in IETF RFC 1951' at level 5.

**Reviewer's recommendation.** Decide in DECISIONS.md before P1.8. Recommended: versioned binary layout, no compression, nickname capped in bytes, with the worst case asserted as a compile-time-checkable formula in tests and a JSON debug view in payload.py. If JSON is kept: state raw deflate (Python zlib with wbits -15), cap output while inflating, skip deflate when it does not shrink, and keep the adversarial size test from MATCH-6.

**Outcome: Adopted (D-015).**

Sources: <https://developer.apple.com/documentation/compression/compression_zlib>

### MATCH-14: Decode checks are incomplete, unordered, and a chart mismatch cannot tell who must update

Severity minor · gap · plan sections: 5.2 ('a mismatch (different app versions) asks the player to update'), 5.4, 5.5 ('Decoding rejects ...'), Appendix A ('maxScore is the every-note-at-x8 ceiling'), P1.9

**The plan says.** 'Decoding rejects unknown versions, bad signatures, scores above the chart's theoretical maximum, more than 32 entries and anything over 4 KB.'

**Problem.** (1) Order matters and is unstated: if the score bound is checked against the local chart before the chart hash is compared, a newer chart with a higher maximum produces 'Couldn't read this challenge' instead of 'Update needed'. (2) With only an 8-hex hash the device cannot tell whether it or the sender is out of date, so it may tell the up-to-date player to update. (3) Missing checks: duplicate player ids in e; a in 0..10,000; c &lt;= note count; lv in 1..50; t not far in the future; r >= 1; duel has at most 2 entries; sum of sr &lt;= r-1; nickname rules (MATCH-6); unknown song id (receiver is behind). (4) The x8 ceiling is loose: Hype can cover at most 48 beats (6 phrases x 25% x 32 beats), so in the Appendix A example the ceiling of 337,600 sits far above anything reachable from a 162,800 base; forged scores up to twice the base pass.

**Evidence.** Appendix A numbers recomputed: 412 notes x 100 x 8 = 329,600 plus 40 hold beats x 25 x 8 = 8,000 gives 337,600; base 158,800 + 4,000 = 162,800. A 3,898-character payload can inflate to 3 MB (computed), so the size check must precede inflation.

**Reviewer's recommendation.** Specify the decode pipeline in 5.5 as an ordered list with one result per failure: URL length, version (Update needed), MAC, inflate with output cap, structural bounds, song known (else Update needed), content revision and chart hash (ahead: 'Ask &lt;name> to update'; behind: 'Update needed'), then per-entry bounds against the chart. An entry failing a per-entry check is dropped, not the whole match. Have chartcheck write a tighter bound (base score plus the best 48 Hype beats) as maxScore. Give each rule a tamper test in P1.9.

**Outcome: Adopted (D-019).**

### MATCH-15: XP rules are not yet a single computable formula: floating-point rounding, practice halving, streak percentage and bonus scope are ambiguous

Severity minor · ambiguity · plan sections: 6.1 (table and 'Order of operations'), 6.4, Appendix D (streak.days), P1.7, Phase 6 done-when

**The plan says.** 'add the events, apply the streak bonus, apply the featured multiplier, round down. Practice runs earn half XP.' 'Daily streak +10% per consecutive day, max +50%'.

**Problem.** (1) Implemented with Double, 'round down' gives wrong results for reachable inputs, and Swift, Python tests and the plan's tables will disagree. (2) Where the practice halving sits relative to the multipliers and the floor is unstated. (3) Day 1 of a streak could mean +0% or +10% (does days = 4 mean +30% or +40%?). (4) Unstated whether the streak and featured multipliers scale the +100 first-run bonus, whether a practice run can earn the first-run bonus and extend the streak, and what happens to XP beyond level 50. (5) Any finished run pays the full 'Finish a song' 100, including a run started from a duel bubble and never sent, which bypasses the practice halving, and a run with the phone lying on the table.

**Evidence.** python3: floor(180 x 1.4) evaluates to 251, exact value 252 (a 4-star run at +40% streak); 28 of the reachable (event sum, streak, featured, practice) combinations differ between float and exact arithmetic. Typical-run check: 3-4 stars pays 160-180 on a loss and 235-255 on a win.

**Reviewer's recommendation.** Write the formula in 6.1 in integers: xp = floor(E x (100 + S) x F x P / 20000) with E the event sum, S = 10 x min(5, streakDays - 1) (so day 1 is +0%, [DECIDE]), F = 150 or 100, P = 50 for practice else 100. State: the first-run bonus is inside E; practice counts for the daily streak but earns the halved total; deferred duel and podium bonuses are flat (MATCH-4); XP keeps accumulating past level 50 with the level capped. A run earns 'Finish a song' only with at least 1 star (20% of base), and a run opened from a bubble but not sent is credited as practice. Put 10 worked examples in the plan and use them as golden tests shared by Swift and Python.

**Outcome: Adopted (D-072).**

### MATCH-16: Daily streak and 'first run of the day' are undefined under time-zone travel and clock changes

Severity minor · gap · plan sections: 6.1 ('First run of the day +100'; 'Daily streak'), 6.4 ('consecutive local calendar days; a missed day resets it'), Appendix D (streak.lastPlayed '2026-11-12')

**The plan says.** 'at least one finished run on consecutive local calendar days; a missed day resets it.' lastPlayed is stored as a bare local date.

**Problem.** A bare local date loses the information needed to be fair or consistent. Eastward travel across many zones can skip a local calendar day although less than 30 hours passed, resetting a streak. A clock set backwards makes 'today' earlier than lastPlayed, a case with no rule. Setting the clock forward one day at a time farms +100 and builds a +50% streak in minutes; the plan accepts self-only cheating, but the level and titles are shown to friends on every card. Which instant decides the day (run start or run end, relevant at midnight) is also unstated.

**Evidence.** Reasoning; Appendix D stores only {days, lastPlayed}. Example: a run at 23:00 Monday in Los Angeles is 07:00 Tuesday UTC; landing in Tokyo 25 hours later is already Wednesday local time, so local Tuesday never had a run.

**Reviewer's recommendation.** Store lastRunAt (UTC seconds), lastLocalDay (year-month-day in the Gregorian calendar at run end) and a high-water mark of the latest local day ever credited. Rules: day difference 0 is the same day; 1 extends the streak; 2 or more resets unless less than 48 h of real time elapsed (travel grace); a local day at or before the high-water mark never grants the first-run bonus or a streak step again. Evaluate at run end. Put these cases in the P1.7 tests with an injected clock and calendar.

**Outcome: Adopted (D-073).**

### MATCH-17: Featured song by 'ISO week mod song count' is uneven at year boundaries, repeats with 3 or 4 songs, and is not 'the same for everyone'

Severity minor · design-flaw · plan sections: 6.4 ('rotates every Monday by ISO week number (week mod song count). It's the same for everyone without a server'), 13 ('launch can go with 3 songs if needed'), P1.7

**The plan says.** 'rotates every Monday by ISO week number (week mod song count). It's the same for everyone without a server'.

**Problem.** ISO week numbers restart at 1 after week 52 or 53, so the cycle breaks every January. With the fallback of 3 songs the same song is featured in week 52 and week 1 of every 52-week year; with 4 songs it repeats across the 2026/27 boundary. With 5 songs two songs are skipped and three repeat. The index is into an unspecified ordering of songs, the count changes when an update adds a song (the featured song jumps mid-week and differs between players on different versions), 'Monday' is local time so players in different zones disagree for up to a day, and an implementation using the user's current calendar would use locale week rules (weeks starting on Sunday, different week 1) and non-Gregorian calendars.

**Evidence.** python3: ISO 2026 has 53 weeks (2032 is the next). Indices for the last three and first three weeks: 3 songs, 2027 into 2028: 2,0,1,1,2,0; 4 songs, 2026 into 2027: 3,0,1,1,2,3; 5 songs, 2026 into 2027: 1,2,3,1,2,3. 1 January 2027 is ISO 2026-W53 day 5.

**Reviewer's recommendation.** Define: weekIndex = floor((UTC day number - day number of Monday 2026-01-05) / 7); featured = schedule[weekIndex mod schedule.count], where schedule is an explicit ordered list of song ids in progression.json. New songs are appended to the list. Evaluate in UTC at run end. Reword the claim to 'the same for everyone on the same app version'. Test year boundaries 2026/27 and 2027/28 and a schedule-length change.

**Outcome: Adopted (D-074).**

### MATCH-20: Build the match and progression rules first as an executable Python reference with shared golden vectors, since Python runs here and Swift does not

Severity minor · opportunity · plan sections: 7.2 (tools/payload.py), 11 (Rules, Payload, Determinism rows), 12, P1.7, P1.8, P1.9, P5.1, Phase 4 done-when

**The plan says.** P1.9: 'golden scoring runs, codec round-trips and tamper cases, payload size limits, and a bot simulator'. Section 12: the sandbox 'has no Swift toolchain'.

**Problem.** The protocol risks in this review (merge, settlement, conflict resolution, size bounds, XP arithmetic, week rotation) are pure logic that can be validated today, but the plan tests them only in Swift, which cannot be compiled in the authoring environment, and only through sequential happy-path device tests in Phase 4. No test in the plan exercises reordering, duplication or loss of messages, multi-device identities, or membership change.

**Evidence.** No Swift toolchain is present in this environment (checked: no swift or swiftc on PATH); python3 with zlib and hmac is available and was used for every number in this review.

**Reviewer's recommendation.** Add to Phase 1 (alongside P5.1): tools/refmodel/ with Python implementations of the codec, merge, ranking, settlement, XP and featured rotation, plus a conversation simulator (N devices, random interleavings, reinstall and second-device events) asserting convergence, no lost entry and exactly-once XP. Export fixtures (payload vectors, merge cases, XP cases, rotation dates) as JSON under Packages/RiffCore/Tests/RiffCoreTests/Fixtures; the Swift tests load the same files, so the Mac build proves the two implementations agree. Add to the Phase 4 gate: one forced concurrent submission, one simultaneous rematch, one bubble opened on the same Apple ID's second device, one member without the app.

**Outcome: Adopted with changes (D-076).** Written in Swift inside the RiffCore tests instead of a Python reference model, because Swift now runs in every session.

### MATCH-18: Unlock counts, defaults and the sample profile do not agree with each other

Severity nit · inconsistency · plan sections: 6.2, 6.3, Appendix D

**The plan says.** 15 + 6 + 8 + 6 + 5 unlocks; 'About one reward per level, front-loaded so levels 2-10 each unlock something'; sample profile at level 10 with xp 8240 has three unlocked items and equips 'frame.basic' and 'fx.sparks'.

**Problem.** The table totals 40 items for 49 level-ups, which fits 'about one per level' only if the five default items a level-1 player needs are extra; if the defaults are inside the counts, 35 rewards remain and, after levels 2-10, 26 rewards cover 40 levels whose cost reaches 5,300 XP (about 23 runs) each. The sample profile equips two items that are not in its unlocked list and holds 3 unlocks at level 10 although levels 2-10 alone should have granted 9. It also stores both xp and level, which can drift apart when the curve is retuned.

**Evidence.** 15+6+8+6+5 = 40; levels 2-50 = 49 level-ups; level 49 to 50 costs 400 + 100 x 49 = 5,300; 8,240 XP is level 10 (level 11 needs 9,500), all recomputed.

**Reviewer's recommendation.** State in 6.3 that each type has one default item outside the counts (or adjust the counts), give progression.json an explicit level-to-reward table with the nine empty levels chosen deliberately, fix the Appendix D example, and remove 'level' from the stored profile (derive it from xp).

**Outcome: Adopted (D-075).**

### MATCH-19: Ranking details left open: 'whoever played first', 'top 3 plus your own place', and conversations with no remote participant

Severity nit · ambiguity · plan sections: 4.6 ('Duel tie-breakers, in order: score, accuracy, longest streak, then whoever played first'), 5.1 ('top 3 plus your own place'), 5.3 ('Captions read the same for everyone'), 5.4

**The plan says.** Tie-break ends with 'whoever played first'; the group bubble shows 'top 3 plus your own place'.

**Problem.** 'Played first' can mean array order or the self-reported timestamp t; after a merge (MATCH-1) array order is not stable across devices and t depends on each phone's clock, so two devices can rank a tie differently and pay different podium XP. The bubble image is rendered once by the sender and is identical for every viewer, so 'your own place' on the bubble can only be the sender's place; the per-viewer place exists only inside the app. Mode selection for a conversation with zero remote participants (a note to self) is undefined.

**Evidence.** MSMessageTemplateLayout carries one image set by the sender; plan 5.3 already notes captions are the same for everyone.

**Reviewer's recommendation.** Define ranking as a pure function of payload integers: score desc, a desc, c desc, t asc, player id asc; entries are stored sorted by that key so every device encodes the same bytes. Change 5.1 to 'the card shows the top 3 and the sender's place; the app shows yours'. With zero remote participants offer Practice only.

**Outcome: Adopted (D-061, D-022).**

Sources: <https://developer.apple.com/documentation/messages/msmessagetemplatelayout>

</details>

**Checked and found sound (MATCH).**

- Level curve arithmetic is correct: 500 XP to level 2, 8,100 total to level 10, 142,100 total to level 50 (sum of 400+100L recomputed); the sample profile's 8,240 XP is level 10.
- 'About 35 typical runs' to level 10 and '200-300 XP for a typical duel turn' are reasonable: a 3-4 star run pays 160-180 on a loss and 235-255 on a win; the 50% win-rate average is 207 without daily bonuses (39 runs) and 218-327 per run with the first-run bonus and a streak (25-37 runs). Maximum single run is 1,001 XP, minimum 100.
- A duel payload is under 1 KB: 290 characters for the opening turn and 371-531 for two entries with ASCII, emoji or CJK nicknames (python3, raw deflate level 5, base64url).
- A 32-entry round with a 32-key series map stays inside 4 KB for nicknames of 16 Unicode scalars: 2,298 (random ASCII), 3,134 (emoji), 3,602 (CJK) characters. The claim fails only for the limit as literally written (16 grapheme clusters), see MATCH-6.
- The 4 KB cap is below Apple's documented limit: 'the URL cannot be longer than 5,000 characters' (MSMessage.url).
- HMAC-SHA256 truncated to 16 bytes is cryptographically adequate (128-bit tag, within RFC 2104 guidance); the weakness is the shared embedded key, which the plan already acknowledges.
- Appendix A's example numbers are internally consistent: baseScore 162,800 = 158,800 note points (x1, x2, x3 for ten notes each, then x4) + 4,000 sustain (40 hold beats); maxScore 337,600 = 412 x 800 + 40 x 25 x 8.
- An 8-hex-character player id is collision-safe for the group size (1.2e-7 for 32 players); the problem is where the id comes from, not its length.
- Unlock arithmetic: 15+6+8+6+5 = 40 rewards for 49 level-ups is consistent with 'about one reward per level' provided default items are counted separately.
- One MSSession per match does replace the previous bubble on update (MSSession and insert documentation), so 'one bubble per match' is how the platform behaves in the non-concurrent case.
- Reading the selected message on every activation (section 3) is the right instinct and matches Apple's note that selectedMessage is not refreshed; it needs the ledger merge from MATCH-1 to be sufficient.
- Using CryptoKit and the system Compression library (raw DEFLATE, RFC 1951) is technically workable on iOS 17; Python's zlib with wbits=-15 interoperates.

## Gameplay rules, scoring and determinism (GAME)

| ID | Severity | Finding | Check | Outcome |
| --- | --- | --- | --- | --- |
| GAME-1 | major | With no ghost-tap penalty, blind mashing gives a Full Combo and about 80% of base score | Not re-checked | Owner decision: D-052 |
| GAME-2 | major | The engine has no time or event-ordering contract, so results depend on frame timing and replays cannot be exact | Not re-checked | Adopted: D-050 |
| GAME-3 | major | Sustain points and Hype drain are continuous, fractional quantities with no rounding rule, so scores are frame-rate dependent and base score is not reproducible | Not re-checked | Adopted: D-051 |
| GAME-4 | major | Star thresholds miss the plan's own target: one miss costs a fixed 6,400 points, so stars mostly count misses and Easy charts are hit hardest | Not re-checked | Adopted: D-053 |
| GAME-5 | major | Same-lane minimum gaps (90, 150, 250 ms) sit inside the 130 ms window, so one skipped note downgrades every following hit | Not re-checked | Adopted: D-054 |
| GAME-6 | major | Hype rules leave at least eight behaviours undefined | Not re-checked | Adopted: D-055 |
| GAME-7 | major | Hold rules are incomplete: missed head, late head, re-press, finger slide, same-lane touches, holds shorter than the hit window | Not re-checked | Adopted: D-056 |
| GAME-8 | major | Nothing versions the scoring rules: two app versions with the same chart can score a duel differently, and stored base scores go stale | Not re-checked | Adopted: D-008 |
| GAME-9 | major | Unlimited restarts with a visible target let the second player retry until they win | Not re-checked | Owner decision: D-058 |
| GAME-10 | minor | Run lifecycle is underspecified: lead-in length, where resume restarts, holds across a pause, when a run is final | Not re-checked | Adopted: D-059 |
| GAME-11 | minor | The difficulty table cannot be enforced as written and omits the rules that keep charts playable with two thumbs | Not re-checked | Adopted: D-060 |
| GAME-12 | minor | Judgement and streak edge cases are open: streak before or after the note, same-timestamp order, window edges, Easy's miss time | Not re-checked | Adopted: D-057 |
| GAME-13 | minor | Song length is stated three ways and the longer one breaks the 'under 2 minutes' pillar | Not re-checked | Owner decision: D-062 |
| GAME-14 | minor | Accuracy rounding and the last tie-break are not defined in a way every device computes identically | Not re-checked | Adopted: D-061 |
| GAME-15 | minor | maxScore is a valid ceiling but about 1.6 times looser than anything reachable, and the plan's headline score exceeds it | Not re-checked | Adopted: D-063 |
| GAME-16 | minor | Touch-zone geometry contradicts itself, and 'Portrait only' is not something the extension can enforce | Not re-checked | Device spike decides: D-064 |
| GAME-17 | minor | Test determinism needs three things the plan does not list: a seeded generator for bots, no dependence on Dictionary order, and the simulator as a command-line tool | Not re-checked | Adopted: D-007, D-009 |

<details>
<summary>Full text of the GAME findings</summary>

### GAME-1: With no ghost-tap penalty, blind mashing gives a Full Combo and about 80% of base score

Severity major · design-flaw · plan sections: 4.3, 14 (Ghost-tap penalty row), 4.6, P1.9

**The plan says.** 4.3: 'A touch matches the earliest unjudged note in its lane whose window contains the touch time.' and 'A touch that matches no note (a ghost tap) costs nothing in v1. [DECIDE]'. Section 14 recommends 'Ghost-tap penalty: None in v1'.

**Problem.** Every note has a 260 ms wide window (312 ms on Easy) and stray touches are free, so tapping each lane periodically with a period at or under the window width hits every note without reading the chart. The streak never breaks, so the x4 multiplier and Full Combo are kept. A blind masher out-scores an honest mid-skill player, and the same trick used only on hard passages is a strictly dominant way to protect a streak. The whole product is score duels, so the plan's recommended default undermines them.

**Evidence.** Simulation of the plan's rules (earliest-unjudged matching, 45/90/130 ms windows, streak tiers of 10, random charts at the 8.4 densities, 60 charts each): tapping every lane every 250 ms (16 taps/s over four fingers) scores a median 82% of base on Easy with FC in 60/60 runs, 77% on Medium (FC 45/60) and 77% on Hard (FC 43/60); every 200 ms gives 83% with FC 60/60 on Medium and Hard. Expert needs a 125 ms period (79%, FC 60/60). For comparison an honest bot with 4% misses and 35 ms timing sigma scores 55-58% of base, and one with 1.5% misses scores 78-82%. With 'ghost tap resets the streak' the same masher drops to 18-24%. Scripts: /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_c.py and game_b.py.

**Reviewer's recommendation.** Change the section 14 recommendation and write the rule into 4.3: a touch-down that matches no note resets the streak to 0 on every difficulty; it is not a Miss for accuracy or Hype phrases. Redefine Full Combo as 'longest streak equals note count' so a mashed run cannot earn it. Two exemptions: a touch-down in a lane within bounceGrace (start 80 ms) after a hit in that lane is ignored, and touches before the first note's window opens or after the last note is judged are ignored. Keep ghostTapPenalty (none, dropTier, resetStreak) per difficulty in GameConfig so Easy can be softened after playtests. Add a masher bot to P1.9 (each lane every 200 ms and 250 ms, random phase) with the acceptance rule: never a Full Combo and below the casual bot's median on every shipped chart. Also reword the 4.3 table row 'Miss: beyond 130, or no touch': a touch outside every window is a ghost tap, never a Miss, and only an expired window produces a Miss.

**Device test.** On the Phase 3 slice with the plan's current rules, lay the phone flat and drum four fingers (one per lane) at roughly 4-5 taps per second each for a whole Easy, Medium and Hard chart without looking at the notes. Record misses, Full Combo and score as a share of base score from the Diagnostics report, then repeat with the streak-reset rule enabled.

**Outcome: Owner decision (D-052).**

Sources: /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_c.py, /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_b.py

### GAME-2: The engine has no time or event-ordering contract, so results depend on frame timing and replays cannot be exact

Severity major · gap · plan sections: 4.3, 7.3 step 4, 11 (Determinism row), P1.3, P1.4, P1.5, P1.9

**The plan says.** 7.3: 'Each touch is judged at the song time of its hardware timestamp, not the frame that processed it'. 4.3: 'A note still unhit 130 ms after its time becomes a Miss.' Section 11: 'Same inputs give the same score: record an input log, replay it through the game session, compare'.

**Problem.** Touches are judged at their hardware timestamp, but the miss sweep, Hype expiry, sustain accrual and hold ends are unspecified and would naturally run on frame time. A touch is always delivered after its timestamp, so three things go wrong. (1) A valid Good hit at +125 ms that is delivered after a frame at +132 ms has already swept the note becomes a ghost tap plus a Miss. (2) A note tapped 5 ms before Hype expires but processed after the frame that ended Hype scores x4 instead of x8, a 400-point swing. (3) The same input log fed with a different frame cadence gives a different score, so the determinism test in section 11 cannot be an exact comparison. Nothing defines the order of events that share a timestamp, which will be common: two chord touches, or a Hype tap and a note tap, reported in the same touch scan.

**Evidence.** Apple's UIEvent documentation states that touch data is sampled faster than it is delivered ('Some devices gather touch data at rates up to 240 Hz, which is normally higher than the rate that touches are delivered to your app'), and UITouch.timestamp is 'the time, in seconds since system startup, that the touch originated', so delivery time is always later than the timestamp the plan judges with. The plan defines no engine API, time type, tie order or rule for when a Miss becomes final. The frame-dependence is shown numerically in GAME-3.

**Reviewer's recommendation.** Add a section 4.9 'Engine contract' and build P1.3-P1.5 against it. (a) Song time is Int64 microseconds, signed (negative in the lead-in); all windows in GameConfig are integer microseconds. (b) The engine never reads a clock or random source. Its API is apply(event) for touchDown(id, lane, t), touchUp(id, t) (also used for cancels) and activateHype(t), plus advance(to: t). (c) Internally it keeps a queue of scheduled events (miss deadline = note time + Good window, hold end, Hype expiry) and processes everything in one total order: time, then class (activateHype, touchDown, touchUp, holdEnd, missDeadline, hypeExpiry), then lane. This makes a touch at exactly the window edge a hit and a touch at exactly Hype expiry doubled. (d) Driver rule: inputs are applied as they arrive; each frame calls advance(to: songTimeNow - inputGuard) with inputGuard in GameConfig (start 50 ms). An input older than the engine's current time is clamped to it and counted in Diagnostics. Miss feedback therefore appears inputGuard later than the window edge; hit feedback is immediate. (e) P1.9 adds a partition-invariance property test: replaying one input log with random advance() subdivisions must give an identical RunSummary and event list. The input log format is exactly the apply() events plus chart hash, rules version and difficulty.

**Device test.** In spike S3 (or P3.3), log for every touch-down the difference between CACurrentMediaTime() at the moment the handler runs and touch.timestamp, over a 3-minute session at 60 Hz and at 120 Hz, including while the highway is rendering 200 sprites. Paste p50, p99 and max in the Diagnostics report; set inputGuard to the max plus one frame.

**Outcome: Adopted (D-050).**

Sources: <https://developer.apple.com/documentation/uikit/uievent/coalescedtouches(for:)>, <https://developer.apple.com/documentation/uikit/uitouch/timestamp>

### GAME-3: Sustain points and Hype drain are continuous, fractional quantities with no rounding rule, so scores are frame-rate dependent and base score is not reproducible

Severity major · ambiguity · plan sections: 4.4, 4.5, 4.6, 8.3 step 4, P1.1, P1.4, P1.6, Appendix A

**The plan says.** 4.4: 'Holds add sustain points continuously while held, capped at the hold's length: sustain points = 25 x beats held x m'. 4.5: 'the meter drains 1/32 per beat'. 4.6: 'The chart tool computes it [base score] offline and stores it in each chart.' Appendix A stores tempo as a float ('bpm': 128.0); the payload score is an Int.

**Problem.** Scores are integers but sustain is fractional: the Expert minimum hold of 1/4 beat is worth 6.25, 12.5 or 18.75 points at x1-x3, and no rounding rule exists (per frame, per hold or per run). 'Continuously' invites per-frame accrual, which attributes whole frames to the wrong multiplier and samples the release late. Hype drain per frame has the same problem for its expiry time. Base score is computed by a Python tool and scores by Swift, so the two must round identically or star cutoffs and golden tests disagree. Tick-to-time conversion across tempo changes is also unspecified (float accumulation order, and no time-to-tick inverse, which sustain and Hype both need).

**Evidence.** Computed: a 4-beat hold at 128 BPM with the multiplier going x4 to x8 at 0.500 s and release at 1.700 s is worth 618.67 points exactly; naive per-frame accrual gives 622.22, 618.67 or 616.89 depending on frame rate (60 or 120 fps) and frame phase. One 60 Hz frame of sustain at x8 is 7.1 points, so identical play differs by several points per event between devices. Script: /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_e.py. Double arithmetic itself is not the risk (same code on arm64 gives the same bits); frame-dependent accumulation and unspecified rounding are.

**Reviewer's recommendation.** Specify integer tick-domain math. (1) Tempo is stored as integer milli-BPM ('mbpm': 128000), which is also lossless from the source .chart format. Time of a tick inside a tempo segment = segStartUs + floor(deltaTicks x 60,000,000,000 / (mbpm x resolution)); segment starts are accumulated with the same formula; the inverse is tick = segTick + floor(deltaUs x mbpm x resolution / 60,000,000,000). Both fit in Int64 for any 2-minute song. (2) A beat is always 'resolution' ticks (a quarter note), whatever the time signature. (3) Sustain: while a hold is live the engine adds m x deltaTicks to one integer accumulator U, splitting at every event that changes m; score = notePoints + floor(25 x U / resolution), one floor for the whole run. (4) Hype meter is an integer in ticks: phrase = 8 x resolution, cap = 32 x resolution, activation threshold = 16 x resolution; while active it drains one unit per chart tick, so expiry tick = activation tick + meter, converted to microseconds once (and recomputed when a phrase adds meter). (5) baseScore = perfect run evaluated in ticks with the same formulas (notes at a tick are scored in lane order, then sustain from that tick uses the new streak); maxScore = 800 x noteCount + floor(200 x totalHoldTicks / resolution). (6) Golden test: for every bundled chart the Swift perfect-run bot must equal computed.baseScore exactly.

**Outcome: Adopted (D-051).**

Sources: /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_e.py

### GAME-4: Star thresholds miss the plan's own target: one miss costs a fixed 6,400 points, so stars mostly count misses and Easy charts are hit hardest

Severity major · design-flaw · plan sections: 4.4, 4.6, 8.4, P1.6, P1.9

**The plan says.** 4.6: stars at 20/40/60/80/95% of base score, where 'Base score is a perfect run with no Hype', and 'Thresholds get tuned with the bot simulator (task P1.9) so a capable player lands 3-4 stars at their usual difficulty.' 4.4: m = min(4, 1 + floor(s/10)). 8.4: Easy averages 1-2 notes per second.

**Problem.** After a miss the next 30 notes score at x1, x2, x3 instead of x4, so one miss at full multiplier costs 400 + 3,000 + 2,000 + 1,000 = 6,400 points regardless of chart length. As a share of base that is about 2.6% on a 630-note Expert chart but 16.5% on a 112-note Easy chart and 35.6% on a 60-note Easy chart (1 note/s for 60 s, which 8.4 allows). The stated starting thresholds therefore do not deliver '3-4 stars for a capable player', and no single percentage table can fit both Easy and Expert, because the miss cost does not scale with chart size. On Easy the 30-note ramp is also 15-30 seconds of play.

**Evidence.** Exact arithmetic, all other notes Perfect, misses evenly spread: Easy 112 notes: 1 miss = 84% (4 stars), 2 = 67% (3), 3 = 53% (2), 5 = 40% (1). Easy 60 notes: 1 miss = 65% (3 stars), 2 = 48% (2). Expert 450 notes: 5 misses = 82% (4 stars), 12 = 56% (2). Bot runs (independent misses, Gaussian timing, no Hype; 4,000 runs each, an assumption that is harsher than clustered real misses): 8% misses and 45 ms sigma gives a median 36-39% of base (1 star in 56-83% of runs); 4% misses and 35 ms sigma gives 55-58% (2 stars most often); 1.5% misses gives 78-82%. Script: /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_b.py.

**Reviewer's recommendation.** (1) Make star cutoffs per-chart data: chartcheck writes computed.starCutoffs (five absolute scores) from a per-difficulty share table in the shared rules file, and StarRating reads them, so tuning never needs a code change and both phones agree through the chart hash. (2) Replace the starting shares with 10/25/45/65/85%, which maps the five bots above to 1-5 stars without Hype; re-derive them with the P1.9 simulator before any screen shows stars. (3) Bound the ramp relative to chart size: make streakPerTier a per-difficulty GameConfig value (start Easy 4, Medium 6, Hard 8, Expert 10) or add a chartcheck minimum of 120 notes per chart; record the choice in DECISIONS.md. (4) State that the share can exceed 100% with Hype and that the comparison is done in integers: score x 100 >= baseScore x percent.

**Outcome: Adopted (D-053).**

Sources: /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_b.py

### GAME-5: Same-lane minimum gaps (90, 150, 250 ms) sit inside the 130 ms window, so one skipped note downgrades every following hit

Severity major · design-flaw · plan sections: 4.3, 8.4, P1.2, P1.3

**The plan says.** 4.3: Good window 130 ms either side; 'A touch matches the earliest unjudged note in its lane whose window contains the touch time.' 8.4: minimum gap on one lane is 400 / 250 / 150 / 90 ms for Easy / Medium / Hard / Expert.

**Problem.** When two same-lane notes are closer than the Good window (plus how early the player taps), a skipped note is still live when the tap for the next note arrives, so earliest-unjudged matching gives that tap to the stale note as a late Good or Great. The next tap then lands on the note before it, and so on until a gap appears; the last note of the run becomes the Miss. On Expert three windows can overlap at once (notes at 0, 90 and 180 ms all contain t = 85 ms). A 90 ms same-lane repeat is also about 11 taps per second on one column, beyond a single thumb.

**Evidence.** Simulation of the plan's rule, first note of a same-lane run skipped, the rest tapped: gap 90 ms, on time: every hit judged Great(+90) instead of Perfect; gap 120 ms, on time: every hit Good(+120); gap 150 ms (Hard minimum) with taps only 20 ms early: every hit Good(+130). Nearest-note matching fixes these but breaks the opposite case: a player consistently 50 ms late on a 90 ms run gets Miss plus a ghost tap. Script: /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_e.py.

**Reviewer's recommendation.** For v1 keep earliest-unjudged matching and remove the overlap at chart level: chartcheck enforces same-lane gap > Good window + Perfect window for the chart's difficulty, so a tap inside the next note's Perfect window can never be captured by the previous note. The 8.4 column becomes 400 / 250 / 180 / 180 ms (Easy needs at least 211 ms and already has 400). If faster same-lane repeats are wanted on Expert later, change the judge instead: clip each note's window at the midpoint to its same-lane neighbours so windows never overlap, and record the trade-off in DECISIONS.md. Add golden tests for a skipped-note run at the minimum legal gap with taps at -45, 0 and +45 ms.

**Device test.** Debug chart with same-lane repeats at 250, 180, 150, 120 and 90 ms spacing (8 notes each, separated by rests). Three playtesters play it with two thumbs; record hit rate and judgement mix per spacing from Diagnostics to confirm where single-lane repeats stop being playable.

**Outcome: Adopted (D-054).**

Sources: /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_e.py

### GAME-6: Hype rules leave at least eight behaviours undefined

Severity major · ambiguity · plan sections: 4.2 (Hype phrase row), 4.5, Appendix A (hype array), P1.4, 8.3 step 2

**The plan says.** 4.2: 'Hit every note in the phrase at Good or better to charge Hype.' 4.5: 'Each completed Hype phrase adds 25% to the meter, up to 100%. Charts carry 4-6 phrases per song.' 'At 50% or more, the player taps the Hype button'. 'While active, the multiplier doubles (max x8) and the meter drains 1/32 per beat'. Appendix A: 'hype': [{ 'start': 3072, 'end': 4608 }].

**Problem.** Two engineers would differ on: (1) whether 'end' is inclusive and which phrase a hold belongs to; (2) when a phrase completes (last note judged, or phrase end tick) and whether a dropped sustain fails it; (3) whether a phrase completed while Hype is active adds meter and extends it; (4) what happens to a phrase completed at 100% (4-6 phrases is 100-150% in total); (5) whether activation is allowed mid-phrase and whether it can be cancelled; (6) which timestamp decides whether a note is doubled; (7) what a Miss does to an active Hype; (8) leftover meter at song end. 'At Good or better' is redundant, since every hit is Good or better. Phrase count is fixed at 4-6 regardless of length: six phrases are 48 beats, 37.5% of a 60 s song at 128 BPM.

**Evidence.** Plan text only gives the five sentences quoted. Arithmetic: 25% = 8 beats, 6 phrases = 48 beats; a 60 s song at 128 BPM has 128 beats (37.5% under Hype), a 90 s song 192 beats (25%).

**Reviewer's recommendation.** Add these rules to 4.5. R1: a phrase is the half-open tick range [start, end); its members are notes whose head tick is inside; a hold belongs by its head only. R2: a phrase fails at its first member Miss and completes the moment its last member is hit; sustains do not matter. R3: completion adds 8 beats of meter, clamped at 32; overflow is discarded; this also applies while Hype is active, which extends it. R4: activation is accepted only when Hype is inactive and the meter is at least 16 beats; it takes effect at the button touch's timestamp; otherwise the tap is ignored at no cost; Hype cannot be cancelled. R5: a note is doubled if activation &lt;= touch time &lt;= expiry; sustain is doubled tick by tick. R6: a Miss does not affect the meter or an active Hype; pause freezes it; unused meter at the end is lost. R7 (chartcheck): phrases sorted and non-overlapping, at least 4 member notes at every difficulty, both notes of a chord in the same phrase, last phrase ends at least 16 beats before the final note, and total capacity (8 beats x phrase count) at most 30% of the song's beats. Meter arithmetic in integer ticks as in GAME-3.

**Outcome: Adopted (D-055).**

### GAME-7: Hold rules are incomplete: missed head, late head, re-press, finger slide, same-lane touches, holds shorter than the hit window

Severity major · ambiguity · plan sections: 4.2 (Hold row), 4.4, 8.4 (Shortest hold), P1.2, P1.3, P1.4

**The plan says.** 4.2: 'Head judged like a tap; sustain points accrue while held; releasing early ends the sustain without a miss'. 4.4: sustain uses m, 'capped at the hold's length'. 8.4: shortest hold is 1/4 beat on Expert.

**Problem.** Undefined: (1) whether a missed head still lets the player grab the tail late; (2) whether sustain starts at the head's time or the touch's time when the head is hit early or late; (3) whether the sustain multiplier is the live one or latched at the head; (4) whether a released hold can be re-pressed; (5) whether a finger sliding into another column releases the hold or hits a note there; (6) what a second finger in the same lane does during a hold; (7) how soon a new note may follow a hold's end in the same lane; (8) what a touch cancel (system gesture, pause) does. Also, 1/4 beat is 117 ms at 128 BPM and 83 ms at 180 BPM, shorter than the 130 ms Good window, so a head hit late can arrive after the hold is already over.

**Evidence.** Computed: 1/4 beat = 150 ms at 100 BPM, 117 ms at 128, 100 ms at 150, 83 ms at 180; value 6.25 points at x1. The plan's hold text is the single table row quoted.

**Reviewer's recommendation.** Add to 4.2/4.4: H1 a hold is one note (its head) for streak, accuracy, note count and Hype phrases. H2 the touch that hits the head owns the hold; a touch stays bound to the lane it began in until it ends, and movement is ignored. H3 sustain accrues over ticks [max(headTick, touchTick), min(endTick, releaseTick)), with the live multiplier, in the integer form of GAME-3. H4 a missed head kills the whole hold; later touches in that lane are ordinary touches. H5 lifting or a touch cancel ends the sustain for good: no re-press, no Miss, no effect on streak, phrases or Full Combo. H6 any other touch-down in the lane during a hold is judged as a normal touch. H7 chartcheck: no note in a lane between a hold's head and end; the next same-lane note starts at least the same-lane minimum gap after the hold's end; minimum hold length is the larger of the 8.4 beat fraction and 250 ms. H8 the tail of a dead or released hold is drawn dimmed.

**Outcome: Adopted (D-056).**

Sources: /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_a.py

### GAME-8: Nothing versions the scoring rules: two app versions with the same chart can score a duel differently, and stored base scores go stale

Severity major · gap · plan sections: 4 (intro), 4.6, 5.2, 5.5, 8.3 step 4, P1.6, Appendix A (computed), Appendix C, 15 (intro)

**The plan says.** Section 4: 'Every number below is a starting value kept in one config file and tuned in playtests.' 5.2: 'The payload carries a chart hash, and a mismatch (different app versions) asks the player to update.' 4.6: base score is computed offline by the chart tool 'and stores it in each chart'. P1.6 also lists 'base score and theoretical maximum per chart' in RiffCore. Appendix C has v (schema version) and ch (chart hash, 8 hex) only.

**Problem.** The fairness check covers chart content but not the rules. A retune shipped in an update (a window, a points value, tier size, Hype drain, ghost-tap rule) leaves v and ch unchanged, so two players on different versions are scored under different rules with no 'Update needed' screen. The hash itself is undefined: which bytes, which function, and how it avoids hashing its own field inside 'computed'. baseScore, maxScore and any star cutoffs stored in chart files depend on GameConfig and silently go stale when it changes. Scoring exists twice (Python chartcheck and Swift RiffCore) with no rule for which is authoritative, and GameConfig.swift cannot be read by the Python tools.

**Evidence.** Appendix C fields; 12.2 only requires a schema bump for payload shape changes ('Any payload change bumps the schema version'). No section defines the hash input.

**Reviewer's recommendation.** (1) Move every scoring number into one bundled data file, rules.json, with an integer rulesVersion; RiffCore decodes it into GameConfig and the Python tools read the same file. (2) Define the chart hash as the first 8 hex characters of SHA-256 over a canonical byte string: a fixed prefix, rulesVersion, songId, part, difficulty, resolution, tempo list, notes sorted by (tick, lane) with lengths, and hype ranges, one ASCII line each. The 'computed' block is excluded. A rules change therefore changes every hash and reuses the existing 'Update needed' path with no payload change. (3) RiffCore is the authority for baseScore, maxScore and star cutoffs; chartcheck writes them and a RiffCore test recomputes hash, baseScore, maxScore and cutoffs for every bundled chart and requires exact equality. (4) A test stores a digest of rules.json next to rulesVersion and fails if the file changes without a version bump.

**Outcome: Adopted (D-008).**

### GAME-9: Unlimited restarts with a visible target let the second player retry until they win

Severity major · design-flaw · plan sections: 4.7, 5.2, 5.4, 6 (intro), Appendix C (Entry)

**The plan says.** 4.7: 'Restarting is allowed until you submit; only the submitted run counts for the round.' 5.2: 'One submitted score per player per round; restarts before submitting are fine.' 5.4: the responder's screen shows 'the score to beat'. Section 6: 'a duel is always decided by the run itself'.

**Problem.** The responder knows the exact score to beat and can replay without limit or trace, so a duel is decided by patience rather than a run. The first player can also grind before sending, but cannot answer afterwards. A finished run that was not good enough can simply be discarded, and closing Messages discards one mid-song. Manual pauses (collapsing the view) are also unlimited and leave the frozen highway readable, so a hard passage can be studied and taken in pieces. Practice mode already exists for learning a chart.

**Evidence.** Reasoning from the quoted rules; the plan has no attempt counter in the payload (Appendix C Entry has p, n, s, a, c, st, fc, lv, t) and no persisted 'attempt started' state.

**Reviewer's recommendation.** Add a [DECIDE] with this recommendation: challenge runs allow retries but count them. When play starts, the app writes an attempt record keyed by match id and round to the App Group store before the first note; Entry gains tr (tries, 1-99); the card shows it ('412,300, try 3'); tie-break order becomes score, accuracy, longest streak, fewer tries, entry order. A stricter option to offer is a single attempt, with restart allowed only in the first 10 seconds. For pauses: blank the highway while paused and record a pause count in RunSummary for Diagnostics. Practice runs are never counted.

**Outcome: Owner decision (D-058).**

### GAME-10: Run lifecycle is underspecified: lead-in length, where resume restarts, holds across a pause, when a run is final

Severity minor · ambiguity · plan sections: 4.1, 4.7, P1.5, 7.3 step 6

**The plan says.** 4.1: 'Scroll speed is the time a note spends on screen: 1.6 s on Easy down to 1.1 s on Expert'. 4.7: 'the music starts after the first notes have had their full scroll time (at least 2 s), with a 3-2-1 count on the beat'; 'Resume shows a 3-beat countdown and restarts audio in sync'; 'the song always plays to the end'.

**Problem.** (1) 'Time a note spends on screen' is not the approach time: the strike line is 18% above the bottom, so a note is on screen longer than it takes to reach the line. (2) A count 'on the beat' needs a whole number of beats, but the lead-in is given in seconds; four beats at 128 BPM is 1.875 s, under the 2 s minimum. (3) Resume does not say whether song time continues from the pause point or rewinds, what happens to notes whose window was open, or to holds in progress. (4) It is not stated when the score is final: last note judged, or audio end. A player who collapses the view during the outro may or may not have a submittable run.

**Evidence.** Arithmetic: one beat at 128 BPM is 468.75 ms; 4 beats = 1.875 s, 5 beats = 2.344 s. The example chart's first note is at tick 768 = 1.875 s.

**Reviewer's recommendation.** Specify: scroll time is the approach time from spawn to the strike line. Lead-in = the smallest whole number of beats at the opening tempo that is at least max(2 s, approach time minus first note time), with the count on its last three beats; song time runs from minus lead-in. On pause the driver sends touchUp for every active touch (holds end under rule H5 of GAME-7) and stops calling advance; engine time never moves backwards. On resume the audio pre-rolls from 3 beats before the pause point while the highway scrolls already-judged notes dimmed, and the engine resumes at the pause point. The run is final when every note is judged and every hold has ended or been released; the outro can be skipped and leaving after that point keeps the result.

**Outcome: Adopted (D-059).**

### GAME-11: The difficulty table cannot be enforced as written and omits the rules that keep charts playable with two thumbs

Severity minor · gap · plan sections: 8.4, 4.1, 4.2, P1.2, 8.3 steps 3-4, Appendix A

**The plan says.** 8.4 table: average / peak notes per second, Chords 'None / Rare / Yes / Yes', minimum gap on one lane, shortest hold. 4.2: 'max 2 notes per chord'. 4.1: 'Two-thumb layout: lanes 1-2 for the left thumb, 3-4 for the right.'

**Problem.** 'Rare' and 'Yes' are not checkable. Average and peak notes per second have no measurement span or window, and it is not stated whether a chord counts as one or two. There is no limit on simultaneous contacts: a hold plus a chord needs three fingers, which a two-thumb layout cannot do. There is no minimum gap between notes on different lanes, so Easy ('Chords: None') can contain two notes 10 ms apart, which is a chord in all but name. The example Expert chart breaks the table under the obvious reading.

**Evidence.** Appendix A/B: 412 notes over durationSec 92.0 is 4.48 notes per second, below Expert's 5-7 average unless the span is first-to-last note and under 82.4 s. The ranges themselves are consistent: four lanes at the same-lane gaps allow 10, 16, 26.7 and 44 notes per second against peaks of 3, 5, 7 and 10.

**Reviewer's recommendation.** Replace the table's loose cells with rules chartcheck and reduce.py both use: average = note count / (last note time - first note time); peak = most notes in any sliding 1,000 ms window, each chord note counted. Chords: Easy 0; Medium at most 5% of notes and no two chords within one beat; Hard at most 20%; Expert at most 35% (starting values). Minimum gap between notes on different ticks, any lanes: 250 / 150 / 100 / 70 ms. Simultaneous contacts (active holds plus notes starting on a tick): at most 1 on Easy, 2 elsewhere. Add the hold rules of GAME-7 and the same-lane gaps of GAME-5. Fix the example so it passes.

**Outcome: Adopted (D-060).**

Sources: /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_a.py

### GAME-12: Judgement and streak edge cases are open: streak before or after the note, same-timestamp order, window edges, Easy's miss time

Severity minor · ambiguity · plan sections: 4.3, 4.4, Glossary (Streak), P1.3, P1.4

**The plan says.** 4.4: points use 'the current streak s (consecutive notes without a miss, every chord note counted)'. 4.3: windows given as plus or minus 45 / 90 / 130 ms; 'Easy widens every window by 20%'; 'A note still unhit 130 ms after its time becomes a Miss.'

**Problem.** (1) 'Current streak' can mean before or after counting the note being scored; the two readings differ by 300 points per ramp. (2) Two chord notes with different judgements at a tier boundary score differently depending on which is processed first (Perfect at x1 plus Good at x2 is 200; the reverse is 250), and both touches can carry the same timestamp. (3) It is not said whether a touch at exactly 45, 90 or 130 ms is inside the window. (4) The Miss sentence says 130 ms flat, but Easy's Good window is 156 ms.

**Evidence.** Computed for 412 Perfect notes: streak-before gives 158,800 and streak-after gives 159,100. Only streak-before reproduces both Appendix A numbers (158,800 + 40 sustain beats x 100 = 162,800 baseScore; 412 x 800 + 40 x 200 = 337,600 maxScore), so the plan's own example implies it. Easy windows are 54 / 108 / 156 ms.

**Reviewer's recommendation.** State in 4.4: s is the streak before the note is added, so notes 1-10 of a streak score x1 and x4 starts at the 31st. State in 4.3: windows are inclusive (absolute offset &lt;= window, in integer microseconds); a note becomes a Miss when time passes note time + that difficulty's Good window (156 ms on Easy); events with equal timestamps are processed in the class-then-lane order of GAME-2. Add boundary golden tests at exactly 45, 90, 130 and 130.001 ms and a chord across the streak 9/10 boundary.

**Outcome: Adopted (D-057).**

Sources: /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_a.py

### GAME-13: Song length is stated three ways and the longer one breaks the 'under 2 minutes' pillar

Severity minor · inconsistency · plan sections: 1 (How a turn works, Snackable pillar), 2 (5 launch songs row), 4 (intro), 8.2, Appendix B

**The plan says.** Section 1: 'play a 60-90 second run' and 'a full turn takes under 2 minutes, menus included'. Section 4: 'A run is one 60-90 second song'. Section 2: '5 launch songs, 60-120 s each'. 8.2: 'A 60-120 second edit'. Appendix B: 'durationSec': 92.0.

**Problem.** A 120 s song cannot fit a turn of under 2 minutes, and even 90 s leaves about 25 s for opening the app, picking a song, the lead-in, results and sending. The example manifest (92 s) is outside the 60-90 s range the gameplay spec states. Song length also drives note counts, Hype capacity and the star maths.

**Evidence.** 90 s song + lead-in of at least 2 s + menus and results; 120 s song alone equals the 2-minute budget.

**Reviewer's recommendation.** Use 60-90 s everywhere (sections 2 and 8.2 change), make manifest validation reject durationSec outside 55-95 s, and change the Appendix B example to a value in range. If 120 s songs are wanted, change the pillar to 'under 3 minutes' instead and record it in DECISIONS.md.

**Outcome: Owner decision (D-062).**

### GAME-14: Accuracy rounding and the last tie-break are not defined in a way every device computes identically

Severity minor · ambiguity · plan sections: 4.6, Appendix C (Entry.a, Entry.t), P1.6, P1.8

**The plan says.** 4.6: 'Accuracy = (Perfects + 0.8 x Greats + 0.5 x Goods) / total notes' and 'Duel tie-breakers, in order: score, accuracy, longest streak, then whoever played first.' Appendix C: 'a: accuracy in basis points, 0-10,000' and 't: Unix time in seconds'.

**Problem.** The payload carries accuracy as an integer but no rounding rule is given, and the tie-break compares accuracy. 'Whoever played first' has two candidate sources: the entry's device clock time t, which comes from different phones and can be wrong or changed, and the order of entries in the array.

**Evidence.** Plan text; with float division, 0.8 and 0.5 weights and a round-versus-floor choice can differ by one basis point between implementations.

**Reviewer's recommendation.** Define accuracy in integers: a = floor((10,000 x Perfects + 8,000 x Greats + 5,000 x Goods) / noteCount), where noteCount is the chart's note count (a hold counts once). Tie-breaks compare the transmitted integers. 'Played first' means lower index in the entries array; t is display-only. Ranking in group rounds uses the same four keys.

**Outcome: Adopted (D-061).**

### GAME-15: maxScore is a valid ceiling but about 1.6 times looser than anything reachable, and the plan's headline score exceeds it

Severity minor · opportunity · plan sections: Appendix A, 5.5, 1, 5.3

**The plan says.** Appendix A: 'maxScore is the every-note-at-x8 ceiling used to reject impossible scores' with baseScore 162,800 and maxScore 337,600 for the Neon Nights Expert example. Sections 1 and 5.3 use 'Beat 412,300 on Neon Nights, Expert' as the example bubble.

**Problem.** Every note at x8 is 2.07 times base, but Hype can only be active for 8 beats per phrase, at most 48 beats with six phrases, so real scores top out near 1.2-1.5 times base. An edited score between that and maxScore passes the sanity check. Separately, the example bubble's 412,300 is above the same chart's maxScore of 337,600, so the plan's own decoder would reject it.

**Evidence.** 337,600 / 162,800 = 2.07. Total meter gained is at most 25% x phrase count, so Hype is active for at most 8 x phrases beats: 48 of the example's 196 beats (92 s at 128 BPM), 24.5%. 412,300 > 337,600.

**Reviewer's recommendation.** Have chartcheck and RiffCore compute a tighter ceiling: baseScore plus the points of the highest-scoring 8 x phraseCount beats of the perfect run (a sliding sum over per-tick points; it is still a strict upper bound because Hype coverage can never exceed that many beats). Store it as maxScore. Add cheap consistency checks on decode: fc implies longest streak equals note count, stars equal the locally recomputed value, longest streak at most note count. Change the example score in sections 1 and 5.3 to one under the example chart's ceiling.

**Outcome: Adopted (D-063).**

Sources: /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/game_a.py

### GAME-16: Touch-zone geometry contradicts itself, and 'Portrait only' is not something the extension can enforce

Severity minor · inconsistency · plan sections: 4.1, 4.5, 3 (screen sizes row)

**The plan says.** 4.1: 'notes travel toward a strike line about 18% above the bottom edge. Portrait only.' and 'Touch zones are the bottom 35% of the screen split into 4 equal columns. A touch anywhere in a column counts, so thumbs never cover the gem.' 4.5: the Hype button sits 'just above the right-hand touch zone'. Section 3: 'highway width capped'.

**Problem.** (1) The strike line (18%) is in the middle of the touch zone (0-35%), so thumbs rest on the line and cover gems for the last part of their travel; the stated benefit does not follow. (2) Percentages are 'of the screen', but the extension only owns the expanded view, minus the bottom safe area. (3) Four equal columns of the screen do not line up with a width-capped highway on iPad or a wide foldable. (4) A button just above the right touch zone sits on the approach path of lanes 3-4. (5) Orientation is controlled by the host app; an extension's view controller is not the window's root, so it cannot refuse landscape if Messages rotates.

**Evidence.** Apple's supportedInterfaceOrientations documentation: 'the system calls this method on the root view controller or the topmost modal view controller that fills the window'. An extension's controller is hosted inside Messages, so it is neither (inference; not confirmed on a device).

**Reviewer's recommendation.** Define layout against the game view's safe-area rectangle, with strikeLineY and touchZoneTop as layout constants tuned in spike S3. Decide and state one of: thumbs tap on the line (then draw hit feedback above the touch zone and delete the 'never cover' claim) or thumbs tap below it (strike line at the top of the touch zone). Touch columns follow the highway's lane edges at the strike line, with the two outer columns extended to the view edges. Place the Hype control outside the highway's projected footprint. Replace 'Portrait only' with: when the view is wider than tall, pause and show a rotate prompt.

**Device test.** In spike S2/S3 on an iPhone with rotation lock off: open the extension expanded, log view bounds and safeAreaInsets, rotate to landscape and log whether the view rotates and its new bounds. On the same build draw the 18% line and 35% zone and check by hand whether resting thumbs cover the line. Repeat on iPad.

**Outcome: Device spike decides (D-064).**

Sources: <https://developer.apple.com/documentation/uikit/uiviewcontroller/supportedinterfaceorientations>

### GAME-17: Test determinism needs three things the plan does not list: a seeded generator for bots, no dependence on Dictionary order, and the simulator as a command-line tool

Severity minor · gap · plan sections: 11 (Determinism and Balance rows), P1.9, P5.4, Appendix C (sr: [String: Int]), 8.3 step 4

**The plan says.** P1.9: 'golden scoring runs ... and a bot simulator that reports star distributions by skill level'. Section 11: 'Bot simulator at 5 skill levels, varying timing noise and miss rate', run for 'Each new chart'. Appendix C: 'var sr: [String: Int]' and a signature over the payload.

**Problem.** Swift's default random generator cannot be seeded, so bot results would change on every run and star tuning would not be reproducible. Dictionary iteration order and Hasher values change between launches, so any engine event list, chart hash or signed payload bytes built by iterating a Dictionary can differ between two runs or two phones. The simulator is described as a test, but P5.4 and chartcheck need to run it per chart from the tools.

**Evidence.** Apple documentation: SystemRandomNumberGenerator 'is automatically seeded'; Hasher: 'Do not save or otherwise reuse hash values across executions of your program. Hasher is usually randomly seeded'; Dictionary: 'The order of key-value pairs in a dictionary is stable between mutations but is otherwise unpredictable'; JSONEncoder offers the sortedKeys output option for stable key order.

**Reviewer's recommendation.** Add to P1.9 and 12.2: RiffCore ships its own small seeded generator (SplitMix64) used by every bot, with the seed printed in reports. RiffCore never iterates a Dictionary or Set where order reaches output; payload and golden-file encoding use JSONEncoder with sortedKeys, and the signature is computed over those canonical bytes. Add a SwiftPM executable target (riff-tool) in the RiffCore package exposing basescore, hash, stars and simulate, which chartcheck.py calls, so there is one implementation of the rules.

**Outcome: Adopted (D-007, D-009).**

Sources: <https://developer.apple.com/documentation/swift/systemrandomnumbergenerator>, <https://developer.apple.com/documentation/swift/hasher>, <https://developer.apple.com/documentation/swift/dictionary>, <https://developer.apple.com/documentation/foundation/jsonencoder/outputformatting-swift.struct/sortedkeys>

</details>

**Checked and found sound (GAME).**

- Multiplier formula is self-consistent across sections 4, 4.4 and 4.5: x1 for streak 0-9, x2 for 10-19, x3 for 20-29, x4 from 30, x8 cap with Hype.
- Appendix A example numbers are internally consistent under 'streak counted before the note': 412 Perfects = 158,800; plus 40 beats of sustain at x4 = 162,800 (baseScore); 412 x 800 + 40 x 200 = 337,600 (maxScore). The 'after' reading (159,100) cannot reproduce both.
- maxScore as defined (every note Perfect at x8 plus every sustain tick at x8) is a true upper bound on any achievable score under section 4: there is no other point source, the multiplier never exceeds 8 and sustain is capped at hold length.
- Hype arithmetic: 25% per phrase = 8 beats, a full meter = 32 beats = 8 bars of 4/4, the 50% threshold = 16 beats.
- Easy windows are 54 / 108 / 156 ms; with Easy's 400 ms same-lane gap no two windows in a lane overlap (312 &lt; 400).
- The 8.4 peak densities never exceed what the same-lane gaps permit (four lanes allow 10, 16, 26.7 and 44 notes per second against peaks of 3, 5, 7 and 10).
- 7.3 step 4 is sound: judging at UITouch.timestamp (seconds since system startup, per Apple's documentation) removes up to one frame of error, and '8-16 ms' matches 120 Hz and 60 Hz frame times (8.3 and 16.7 ms).
- The 'at least 2 s' lead-in covers the slowest allowed scroll time (2.0 s).
- Sustain is a small, non-exploitable share of score: a 4-beat hold at x4 is 400 points, the same as one Perfect note at x4, and sustain is 2.5% of the example chart's base score.
- Base score ('a perfect run with no Hype') is well defined in the tick domain once a rounding rule exists, because in a perfect run the streak changes exactly at note ticks.
- Accuracy weights equal judgement points / 100, and the four tie-break keys form a total order once 'played first' is read as entry order.

## Audio, clock and latency (AUD)

| ID | Severity | Finding | Check | Outcome |
| --- | --- | --- | --- | --- |
| AUD-1 | major | Audio session policy is never specified; the default session is muted by the Ring/Silent switch | Not re-checked | Owner decision: D-030 |
| AUD-2 | major | The song clock is host-time dead reckoning from a requested T0, and the drift monitor and the "under 2 ms drift" gate are not well defined | Not re-checked | Adopted: D-031 |
| AUD-3 | major | L is defined as hardware latency plus the I/O buffer; with a scheduled start the buffer is already in the timestamp, so this double-counts it | Not re-checked | Device spike decides: D-032 |
| AUD-4 | major | A 16-tap calibration is too noisy for the +/-10 ms Phase 2 gate, and the estimator is unspecified | Not re-checked | Adopted: D-033 |
| AUD-5 | major | Spike S1 tests the least uncertain thing and omits the extension audio-session unknowns; it has no pass/fail rules | Not re-checked | Adopted: D-041 |
| AUD-6 | major | Bluetooth latency is treated as a stable per-route constant, "per-route" is undefined, and AirPlay/HDMI/CarPlay are not handled | Not re-checked | Owner decision: D-034 |
| AUD-7 | major | Visual offset: display latency depends on the refresh rate, and a tap-to-flash test is a poor way to measure it | Not re-checked | Adopted: D-033 |
| AUD-10 | minor | The iOS 27 SDK deprecates the core calls Phase 2 depends on; replacements exist only on iOS 27 | Not re-checked | Adopted: D-036 |
| AUD-11 | minor | Stem and chart alignment depends on one specific AAC encoder path, with no check; the timing test asset should not be AAC at all | Not re-checked | Adopted: D-037 |
| AUD-12 | minor | Reactive feedback (miss duck, tap-click, haptic) is specified without regard to output latency | Not re-checked | Adopted: D-038 |
| AUD-13 | minor | Reading the host clock with mach_absolute_time or systemUptime requires a privacy-manifest entry | Not re-checked | Adopted: D-039 |
| AUD-14 | minor | Autoplay cannot check chart sync "by ear": nothing audible marks the notes | Not re-checked | Adopted: D-040 |
| AUD-8 | minor | Timestamp-based judging plus a per-frame miss sweep can turn a valid late-delivered touch into a miss | Not re-checked | Adopted: D-050 |
| AUD-9 | minor | Pause, resume, interruption and route-change mechanics are named but not specified | Not re-checked | Adopted: D-035 |

<details>
<summary>Full text of the AUD findings</summary>

### AUD-1: Audio session policy is never specified; the default session is muted by the Ring/Silent switch

Severity major · gap · plan sections: 3 (audio latency row), 4.7, 4.8, Phase 2 P2.1, 7.4 (Open to Home under 1 s), Appendix B (previewStartSec)

**The plan says.** P2.1: "Audio engine: one player node per stem plus effects, audio session setup, interruption and route-change handling." No category, options, activation/deactivation timing or silent-switch behaviour appears anywhere in the plan.

**Problem.** If the category is left at the default (soloAmbient) or set to ambient, the Ring/Silent switch silences the song and the game is unplayable for everyone whose phone is on silent. The only category that plays through silent is .playback, which is non-mixable: activating it stops the user's Music/Spotify. That makes activation timing a design decision the plan has not made: activating on extension launch, in compact view, or for song-picker previews (the manifest carries previewStartSec) would kill background music every time the app drawer opens, and failing to deactivate with notifyOthersOnDeactivation leaves it stopped. Activation can also fail (higher-priority session such as a call), and deactivating while the engine runs returns an isBusy error. None of this is listed as a decision or a verify-on-device item.

**Evidence.** AVAudioSession overview: default session behaviour includes "In iOS, setting the Ring/Silent switch to silent mode silences any audio the app is playing". Category.soloAmbient: "The default audio session category. Your audio is silenced by screen locking and by the Silent switch". Category.ambient: "Screen locking and the Silent switch ... silence your audio". Category.playback: "your app audio continues with the Silent switch set to silent ... By default, using this category implies that your app's audio is nonmixable—activating your session will interrupt any other audio sessions which are also nonmixable". AVAudioSession overview note: "it's generally preferable to defer this call until your app begins audio playback". setActive(_:options:): "The session fails to activate if another audio session has higher priority than yours (such as a phone call) ... Deactivating an audio session with running audio objects stops the objects, makes the session inactive, and returns an AVAudioSession.ErrorCode.isBusy error." I found no Apple statement or forum evidence either way about activating a non-mixable playback session from a Messages extension process.

**Reviewer's recommendation.** Add a subsection "7.3a Audio session policy" and a [DECIDE] row. Policy: category .playback, mode .default, no options. Create the engine and touch AVAudioSession lazily when the player taps Play (or explicitly taps a preview), never in willBecomeActive or compact view (also protects the 1 s open budget). On finish, pause, collapse or willResignActive: stop players, stop the engine, then setActive(false, options: .notifyOthersOnDeactivation). Handle a thrown setActive with a visible "Can't start audio right now (on a call?)" state. Before starting, if AVAudioSession.outputVolume == 0 show "Turn the volume up". [DECIDE]: "Game audio plays even when the phone is on silent (recommended)" versus respecting silent and blocking Play with a prompt. Make the extension-side behaviour the first item of spike S1 (see AUD-5).

**Device test.** Inside the Messages extension on a real iPhone, Ring/Silent set to silent and Apple Music playing: tap Play. Expect setCategory(.playback) and setActive(true) to succeed, Music to stop, the song to be audible. Finish or collapse: Music resumes within about 2 s. Repeat while on a phone call: expect a clean error state, no crash.

**Outcome: Owner decision (D-030).**

Sources: <https://developer.apple.com/documentation/avfaudio/avaudiosession>, <https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback>, <https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/soloambient>, <https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/ambient>, <https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive(_:options:)>

### AUD-2: The song clock is host-time dead reckoning from a requested T0, and the drift monitor and the "under 2 ms drift" gate are not well defined

Severity major · design-flaw · plan sections: 7.3 steps 1, 2, 5, 6, Phase 2 P2.3 and Done-when, Phase S1, 15 intro (drift threshold), 7.2 (SongClock in RiffMessages/Audio)

**The plan says.** "t_song(t) = (t - T0) - L - delta_audio"; "Once per second, the clock estimate is compared with the player node's rendered sample time; drift over 3 ms is corrected gradually"; "Pause and resume re-anchor T0"; done when "drift stays under 2 ms over 3 minutes".

**Problem.** Four separate problems. (a) (t - T0) runs on the host clock from the start time that was requested, not the one realized, so it is not the audio clock the plan says is the source of truth. The two clocks skew: 2 ms over 180 s is 11 ppm; a 50 to 100 ppm DAC or Bluetooth clock gives 9 to 18 ms over 3 minutes. So the gate either fails for hardware reasons the code cannot fix, or (if measured after correction) tests the monitor against itself. (b) The "rendered sample time" (lastRenderTime) advances in I/O-buffer steps: 256 to 1024 frames is 5.3 to 21.3 ms at 48 kHz. Compared naively against a continuous host clock once per second it shows a 0 to 21 ms sawtooth, larger than the 3 ms threshold, so the monitor would chase noise. It is only meaningful when evaluated at lastRenderTime.hostTime. (c) When audio stops (interruption, hardware format change) the formula keeps advancing until a notification handler runs, so the miss sweep scores misses against silence. (d) The resume formula has no term for the resume position. Also, S1 says "log drift" without saying between what; two players on one engine cannot drift from each other.

**Evidence.** Computed: 2e-3/180 = 11.1 ppm; 50 ppm x 180 s = 9 ms; 100 ppm x 180 s = 18 ms; 1024/48000 = 21.3 ms, 256/48000 = 5.3 ms. AVAudioTime docs: a time is represented "As host time, using the system's basic clock with mach_absolute_time()" and "As audio samples at a particular sample rate". AVAudioPlayerNode docs: the player timeline is superimposed on node sample times and playerTime(forNodeTime:) returns "nil if the player isn't playing". AVAudioEngineConfigurationChangeNotification: on a hardware channel-count or sample-rate change "the audio engine stops, uninitializes itself, and issues this notification". setPreferredIOBufferDuration docs: typical maximum buffer 0.093 s, minimum about 0.005 s. A 2017 forum report (thread 93917, unanswered) describes host-time scheduling producing silence, so the realized start should be measured, not assumed.

**Reviewer's recommendation.** Rewrite 7.3 steps 2 and 5 as a sample-anchored clock. Each frame: n = player.lastRenderTime, p = player.playerTime(forNodeTime: n); o = segmentStartSec + p.sampleTime/p.sampleRate - AVAudioTime.seconds(forHostTime: n.hostTime). Keep a filtered offset ô that slews at most 0.2 ms per frame toward o and snaps (and counts a glitch) if |o - ô| > 50 ms. t_song(t) = t + ô - L - delta. During the lead-in, before the first valid pair, use the requested T0. Stall rule: if lastRenderTime is nil, the player is not playing, or now - n.hostTime > 2 x ioBufferDuration + 50 ms, freeze the clock and enter Paused. Put the filter, stall rule and pause/resume mapping in RiffCore as a pure ClockModel fed with (hostSeconds, sampleTime, sampleRate) so it is unit-tested in CI; keep only the AVFoundation adapter in RiffMessages/Audio. Replace the gate with: over 3 minutes on each route, |SongClock - sample-time truth| evaluated at render-pair instants is under 1 ms at p99 with zero unflagged discontinuities; raw host-versus-sample skew is logged in ppm and not gated. Replace the 3 ms drift threshold in GameConfig with the slew and snap constants.

**Device test.** S1 logs (hostTime, sampleTime) pairs from player.lastRenderTime / playerTime(forNodeTime:) at 10 Hz for 3 minutes on speaker, wired adapter and AirPods. Report: realized start minus requested T0 in ms, skew in ppm, step size in frames, and whether playerTime is non-nil and negative between play(at:) and T0 (the lead-in clock depends on it).

**Outcome: Adopted (D-031).**

Sources: <https://developer.apple.com/documentation/avfaudio/avaudioplayernode>, <https://developer.apple.com/documentation/avfaudio/avaudiotime>, <https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification>, <https://developer.apple.com/documentation/avfaudio/avaudiosession/setpreferrediobufferduration(_:)>, <https://developer.apple.com/forums/thread/93917>

### AUD-3: L is defined as hardware latency plus the I/O buffer; with a scheduled start the buffer is already in the timestamp, so this double-counts it

Severity major · factual-error · plan sections: 7.3 step 2, Phase 2 P2.1 ("plus effects"), 11 Diagnostics report

**The plan says.** "subtracts the output latency L (hardware latency plus I/O buffer, read from the audio session)".

**Problem.** Audio that is started against a render timestamp (play(at:) with a host time) leaves the device at that timestamp plus the device and stream latency. The I/O buffer length is already accounted for in the timestamp. Adding ioBufferDuration to L over-compensates by 5.3 to 21.3 ms (the usual default buffer is about 1024 frames, roughly half the +/-45 ms Perfect window). Calibration would hide it as a negative offset, but uncalibrated play is biased and the stored offset then silently depends on the granted buffer size, which is only a preference (16 ms difference between 256 and 1024 frames at 48 kHz). L as defined also ignores processing latency of any effect unit placed after the stem players.

**Evidence.** AVAudioNode.h (iOS SDK header): outputPresentationLatency of the output node is "the presentation latency of the device itself when rendering to an audio device (see AVAudioIONode(presentationLatency))"; for a node connected directly to it, "the output node's presentation latency plus the output node's processing latency"; and "it is recommended not to cache this value". AVAudioIONode.presentationLatency: "This corresponds to kAudioDevicePropertyLatency and kAudioStreamPropertyLatency". No buffer term in either. Apple Developer Forums thread 25197 (poster theanalogkid): "The timestamp you see at the render proc. account for the buffer frame size and the safety offset but the stream and device latencies are not accounted for." The forum post is a secondary source and I could not measure iOS behaviour, hence medium confidence.

**Reviewer's recommendation.** Change step 2 to: L = player.outputPresentationLatency, falling back to AVAudioSession.outputLatency if it reports 0; read it after the engine starts and again on every route or configuration change; do not add ioBufferDuration. ioBufferDuration is added only when estimating latency of unscheduled play-now sounds (tap-click). State that no latency-bearing effect unit sits between a stem player and the main mixer ("effects" in P2.1 means separate SFX players). The Diagnostics report prints outputLatency, outputPresentationLatency, granted ioBufferDuration and hardware sample rate as separate fields.

**Device test.** Differential test that cancels human bias: same person, same sitting, built-in speaker. Run a 32-tap click test with preferredIOBufferDuration 0.005 and again with 0.023 (log the granted values), alternating three times, computing offsets with L = outputLatency only. Medians agreeing within +/-5 ms confirm the buffer does not belong in L; a shift close to the buffer difference (about 16 ms) means it does.

**Outcome: Device spike decides (D-032).**

Sources: <https://raw.githubusercontent.com/theos/sdks/master/iPhoneOS16.5.sdk/System/Library/Frameworks/AVFAudio.framework/Headers/AVAudioNode.h>, <https://developer.apple.com/documentation/avfaudio/avaudionode/outputpresentationlatency>, <https://developer.apple.com/documentation/avfaudio/avaudioionode/presentationlatency>, <https://developer.apple.com/forums/thread/25197>

### AUD-4: A 16-tap calibration is too noisy for the +/-10 ms Phase 2 gate, and the estimator is unspecified

Severity major · design-flaw · plan sections: Phase 2 P2.5, Phase 2 Done-when, 7.3 step 2, 1 (Fair timing pillar), P7.1

**The plan says.** "Latency calibrator: tap-along audio test (16 taps, trimmed mean)" and done when "the mean tap offset on the click track is within +/-10 ms on speaker and wired".

**Problem.** The measuring instrument is a person. With per-tap scatter of 25 to 35 ms (ordinary for casual players) a 16-tap trimmed mean has a standard error of 6.5 to 9.1 ms. The gate then compares a second noisy run against the first, so a perfectly correct build passes only 73% (sigma 25), 57% (sigma 35) or 46% (sigma 45) of the time: the gate is flaky and cannot tell a 10 ms bug from noise. 2 to 10% of calibrations land more than 15 ms wrong. People also tap ahead of a metronome by tens of milliseconds, so the result is person plus device and may not match the same person's bias when reading a note highway. On built-in routes, where the reported latency may already be accurate to a few ms, a mandatory noisy calibration can make timing worse than the default. The plan gives no rules for warm-up taps, missed or extra taps, rejecting a sloppy run, or period aliasing (an offset beyond half the click period is ambiguous).

**Evidence.** Monte Carlo, 200,000 trials, script at /tmp/claude-0/-home-user-imessage-jam-sessions/1091d72a-dedf-55f2-8d6c-c68b0ba05340/scratchpad/review/calib.py. 16 taps, trim 2 each side: SE 6.47 ms (sigma 25), 9.07 ms (sigma 35), 11.66 ms (sigma 45); P(|post-calibration mean| &lt;= 10 ms) = 0.73, 0.57, 0.46; P(|calibration error| > 15 ms) = 2.1%, 9.8%, 19.9%. With 32 taps: SE 4.57 ms (sigma 25), 6.43 ms (sigma 35). Sensorimotor-synchronization literature (Repp and Su 2013 review; a 2022 preprint) describes taps "typically preceding the metronome by tens of milliseconds".

**Reviewer's recommendation.** Specify the estimator as pure code in RiffCore with tests: click period at least 600 ms (100 BPM) so +/-300 ms is unambiguous; 4 warm-up clicks discarded, then 32 scored; each tap matched to its nearest click; estimate = median (or 25% trimmed mean); reject and re-prompt if fewer than 24 matched taps or robust SD above 40 ms; clamp to +/-300 ms; show the number with "test again". Replace the Phase 2 gate with: (i) the automated clock gate from AUD-2; (ii) the mean of three separate 32-tap validation runs within +/-10 ms on speaker and wired; (iii) the 240 fps capture check from AUD-7. Add a post-run suggestion: after any run with 30 or more judged hits, if |median signed error| exceeds 15 ms, offer a one-tap "Adjust by X ms". First run: require the tap test only on wireless or unknown routes; on speaker and wired use defaults derived from S1 and let the post-run suggestion refine them.

**Outcome: Adopted (D-033).**

Sources: <https://link.springer.com/article/10.3758/s13423-012-0371-2>

### AUD-5: Spike S1 tests the least uncertain thing and omits the extension audio-session unknowns; it has no pass/fail rules

Severity major · gap · plan sections: Phase S (S1, S4, Done-when), 11 (Timing row, Diagnostics report), 13 (Timing risk row), 15.F ("verify on device")

**The plan says.** "S1 Audio sync: start backing and stem at one host time, log drift for 3 minutes, and run a tap-along test on speaker, wired and AirPods." "Done when: you paste the Diagnostics report from each test device back to me. Any blocker changes the plan before Phase 3."

**Problem.** Two players on one AVAudioEngine share one sample clock, so stem-to-stem drift is zero by construction; S1 as written mostly confirms that. What is genuinely unknown, and existential for the product, is not in S1 or in any verify-on-device note: whether a Messages extension process can activate a non-mixable playback session and run a 90 s song; what happens to it on compact/collapse, app switch and lock; whether interruption, route-change and engine configuration notifications reach the extension; what I/O buffer is granted; which start-time form works and how accurately. "Drift" is undefined, "wired" is undefined on phones with no headphone jack, and with no thresholds a pasted report cannot say whether a blocker exists.

**Evidence.** Plan text as quoted; the only device-verification items named in the plan are haptics, 120 Hz, participant names/IDs and bubble taps. Web and Apple-forum searches found no documentation or reports on AVAudioSession activation from a Messages extension (keyboard and notification-service extensions do report setActive failures, error 561015905), so this is unverified rather than known-good.

**Reviewer's recommendation.** Rewrite S1 as a checklist run inside the extension target, each line with a threshold. S1.1 Session: results of AUD-1's test in expanded and compact; behaviour on collapse, app switch, lock, incoming call (banner and full screen), Siri, alarm; a log of which notifications fired (interruption, iOS 27 lifecycle, routeChange, AVAudioEngineConfigurationChange, NSExtensionHostWillResignActive, MSMessagesAppViewController callbacks). S1.2 Scheduling: play(at:) with a host-time-only AVAudioTime versus a sample-time one; realized start error under 1 ms; both players report identical player sample time at the same node time. S1.3 Clock log per AUD-2. S1.4 Per-route latency fields and the differential buffer test from AUD-3. S1.5 Tap test, 32 taps x 3, per route, at least two people. Decision rules written in the plan: session cannot activate in the extension means stop and re-plan before any other phase; median residual on speaker within +/-15 ms across devices means no mandatory calibration on built-in routes; realized start error above 1 ms means anchor only on render pairs. Name the wired device (Apple USB-C or Lightning 3.5 mm adapter, or wired EarPods). Extend the Diagnostics report with: session category, hardware and file sample rates, granted ioBufferDuration, outputLatency, outputPresentationLatency, port type plus a hash of the port UID, skew ppm, glitch count, realized start error.

**Device test.** The checklist above, run on at least two iPhones (oldest supported and current) inside Messages.

**Outcome: Adopted (D-041).**

Sources: <https://developer.apple.com/forums/thread/709107>, <https://developer.apple.com/forums/thread/110458>

### AUD-6: Bluetooth latency is treated as a stable per-route constant, "per-route" is undefined, and AirPlay/HDMI/CarPlay are not handled

Severity major · risk · plan sections: 3 (audio latency row), 7.5 (per-route offsets in settings.json), Phase 2 P2.5, 13 (Bluetooth latency complaints), 11 (device matrix)

**The plan says.** "per-route calibration, a Bluetooth warning"; "Detect the route, apply a default offset, prompt to calibrate, suggest speaker or wired for best scores"; "Bluetooth defaults and warning".

**Problem.** (1) Developer reports indicate AirPods latency moves while iOS keeps reporting about 160 ms: one measured 215 to 220 ms right after connecting, decaying to 155 to 160 ms over 20 to 30 minutes; another saw the reported value stay at 160 ms while the system changed the real in-ear latency from 151 ms to 60 ms. A 55 to 65 ms swing is larger than the +/-45 ms Perfect window, so a calibration from minute 1 is wrong at minute 20 and "prompt to calibrate" does not fix it. (2) "Per-route" is not defined: one stored offset for every bluetoothA2DP device is wrong because latency differs per headset. (3) "Apply a default offset" on top of an L that already contains iOS's Bluetooth estimate double-counts unless the default is defined as a residual. (4) AirPlay can add about 2 s, and HDMI or car outputs add unknown processing delay; the plan's lead-in, miss duck and tap-click make no sense there and nothing blocks them.

**Evidence.** Apple Developer Forums thread 679274 (iPhone 12 mini, AirPods 2): "session.outputLatency // 160.667ms"; "the actual measured latency is ca 215-220ms at first, but it is continuously decreasing over time. After about 20-30mins ... around 155-160ms". Thread 764070: kAudioDevicePropertyLatency "seems to always report 160ms for AirPods" while system logs show "latency 151MSec" then "latency 60MSec". Both are single-developer reports with no Apple reply. AVAudioSession.outputLatency docs: "Using an AirPlay-enabled device for your audio content can result in a 2-second delay. Check for this delay in game content." AVAudioSessionPortDescription.uid: "A system-assigned unique identifier (UID) for the port."

**Reviewer's recommendation.** Add a route table to section 7.3. Classes: built-in (builtInSpeaker), wired (headphones, usbAudio), wireless (bluetoothA2DP, bluetoothLE), unsupported (airPlay, HDMI, carAudio and anything unrecognized). Store offsets keyed by portType for built-in and by portType + port UID for wired and wireless. The default offset for every class is 0 residual on top of the reported L; add a Bluetooth constant only if S1 data shows a consistent residual. Wireless: non-blocking banner ("Wireless audio: timing can drift; speaker or wired is best"), an 8-click quick check offered before a duel run when that UID's calibration is older than 10 minutes or the device just connected, plus the post-run suggestion from AUD-4. Unsupported: block Play with an explanation. Add a [DECIDE]: whether wireless runs may use slow in-run adaptive offset (at most 0.5 ms per hit toward the running median error) in duels. Device matrix adds one non-Apple Bluetooth headset.

**Device test.** Freshly connected AirPods: run the 32-tap test at 0, 5, 15 and 30 minutes of continuous connection, logging outputLatency each time. A spread of medians above 20 ms with a constant reported value confirms the instability.

**Outcome: Owner decision (D-034).**

Sources: <https://developer.apple.com/forums/thread/679274>, <https://developer.apple.com/forums/thread/764070>, <https://developer.apple.com/documentation/avfaudio/avaudiosession/outputlatency>, <https://developer.apple.com/documentation/avfaudio/avaudiosessionportdescription/uid>

### AUD-7: Visual offset: display latency depends on the refresh rate, and a tap-to-flash test is a poor way to measure it

Severity major · design-flaw · plan sections: 7.3 step 3, Phase 2 P2.5 (visual flash test), 7.4 (frame rate row), P7.2 (offsets), Phase S3

**The plan says.** "Each frame places notes using the song time plus a visual offset from calibration." P2.5: "visual flash test".

**Problem.** (1) The delay from the frame callback to light leaving the panel is a number of frame intervals, not a per-user constant. The same phone runs at 8.3 ms per frame at 120 Hz and 16.7 ms at 60 Hz (Low Power Mode, thermal limits, or the extension not being granted 120 Hz, which the plan itself marks unverified), so a single stored offset is wrong by roughly 8 to 17 ms whenever the rate changes. (2) Synchronizing taps to flashes is known to be much more variable than to sound, and the result also contains touch latency and a different personal bias from the audio test; the plan does not say how the two test results combine into one visual offset. (3) SKScene.update's currentTime is the frame's start time, not when the frame is seen, so "song time at update" is already about two frames stale at display.

**Evidence.** SKScene.update(_:) docs: currentTime is "The current system time". UIUpdateInfo.estimatedPresentationTime (iOS 18+): "an estimate for when current UI update changes become visible onscreen". UIUpdateLink.wantsImmediatePresentation docs say opting in makes the frame present "one frame duration sooner", which implies at least one extra frame by default. CADisplayLink.targetTimestamp: "when the next frame displays". Forum thread 736327 (single developer, unverified) reports about two frames (33 ms) input-to-draw on a 60 Hz iPhone and one 120 Hz frame on iPhone 14 Pro. Literature search: "synchronization of finger taps with periodically flashing visual stimuli is known to be much more variable than synchronization with an auditory metronome". Frame arithmetic: 1000/60 = 16.7 ms, 1000/120 = 8.3 ms. The exact pipeline depth for a SpriteKit view inside a Messages extension is not documented, hence medium confidence.

**Reviewer's recommendation.** Change step 3 to: notes are drawn at t_song(presentationTime) + visualTrim, where presentationTime is UIUpdateInfo.current(for: view).estimatedPresentationTime on iOS 18 and later, otherwise the latest CADisplayLink.targetTimestamp plus one measured frame interval (a display link kept alongside the SKView supplies it). Remove the flash-tap test from P2.5. Keep a visual trim slider (+/-50 ms, default 0) with a live preview: click track with scrolling notes and the instruction "slide until the note crosses the line on the click". Store only the trim. The debug HUD shows the measured frame interval. Add the capture test below to S3 and to the Phase 2 gate.

**Device test.** Autoplay the click track with a full-width strike-line flash on every note and an audible tick scheduled at each note's sample time (AUD-14). Film the screen and speaker with a second iPhone at 240 fps. With trim 0, flash and tick must coincide within +/-2 video frames (about +/-8 ms) at 120 Hz and again at 60 Hz (turn on Low Power Mode).

**Outcome: Adopted (D-033).**

Sources: <https://developer.apple.com/documentation/uikit/uiupdateinfo/estimatedpresentationtime>, <https://developer.apple.com/documentation/uikit/uiupdatelink/wantsimmediatepresentation>, <https://developer.apple.com/documentation/spritekit/skscene/update(_:)>, <https://developer.apple.com/documentation/quartzcore/cadisplaylink/targettimestamp>, <https://developer.apple.com/forums/thread/736327>

### AUD-10: The iOS 27 SDK deprecates the core calls Phase 2 depends on; replacements exist only on iOS 27

Severity minor · risk · plan sections: 7.1 (Audio row; Minimum iOS 17.0), Phase 2 P2.1, P2.2, 4.8 (haptic), 12 (current Xcode)

**The plan says.** "AVAudioEngine, one player node per stem", "Synchronized start at a host time", minimum iOS 17.0, built with "current Xcode".

**Problem.** Built against the iOS 27 SDK, the plan's audio code hits deprecations on its central calls, and the replacements are throwing methods available only from iOS 27, so a 17.0 deployment target needs both paths. A project configured to treat warnings as errors will not build. The older non-throwing calls signal misuse (for example starting a player while the engine is not running) with Objective-C exceptions that Swift cannot catch, which would crash the extension during the resume and interruption flows.

**Evidence.** Apple documentation JSON, checked 2026-11-14: AVAudioPlayerNode.play(at:) and play() have deprecatedAt 27.0 on iOS; playAudio(at:) ("func playAudio(at when: AVAudioTime?) throws") and playAudio() are introduced in iOS 27.0. AVAudioEngine.connect(_:to:format:) deprecatedAt 27.0; connectNode(_:to:format:) throws, iOS 27.0+. AVAudioNode.installTap(onBus:bufferSize:format:block:) is marked deprecated. UIImpactFeedbackGenerator.init(style:) deprecatedAt 27.0; init(style:view:) is iOS 17.5+. AVAudioSession.didBecomeInactiveNotification, resumptionRecommendationNotification and activate(options:) are iOS 27.0+; on iOS the legacy interruptionNotification is not yet marked deprecated (only on visionOS 27), but Apple's article says later releases will deprecate it.

**Reviewer's recommendation.** Add RiffMessages/Audio/AudioCompat.swift with small throwing wrappers: startPlayer(_:at:) and connect(_:to:format:) use the iOS 27 API under if #available(iOS 27, *), otherwise the old call guarded by an engine.isRunning check that throws a Swift error instead of reaching the exception. Haptics use init(style:view:) on 17.5+ and init(style:) below. Observe the iOS 27 lifecycle notifications under #available and the legacy notification otherwise. Do not use installTap for the clock. In project.yml do not enable warnings-as-errors for deprecations. Record this in docs/DECISIONS.md.

**Outcome: Adopted (D-036).**

Sources: <https://developer.apple.com/documentation/avfaudio/avaudioplayernode/play(at:)>, <https://developer.apple.com/documentation/avfaudio/avaudioplayernode/playaudio(at:)>, <https://developer.apple.com/documentation/avfaudio/avaudioengine/connectnode(_:to:format:)>, <https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator/init(style:view:)>, <https://developer.apple.com/documentation/avfaudio/avaudiosession/didbecomeinactivenotification>, <https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions>

### AUD-11: Stem and chart alignment depends on one specific AAC encoder path, with no check; the timing test asset should not be AAC at all

Severity minor · risk · plan sections: 8.2, 8.5, Phase 5 P5.1, P5.2, Appendix B (stems, audioOffsetMs)

**The plan says.** "WAV at 44.1 or 48 kHz ... all the same length and start point"; "Encoded to AAC (.m4a) on the Mac with afconvert"; 8.5: "Placeholder content I can make now: Click track".

**Problem.** (1) AAC files start with priming frames. Apple's reader removes them as the file declares, and assumes 2112 samples when the file does not say. A stem encoded by anything other than the planned afconvert step (the sandbox, which has no afconvert, or a composer's export) can therefore decode shifted against the other stem and the chart by an encoder-dependent amount; a 1024-sample encoder delay read as 2112 is 1088 samples, 24.7 ms at 44.1 kHz or 22.7 ms at 48 kHz. Nothing in chartcheck or the tests would catch it. (2) The click track is the reference for every timing test, yet it is generated where afconvert cannot run, so it would be either PCM or encoded by a different encoder. (3) "44.1 or 48 kHz" lets two stems of one song differ in rate, and nothing asserts equal rate and frame count.

**Evidence.** Apple TN2258: "With ExtAudioFile, priming and remainder values are read from the file (if present) and those samples are removed from the decoded bitstream automatically on behalf of the client. If these values are not present in the file, the default values are used" and "The default setting for AAC priming is 2112 samples"; "The encoding delay for an AAC encoder is implementation dependent." Computed: (2112 - 1024)/44100 = 24.7 ms; /48000 = 22.7 ms. That AVAudioFile reads through ExtAudioFile, and the 1024-sample figure for a non-Apple encoder, are from memory and not verified here. AVAudioPlayerNode docs: "It's preferable to configure the node's output sample rate to match that of the files, and to use a mixer to perform the rate conversion."

**Reviewer's recommendation.** In 8.2: all shipped audio is 48 kHz stereo AAC-LC (no HE-AAC), produced only by a scripted Mac step, tools/encode_audio.sh, wrapping afconvert. Add a macOS test (or a chartcheck step run on the Mac) that opens each .m4a with AVAudioFile and asserts: both stems have the same sample rate and identical length equal to the source WAV frame count, and the cross-correlation peak against the source WAV is at lag 0 (+/-1 sample). The click track and calibration clicks are synthesized into AVAudioPCMBuffers at run time (or shipped as mono 48 kHz 16-bit PCM, about 5.8 MB per minute, test builds only), never AAC. Connect each player to the mixer with file.processingFormat.

**Outcome: Adopted (D-037).**

Sources: <https://developer.apple.com/library/archive/technotes/tn2258/_index.html>, <https://developer.apple.com/documentation/avfaudio/avaudioplayernode>

### AUD-12: Reactive feedback (miss duck, tap-click, haptic) is specified without regard to output latency

Severity minor · design-flaw · plan sections: 4.4, 4.8, Phase 2 P2.4

**The plan says.** "A miss ducks the instrument stem for about 300 ms"; "an optional tap-click helps in practice"; "A light haptic on Perfect, on by default".

**Problem.** These react to events, so they cannot be scheduled ahead: the player hears them at decision time plus up to one I/O buffer plus L. A miss is only known 130 ms after the note, so the duck is heard roughly 150 to 190 ms after the missed note on the speaker and 290 to 350 ms after it on AirPods. A fixed 300 ms duck then covers the next 2 to 3 notes at 7 to 10 notes per second, muting notes the player hit. A tap-click on Bluetooth arrives 160 to 220 ms after the tap, which is a misleading timing cue in a mode meant for practice. The haptic only has low latency if the generator was prepared in advance, and the Taptic Engine goes idle after each trigger.

**Evidence.** Computed: 130 ms + L(160..220 ms) = 290..350 ms; 0.3 s x 7 notes/s = 2.1 notes, x 10 = 3 notes. UIFeedbackGenerator.prepare() docs: "Calling prepare() and then immediately triggering feedback (without any time in between) does not improve latency" and "After feedback is triggered, the Taptic Engine returns to its idle state. If you might trigger additional feedback within the next few seconds, immediately call prepare()".

**Reviewer's recommendation.** Duck rule in 4.8 and P2.4: on a miss, ramp the stem to about 15% gain over 15 ms and hold until the next successful hit on any lane (minimum 120 ms, maximum 600 ms), then ramp back over 30 ms. Tap-click: offered only on built-in and wired routes when L + ioBufferDuration is under 40 ms; request a 5 ms I/O buffer while it is enabled. Haptic: one generator created with the game view, prepare() at song start and again immediately after each impact, at most one impact per 60 ms.

**Outcome: Adopted (D-038).**

Sources: <https://developer.apple.com/documentation/uikit/uifeedbackgenerator/prepare()>

### AUD-13: Reading the host clock with mach_absolute_time or systemUptime requires a privacy-manifest entry

Severity minor · gap · plan sections: 7.3, Phase 0 P0.2, Phase 8 P8.2

**The plan says.** P8.2: "Privacy manifest, a 'Data Not Collected' privacy label and the age rating." The timing model needs the current host time every frame.

**Problem.** The obvious ways to read "now" on the host timebase, mach_absolute_time() and ProcessInfo.systemUptime, are required-reason APIs. An upload whose binary uses them without a declared reason is flagged by App Store Connect. The manifest must sit in the bundle whose executable makes the call (the extension), and leaving it to Phase 8 means TestFlight uploads in Phase S trip on it first.

**Evidence.** Apple, Describing use of required reason API: "apps that don't describe their use of required reason API in their privacy manifest file aren't accepted by App Store Connect". NSPrivacyAccessedAPIType reference, category NSPrivacyAccessedAPICategorySystemBootTime lists exactly systemUptime and mach_absolute_time(); reason 35F9.1 covers measuring "the amount of time that has elapsed between events that occurred within the app". CACurrentMediaTime() is documented as "derived by calling mach_absolute_time()" and is not on the list.

**Reviewer's recommendation.** In the clock code use CACurrentMediaTime() with AVAudioTime.hostTime(forSeconds:) and AVAudioTime.seconds(forHostTime:); do not call mach_absolute_time or systemUptime directly. If either is used anyway, add NSPrivacyAccessedAPICategorySystemBootTime with reason 35F9.1 to the extension's PrivacyInfo.xcprivacy. Create the privacy manifest in P0.2 so the first TestFlight build already carries it.

**Outcome: Adopted (D-039).**

Sources: <https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api>, <https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype>, <https://developer.apple.com/documentation/quartzcore/cacurrentmediatime()>

### AUD-14: Autoplay cannot check chart sync "by ear": nothing audible marks the notes

Severity minor · gap · plan sections: 8.3 step 5, Phase 3 P3.6, Phase 5 P5.4, 4.8 (no hit sounds)

**The plan says.** "Autoplay in a debug build plays the chart perfectly against the audio to check sync by eye and ear." 4.8: "No hit sounds by default".

**Problem.** Autoplay makes no sound of its own, so there is nothing to compare by ear. By eye it compares the chart with the display path and whatever visual offset is set, not with the audio. A tap-click fired from the game loop is quantized to frames and I/O buffers, so it cannot serve as a precise marker either. Chart-to-audio offset errors of 10 to 30 ms would pass this QA step.

**Evidence.** Plan text as quoted. AVAudioPlayerNode docs: scheduling methods take a `when` time and "If the when parameter is a sample time, the parameter interprets it as such", so a tick can be placed on an exact sample of the player timeline.

**Reviewer's recommendation.** Add an assist tick to P2.1 and P3.6: a third player node schedules a short PCM tick at each note's exact sample time on the same start anchor as the stems (scheduleBuffer(_:at:) with a sample-time AVAudioTime), independent of display and touch. Chart QA in 8.3 step 5 and P5.4 becomes "the tick lands on the instrument's attack". Also add an offline option to chartcheck: mix ticks into the backing WAV at chart times and write a preview file, so charts can be checked on any computer before a device build. The same tick is the audio marker for the capture test in AUD-7.

**Outcome: Adopted (D-040).**

Sources: <https://developer.apple.com/documentation/avfaudio/avaudioplayernode>

### AUD-8: Timestamp-based judging plus a per-frame miss sweep can turn a valid late-delivered touch into a miss

Severity minor · design-flaw · plan sections: 4.3 (miss rule), 7.3 step 4, 7.4 (Touch to judgement: same frame), Phase 1 P1.3 (miss sweep), Phase 3 P3.3, 11 (Determinism row)

**The plan says.** "Each touch is judged at the song time of its hardware timestamp, not the frame that processed it" and "A note still unhit 130 ms after its time becomes a Miss."

**Problem.** Judging by timestamp means input arrives from the past. Touches reach the app about once per display frame, later after a main-thread hitch. If the frame's miss sweep (driven by current song time) runs before a pending touch is delivered, a touch whose timestamp is inside the window finds its note already marked Miss and becomes a ghost tap: a false miss, a streak reset and a stem duck. Example: touch stamped at note +125 ms, delivered 8 to 17 ms later, after the +130 ms sweep. The same undefined ordering makes the planned record-and-replay determinism test ambiguous. The plan also does not say that input must come from UIKit touch callbacks; SwiftUI gestures do not expose the hardware timestamp, and a view receives only one touch unless isMultipleTouchEnabled is set, which chords need.

**Evidence.** Reasoning from the plan's own rules. Frame intervals: 16.7 ms at 60 Hz, 8.3 ms at 120 Hz. UITouch.timestamp docs: "the time, in seconds since system startup, that the touch originated or was last changed". UIView.isMultipleTouchEnabled docs: "The default value of this property is false."

**Reviewer's recommendation.** Define the ordering in RiffCore: GameSession.advance(inputs:to:) takes inputs sorted by timestamp, applies every input with timestamp at or before the target song time first, then sweeps misses only for notes with time + window &lt; songTime - inputGrace, with inputGrace = 2 frame intervals (config value, 34 ms at 60 Hz). Miss feedback appears at most 34 ms later; scores are unchanged. InputController queues UITouch began/ended events from UIKit handlers on the SpriteKit view (set isMultipleTouchEnabled = true in didMove(to:)) and the scene's update drains the queue before advancing. Add a golden test: a touch at +125 ms delivered after a 150 ms stall is judged Good, not Miss. Diagnostics logs delivery delay (CACurrentMediaTime() - touch.timestamp) at p50 and p99.

**Outcome: Adopted (D-050).**

Sources: <https://developer.apple.com/documentation/uikit/uitouch/timestamp>, <https://developer.apple.com/documentation/uikit/uiview/ismultipletouchenabled>

### AUD-9: Pause, resume, interruption and route-change mechanics are named but not specified

Severity minor · gap · plan sections: 4.7, 7.3 step 6, Phase 2 P2.1, P2.2, Phase 4 P4.5 (collapse mid-song)

**The plan says.** "Collapsing the view, a call, Siri or leaving Messages pauses at once. Resume shows a 3-beat countdown and restarts audio in sync." "Pause and resume re-anchor T0."

**Problem.** The details that decide whether "in sync" holds are missing. (1) The pause triggers omit route loss and hardware format change: the engine stops itself on a sample-rate or channel-count change, and since iOS 17 a route disconnect interrupts the session by default. Alarms, host-app resign-active (Control Center, app switcher) and media-services reset are also absent. (2) No method is given for restarting at a position; relying on pause()/play() after the engine has stopped is fragile. (3) Deactivating the session while the engine runs returns isBusy. (4) A suspended process receives its interruption notice only after it runs again, and Messages may terminate the extension while collapsed or backgrounded, so the paused run may not exist on return. (5) A 3-beat countdown is 1.0 s at 180 BPM, shorter than a Bluetooth link may need to restart cleanly. (6) iOS 27 adds session lifecycle notifications that Apple recommends for new code; iOS 17 to 26 need the legacy one.

**Evidence.** AVAudioEngineConfigurationChangeNotification: "the audio engine stops, uninitializes itself, and issues this notification. The nodes remain in an attached and connected state". prefersInterruptionOnRouteDisconnect (iOS 17+): "The default value is true". interruptionNotification: "the system deactivates an app's audio session when it suspends the app process ... This notification is necessarily delayed in time". Handling audio interruptions: "In iOS 27 ... AVAudioSession posts a set of life-cycle notifications ... Adopt these notifications for new code". ExtAudioFileSeek: a subsequent read "returns samples from precisely this location, even if it is located in the middle of a packet" (sample-accurate restart from AAC is feasible). AVAudioPlayerNode.stop(): "returns the player timeline to sample time 0". 3 beats at 180 BPM = 1.0 s, at 128 BPM = 1.41 s. Forum thread 679274 describes Bluetooth start-up behaviour. Engine and player state after an interruption inside an extension is not documented.

**Reviewer's recommendation.** Specify one path, suspendRun(reason), called from: willTransition(to: .compact), willResignActive(with:), NSExtensionHostWillResignActive, interruption began (legacy) or didBecomeInactive (iOS 27, under #available), routeChange, AVAudioEngineConfigurationChange, mediaServicesWereReset, and the clock stall rule from AUD-2. It records p = current heard song time, stops both players, stops the engine, then setActive(false, .notifyOthersOnDeactivation). Resume only on a user tap: setActive(true); engine.start(); re-read L and pick the offset for the current route; for each stem scheduleSegment(file, startingFrame: round(p x fileSampleRate), frameCount: remaining, at: nil); prepare; start both with one AVAudioTime at now + max(3 beats, 1.5 s); set the clock's segmentStartSec = p. Countdown ticks are PCM buffers scheduled on a third player against the same anchor, not UI timers. State in 4.7 that a run lost to process termination is discarded ("Run interrupted, play again") and nothing is persisted mid-run.

**Device test.** Mid-song on a real iPhone: remove AirPods; plug in a wired adapter; receive a call (banner style and full screen); invoke Siri; let an alarm fire; collapse to compact; switch apps for 30 s and return. Each must reach the pause screen within about 200 ms with no misses scored during silence, and after resume the AUD-2 probe shows clock error under 2 ms and the assist tick still lands on the notes.

**Outcome: Adopted (D-035).**

Sources: <https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification>, <https://developer.apple.com/documentation/avfaudio/avaudiosession/prefersinterruptiononroutedisconnect>, <https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification>, <https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions>, <https://developer.apple.com/documentation/audiotoolbox/extaudiofileseek(_:_:)>, <https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nsextensionhostwillresignactive>

</details>

**Checked and found sound (AUD).**

- One timebase for touches, frames and audio: UITouch.timestamp is seconds since system startup (same definition as ProcessInfo.systemUptime), CACurrentMediaTime() is derived from mach_absolute_time(), and AVAudioTime host time uses mach_absolute_time(); AVAudioTime.seconds(forHostTime:) and hostTime(forSeconds:) convert between them. Step 4 of 7.3 is feasible as written.
- Judging each touch at its hardware timestamp instead of the frame that processed it is the right design and does remove up to one frame of error (8.3 ms at 120 Hz, 16.7 ms at 60 Hz).
- Two AVAudioPlayerNodes on one AVAudioEngine started with the same AVAudioTime give a sample-aligned start of backing and stem, and a host-time-only AVAudioTime is honoured (docs: a host time is used when the sample time is invalid and the engine renders to a device).
- Streaming from disk with scheduleFile/scheduleSegment is the right memory choice: decoding two 90 s stereo stems to float PCM would take 63.5 MB at 44.1 kHz (69.1 MB at 48 kHz), 85 to 92 MB for 120 s songs.
- AAC .m4a stems produced by afconvert can be sample-aligned at frame 0: Apple TN2258 says ExtAudioFile reads priming and remainder values from the file and removes those samples automatically; ExtAudioFileSeek is documented as sample-accurate even mid-packet, so resuming from an arbitrary frame is feasible.
- The two-offset model is right in structure: the audio offset shifts song time for both judging and drawing, the visual offset shifts drawing only, and the sign of L and delta in the formula is correct once L is defined as in AUD-3.
- A tap-along audio test measures the quantity the judge needs (touch timestamp against heard audio, including touch-sensor latency and the player's own bias), so no separate touch-latency term is required.
- Route-aware design is justified by Apple's own docs: AVAudioSession.outputLatency warns that AirPlay can add a 2-second delay, and latency is reported per route.
- No real-time render-thread code is needed for this design (player nodes only), which keeps the Swift 5 mode / strict-concurrency concern in 7.1 small for the audio layer.
- A lead-in of at least 2 s is enough for engine start, decoder preparation and scheduling, provided the engine is started at the beginning of the lead-in and not at T0.
- Audio size fits the download budget: 5 songs x 2 stems x 120 s at 160 kbps is 24 MB, against the 60 MB target.
- The plan correctly flags haptics inside the extension as verify-on-device; nothing in the docs contradicts using UIImpactFeedbackGenerator there.

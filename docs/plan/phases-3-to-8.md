# Phases 3 to 8

The later phases as amended by the review. They are outlined, not yet broken down to file level:
each gets its own detailed document when the phase before it is under way, because Phase S results
will change the details. Task ids follow PLAN.md section 9; new tasks are marked.

## Phase 3: playable slice

One song, start to finish, on a real iPhone.

| Task | What | Changed by the review |
| --- | --- | --- |
| P3.1 Game screen | SpriteKit view hosted in SwiftUI | Guard is by view size, not orientation: pause and ask to rotate back when wider than tall or too short (D-026) |
| P3.2 Highway scene | Projection, lanes, strike line, beat lines, pooled notes, hold trails | Layout from the game view's safe-area rectangle; strike-line position from spike S3 (D-064). Projection math in `iMessageRiffCore` so it is unit-tested |
| P3.3 Input | Touches into the game session | A UIKit input view with its own gesture recognizer over the highway; blocks competing recognizers during a song; a cancelled touch is a release; columns sit above the home-indicator inset (D-025) |
| P3.4 Effects and HUD | Sparks, judgement text, streak, score, Hype | Hit feedback immediate; miss feedback after the input guard (D-050) |
| P3.5 Results screen | | Shows tries and ghost-tap count |
| P3.6 Autoplay | Debug chart QA | With the assist tick, so sync is audible (D-040) |
| P3.7 Driver (new) | The frame loop: apply inputs, `advance(to: now - inputGuard)`, render at presentation time | The engine contract in GAME_RULES section 2 |

**Done when:** the click track and one placeholder song play through on a real iPhone at 60 fps (120
on ProMotion if spike S4 grants it), under 1% dropped frames, inside the memory budget from spike S6,
with zero cancelled touches in the S5 protocol.

## Phase 4: Messages integration

Rules: [MATCH_PROTOCOL.md](../specs/MATCH_PROTOCOL.md). Most of the logic already exists in
`iMessageRiffCore` from P1.8; this phase connects it to Messages.

| Task | What | Changed by the review |
| --- | --- | --- |
| P4.1 Lifecycle and router | Feed every callback into the routing function | Router is pure and already tested; selection is sticky; Home action (D-021) |
| P4.2 Composer | Session messages, URL, template layout, score card, captions | Summary and accessibility text; nicknames from the payload; fixed-size opaque card (D-022). URL form from spike S2.1 (D-017) |
| P4.3 Duel flow | Start, respond, result, rematch, waiting | Submission state machine; run persisted at song end; previous-round summary (D-014, D-020) |
| P4.4 Group round flow | Leaderboard card, close round | Deadline and roster size in the payload; late entries (D-012) |
| P4.5 Edge cases | Version or chart mismatch, unreadable payload, collapse mid-song | Ordered decode outcomes (D-019); no external links (D-023); non-iMessage chats (D-024) |
| P4.6 Match store (new) | Per-device store, merge on every decode including `didReceive`, Re-post | Preserve fragments and the first-final descriptor across restarts (D-011, D-119) |
| P4.7 Settlement (new) | Minimal durable profile and ledger; bonus XP | Commit joined fragments, first-final descriptor, profile and ledger atomically before displaying final results (D-014, D-119) |

**Done when:** 3 duel rounds between two real iPhones and one 3-person group round finish with correct
winners, series and bubble updates, on iPhone and iPad; **and** the concurrency protocol from spike
S2.5 ends with every device showing the same merged standings after at most one Re-post. Each local
ledger pays at most once based on its first final observation; late arrivals can leave earlier
payouts different across devices (D-099). Restart and interrupted-write tests cover P4.6/P4.7.

## Phase 5: content

**Not yet reviewed** (D-082): the content pipeline, licensing options and placeholder audio were in
the review area that did not run. Known changes so far:

- Songs are 60 to 90 seconds (D-062).
- `imessageriffcli` replaces the Python `chartcheck`; Python keeps conversion, draft reduction and audio
  generation (D-007).
- Chart rules are numeric and enforced ([CHART_FORMAT.md](../specs/CHART_FORMAT.md) section 4), and
  every chart must pass the masher-bot rule (GAME_RULES section 10).
- Shipped audio goes through one scripted encoder path and an alignment test (D-037).
- The `.chart` source-format details must be verified before `chartconv` is written.

Music sourcing (D-101) is the longest lead time in the project and is independent of everything
above: it can start now.

## Phase 6: progression and profile

| Task | Changed by the review |
| --- | --- |
| P6.1 Profile store | Extend Phase 4's durable profile with records and settings; device-only, stated on the Profile screen (D-070); stored in the extension's own container (D-005, D-119) |
| P6.2 XP on results, level-up, unlocks | One integer XP formula (D-072); bonus XP from the ledger (D-014) |
| P6.3 Records and Profile screen | Series records keyed by the opponent's player id (D-010) |
| P6.4 Daily streak and featured song | Travel-safe streak (D-073); fixed-epoch rotation (D-074) |

**Done when:** XP and unlocks match the progression tests in `iMessageRiffCore` on device.

## Phase 7: polish, onboarding and accessibility

As PLAN.md, plus: nickname entry requests the expanded view (D-029); an in-app privacy policy and
licences screen (D-023); a calibration prompt sized to the "under two minutes" pillar. Accessibility
was in the review area that did not run.

## Phase 8: beta and launch

As PLAN.md, minus what moved earlier: the App Store Connect record, icon slots, privacy manifest and
export-compliance answer are done in Phase 0 and Phase S (D-028). Real icon and score-card artwork
replace the placeholders here. App Review and trademark exposure were in the review area that did
not run.

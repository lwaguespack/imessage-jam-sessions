# Match protocol

How a duel or group round is represented, merged, sent in a message, decoded, ranked and settled.
There is no server: every shared fact travels in a message URL, and every device keeps its own copy.

**Status: draft 2, partially implemented.** The draft 1 merge and conversation tests found lost entries,
non-associative history selection and an unresolved tie. Decisions D-097 to D-099 specify the
corrections and their limits. The version-2 binary codec and version-1 decode test are implemented;
URL routing and the chart-aware decode pipeline remain. Section 13 lists open and device questions. Decisions are `D-0xx` in
[../DECISIONS.md](../DECISIONS.md).

## 1. Terms

- **Match**: one bubble's worth of play in one conversation. One `MSSession`; one match id.
- **Round**: one song at one difficulty inside a match. Rounds are numbered from 1.
- **Entry**: one player's submitted run in a round.
- **Duel**: a match in a conversation with exactly one remote participant. **Round mode**: more than
  one. With no remote participant, only Practice is offered.

## 2. Identity

1. Each install generates a random 8-byte `playerId` on first launch and stores it with the profile.
   It is never derived from Messages. (D-010)
2. "Me" is the entry whose `playerId` equals the stored one.
3. Messages participant UUIDs are scoped to one device. They are used only locally: the roster count
   (`remoteParticipantIdentifiers.count + 1`), and the check "this message was sent by me"
   (`senderParticipantIdentifier == localParticipantIdentifier`).
4. Identity and progress are per device in v1.

## 3. State

```text
MatchState
  matchId            8 random bytes, fixed for the match
  mode               duel | round
  rulesVersion       GameConfig.rulesVersion of the sender
  contentRevision    integer; rises whenever bundled songs or charts change
  round              r, starting at 1
  history            one value containing series, previousChart and previous:
                     series is duel wins per playerId; previous summarises round r-1
  proposals          set of Proposal; at most 4 in a duel or 8 in a group round

Proposal
  descriptor         songId, part, difficulty, chartHash (4 bytes), starter (playerId), t0 (Unix seconds),
                     rosterSize n, deadlineHours (0 in a duel)
  closedAt           Unix seconds, or 0 while not closed
  entries            set of Entry, at most one per playerId within this proposal

Entry
  playerId, nickname, score, accuracy (basis points), longestStreak, tries (1 to 99),
  level, titleId, frameId, fullCombo, t (Unix seconds when the run finished)
```

Across all proposals there are at most 8 entries in a duel or 32 in a group round. An entry belongs
to the chart in its proposal, even when that proposal does not win. New entries carry `fullCombo` as
true or false; a version-1 import may be unknown. Stars are derived from score and the chart, and
Gold also needs a known true `fullCombo`. Score and longest streak alone cannot establish Full Combo:
a penalised ghost before the first hit leaves both unchanged. (D-071, D-098)

### 3.1 Nicknames

NFC-normalised; 1 to 16 grapheme clusters **and** at most 32 UTF-8 bytes; not whitespace-only; no
control, newline or bidirectional-control scalars (U+061C, U+200E, U+200F, U+202A to U+202E and
U+2066 to U+2069). Enforced on input and again on decode; an invalid nickname is replaced by
"Player" and the replacement is reported, while the entry is kept. A wire length over 32 bytes
violates the structural bound and rejects the payload before nickname repair. (D-018, D-110)

## 4. Merge

Every device keeps a `MatchStore` of received and sent states, keyed by match id and round.
For compatible states whose full join fits the limits, `merge(a, b)` is commutative, associative and
idempotent. (D-011, D-097)

1. Different `matchId`: not mergeable.
2. Different mode, `rulesVersion` or `contentRevision`: incompatible, not merged. The decode pipeline
   handles revision mismatches; the store keeps the original fragments.
3. Different round numbers: the higher round is the current view, but the store retains each round
   separately. A payload carries only the current round and a summary of the immediately previous
   round; it cannot repair every arbitrarily old round on its own.
4. A proposal's immutable key is `(t0, starter, songId, part, difficulty, chartHash, rosterSize,
   deadlineHours)`, compared in that order. IDs and hashes compare by unsigned bytes, song IDs by
   ASCII bytes, and enums by their wire values. Union proposals by this key; within one proposal,
   union entries by `playerId` and choose the smaller `(t, canonicalEntryBytes)` on duplicates.
   `closedAt` is the smaller non-zero value. Sort proposals by key and entries by `playerId`.
5. Merge `history` as one value: choose the lexicographically smaller **canonical history bytes**,
   independent of proposals and entries. Choosing by whole-state bytes is not associative.
6. The smallest proposal key wins. Its descriptor and `closedAt` describe the round. The visible
   entries are the union, with the same per-player tie-break, of entries in **all** proposals for
   its chart (song, part, difficulty and hash). Entries for other charts remain in the state and
   their owners keep their personal best and finish XP. Thus same-chart rematches combine even if a
   different-chart proposal arrives between them. (D-013)
7. If the full union exceeds either the proposal or entry limit, return **capacity exceeded**:
   preserve the original fragments locally and block re-posting that union. Never truncate entries or
   silently choose one fragment. The merge laws apply when every join in the expression fits. (D-097)

Use of the store:

- `didReceive`, `willBecomeActive` and `didSelect` all route the decoded state into the store, also
  mid-song. The store preserves unmergeable and over-capacity fragments and reports the reason.
- An outgoing message carries the full join of compatible fragments and my entry, never the selected
  state alone. If that join exceeds capacity it is not sent.
- **Re-post.** If the tapped bubble lacks an entry the store has, the match screen shows the merged
  standings and offers "Re-post", which inserts the merged state without replaying.

## 5. When a round is final

**Duel.** Final when the winning chart has the winning starter's entry and an entry from another
player. If more than one other id appears, use the earliest `(t, playerId)` as the opponent; keep
the other entries in the state.

**Round mode.** The end time is `F = min(t0 + deadline, max(t0, closedAt) if set)`. Standings are
the winning-chart entries with `t <= F`; later ones are shown as late. The round is final when
`closedAt` is set, the eligible entry count reaches `n`, or the local clock passes `t0 + deadline`.
Only the winning starter's device offers "Close round". The deadline is 24 hours (D-012).

A device records which proposal it first saw as final and does not silently reopen it. If a newly
arrived earlier proposal changes that winner, show a conflict and block normal rematch/settlement
until the user starts a new match. Late entries for the same winning proposal can still change
standings. Without a server, clocks and message delivery cannot guarantee every device first sees the
same final snapshot. (D-099)

## 6. Ranking

A total order on entries, computed only from transmitted integers:
score descending, accuracy descending, longest streak descending, tries ascending, `t` ascending,
`playerId` ascending. The duel winner is the higher-ranked entry; there are no ties. (D-061)

## 7. Starting the next round

The device that starts round `r + 1` builds a state with one new proposal containing its own run and
`closedAt = 0`. Its history carries the duel series and the previous round's two duel entries or top
three group entries. A rematch may use the same song or a new one.

## 8. Settlement

Bonus XP (duel win, podium) is paid from a **ledger** in the local store, keyed by `(matchId, round)`.
A device pays its own player once, the first time it sees a final round containing its own entry,
either as the current round or through `previous` of a later state. Reopening a bubble never pays
again. The ledger record and XP update must be persisted atomically. A late-delivered entry does not
re-pay or claw back, even if it changes the eventual winner; two devices can therefore have paid
different first-observed winners. This is an explicit limitation, not global agreement. (D-014, D-099)

## 9. Submitting a turn

States of a finished run: **played**, **staged**, **sending**, **confirmed**. (D-020)

1. An attempt record `(matchId, round)` is written when a challenge run starts; `tries` counts them.
2. The `RunSummary` is persisted synchronously when the song ends, before the results screen.
3. `insert` stages a draft and the view requests the compact style so the Send button is reachable.
4. A selected message with `isPending == true` is "not sent yet", never "waiting".
5. On `didCancelSending`, or on any later activation where the bubble lacks the stored entry, the app
   offers "Send your score" again without replaying.
6. **Confirmed** only when the entry is seen in a non-pending message.

## 10. Wire format, version 2

Binary, then base64url without padding. No compression. Encoding is canonical: proposals and entries
are sorted as in section 4. Integers are unsigned LEB128 unless a size is given; varints are minimal
and bounded as listed. Fixed-width IDs and chart hashes use big-endian byte order. The version-2
codec, configuration limits and version-1 decode test landed together. (D-015, D-098)

| Field | Size |
| --- | --- |
| Wire version (`2`) | 1 byte, always first |
| `matchId` | 8 bytes |
| Flags (bit 0: round mode; all other bits zero) | 1 byte |
| `rulesVersion`, `contentRevision`, `round` | UInt32 varints, at most 5 bytes each |
| History | series count + at most two `(playerId: 8, wins: UInt32 varint)`; previous-chart flag and chart identity; previous count + at most three short entries as below |
| Proposal count | 1 byte |
| Each proposal | song ID length + up to 24 ASCII bytes; part 1; difficulty 1; chart hash 4; starter 8; `t0` UInt32 varint; roster size 1; deadline hours 1; `closedAt` UInt32 varint; entry count 1 |
| Each entry | player ID 8; nickname length + up to 32 UTF-8 bytes; score UInt32 varint; accuracy varint (at most 10,000); streak UInt32 varint; tries, level, title ID, frame ID and Full Combo status 1 byte each; `t` UInt32 varint |
| Tag | 8 bytes |

History's short entry is player ID 8; score UInt32 varint; accuracy varint; streak UInt32 varint;
tries 1; `t` UInt32 varint; Full Combo status 1. Series and previous entries are sorted by player ID.
Round mode has no series; previous has at most two entries in a duel and three in round mode.
The previous-chart flag is 0 when previous is empty, otherwise 1 followed by song ID, part,
difficulty and chart hash in the same form as a proposal. This lets the decoder validate the
previous entries against their own chart's note count and score ceiling. (D-111)
Part `lead` is 0; difficulty is Easy 0, Medium 1, Hard 2, Expert 3. Other enum values are invalid.
The roster is exactly 2 in a duel and 3 through 32 in a group round; the deadline is 0 for a duel
and 1 through 255 hours for a group round.

`t0`, `closedAt` and entry `t` are **absolute** unsigned Unix seconds, not offsets: a receiver's
clock can be behind the starter's. A time is 1 through `UInt32.max`; `closedAt = 0` means open.
Full Combo status is 0 for no, 1 for yes, 2 for unknown legacy data; other values are invalid.
New runs write only 0 or 1. The UInt32 time bound needs revisiting before 2106.

**Tag.** The first 8 bytes of HMAC-SHA256 over ASCII `riff-match-v2` followed by every preceding
byte, with `GameConfig.payload.integrityKeyV2 = SHA256("riff-match-integrity-key-v2")`. It detects
corruption and casual edits; it is not a secret. (D-016)

**Size**, computed from the field maxima:

| Case | Upper-bound bytes | Base64url characters |
| --- | --- | --- |
| Duel, 4 proposals and 8 entries | 887 | 1,183 |
| Round mode, 8 proposals and 32 entries | 2,607 | 3,476 |

The bounds use 141 bytes of history, 52 per proposal and 63 per entry, even where a mode's actual
history is smaller. With the placeholder query URL the group bound is 3,501 characters. The cap is
4,096 characters for the whole URL; longer configured domains must be checked too. A unit test
asserts these bounds and the 1,024-byte duel cap.

### 10.1 Version 1

Version 1 was documented but never implemented or shipped. The codec includes a decode test for a
version-1, round-1 group fixture with no previous summary, promotes its single descriptor to one proposal,
converts its non-negative time offsets to absolute times, and marks Full Combo unknown. The draft did
not define the bytes of its “short entries”; other legacy variants are reported as unsupported, not
guessed. Version-1 tags use the existing `integrityKeyV1`.

### 10.2 URL

Three candidate forms; the device spike picks one (D-017). The decoder accepts all three.

1. `data:` URL carrying the payload (no server contact, no domain to own).
2. `https://<domain>/m#<payload>`: the fragment is never sent to the server.
3. `https://<domain>/m?p=<payload>` on a static page with no request logging: last resort.

Until a domain is chosen the placeholder is `riff.invalid`, which never resolves.

### 10.3 Decoding

An ordered pipeline; each step has its own outcome. (D-019)

1. URL longer than 4,096 characters: unreadable.
2. Extract and base64url-decode the payload: unreadable on failure.
3. Wire version above what this build knows: **Update needed**.
4. Check the tag with the key for that wire version: unreadable on mismatch.
5. Structural bounds (lengths, counts, enumerations): unreadable. A version-1 variant whose layout
   was never defined is **unsupported legacy message**.
6. `rulesVersion` or `contentRevision` above mine: **Update needed**. Below mine: **"Ask Sam to
   update"**.
7. Unknown song, or chart hash mismatch at equal revisions: unreadable.
8. Per entry: score at most the chart's ceiling, accuracy at most 10,000, streak at most the note
   count, tries at least 1. A known true Full Combo also requires streak equal to note count. A
   failing entry is dropped; the match is kept.

"Unreadable" shows "Couldn't read this challenge" with Start new.

## 11. Routing

The screen shown is a pure function, re-evaluated on `willBecomeActive`, `didBecomeActive`,
`didSelect`, `didReceive` and `didTransition`, of: presentation style, the selected message's key and
`isPending`, the last-handled message key, a "user left this match" flag, the decode outcome, and the
store. Selection in Messages is sticky, so every match screen has a Home action that sets the flag;
it clears only when a different message is selected. The function lives in `RiffCore`. (D-021)

| Condition | Screen |
| --- | --- |
| No selection, or the flag is set | Home |
| Decode outcome is Update needed, ask to update, or unreadable | The matching notice |
| The full join exceeds capacity, or a previously final winner changed | An explicit conflict notice; preserve fragments |
| Open round, no stored entry of mine | Your turn |
| Open round, my entry stored but not in the bubble | Send your score, or Re-post |
| Open round, my entry confirmed | Waiting, with standings |
| Final round | Results, with Rematch |

## 12. The bubble

Template layout. The image is the rendered score card: song, difficulty, the two scores or the top
three plus the sender's place, the leader marked, the series score, and each try count. Captions use
nicknames from the payload. Every message sets `summaryText` ("Sam scored 212,300 on Neon Nights") and
`accessibilityLabel` (a full sentence with scores and standing). The card image has a fixed pixel size
and is opaque. (D-022)

## 13. Open questions and device checks

| Question | Settled by |
| --- | --- |
| Which URL form survives a round trip byte-exact on iPhone, iPad and Mac | Spike S2 |
| After two concurrent session updates, what each device shows, and which callbacks deliver them | Spike S2, three devices |
| Does a message sent from my other device arrive with the sender equal to my local participant | Spike S2 |
| `insert` plus Send versus an in-app "Send score" button using `send` | Spike S2 |
| What SMS, RCS and mixed groups receive, and whether the extension can detect them | Spike S2 |
| Does the undocumented participant-name placeholder render real names | Spike S2 |
| An open duel round the opponent never answers: may the waiting player withdraw | Owner; default: start a new match from the drawer |
| How to recover arbitrarily old round details after several rematches | Open: only the current and previous round travel in one payload |
| A bound on `series` and long matches | Two UInt32 counters; reject overflow rather than wrap |

## 14. Required tests (Phase 1)

- Codec round trip for every field at its minimum and maximum; canonical bytes; previous-version
  decode once a version 2 exists.
- Tamper cases: each byte flipped fails the tag or a bound; oversize; truncated.
- Worst-case size formula against the cap.
- Merge laws on generated states: commutative, associative, idempotent.
- Ranking is a total order; duel winner; group standings with late entries and `closedAt`.
- Decode pipeline: one test per outcome, in order.
- Router: one test per row of section 11, plus sticky selection and the Home flag.
- **Conversation simulator**: several devices, random message orders, duplicates, drops, a
  reinstall, a second device; asserts every device converges after re-post, no entry is lost, and
  bonus XP is paid exactly once. Seeded and reproducible. (D-076)
- Golden vectors (hex payloads with their decoded states) stored as fixtures.

## 15. GameConfig changes required

Applied in task P1.0. The table is kept as the record of what changed from PLAN.md revision 1.
`integrityKeyV1` is the SHA-256 of the ASCII text `riff-match-integrity-key-v1` (D-084).

| Property | Was | Now | Why |
| --- | --- | --- | --- |
| `payload.playerIDHexCharacters` | `8` | `playerIDBytes 8` | D-010 |
| `payload.matchIDCharacters` | `10` | `matchIDBytes 8` | D-015 |
| `payload.signatureBytes` | `16` | `tagBytes 8` | D-016 |
| `payload.integrityKeyV1` | absent | a fixed 32-byte constant | D-016 |
| `payload.maxEncodedBytes` | `4096` | `maxURLCharacters 4096` | MATCH-6 |
| `payload.maxNicknameCharacters` | `16` | keep, add `maxNicknameBytes 32` | D-018 |
| `payload.chartHashHexCharacters` | `8` | `chartHashBytes 4` | D-015 |
| `payload.maxSongIDBytes` | absent | `24` | D-015 |
| `match.groupDeadlineHours` | absent | `24` | D-012 |
| `match.maxTries` | absent | `99` | D-058 |

P1.8's merge model added `payload.maxDuelProposals = 4`, `payload.maxRoundProposals = 8` and
`payload.maxDuelEntries = 8`. The codec added `payload.integrityKeyV2` and changed
`payload.schemaVersion` to 2 with the legacy decode test. The existing `payload.maxEntries = 32`
bounds the total entries in a group round.

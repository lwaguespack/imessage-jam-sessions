# Match protocol

How a duel or group round is represented, merged, sent in a message, decoded, ranked and settled.
There is no server: every shared fact travels in a message URL, and every device keeps its own copy.

**Status: draft 1.** Built from PLAN.md sections 5 and 6 and the review (MSG-1 to MSG-15, MATCH-1 to
MATCH-20). Only the Messages findings have had a skeptic pass. Section 13 lists what is open,
including everything a real device must confirm. Decisions are `D-0xx` in
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
  descriptor         songId, part, difficulty, chartHash (4 bytes), starter (playerId), t0 (Unix seconds),
                     rosterSize n, deadlineHours (0 in a duel)
  closedAt           Unix seconds, or 0 while not closed
  entries            set of Entry, at most one per playerId
  series             duel only: wins per playerId over completed rounds
  previous           summary of round r-1: both entries (duel) or the top three (round mode); empty for r = 1

Entry
  playerId, nickname, score, accuracy (basis points), longestStreak, tries (1 to 99),
  level, titleId, frameId, t (Unix seconds when the run finished)
```

Stars and Full Combo are not stored: they are derived from the score, the chart and the streak.
(D-071)

### 3.1 Nicknames

NFC-normalised; at most 16 grapheme clusters **and** at most 32 UTF-8 bytes; no control, newline or
bidirectional-override scalars. Enforced on input and again on decode; an invalid nickname is
replaced by "Player", the entry is kept. (D-018)

## 4. Merge

Every device keeps a `MatchStore`: for each match id, the merge of every state it has decoded or sent.
`merge(a, b)` must be commutative, associative and idempotent. (D-011)

1. Different `matchId`: not mergeable.
2. Different round numbers: the state with the higher `r` wins whole. (Its `previous` field carries
   the result of the round before it.)
3. Same `r`, **same chart** (song, part, difficulty, chart hash): the descriptor is the one with the
   smaller `(t0, starter)`; entries are the union keyed by `playerId`; when both have an entry for
   one player, keep the one with the smaller `t`, then the smaller encoded bytes; `closedAt` is the
   smaller non-zero value. This covers two players who start the same rematch at once: the round is
   simply complete. (D-013)
4. Same `r`, **different chart**: a conflict. The state with the smaller `(t0, starter)` wins whole.
   The device whose run lost keeps it as a personal best, keeps its finish XP, and shows "Sam started
   round 4 first. Your run was saved; play Sam's song."
5. `series` and `previous` are equal for equal `r` by construction. If they differ, take them from the
   state whose encoded bytes are smaller.

Use of the store:

- `didReceive`, `willBecomeActive` and `didSelect` all route the decoded state into the store, also
  mid-song.
- An outgoing message always carries `merge(store, selected) + my entry`, never the selected state
  alone.
- **Re-post.** If the tapped bubble lacks an entry the store has, the match screen shows the merged
  standings and offers "Re-post", which inserts the merged state without replaying.

## 5. When a round is final

**Duel.** Final when it holds entries from two different players. If a third id ever appears, the
round uses the starter's entry and the earliest other entry; the rest are ignored.

**Round mode.** The end time is `F = min(t0 + deadline, closedAt if set)`. Standings are the entries
with `t <= F`; later ones are shown as late. The round is final when `closedAt` is set, or the entry
count reaches `n`, or the local clock passes `t0 + deadline`. Only the starter's device offers
"Close round". The deadline is 24 hours (D-012, owner decision).

A final round is never reopened. After it is final, any participant may start round `r + 1`.

## 6. Ranking

A total order on entries, computed only from transmitted integers:
score descending, accuracy descending, longest streak descending, tries ascending, `t` ascending,
`playerId` ascending. The duel winner is the higher-ranked entry; there are no ties. (D-061)

## 7. Starting the next round

The device that starts round `r + 1` builds: `round = r + 1`; a new descriptor; `entries` holding its
own run; `series` with the winner of round `r` incremented (duel); `previous` summarising round `r`;
`closedAt = 0`. A rematch may use the same song or a new one.

## 8. Settlement

Bonus XP (duel win, podium) is paid from a **ledger** in the local store, keyed by `(matchId, round)`.
A device pays its own player once, the first time it sees a final round containing its own entry,
either as the current round or through `previous` of a later state. Reopening a bubble never pays
again. A late-delivered entry does not re-pay or claw back. (D-014)

## 9. Submitting a turn

States of a finished run: **played**, **staged**, **sending**, **confirmed**. (D-020)

1. An attempt record `(matchId, round)` is written when a challenge run starts; `tries` counts them.
2. The `RunSummary` is persisted synchronously when the song ends, before the results screen.
3. `insert` stages a draft and the view requests the compact style so the Send button is reachable.
4. A selected message with `isPending == true` is "not sent yet", never "waiting".
5. On `didCancelSending`, or on any later activation where the bubble lacks the stored entry, the app
   offers "Send your score" again without replaying.
6. **Confirmed** only when the entry is seen in a non-pending message.

## 10. Wire format, version 1

Binary, then base64url without padding. No compression. Encoding is canonical: equal states give
equal bytes (entries sorted by `playerId`). Integers are unsigned LEB128 varints unless a size is
given. (D-015)

| Field | Size |
| --- | --- |
| Wire version (`1`) | 1 byte, always first, so any future client can read it |
| `matchId` | 8 bytes |
| Flags (bit 0: round mode) | 1 byte |
| `rulesVersion`, `contentRevision`, `round` | varints |
| `songId` | length byte + up to 24 ASCII bytes |
| `part`, `difficulty` | 1 byte each |
| `chartHash` | 4 bytes |
| `starter` | 8 bytes |
| `t0` | varint |
| `rosterSize`, `deadlineHours` | 1 byte each |
| `closedAt` as seconds after `t0`, 0 if open | varint |
| Entry count | 1 byte |
| Each entry: `playerId` 8, nickname length + up to 32, `score`, `accuracy`, `longestStreak` varints, `tries`, `level`, `titleId`, `frameId` 1 byte each, `t` as seconds after `t0` varint | up to 56 bytes |
| Duel: two `(playerId, wins)` pairs, then `previous` (flag, two short entries) | up to 55 bytes |
| Round mode: `previous` (count, up to three `(playerId, score)`) | up to 37 bytes |
| Tag | 8 bytes |

**Tag.** The first 8 bytes of HMAC-SHA256 over the ASCII string `riff-match-v1` followed by every
preceding byte, with the constant key `GameConfig.payload.integrityKeyV1`. It detects corruption and
casual edits; it is not a secret. (D-016)

**Size**, computed from the field maxima:

| Case | Bytes | URL payload characters |
| --- | --- | --- |
| Duel, typical | 177 | 236 |
| Duel, worst case | 241 | 322 |
| Round mode, 32 entries, worst case | 1,903 | 2,538 |

The cap is 4,096 characters for the whole URL; Apple's limit is 5,000. A unit test asserts the
worst-case formula against the cap.

### 10.1 URL

Three candidate forms; the device spike picks one (D-017). The decoder accepts all three.

1. `data:` URL carrying the payload (no server contact, no domain to own).
2. `https://<domain>/m#<payload>`: the fragment is never sent to the server.
3. `https://<domain>/m?p=<payload>` on a static page with no request logging: last resort.

Until a domain is chosen the placeholder is `riff.invalid`, which never resolves.

### 10.2 Decoding

An ordered pipeline; each step has its own outcome. (D-019)

1. URL longer than 4,096 characters: unreadable.
2. Extract and base64url-decode the payload: unreadable on failure.
3. Wire version above what this build knows: **Update needed**.
4. Tag mismatch: unreadable.
5. Structural bounds (lengths, counts, enumerations): unreadable.
6. `rulesVersion` or `contentRevision` above mine: **Update needed**. Below mine: **"Ask Sam to
   update"**.
7. Unknown song, or chart hash mismatch at equal revisions: unreadable.
8. Per entry: score at most the chart's ceiling, accuracy at most 10,000, streak at most the note
   count, tries at least 1. A failing entry is dropped; the match is kept.

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
| A bound on `series` and long matches | None needed: `series` is two counters and only one round is carried |

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

| Property | Now | Required | Why |
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

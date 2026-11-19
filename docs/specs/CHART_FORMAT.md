# Chart and song formats

The files a song ships as, and the rules a chart must pass. `riffcli` (built from the engine) is the
only tool that validates charts and writes their computed fields. (D-007)

**Status: draft 1.** The validation numbers come from the gameplay review (GAME-5, GAME-7, GAME-11),
which has not had a skeptic pass. Sections 1 to 4 are implemented and tested as written here; how each
rule is measured was settled in task P1.2 (D-088, D-089). The mapping from the Moonscraper `.chart`
source format in section 6 is from PLAN.md and is **unverified**: the content review did not run
(D-082).

## 1. Chart file

One JSON file per song, part and difficulty. Changes from PLAN.md appendix A: tempo is integer
milli-BPM, and `computed` gains star cut-offs and the rules version.

```json
{
  "format": "riff-chart",
  "version": 1,
  "songId": "neon-nights",
  "part": "lead",
  "difficulty": "expert",
  "lanes": 4,
  "resolution": 192,
  "tempo": [{ "tick": 0, "mbpm": 128000 }],
  "timeSignatures": [{ "tick": 0, "num": 4, "den": 4 }],
  "notes": [
    { "tick": 768, "lane": 0 },
    { "tick": 960, "lane": 2, "length": 192 },
    { "tick": 1152, "lane": 1 },
    { "tick": 1152, "lane": 3 }
  ],
  "hype": [{ "start": 3072, "end": 4608 }],
  "sections": [{ "tick": 0, "name": "Intro" }],
  "computed": {
    "rulesVersion": 1,
    "noteCount": 412,
    "baseScore": 0,
    "maxScore": 0,
    "starCutoffs": [0, 0, 0, 0, 0],
    "hash": "00000000"
  }
}
```

The zeros are placeholders: real values are written by `riffcli chart compute`, never by hand.

- Lanes are 0 to 3 in the file. `resolution` is ticks per quarter note.
- Two notes on one tick form a chord (at most 2 notes). `length` in ticks marks a hold.
- `hype` phrases are half-open tick ranges `[start, end)`.
- `timeSignatures` and `sections` are for display (beat lines, practice) and never affect scoring.
- Notes must be sorted by `(tick, lane)`; the validator rejects unsorted or duplicate notes.
- Reading is strict. A file is refused if a field is missing, has the wrong type, or is not one this
  format defines: a misspelt `length` would otherwise turn a hold into a tap without a word. `length`
  is the only optional field; a tap leaves it out and never writes `null`. Every number is a whole
  number. (D-089)
- `riffcli` writes chart files as canonical JSON: keys in code-point order, two-space indentation and
  one trailing newline.

## 2. Chart hash

The first 4 bytes, as 8 lowercase hex characters, of SHA-256 over these UTF-8 lines joined by `\n`:

```text
riff-chart-v<version>
rules=<rulesVersion>
song=<songId>;part=<part>;difficulty=<difficulty>;lanes=<lanes>;resolution=<resolution>
tempo=<tick>:<mbpm>,<tick>:<mbpm>,...
notes=<tick>:<lane>:<length or 0>,...          (sorted by tick, then lane)
hype=<start>:<end>,...
```

- `<rulesVersion>` is the engine's `GameConfig.rulesVersion` when the hash is computed, not the
  number stored in the file.
- A tap is written with length 0. The lists are written in file order, which validation has already
  fixed. An empty list leaves nothing after its `=`. There is no newline after the last line.

`computed`, `timeSignatures` and `sections` are excluded, so the hash never covers itself and
cosmetic edits do not change it. Because the rules version is included, two app versions with
different scoring rules never agree on a hash. (D-008)

## 3. Computed fields

`riffcli chart compute <file>` validates, then writes `computed`: `rulesVersion` (the engine's),
`noteCount` (a hold counts once, a chord counts each note), `baseScore`, `maxScore` and `starCutoffs`
as defined in [GAME_RULES.md](GAME_RULES.md) section 7, and `hash`. `riffcli chart check <file>` fails
if any stored value differs from a fresh computation.

- `compute` rewrites the whole file as canonical JSON (section 1). A file that cannot be read or that
  breaks a rule is left as it was; both commands then print every issue and exit with status 1.
- Until the scoring engine exists (task P1.6), `compute` writes `rulesVersion`, `noteCount` and `hash`
  and carries `baseScore`, `maxScore` and `starCutoffs` over unchanged, and `check` compares only the
  three it writes.
- Both commands read the chart alone, so the rules in section 4.2 that need the song's manifest are
  not checked by either (section 7).
- `scripts/check.sh` runs `check` on the example chart in the tests' `Fixtures` folder. CI is to run
  it over every bundled chart once there are any.

## 4. Validation rules

`ChartValidator` checks a chart in two passes. It reports every broken rule by the id below, with a
tick and a lane where the rule has a place. Every number in this section is a `GameConfig` property,
in the `charts`, `songs`, `highway`, `hype` or `payload` group. (D-088)

### 4.1 Structure

A chart that breaks a structure rule is reported with those issues only: the content rules are stated
in milliseconds, and times mean nothing while ticks or tempos are out of range.

| Id | Rule |
| --- | --- |
| `format` | `format` is `riff-chart` and `version` is 1 |
| `songId` | 1 to 24 characters from `a` to `z`, `0` to `9` and `-` |
| `lanes` | `lanes` is 4 |
| `resolution` | 1 to 960 ticks per beat (D-086) |
| `tempoList` | At least one entry; the first is at tick 0; ticks strictly ascend; none is after the last tick |
| `tempoRange` | Each tempo is 40 to 300 BPM, both included |
| `noteTick` | 0 to the last tick |
| `noteLane` | 0 to 3 |
| `holdLength` | Where present, 1 to the last tick |
| `noteOrder` | Strictly ascending by tick, then lane, so no note is written twice |
| `chordSize` | At most 2 notes on a tick |
| `phraseRange` | `0 <= start < end`, and `end` is not after the last tick |
| `phraseOrder` | Each phrase starts at or after the end of the one before |

The **last tick** is 456,000: where the longest song the validator accepts, 95 seconds, ends at the
fastest tempo and the finest resolution (`95 s * 300 BPM * 960 / 60`). No valid chart reaches past it,
and with every tick at or below it the tick-to-time arithmetic cannot overflow.

### 4.2 Content

Times come from the tick conversion in GAME_RULES.md section 1.1. A note's **head** is its tick. Its
**end** is its tick plus its length; a tap ends on its head.

| Id | Rule | Easy | Medium | Hard | Expert |
| --- | --- | --- | --- | --- | --- |
| `averageDensity` | Average notes per second | 1 to 2 | 2 to 3.5 | 3.5 to 5 | 5 to 7 |
| `peakDensity` | Most notes in any 1,000 ms | 3 | 5 | 7 | 10 |
| `chordShare` | Chord notes as a share of all notes, at most | 0% | 5% | 20% | 35% |
| `chordSpacing` | Beats from one chord to the next, at least | no limit | 1 | no limit | no limit |
| `sameLaneGap` | Gap between notes in one lane, at least | 400 ms | 250 ms | 180 ms | 180 ms |
| `crossLaneGap` | Gap between notes on different ticks, at least | 250 ms | 150 ms | 100 ms | 70 ms |
| `contacts` | Fingers down at once, at most | 1 | 2 | 2 | 2 |
| `holdTooShort` | Shortest hold in beats; never under 250 ms | 1 | 1/2 | 1/2 | 1/4 |

How each is measured:

- **Average density** is the note count divided by the time from the first head to the last. Both
  limits are allowed. A hold counts once and each note of a chord counts. A chart with notes on fewer
  than two ticks has no such time: it is reported as `noteSpan` and neither density is checked.
- **Peak density** counts the heads in a window that starts at a note and stops short of 1,000 ms
  later, so a steady four notes a second peaks at 4, not 5. Only the busiest window is reported.
- **A chord** is two notes on one tick, and both are chord notes. Chord spacing is the distance in
  ticks from one chord to the next; exactly one beat is allowed.
- **The same-lane gap** runs from the end of one note to the head of the next in that lane, so after a
  hold it starts when the hold ends. A note whose head is before the end of a hold in its lane is
  reported as `noteDuringHold`.
- **The cross-lane gap** is the time from one tick that has notes to the next, whatever the lanes.
- **Contacts** at a tick are the notes whose head is on it plus the holds that started earlier and end
  later. A hold that ends on the tick is not counted.
- **A hold** must cover its beat fraction (`length * denominator >= resolution * numerator`) and last
  250 ms from head to end.

Phrases and song length, for every difficulty:

| Id | Rule |
| --- | --- |
| `phraseCount` | 4 to 6 phrases |
| `phraseMembers` | At least 4 notes have their head tick in `[start, end)` |
| `phraseTail` | The last phrase's `end` is at least 16 beats before the head of the last note |
| `hypeCapacity` | 8 beats per phrase come to at most 30% of the song's beats, counted from tick 0 to the latest end of any note |
| `songLength` | The latest end of any note, in milliseconds rounded up, is at most the manifest's `durationMs`; at most 95,000 when no manifest is supplied |
| `manifestSong` | A supplied manifest's `id` equals the chart's `songId` |
| `manifestDuration` | A supplied manifest's `durationMs` is 55,000 to 95,000 (section 5) |

What follows from these rules:

- Both notes of a chord share a tick, so they are always in the same phrase; nothing has to check it.
- Four phrases at 30% need a chart of at least 106 2/3 beats. A song whose notes end at 60 seconds
  needs an average of about 107 BPM, and one at 90 seconds about 71 BPM. A slower song cannot pass,
  although tempos down to 40 BPM are allowed. (D-090)
- `timeSignatures` and `sections` are not validated (section 7).
- The same-lane gap of every difficulty exceeds its Good window plus its Perfect window, so a tap
  inside one note's Perfect window can never be captured by the note before it. That is a property of
  the limits, checked by a test of `GameConfig`, not a rule a chart can break. (D-054)

## 5. Song manifest

As PLAN.md appendix B, with these changes:

- Times are whole milliseconds, like `audioOffsetMs`: `durationSec` becomes `durationMs` and
  `previewStartSec` becomes `previewStartMs`. (D-087)
- `durationMs` must be within 60,000 to 90,000 (the validator accepts 55,000 to 95,000). (D-062)
- A `contentRevision` integer is added at the catalogue level.

Shipped audio is 48 kHz stereo AAC-LC produced by one scripted encoder path; a test asserts both
stems have the same sample rate and length. (D-037)

## 6. Source format (unverified)

PLAN.md proposes charting Expert in Moonscraper Chart Editor and converting its `.chart` text file:
the first four fret lanes become lanes 0 to 3, sustain lengths become holds, phrase markers become
Hype phrases, and the sync track becomes the tempo map (its tempos are already milli-BPM). None of
those details has been checked against the format. That check is part of task P5.1 and of the
outstanding content review.

## 7. Open questions

1. The `.chart` details in section 6.
2. Whether Easy needs chords at all once playtested (currently none).
3. Whether placeholder audio can be produced on Linux with a known-good encoder path, or must be
   encoded on a Mac (AUD-11).
4. Where `contentRevision` lives: section 5 puts it "at the catalogue level", and no catalogue file is
   defined yet. Task P1.8 compares it when decoding a match.
5. What the manifest's `audioOffsetMs` and `intensity` mean: PLAN.md appendix B lists them without a
   definition. Nothing in Phase 1 reads them.
6. Whether `timeSignatures` and `sections` need rules of their own (ascending ticks, sensible values).
   Nothing reads them before the beat lines and practice mode of Phase 3, so the validator ignores
   them.
7. Whether an Easy chart may put a note on the tick where a hold in another lane ends. The contact rule
   allows it, because the hold is over, but it asks a beginner to lift one finger as another lands.
8. Which command checks a chart against its manifest. `ChartValidator` accepts one; `riffcli chart
   check` reads the chart alone. A song-level check belongs with the content pipeline in Phase 5.
9. Whether short or slow songs should be allowed fewer Hype phrases (section 4.2, D-090).

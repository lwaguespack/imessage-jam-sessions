# Chart and song formats

The files a song ships as, and the rules a chart must pass. `riffcli` (built from the engine) is the
only tool that validates charts and writes their computed fields. (D-007)

**Status: draft 1.** The validation numbers come from the gameplay review (GAME-5, GAME-7, GAME-11),
which has not had a skeptic pass. The mapping from the Moonscraper `.chart` source format in section 6
is from PLAN.md and is **unverified**: the content review did not run (D-082).

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

## 2. Chart hash

The first 4 bytes, as 8 lowercase hex characters, of SHA-256 over these UTF-8 lines joined by `\n`:

```text
riff-chart-v1
rules=<rulesVersion>
song=<songId>;part=<part>;difficulty=<difficulty>;lanes=<lanes>;resolution=<resolution>
tempo=<tick>:<mbpm>,<tick>:<mbpm>,...
notes=<tick>:<lane>:<length or 0>,...          (sorted by tick, then lane)
hype=<start>:<end>,...
```

`computed`, `timeSignatures` and `sections` are excluded, so the hash never covers itself and
cosmetic edits do not change it. Because the rules version is included, two app versions with
different scoring rules never agree on a hash. (D-008)

## 3. Computed fields

`riffcli chart compute <file>` validates, then writes `computed`: `noteCount` (a hold counts once, a
chord counts each note), `baseScore`, `maxScore` and `starCutoffs` as defined in
[GAME_RULES.md](GAME_RULES.md) section 7, and `hash`. `riffcli chart check <file>` fails if any stored
value differs from a fresh computation. CI runs it over every bundled chart.

## 4. Validation rules

Times are computed with the tick conversion in GAME_RULES.md section 1.1.

| Rule | Easy | Medium | Hard | Expert |
| --- | --- | --- | --- | --- |
| Average notes per second (note count / time from first to last note) | 1 to 2 | 2 to 3.5 | 3.5 to 5 | 5 to 7 |
| Peak: most notes in any sliding 1,000 ms window, chord notes counted each | 3 | 5 | 7 | 10 |
| Chord notes as a share of all notes, at most | 0% | 5% | 20% | 35% |
| Minimum gap between notes in one lane | 400 ms | 250 ms | 180 ms | 180 ms |
| Minimum gap between notes on different ticks, any lanes | 250 ms | 150 ms | 100 ms | 70 ms |
| Simultaneous contacts (live holds plus notes starting on a tick), at most | 1 | 2 | 2 | 2 |
| Shortest hold: the larger of this beat fraction and 250 ms | 1 | 1/2 | 1/2 | 1/4 |

Also, for every difficulty:

- Medium: no two chords within one beat.
- No note in a lane between a hold's head and its end; the next note in that lane starts at least the
  same-lane gap after the hold ends.
- Hype phrases: sorted, non-overlapping, at least 4 member notes each, both notes of a chord in the
  same phrase, the last phrase ending at least 16 beats before the final note, 4 to 6 phrases, and
  total capacity (8 beats per phrase) at most 30% of the song's beats.
- Tempo between 40 and 300 BPM. Resolution between 1 and 960 ticks per beat. First note at or after
  tick 0. Song length within the manifest's duration.
- The same-lane gap exceeds the Good window plus the Perfect window of the difficulty, so a tap inside
  one note's Perfect window can never be captured by the note before it. (D-054)

All limits are `GameConfig.charts` properties.

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

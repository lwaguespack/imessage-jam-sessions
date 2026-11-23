# Progression rules

Phase 1's pure, integer progression rules. Callers supply timestamps, UTC offsets, install IDs and
the catalogue; `RiffCore` never reads a clock, time zone or random source.

## 1. Run XP

For a completed run, let:

```text
E = finishRun + perStar * stars + (fullCombo ? fullComboXP : 0)
    + (firstRunOfDay ? firstRunOfDayXP : 0)
S = min(maxStreakBonusPercent, max(0, streakDays - 1) * streakBonusPercentPerDay)
F = featured ? featuredSongPercent : 100
P = practice ? practicePercent : 100
runXP = floor(E * (100 + S) * F * P / 1_000_000)
```

`stars` is 0 through 5, or `goldStarValue` for Gold. Gold requires Full Combo. The streak length is
the value **after** recording this completed run. Practice runs count for the daily streak and
first-run bonus. Every finished run earns the finish award, including a zero-star run, as in the
original plan; the client-supplied mode decides whether the practice percentage applies.

Duel-win and podium awards are flat, deferred settlement bonuses and are not multiplied a second
time. The match ledger makes each such award at most once per local match and round. XP continues to
accumulate beyond level 50, while the level remains capped. All arithmetic is checked for overflow.
(D-072, D-107)

Examples with the standard config:

- Four stars on streak day 5: `floor(180 * 140 * 100 * 100 / 1_000_000) = 252`.
- A first run with four stars on streak day 2, featured and in practice:
  `floor(280 * 110 * 150 * 50 / 1_000_000) = 231`.
- A later duel-win settlement adds 75 flat XP to the already credited run.

## 2. Daily streak

At run end, the caller provides Unix seconds and the local UTC offset in seconds **at that instant**.
The local Gregorian day is `floor((utcSeconds + offsetSeconds) / 86_400)`, including floor toward
negative infinity before the epoch. The state stores the latest accepted UTC run time, the last local
day and the highest local day ever credited.

1. The first accepted run starts day 1 and earns the first-run bonus.
2. A UTC time earlier than the saved high-water UTC time is rejected for day credit; no saved time
   or streak is rolled back.
3. A local day at or below the credited high-water day earns no first-run bonus or streak increment.
   A later UTC time still becomes the latest run time, including after westward travel.
4. A new local day exactly one day after the high-water day advances the streak by one.
5. A new day two or more days later resets the streak to 1, unless fewer than
   `xp.dailyTravelGraceSeconds` (initially 48 hours) have elapsed since the latest accepted run; in
   that case travel grace advances it by one instead.
6. Each newly credited local day gets the first-run bonus once. The offset is supplied by the device
   for that run; no locale-dependent calendar is consulted inside the engine.

There is no trusted clock. High-water marks prevent crediting the same or earlier local date again,
but cannot detect a user repeatedly setting the device clock forward. (D-073, D-108)

## 3. Featured rotation

The catalogue supplies an explicit ordered, nonempty list of song IDs. The config's
`xp.featuredEpochUnixSeconds` is Monday 2026-01-05 00:00 UTC (`1_767_571_200` Unix seconds):

```text
weekIndex = floor((utcSeconds - epochSeconds) / 604_800)
featured = schedule[euclideanModulo(weekIndex, schedule.count)]
```

The calculation is UTC and does not reset at year boundaries. Before the epoch, negative indices use
Euclidean modulo. Devices on the same catalogue version agree; changing the schedule can change the
selection on an update. An empty schedule is an explicit error, not a fabricated song. The checked-in
catalogue's schedule is empty until songs are bundled. (D-074, D-109)

## 4. Unlocks and profile

`RiffMessages/Resources/progression.json` contains five default cosmetic IDs outside the counts in
`GameConfig.unlocks`, an explicit reward list for every level 1 through `maxLevel`, and the featured
schedule. Levels 2 through 10 each have at least one reward. Every non-default reward ID appears once
and belongs to one of the configured categories and counts. IDs in the current file are placeholders,
not shipped artwork. (D-075)

The profile holds a caller-supplied stable profile ID, nonnegative XP counters keyed by installation
ID, and a grow-only set of unlock IDs. Its encoded counters and unlocks are sorted. Adding XP increases
only the caller's counter; merging matching profiles takes the maximum of each counter and the union
of unlocks. Level is derived from the sum via `LevelCurve`, never stored. After adding or merging XP,
grant every catalogue reward through the derived level. Different profile IDs do not merge. A future
sync layer must preserve the stable profile ID while assigning each installation its own counter ID.
In JSON, each 8-byte profile and installation ID is exactly 16 lowercase hexadecimal characters, so
the entire unsigned ID range round-trips through canonical JSON.
The per-install counter join does not deduplicate the same match award independently credited on two
devices; a future sync design must reconcile settlement records as well as counters before claiming
cross-device exactly-once awards. No such sync exists in v1. (D-070, D-109, D-119)

# Tools

Python tools for content work. Game rules are never re-implemented here: anything that scores a chart
is done by `imessageriffcli`, the Swift command-line tool built from the engine (see `docs/DECISIONS.md`, D-007).

## What exists now

- `imessageriff_tools.config`: the engine's tunables, read from `imessageriff_tools/data/gameconfig.json`. That file is the
  exact output of `imessageriffcli config`. After changing `GameConfig`, run `scripts/sync-config-snapshot.sh`;
  CI fails if the snapshot is stale.
- `python -m imessageriff_tools config [dotted.key]`: print the tunables or one value.

Run the checks with `scripts/test-tools.sh` (ruff, then pytest). The tests need neither Swift nor Docker.

## Planned, not yet written

| Tool | What it will do | Plan task |
| --- | --- | --- |
| `chartconv` | Convert a Moonscraper `.chart` file to the iMessageRiff chart JSON | P5.1 |
| `reduce` | Draft Hard, Medium and Easy from an Expert chart, for hand tuning | P5.1 |
| `clicktrack` | Generate the click-track song and placeholder practice songs | P5.1, P5.2 |
| `encode_audio.sh` | Encode stems to AAC on a Mac with `afconvert` | P5.3 |

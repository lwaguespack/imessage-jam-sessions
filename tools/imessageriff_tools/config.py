"""The engine's tunables, read from a snapshot of `imessageriffcli config`.

The Swift `GameConfig` is the source of truth. `scripts/sync-config-snapshot.sh` regenerates the
snapshot and CI fails when the two differ, so numbers used here can never drift from the engine.
"""

import json
from functools import cache
from importlib import resources
from typing import Any

DIFFICULTIES = ("easy", "medium", "hard", "expert")


@cache
def load() -> dict[str, Any]:
    """Return the whole snapshot."""
    text = (
        resources.files("imessageriff_tools")
        .joinpath("data/gameconfig.json")
        .read_text(encoding="utf-8")
    )
    return json.loads(text)


def get(dotted_key: str) -> Any:
    """Look up a value by dotted path, for example `judging.perfect.windowMicros`."""
    value: Any = load()
    for part in dotted_key.split("."):
        if not isinstance(value, dict) or part not in value:
            raise KeyError(dotted_key)
        value = value[part]
    return value


def lane_count() -> int:
    return get("highway.laneCount")


def ticks_per_beat() -> int:
    return get("charts.defaultTicksPerBeat")


def window_micros(judgement: str, difficulty: str) -> int:
    """Hit window for a judgement, widened by the difficulty's scale and rounded down."""
    base = get(f"judging.{judgement}.windowMicros")
    return base * get(f"judging.windowScalePercent.{difficulty}") // 100


def points(judgement: str) -> int:
    return get(f"judging.{judgement}.points")


def chart_rules(difficulty: str) -> dict[str, Any]:
    return get(f"charts.rules.{difficulty}")


def song_duration_micros() -> tuple[int, int]:
    return get("songs.minDurationMicros"), get("songs.maxDurationMicros")

import json
import subprocess
import sys
from pathlib import Path

import pytest

from riff_tools import __version__, config

TOOLS = Path(__file__).resolve().parent.parent


def test_snapshot_has_every_difficulty():
    for difficulty in config.DIFFICULTIES:
        assert config.chart_rules(difficulty)
        assert config.get(f"highway.scrollTimeMicros.{difficulty}") > 0


def test_values_match_the_plan():
    assert config.lane_count() == 4
    assert config.ticks_per_beat() == 192
    assert [config.points(j) for j in ("perfect", "great", "good")] == [100, 80, 50]
    assert config.window_micros("perfect", "expert") == 45_000
    assert config.window_micros("good", "easy") == 156_000


def test_windows_widen_outward():
    for difficulty in config.DIFFICULTIES:
        windows = [config.window_micros(j, difficulty) for j in ("perfect", "great", "good")]
        assert windows == sorted(windows) and len(set(windows)) == 3


def test_unknown_key_raises():
    with pytest.raises(KeyError):
        config.get("judging.nope")


def run_cli(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, "-m", "riff_tools", *args], cwd=TOOLS, capture_output=True, text=True
    )


def test_cli_prints_version_and_values():
    assert run_cli("--version").stdout.strip() == __version__
    assert json.loads(run_cli("config", "highway.laneCount").stdout) == 4
    assert "judging" in json.loads(run_cli("config").stdout)
    assert run_cli("config", "no.such.key").returncode == 1

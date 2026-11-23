#!/usr/bin/env python3
"""Generate the two original 90-second AAC tones used only by the device spike."""

import math
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "RiffMessages" / "Spike" / "Resources"
RATE = 48_000
FRAMES = RATE * 90
BLOCK = 4_096


def write_tone(path: Path, frequency: int) -> None:
    with wave.open(str(path), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        for start in range(0, FRAMES, BLOCK):
            samples = []
            for frame in range(start, min(start + BLOCK, FRAMES)):
                fade = min(1.0, frame / RATE, (FRAMES - frame) / RATE)
                samples.append(
                    int(3_500 * fade * math.sin(2 * math.pi * frequency * frame / RATE))
                )
            audio.writeframes(struct.pack(f"<{len(samples)}h", *samples))


def main() -> None:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="riff-spike-audio-") as directory:
        for suffix, frequency in (("a", 440), ("b", 660)):
            source = Path(directory) / f"stem-{suffix}.wav"
            destination = DESTINATION / f"spike-stem-{suffix}.m4a"
            write_tone(source, frequency)
            subprocess.run(
                [
                    "afconvert",
                    "-f",
                    "m4af",
                    "-d",
                    "aac",
                    "-b",
                    "64000",
                    str(source),
                    str(destination),
                ],
                check=True,
            )
            print(f"Wrote {destination.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

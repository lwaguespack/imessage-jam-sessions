#!/usr/bin/env python3
"""Usage: scripts/make-placeholder-icons.py [--check]

Writes the temporary app icons (a flat colour with the letter R) and the asset-catalog manifests that list
them. With --check, verifies that every listed file exists with the pixel size its slot needs.
Real artwork replaces these in Phase 8.
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
BACKGROUND = (34, 24, 72)
FOREGROUND = (255, 214, 92)

# (idiom, size in points, scale, platform or None), as Xcode lays out an "iMessage App Icon" set.
MESSAGES_SLOTS = [
    ("iphone", "29x29", 2, None),
    ("iphone", "29x29", 3, None),
    ("iphone", "60x45", 2, None),
    ("iphone", "60x45", 3, None),
    ("ipad", "29x29", 2, None),
    ("ipad", "67x50", 2, None),
    ("ipad", "74x55", 2, None),
    ("ios-marketing", "1024x1024", 1, None),
    ("universal", "27x20", 2, "ios"),
    ("universal", "27x20", 3, "ios"),
    ("universal", "32x24", 2, "ios"),
    ("universal", "32x24", 3, "ios"),
    ("ios-marketing", "1024x768", 1, "ios"),
]
MESSAGES_SET = ROOT / "RiffMessages/Assets.xcassets/iMessage App Icon.stickersiconset"
APP_SET = ROOT / "RiffApp/Assets.xcassets/AppIcon.appiconset"
INFO = {"author": "xcode", "version": 1}


def pixels(size: str, scale: int) -> tuple[int, int]:
    width, height = (int(part) for part in size.split("x"))
    return width * scale, height * scale


def draw(width: int, height: int) -> Image.Image:
    # No alpha channel: App Store marketing icons must be opaque.
    image = Image.new("RGB", (width, height), BACKGROUND)
    canvas = ImageDraw.Draw(image)
    font = ImageFont.load_default(size=max(8, int(min(width, height) * 0.7)))
    canvas.text((width / 2, height / 2), "R", font=font, fill=FOREGROUND, anchor="mm")
    if min(width, height) >= 512:
        small = ImageFont.load_default(size=int(min(width, height) * 0.06))
        canvas.text((width / 2, height * 0.9), "placeholder", font=small, fill=FOREGROUND, anchor="mm")
    return image


def manifests() -> dict[Path, dict]:
    images = []
    for idiom, size, scale, platform in MESSAGES_SLOTS:
        width, height = pixels(size, scale)
        entry = {"filename": f"messages-{idiom}-{width}x{height}.png", "idiom": idiom, "scale": f"{scale}x", "size": size}
        if platform:
            entry["platform"] = platform
        images.append(entry)
    app = [{"filename": "app-1024x1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    return {
        MESSAGES_SET: {"images": images, "info": INFO},
        APP_SET: {"images": app, "info": INFO},
    }


def expected_size(entry: dict) -> tuple[int, int]:
    return pixels(entry["size"], int(entry.get("scale", "1x").rstrip("x")))


def generate() -> None:
    for folder, manifest in manifests().items():
        folder.mkdir(parents=True, exist_ok=True)
        for entry in manifest["images"]:
            draw(*expected_size(entry)).save(folder / entry["filename"], optimize=True)
        (folder / "Contents.json").write_text(json.dumps(manifest, indent=2) + "\n")


def check() -> int:
    problems = []
    for folder in (MESSAGES_SET, APP_SET):
        manifest = json.loads((folder / "Contents.json").read_text())
        for entry in manifest["images"]:
            path = folder / entry.get("filename", "")
            if not entry.get("filename") or not path.is_file():
                problems.append(f"{folder.name}: missing file for {entry}")
                continue
            with Image.open(path) as image:
                if image.size != expected_size(entry):
                    problems.append(f"{path.name}: is {image.size}, needs {expected_size(entry)}")
                if image.mode != "RGB":
                    problems.append(f"{path.name}: mode {image.mode}, needs RGB (no alpha)")
    for problem in problems:
        print(problem, file=sys.stderr)
    print("icons: " + ("FAIL" if problems else "ok"))
    return 1 if problems else 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--check"]:
        sys.exit(check())
    generate()
    sys.exit(check())

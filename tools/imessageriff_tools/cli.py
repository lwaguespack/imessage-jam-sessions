"""Command line entry point: `python -m imessageriff_tools`."""

import argparse
import json
import sys

from . import __version__, config


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="imessageriff_tools", description=__doc__)
    parser.add_argument("--version", action="version", version=__version__)
    commands = parser.add_subparsers(dest="command", required=True)
    show = commands.add_parser("config", help="print the engine tunables, or one value")
    show.add_argument(
        "key", nargs="?", help="dotted path, for example judging.perfect.windowMicros"
    )
    args = parser.parse_args(argv)

    if args.command == "config":
        try:
            value = config.get(args.key) if args.key else config.load()
        except KeyError:
            print(f"imessageriff_tools: no such key: {args.key}", file=sys.stderr)
            return 1
        print(json.dumps(value, indent=2, sort_keys=True))
    return 0

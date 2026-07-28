#!/usr/bin/env python3
"""Convert a binary CHIP-8 ROM into a Verilog $readmemh byte file."""

from pathlib import Path
import argparse
import sys


MAX_ROM_SIZE = 4096 - 0x200


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert a .ch8 binary to an ASCII $readmemh file."
    )
    parser.add_argument("input", type=Path, help="input binary .ch8 ROM")
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "roms" / "rom.hex",
        help="output file (default: project roms/rom.hex)",
    )
    args = parser.parse_args()

    try:
        rom = args.input.read_bytes()
    except OSError as error:
        print("error: cannot read {}: {}".format(args.input, error), file=sys.stderr)
        return 1

    if not rom:
        print("error: ROM is empty", file=sys.stderr)
        return 1
    if len(rom) > MAX_ROM_SIZE:
        print(
            "error: ROM is {} bytes; maximum at load address 0x200 is {}".format(
                len(rom), MAX_ROM_SIZE
            ),
            file=sys.stderr,
        )
        return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    text = "".join("{:02X}\n".format(byte) for byte in rom)
    args.output.write_text(text, encoding="ascii")

    print(
        "converted {} bytes: {} -> {}".format(
            len(rom), args.input, args.output
        )
    )
    print("ROM will occupy CHIP-8 addresses 0x200-0x{:03X}".format(0x1FF + len(rom)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

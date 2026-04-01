#!/usr/bin/env python3
"""
fix_checksum.py - Compute and write the correct checksum into a Genesis ROM header
Usage: python fix_checksum.py input.md output.md
"""

import sys


def fix_checksum(input_path, output_path):
    with open(input_path, "rb") as f:
        data = bytearray(f.read())

    if len(data) % 2 != 0:
        data.append(0)

    while len(data) < 512:
        data.append(0)

    checksum = 0
    for i in range(0x200, len(data), 2):
        word = (data[i] << 8) | data[i + 1]
        checksum = (checksum + word) & 0xFFFF

    data[0x018E] = (checksum >> 8) & 0xFF
    data[0x018F] = checksum & 0xFF

    with open(output_path, "wb") as f:
        f.write(data)

    print(f"  Checksum: ${checksum:04X}")
    print(f"  ROM size: {len(data)} bytes ({len(data) // 1024} KB)")
    print(f"  Written:  {output_path}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python fix_checksum.py input.md output.md")
        sys.exit(1)
    fix_checksum(sys.argv[1], sys.argv[2])

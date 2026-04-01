#!/usr/bin/env python3
"""
archive_phase_build.py - Save a successful build as P<phase>.<n>.
"""

from __future__ import annotations

import argparse
import re
import shutil
from datetime import datetime
from pathlib import Path


def read_header_checksum(rom_path: Path) -> int:
    data = rom_path.read_bytes()
    return (data[0x018E] << 8) | data[0x018F]


def next_build_number(out_dir: Path, phase: int) -> int:
    pattern = re.compile(rf"^P{phase}\.(\d+)\.md$", re.IGNORECASE)
    seen = []
    for path in out_dir.glob(f"P{phase}.*.md"):
        match = pattern.match(path.name)
        if match:
            seen.append(int(match.group(1)))
    return (max(seen) + 1) if seen else 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", type=int, required=True)
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--lst", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    rom_path = args.rom.resolve()
    lst_path = args.lst.resolve()
    out_dir = args.out_dir.resolve()

    if not rom_path.is_file():
        raise FileNotFoundError(f"missing ROM: {rom_path}")
    if not lst_path.is_file():
        raise FileNotFoundError(f"missing listing: {lst_path}")

    out_dir.mkdir(parents=True, exist_ok=True)
    build_number = next_build_number(out_dir, args.phase)
    stem = f"P{args.phase}.{build_number}"

    archived_rom = out_dir / f"{stem}.md"
    archived_lst = out_dir / f"{stem}.lst"
    archived_txt = out_dir / f"{stem}.txt"

    shutil.copy2(rom_path, archived_rom)
    shutil.copy2(lst_path, archived_lst)

    checksum = read_header_checksum(archived_rom)
    archived_txt.write_text(
        "\n".join(
            [
                f"build={stem}",
                f"phase={args.phase}",
                f"timestamp={datetime.now().isoformat(timespec='seconds')}",
                f"checksum=${checksum:04X}",
                f"rom={archived_rom.name}",
                f"lst={archived_lst.name}",
            ]
        )
        + "\n",
        encoding="ascii",
    )

    print(f"Archived build: {archived_rom}")
    print(f"Archived listing: {archived_lst}")
    print(f"Build metadata: {archived_txt}")
    print(f"Header checksum: ${checksum:04X}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

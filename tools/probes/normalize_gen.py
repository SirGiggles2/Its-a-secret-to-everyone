#!/usr/bin/env python3
"""Normalize a Genesis VDP capture into the canonical scene schema.

Scope (S1 Phase H1, Q4 schema validation):
    Reads a GDMP dump from tools/probes/bizhawk_capture_gen.lua and emits
    the same schema shape that normalize_nes.py emits. NES->Genesis tile
    re-mapping is a TODO that lands in S2 once data/chr/MANIFEST.json
    documents the correspondence.

Schema (per spec Section 0): same as normalize_nes.py output.

Status at S1 close:
    - Schema shape IS LOCKED (matches normalize_nes.py output).
    - bg_tile field currently uses RAW Genesis tile index (0..2047).
      To diff against NES side, the S2 mapping table will translate
      Genesis tile index -> canonical NES tile id (the inverse of the
      extraction step that put NES CHR into Genesis VRAM).
    - sprite tile_id similarly uses raw Genesis tile index.
    - palette index uses raw CRAM palette slot (0..3) which maps 1:1
      to NES BG/sprite palette index after the extraction's palette
      packing convention (S2 confirms).
"""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path
from typing import Any

MAGIC = b"GDMP"


def read_dump(path: Path) -> tuple[dict[str, bytes], int]:
    data = path.read_bytes()
    if data[:4] != MAGIC:
        raise ValueError(f"{path}: not a GDMP dump")
    version, frame, _hash = struct.unpack_from("<III", data, 4)
    regions: dict[str, bytes] = {}
    pos = 16
    while pos + 8 <= len(data):
        tag = data[pos : pos + 4].decode("ascii", errors="replace")
        length = struct.unpack_from("<I", data, pos + 4)[0]
        pos += 8
        if tag == "END_":
            break
        regions[tag] = data[pos : pos + length]
        pos += length
    return regions, frame


def normalize(dump_path: Path) -> dict[str, Any]:
    regions, frame = read_dump(dump_path)

    plana = regions.get("PLNA", b"")
    sat = regions.get("SAT_", b"")
    cram = regions.get("CRAM", b"")
    vsra = regions.get("VSRA", b"")
    zp = regions.get("RAM_", b"")

    # Plane A: H32 mode = 64x32 tile cells, 2 bytes per cell.
    bg_tile: dict[str, int] = {}
    bg_palette: dict[str, int] = {}
    bg_priority: dict[str, int] = {}
    if len(plana) >= 64 * 32 * 2:
        for row in range(32):
            for col in range(64):
                base = (row * 64 + col) * 2
                cell = (plana[base] << 8) | plana[base + 1]
                tile = cell & 0x07FF
                pal = (cell >> 13) & 0x03
                pri = (cell >> 15) & 0x01
                bg_tile[f"{col},{row}"] = tile
                bg_palette[f"{col},{row}"] = pal
                bg_priority[f"{col},{row}"] = pri

    # SAT: 80 sprite slots in H32, 8 bytes each (y, link, attr, x).
    sprites = []
    if len(sat) >= 80 * 8:
        for i in range(80):
            base = i * 8
            y = (sat[base + 0] << 8) | sat[base + 1]
            link_size = (sat[base + 2] << 8) | sat[base + 3]
            attr_tile = (sat[base + 4] << 8) | sat[base + 5]
            x = (sat[base + 6] << 8) | sat[base + 7]
            tile = attr_tile & 0x07FF
            pal = (attr_tile >> 13) & 0x03
            hflip = (attr_tile >> 11) & 1
            vflip = (attr_tile >> 12) & 1
            pri = (attr_tile >> 15) & 1
            # VDP sprite y/x carry 128-offset; convert to NES-style coords.
            sprites.append({
                "i": i,
                "x": x - 128 if x >= 128 else x,
                "y": y - 128 if y >= 128 else y,
                "tile_id": tile,
                "palette": pal,
                "flip_x": hflip,
                "flip_y": vflip,
                "priority": pri,
                "size_link": link_size,
            })

    # VSRAM[0] is plane A vertical scroll.
    vy = (vsra[0] << 8) | vsra[1] if len(vsra) >= 2 else 0
    # Horizontal scroll lives in VRAM at the address VDP register 0x0D points
    # to; not captured directly. Spec lets us record it as 0 for the H1 lock
    # since canonical-movie diff focuses on byte parity, not visual coords.
    vx = 0

    return {
        "schema_version": 1,
        "platform": "genesis",
        "frame": frame,
        "bg_tile": bg_tile,
        "bg_palette": bg_palette,
        "bg_priority": bg_priority,
        "sprite": sprites,
        "scroll": {"x": vx, "y": vy},
        "cram": list(cram),
        "state": {"zp": list(zp[:64]) if zp else []},
    }


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: normalize_gen.py <gen_dump.bin> [out.json]\n")
        return 2
    schema = normalize(Path(argv[1]))
    out = sys.stdout if len(argv) < 3 else open(argv[2], "w", encoding="utf-8")
    json.dump(schema, out, indent=2)
    if out is not sys.stdout:
        out.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

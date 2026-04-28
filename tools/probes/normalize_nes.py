#!/usr/bin/env python3
"""Normalize a NES PPU/OAM/PALRAM capture into the canonical scene schema.

Scope (S1 Phase H1, Q4 schema validation):
    Defines the schema shape the NES->Genesis parity diff requires. The NES
    capture format is provisioned; the *content* of bg_tile / sprite tile
    canonicalization is a TODO that lands in S2 (data extraction) once the
    NES->Genesis tile-id mapping is concretely established.

Schema (from spec Section 0):
    bg_tile[col, row]      -- canonical NES tile id (8 KB pattern table)
    bg_palette[col, row]   -- 0..3 (NES BG palette index from attribute byte)
    bg_priority[col, row]  -- 0/1 logical priority layer
    sprite[i]              -- {x, y, tile_id, palette, flip_x, flip_y, priority}
    scroll                 -- {x, y} in canonical NES pixel units
    state                  -- {frame_counter, rng, mode, link_state}

Input format (.bin produced by tools/probes/bizhawk_capture_nes.lua, NOT YET
WRITTEN -- placeholder schema documented here):

    header:    8 bytes magic "NESDMP1\\0" + 4 bytes frame counter u32 LE
    regions:   4-byte tag, 4-byte length u32 LE, payload bytes
    tags:      "NTBL" -- 1 KB nametable for visible screen (32 cols x 30 rows)
               "ATTR" -- 64 bytes attribute table (8x8 super-cell grid)
               "PAL_" -- 32 bytes PALRAM ($3F00-$3F1F)
               "OAM_" -- 256 bytes sprite attribute table
               "SCRL" -- 4 bytes (scroll_x, scroll_y, base_x_high, base_y_high)
               "STAT" -- variable; gameplay state fields per scenario
    terminator: tag "END_" length 0

Output: a Python dict serialized to JSON via stdout (or to argv[2] if given).

Status at S1 close:
    - Schema shape IS LOCKED (this file's data structures + JSON output).
    - bg_tile field uses raw NES tile id (no remap; identity at NES side).
    - sprite tile_id uses raw NES tile id (no remap).
    - Genesis side (normalize_gen.py) WILL need a tile-mapping table from
      data/chr/MANIFEST.json (S2 deliverable) to convert Genesis VRAM tile
      indices back to canonical NES tile ids before diff.
"""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path
from typing import Any


MAGIC = b"NESDMP1\x00"


def read_dump(path: Path) -> tuple[dict[str, bytes], int]:
    data = path.read_bytes()
    if data[:8] != MAGIC:
        raise ValueError(f"{path}: not a NES dump (bad magic)")
    frame = struct.unpack_from("<I", data, 8)[0]
    regions: dict[str, bytes] = {}
    pos = 12
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

    nt = regions.get("NTBL", b"")
    at = regions.get("ATTR", b"")
    palram = regions.get("PAL_", b"")
    oam = regions.get("OAM_", b"")
    scrl = regions.get("SCRL", b"\x00\x00\x00\x00")
    stat = regions.get("STAT", b"")

    bg_tile: dict[str, int] = {}
    bg_palette: dict[str, int] = {}
    bg_priority: dict[str, int] = {}
    if len(nt) >= 32 * 30 and len(at) >= 64:
        for row in range(30):
            for col in range(32):
                bg_tile[f"{col},{row}"] = nt[row * 32 + col]
                # NES attribute table: 64 bytes covering 8x8 super-cells of
                # 4x4 tiles each. Each byte = 4 2-bit palette indices for
                # 2x2 quadrants.
                super_col = col // 4
                super_row = row // 4
                attr_byte = at[super_row * 8 + super_col]
                # Quadrant within super-cell: 2x2 of 2x2 tiles.
                quad_col = (col // 2) & 1
                quad_row = (row // 2) & 1
                shift = (quad_row * 2 + quad_col) * 2
                bg_palette[f"{col},{row}"] = (attr_byte >> shift) & 0x03
                bg_priority[f"{col},{row}"] = 0  # NES BG priority logic TODO

    sprites = []
    if len(oam) >= 256:
        for i in range(64):
            base = i * 4
            y = oam[base + 0]
            tile = oam[base + 1]
            attr = oam[base + 2]
            x = oam[base + 3]
            sprites.append({
                "i": i,
                "x": x,
                "y": y,
                "tile_id": tile,
                "palette": attr & 0x03,
                "flip_x": (attr >> 6) & 1,
                "flip_y": (attr >> 7) & 1,
                "priority": (attr >> 5) & 1,
            })

    sx = scrl[0] if len(scrl) > 0 else 0
    sy = scrl[1] if len(scrl) > 1 else 0

    return {
        "schema_version": 1,
        "platform": "nes",
        "frame": frame,
        "bg_tile": bg_tile,
        "bg_palette": bg_palette,
        "bg_priority": bg_priority,
        "sprite": sprites,
        "scroll": {"x": sx, "y": sy},
        "palram": list(palram),
        "state": {"raw": list(stat)},
    }


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: normalize_nes.py <nes_dump.bin> [out.json]\n")
        return 2
    schema = normalize(Path(argv[1]))
    out = sys.stdout if len(argv) < 3 else open(argv[2], "w", encoding="utf-8")
    json.dump(schema, out, indent=2)
    if out is not sys.stdout:
        out.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

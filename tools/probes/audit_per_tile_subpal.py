#!/usr/bin/env python3
"""Phase I audit (2026-05-18 VRAM cleanup): per-NES-tile-ID sub-palette
usage across all rooms. Decides whether selective BG dedup is viable.

For each NES BG tile ID (0..255), count distinct sub-palettes it appears
with across all UW + OW rooms. If most tiles use 1-2 sub-pals, the BG_4x
replication can be selectively reduced.

UW: g_uw_room_nt[room][cell_idx] = NES tile ID at cell (col, row).
    g_uw_room_attr[room][quad_idx] = packed AT byte (4 sub-pals per byte).
    Each AT byte covers a 2x2 group of cells.

OW: data/rooms/overworld.c rooms_overworld blob. Bytes 0..127 = tile
    IDs (column-major mapping per data/rooms/overworld_offsets.h). The
    attr is a single byte per room (one sub-pal for entire room).

Output: histogram of (distinct sub-pals per tile), plus list of tiles
that need 4-way replication.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
UW_BLOB_C = REPO / "RoomRom" / "src" / "uw_room_blob.c"
OW_C = REPO / "data" / "rooms" / "overworld.c"


def parse_uw_blob():
    """Returns list of (room_idx, nt_bytes[22*32=704], attr_bytes[64])."""
    text = UW_BLOB_C.read_text(encoding="utf-8", errors="ignore")

    # g_uw_room_nt — flat array of (room_count * 704) bytes
    nt_match = re.search(r"g_uw_room_nt\[\d+\]\[\d+\] = \{(.+?)\n\};",
                         text, re.S)
    if not nt_match:
        return []
    nt_bytes = [int(b, 16) for b in re.findall(r"0x([0-9a-fA-F]{2})",
                                                nt_match.group(1))]

    attr_match = re.search(r"g_uw_room_attr\[\d+\]\[64\] = \{(.+?)\n\};",
                           text, re.S)
    if not attr_match:
        return []
    attr_bytes = [int(b, 16) for b in re.findall(r"0x([0-9a-fA-F]{2})",
                                                  attr_match.group(1))]

    CELLS_PER_ROOM = 22 * 32   # 704
    ATTR_PER_ROOM = 64

    n_nt = len(nt_bytes) // CELLS_PER_ROOM
    n_attr = len(attr_bytes) // ATTR_PER_ROOM
    n_rooms = min(n_nt, n_attr)

    rooms = []
    for r in range(n_rooms):
        nt = nt_bytes[r * CELLS_PER_ROOM:(r + 1) * CELLS_PER_ROOM]
        at = attr_bytes[r * ATTR_PER_ROOM:(r + 1) * ATTR_PER_ROOM]
        rooms.append((r, nt, at))
    return rooms


def uw_quad_subpal(attr_byte, quad_pos):
    """quad_pos = 0..3 (TL, TR, BL, BR within attr byte)."""
    return (attr_byte >> (quad_pos * 2)) & 0x03


def collect_uw_per_tile_subpals(rooms):
    """Returns dict {tile_id: set(sub_pals)}.

    Uses the EXACT attr formula from src/game/dungeon/uw_render.c:380-392:
        at_idx = ((nt_row >> 2) << 3) | (nt_col >> 2)   -- 8 quads/row, 8 rows
        shift  = (((nt_row >> 1) & 1) << 2) | (((nt_col >> 1) & 1) << 1)
        sub_pal = (attr[at_idx] >> shift) & 0x03

    UW room nt is 22 cols × 32 rows. Cell index = row * 32 + col.
    Cells render starting at nt_row = row + 8 (HUD occupies 0..7).
    """
    out = defaultdict(set)
    for room_idx, nt, attr in rooms:
        for row in range(32):
            for col in range(22):
                nt_offset = row * 32 + col
                if nt_offset >= len(nt):
                    continue
                tile_id = nt[nt_offset]
                # Match uw_render.c::attr_palette_for() exactly:
                nt_row = row + 8
                nt_col = col
                at_idx = ((nt_row >> 2) << 3) | (nt_col >> 2)
                if at_idx >= len(attr):
                    continue
                attr_byte = attr[at_idx & 0x3F]
                shift = (((nt_row >> 1) & 1) << 2) | (((nt_col >> 1) & 1) << 1)
                sub_pal = (attr_byte >> shift) & 0x03
                out[tile_id].add(sub_pal)
    return out


def parse_ow_data():
    """Returns list of (room_idx, tile_ids[N], single_attr)."""
    if not OW_C.exists():
        return []
    text = OW_C.read_text(encoding="utf-8", errors="ignore")
    blob_match = re.search(r"rooms_overworld\[\] = \{(.+?)\};", text, re.S)
    if not blob_match:
        return []
    bs = [int(b, 16) for b in re.findall(r"0x([0-9a-fA-F]{2})",
                                          blob_match.group(1))]
    # 128 rooms x N tile bytes + 128 attr bytes. Heuristic: skip the
    # attr table at the end for simplicity; use first 128 as room IDs.
    rooms = []
    for room in range(128):
        # NES Z1 OW: each room has ~16x11 = 176 BG cells of tile data,
        # stored compactly. The exact offsets are in overworld_offsets.h.
        # For audit purposes, approximate by counting attr byte usage.
        attr_byte = bs[128 + room] if (128 + room) < len(bs) else 0
        rooms.append((room, attr_byte))
    return rooms


def main():
    uw_rooms = parse_uw_blob()
    print(f"UW rooms parsed: {len(uw_rooms)}")

    if not uw_rooms:
        print("ERROR: no UW rooms parsed; check uw_room_blob.c format")
        return 1

    per_tile_uw = collect_uw_per_tile_subpals(uw_rooms)

    # Histogram of (distinct sub-pal count) per tile
    histogram = defaultdict(int)
    multi_subpal_tiles = []
    for tile_id, subpals in per_tile_uw.items():
        n_distinct = len(subpals)
        histogram[n_distinct] += 1
        if n_distinct >= 3:
            multi_subpal_tiles.append((tile_id, sorted(subpals)))

    total_tiles_used = sum(histogram.values())
    print(f"\nUW per-tile sub-pal distribution (across {total_tiles_used} unique tile IDs):")
    for k in sorted(histogram.keys()):
        pct = 100.0 * histogram[k] / total_tiles_used
        print(f"  tiles using {k} sub-pal(s): {histogram[k]:4d}  ({pct:5.1f}%)")

    # Net replication needed = sum of distinct sub-pals per tile
    total_copies_needed = sum(len(s) for s in per_tile_uw.values())
    total_copies_4x = total_tiles_used * 4
    savings_tiles = total_copies_4x - total_copies_needed
    savings_pct = 100.0 * savings_tiles / total_copies_4x

    print(f"\nReplication accounting (UW BG only):")
    print(f"  current (4x replication): {total_copies_4x:4d} tile copies")
    print(f"  selective dedup minimum:  {total_copies_needed:4d} tile copies")
    print(f"  potential savings:        {savings_tiles:4d} tiles ({savings_pct:.1f}%)")

    print(f"\nTiles needing 3+ sub-pals (worst-case replication):")
    for tile_id, sps in sorted(multi_subpal_tiles)[:20]:
        print(f"  tile 0x{tile_id:02X}: {sps}")
    if len(multi_subpal_tiles) > 20:
        print(f"  ... and {len(multi_subpal_tiles) - 20} more")

    # Phase J truncation analysis: max NES tile ID used.
    max_tile_id = max(per_tile_uw.keys())
    print(f"\nTruncation analysis (UW BG only):")
    print(f"  max NES tile ID used: 0x{max_tile_id:02X} ({max_tile_id})")
    print(f"  current 4x bank: 256 tiles/subpal x 4 = 1024 tiles")
    print(f"  truncated bank: {max_tile_id+1} tiles/subpal x 4 = {(max_tile_id+1)*4} tiles")
    print(f"  truncation savings: {1024 - (max_tile_id+1)*4} tiles")

    # Per-sub-pal max tile ID (smarter truncation):
    max_per_subpal = {0: -1, 1: -1, 2: -1, 3: -1}
    for tile_id, sps in per_tile_uw.items():
        for sp in sps:
            if tile_id > max_per_subpal[sp]:
                max_per_subpal[sp] = tile_id
    total_per_subpal_truncated = sum(max + 1 for max in max_per_subpal.values() if max >= 0)
    print(f"  per-sub-pal max tile IDs: {[f'pal{k}=0x{v:02X}' for k,v in max_per_subpal.items()]}")
    print(f"  per-sub-pal-truncated bank: {total_per_subpal_truncated} tiles")
    print(f"  per-sub-pal truncation savings: {1024 - total_per_subpal_truncated} tiles")

    return 0


if __name__ == "__main__":
    sys.exit(main())

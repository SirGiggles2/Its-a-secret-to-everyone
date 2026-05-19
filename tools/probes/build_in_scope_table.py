"""build_in_scope_table.py — extract every (nes_tile_id, sub_pal) -> Genesis
VRAM slot from bg_sparse_tile_lut + item_chr_manifest.json. Emits
tools/probes/in_scope_tile_table.json for chr_grid_diff to consume.

In-scope = atlas has a non-0xFFFF entry for that (tile, sub_pal) combo,
i.e. the port intentionally extracted bytes for it. Out-of-scope (sentinel
0xFFFF) means the port doesn't render that tile in any scene — diff
ticket for it is informational not regression.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys


def parse_bg_sparse_lut(path: pathlib.Path) -> dict:
    """Parse the const unsigned short bg_sparse_tile_lut[256][4] = { ... }
    block from RoomRom/src/bg_sparse_chr.c."""
    text = path.read_text(encoding="utf-8", errors="ignore")
    # Locate the LUT block
    m = re.search(r"bg_sparse_tile_lut\[256\]\[4\][^=]*=\s*\{(.*?)\};",
                  text, re.DOTALL)
    if not m:
        print("ERROR: bg_sparse_tile_lut not found", file=sys.stderr)
        sys.exit(1)
    body = m.group(1)
    rows = re.findall(
        r"\{\s*0x([0-9A-Fa-f]{4})\s*,\s*0x([0-9A-Fa-f]{4})\s*,"
        r"\s*0x([0-9A-Fa-f]{4})\s*,\s*0x([0-9A-Fa-f]{4})\s*\}",
        body)
    lut = {}
    for i, row in enumerate(rows):
        lut[i] = [int(c, 16) for c in row]
    return lut


def main():
    repo = pathlib.Path(__file__).resolve().parents[2]
    sparse_c = repo / "RoomRom" / "src" / "bg_sparse_chr.c"
    manifest = repo / "RoomRom" / "data" / "item_chr_manifest.json"

    lut = parse_bg_sparse_lut(sparse_c)
    print(f"parsed bg_sparse_tile_lut: {len(lut)} tile_ids")

    # In-scope entries: (tile_id, sub_pal) with non-0xFFFF slot
    in_scope = []
    out_of_scope = []
    for tile_id in range(256):
        for sub_pal in range(4):
            slot = lut.get(tile_id, [0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF])[sub_pal]
            entry = {"tile_id": tile_id, "sub_pal": sub_pal, "slot": slot}
            if slot == 0xFFFF:
                out_of_scope.append(entry)
            else:
                in_scope.append(entry)

    # Item manifest entries (sprite side — tile_id range $20+ items)
    manifest_items = []
    if manifest.exists():
        m = json.loads(manifest.read_text(encoding="utf-8"))
        for it in m.get("item_defs", []):
            manifest_items.append({
                "name": it.get("name"),
                "tile_ids": it.get("tile_ids", []),
                "sprite_size": it.get("sprite_size"),
            })

    out = {
        "schema_version": 1,
        "source": "bg_sparse_tile_lut from RoomRom/src/bg_sparse_chr.c + item_chr_manifest.json",
        "bg_in_scope_count": len(in_scope),
        "bg_out_of_scope_count": len(out_of_scope),
        "manifest_item_count": len(manifest_items),
        "bg_in_scope": in_scope,
        "bg_out_of_scope": out_of_scope,
        "manifest_items": manifest_items,
    }
    out_path = repo / "tools" / "probes" / "in_scope_tile_table.json"
    out_path.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(f"wrote {out_path}")
    print(f"  BG in-scope:     {len(in_scope)} (tile_id, sub_pal) combos")
    print(f"  BG out-of-scope: {len(out_of_scope)} sentinel entries")
    print(f"  manifest items:  {len(manifest_items)} sprite defs")


if __name__ == "__main__":
    main()

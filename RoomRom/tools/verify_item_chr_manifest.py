#!/usr/bin/env python3
"""Verify RoomRom item CHR manifest and renderer source-safety gates."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "RoomRom" / "data" / "item_chr_manifest.json"
HEADER = ROOT / "RoomRom" / "src" / "roomrom_item_chr.h"
SOURCE = ROOT / "RoomRom" / "src" / "roomrom_sprites.c"

REQUIRED_DEFS = {
    "sword_vert",
    "sword_horz",
    "boomerang",
    "arrow_vert",
    "arrow_horz",
    "bomb",
    "explosion",
}

FORBIDDEN_COMMON_GUESSES = {
    "0x82u", "0x83u", "0x84u", "0x85u",
    "0x86u", "0x87u", "0x88u", "0x89u",
}


def fail(msg: str) -> None:
    raise SystemExit(f"FAIL: {msg}")


def main() -> int:
    if not MANIFEST.exists():
        fail(f"missing manifest: {MANIFEST}")
    manifest = json.loads(MANIFEST.read_text(encoding="ascii"))
    if manifest.get("schema_version") != 1:
        fail("unsupported manifest schema")
    if manifest.get("source_policy") != "live_nes_chr_only":
        fail("manifest source_policy must be live_nes_chr_only")

    defs = manifest.get("item_defs", [])
    names = {d.get("name") for d in defs}
    missing = sorted(REQUIRED_DEFS - names)
    if missing:
        fail(f"missing item defs: {', '.join(missing)}")

    total_tiles = 0
    for item_def in defs:
        tile_ids = item_def.get("tile_ids", [])
        if not tile_ids:
            fail(f"{item_def.get('name')} has no tile_ids")
        total_tiles += len(tile_ids)

    variants = manifest.get("variants", [])
    if not variants:
        fail("manifest has no variants")
    for variant in variants:
        tiles = variant.get("tiles", {})
        for item_def in defs:
            for tile_id in item_def["tile_ids"]:
                meta = tiles.get(tile_id)
                if meta is None:
                    fail(f"{variant.get('rom_id')} missing tile {tile_id}")
                if meta.get("source") == "guessed_common_chr":
                    fail(f"{tile_id} uses guessed_common_chr")
                raw = bytes.fromhex(meta.get("bytes", ""))
                if len(raw) != 16:
                    fail(f"{variant.get('rom_id')} {tile_id} is not 16 bytes")

    if not HEADER.exists():
        fail(f"missing generated header: {HEADER}")
    htext = HEADER.read_text(encoding="ascii")
    m = re.search(r"#define\s+ROOMROM_ITEM_CHR_TILE_COUNT\s+(\d+)u", htext)
    if not m:
        fail("generated header missing ROOMROM_ITEM_CHR_TILE_COUNT")
    if int(m.group(1)) != total_tiles:
        fail("generated header tile count does not match manifest")

    src = SOURCE.read_text(encoding="utf-8")
    for token in FORBIDDEN_COMMON_GUESSES:
        if token in src:
            fail(f"renderer still contains forbidden guessed item tile {token}")
    if "roomrom_item_chr" not in src:
        fail("renderer is not wired to generated item CHR atlas")

    print(
        f"OK: item CHR manifest verified "
        f"({len(variants)} variant(s), {total_tiles} generated tiles)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

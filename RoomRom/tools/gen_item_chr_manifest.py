#!/usr/bin/env python3
"""Build the RoomRom item CHR manifest from live NES CHR captures.

The manifest is intentionally based on CHR bytes captured from a running NES
emulator, not on guessed common_chr offsets.  RoomRom's generated item atlas
uses this manifest as its only source.

DEPRECATED (atlas spec P6b, 2026-05-02): this script is superseded by
gen_atlas.py which owns manifest generation for all sprite categories.
See RoomRom/tools/gen_atlas.py for the replacement.

This script remains runnable; walk_z1_disasm.py imports ITEM_DEFS from
it for informational diffing against the disassembly. Do not extend this
script; add new item manifest entries to item_chr_manifest.json directly
and regenerate via gen_atlas.py instead.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Dict, Iterable, List, Tuple


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "RoomRom" / "data" / "item_chr_manifest.json"
DEFAULT_ORIG_CHR = ROOT / "tools" / "out" / "nes_sword_ppu0.bin"


ITEM_DEFS = [
    {
        "name": "sword_vert",
        "item": "sword",
        "direction_class": "vertical",
        "nes_frame_tile": 0x20,
        "sprite_size": [1, 2],
        "tile_ids": [0x20, 0x21],
        "draw_rule": "narrow_8x16",
    },
    {
        "name": "sword_horz",
        "item": "sword",
        "direction_class": "horizontal",
        "nes_frame_tile": 0x82,
        "sprite_size": [2, 2],
        "tile_ids": [0x82, 0x83, 0x84, 0x85],
        "draw_rule": "wide_16x16_hflippable",
    },
    {
        "name": "boomerang",
        "item": "boomerang",
        "direction_class": "rotating",
        "nes_frame_tile": 0x36,
        "sprite_size": [1, 1],
        "tile_ids": list(range(0x36, 0x3E)),
        "draw_rule": "narrow_8x8_phase_cycle",
        "nes_dispatch_note": (
            "Anim_WriteSpecificItemSprites @Narrow (Z_01.asm:5288) "
            "draws single 8x8 sprite per frame at $36/$38/$3A. Genesis "
            "renderer reads tiles $36/$38/$3A (blob offsets 0,2,4); "
            "$37/$39/$3B-$3D over-extracted, harmless VRAM."
        ),
    },
    {
        "name": "arrow_vert",
        "item": "arrow",
        "direction_class": "vertical",
        "nes_frame_tile": 0x28,
        "sprite_size": [1, 2],
        "tile_ids": [0x28, 0x29],
        "draw_rule": "narrow_8x16",
    },
    {
        "name": "arrow_horz",
        "item": "arrow",
        "direction_class": "horizontal",
        "nes_frame_tile": 0x86,
        "sprite_size": [2, 2],
        "tile_ids": [0x86, 0x87, 0x88, 0x89],
        "draw_rule": "wide_16x16_hflippable",
    },
    {
        "name": "bomb",
        "item": "bomb",
        "direction_class": "static",
        "nes_frame_tile": 0x34,
        "sprite_size": [1, 1],
        "tile_ids": [0x34],
        "draw_rule": "narrow_8x8",
        "nes_dispatch_note": (
            "DrawBomb (Z_07.asm:4869) -> DrawCloud -> "
            "Anim_WriteItemSprites with item slot $01, frame 0 -> "
            "ItemFrameTiles[$03] = $34. Tile $34 in [$20,$62) -> "
            "@Narrow path (Z_01.asm:5288), single 8x8 sprite."
        ),
    },
    {
        "name": "explosion",
        "item": "explosion",
        "direction_class": "static",
        "nes_frame_tile": 0x70,
        "sprite_size": [2, 1],
        "tile_ids": [0x70, 0x72, 0x74],
        "draw_rule": "mirrored_16x8_phase_cycle",
        "nes_dispatch_note": (
            "DrawOtherBombClouds (Z_07.asm:4936) draws cloud cluster "
            "via DrawBombOrCloudNoFlashing -> Anim_WriteItemSprites "
            "with item slot $01, frames 1-3 -> ItemFrameTiles[$04..$06] "
            "= $70/$72/$74. Each tile in [$6C,$7C) -> @Wide -> "
            "Anim_WriteMirroredSpritePair (Z_01.asm:5304): 2 8x8 "
            "sprites side-by-side, right=left hflipped, total 16x8. "
            "Generator emits 2 Genesis tiles per NES tile (raw + "
            "hflipped) so SGDK SPRITE_SIZE(2,1) renders both halves."
        ),
    },
    {
        "name": "sword_diag",
        "item": "sword",
        "direction_class": "diagonal",
        "nes_frame_tile": 0x48,
        "sprite_size": [2, 2],
        "tile_ids": [0x48, 0x49, 0x4A, 0x4B],
        "draw_rule": "wide_16x16_hflippable",
    },
]


def hex_id(value: int) -> str:
    return f"0x{value:02X}"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def required_tile_ids() -> List[int]:
    seen: List[int] = []
    for item_def in ITEM_DEFS:
        for tile_id in item_def["tile_ids"]:
            if tile_id not in seen:
                seen.append(tile_id)
    return seen


def classify_tile(tile_id: int) -> str:
    if tile_id < 0x70:
        return "common_sprite_live_chr"
    if tile_id < 0x8E:
        return "runtime_gap_live_chr"
    return "level_sprite_live_chr"


def parse_capture_args(values: Iterable[str]) -> List[Tuple[str, Path]]:
    captures: List[Tuple[str, Path]] = []
    for value in values:
        if "=" not in value:
            raise SystemExit(f"capture must be ROM_ID=PATH, got: {value}")
        rom_id, raw_path = value.split("=", 1)
        rom_id = rom_id.strip().lower()
        if not rom_id:
            raise SystemExit(f"empty ROM id in capture: {value}")
        captures.append((rom_id, Path(raw_path).expanduser()))
    if not captures:
        if DEFAULT_ORIG_CHR.exists():
            captures.append(("orig", DEFAULT_ORIG_CHR))
        else:
            raise SystemExit(
                "no CHR captures supplied and default live dump is missing: "
                f"{DEFAULT_ORIG_CHR}"
            )
    return captures


def read_capture(rom_id: str, path: Path, tile_ids: Iterable[int]) -> Dict[str, object]:
    path = path.resolve()
    data = path.read_bytes()
    if len(data) < 0x1000:
        raise SystemExit(f"{rom_id}: CHR dump must contain at least PPU $0000-$0FFF: {path}")

    tiles: Dict[str, object] = {}
    for tile_id in tile_ids:
        off = tile_id * 16
        tile = data[off:off + 16]
        if len(tile) != 16:
            raise SystemExit(f"{rom_id}: tile {hex_id(tile_id)} outside CHR dump {path}")
        tiles[hex_id(tile_id)] = {
            "ppu_addr": f"0x{off:04X}",
            "source": classify_tile(tile_id),
            "sha256": sha256(tile),
            "flat_pattern": all(b == tile[0] for b in tile),
            "bytes": tile.hex().upper(),
        }

    return {
        "rom_id": rom_id,
        "chr_dump": str(path),
        "chr_dump_sha256": sha256(data),
        "tiles": tiles,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--chr-dump",
        action="append",
        default=[],
        metavar="ROM_ID=PATH",
        help="live NES CHR $0000-$0FFF dump; may be repeated for orig/redux",
    )
    parser.add_argument("--out", default=str(DEFAULT_OUT), help="manifest JSON path")
    args = parser.parse_args()

    tile_ids = required_tile_ids()
    captures = parse_capture_args(args.chr_dump)

    variants = [read_capture(rom_id, path, tile_ids) for rom_id, path in captures]
    manifest = {
        "schema_version": 1,
        "source_policy": "live_nes_chr_only",
        "notes": [
            "Do not source weapon/item tiles from guessed common_chr offsets.",
            "NES tile IDs >= 0x70 are valid only when backed by live CHR bytes.",
        ],
        "item_defs": [
            {
                **item_def,
                "tile_ids": [hex_id(t) for t in item_def["tile_ids"]],
                "nes_frame_tile": hex_id(item_def["nes_frame_tile"]),
            }
            for item_def in ITEM_DEFS
        ],
        "variants": variants,
    }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(manifest, indent=2, ensure_ascii=True) + "\n", encoding="ascii")
    print(f"wrote {out} ({len(variants)} variant(s), {len(tile_ids)} unique tiles)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

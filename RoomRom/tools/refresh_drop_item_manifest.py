"""Update the checked-in item atlas with NES drop tiles proved by nes_drop_probe.lua."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
manifest_path = root / "RoomRom/data/item_chr_manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="ascii"))
common = (root / "RoomRom/out/prg_blocks/orig/CommonSpritePatterns.bin").read_bytes()
misc = (root / "RoomRom/out/prg_blocks/orig/CommonMiscPatterns.bin").read_bytes()

for item_def in manifest["item_defs"]:
    if item_def["name"] in ("fairy_spark_f0", "fairy_spark_f1"):
        item_def["atlas_alias_note"] = (
            "Live NES dungeon drop: OAM $50/$52 reads the CommonSpritePatterns "
            "bank; atlas-local F0-F3 aliases those ROM-derived bytes. "
            "The earlier DemoSpritePatterns alias was contradicted by live CHR."
        )

## $F3 in 8x16 OAM mode selects PT1 $F2/$F3, whose bytes are the first
## 32 bytes of CommonMiscPatterns, not DemoSpritePatterns[$53].
drop_defs = [
    {
        "name": "drop_heart", "item": "heart", "direction_class": "static",
        "nes_frame_tile": "0xF3", "sprite_size": [1, 2],
        "tile_ids": ["0xE0", "0xE1"], "draw_rule": "narrow_8x16",
        "atlas_alias_note": "NES OAM $F3 selects PT1 $F2/$F3 in 8x16 mode; atlas-local E0/E1 aliases those live tiles.",
        "sprite_size_override_reason": "Z_01.asm Anim_WriteSpecificItemSprites @Narrow emits one NES 8x16 OAM entry; Genesis SIZE(1,2) stores both PT1 halves."
    },
    {
        "name": "drop_clock", "item": "clock", "direction_class": "static",
        "nes_frame_tile": "0x66", "sprite_size": [1, 2],
        "tile_ids": ["0x66", "0x67"], "draw_rule": "narrow_8x16",
        "atlas_alias_note": "NES OAM $66 appears twice at x and x+7; the renderer emits two 8x16 sprites and uses the second OAM H-flip bit.",
        "sprite_size_override_reason": "Z_01.asm Anim_WriteSpecificItemSprites @Wide_Slim emits two 8x16 OAM entries, each Genesis SIZE(1,2); the second uses hardware H-flip."
    }
]
manifest["item_defs"] = [d for d in manifest["item_defs"]
                         if d["name"] not in ("drop_heart", "drop_clock")]
manifest["item_defs"].extend(drop_defs)

def entry(raw, addr, source, alias=None):
    value = {
        "ppu_addr": f"0x{addr:04X}", "source": source,
        "sha256": hashlib.sha256(raw).hexdigest(),
        "flat_pattern": len(set(raw)) <= 1,
        "bytes": raw.hex().upper(),
    }
    if alias is not None:
        value["atlas_alias_for_nes_tile"] = alias
    return value

for variant in manifest["variants"]:
    tiles = variant["tiles"]
    for offset, key in enumerate(("0xF0", "0xF1", "0xF2", "0xF3")):
        nes_id = 0x50 + offset
        tiles[key] = entry(common[nes_id * 16:(nes_id + 1) * 16],
                           nes_id * 16, "CommonSpritePatterns_rom", f"0x{nes_id:02X}")
    for offset, key in enumerate(("0xE0", "0xE1")):
        tiles[key] = entry(misc[offset * 16:(offset + 1) * 16],
                           0x1F20 + offset * 16, "CommonMiscPatterns_rom",
                           f"0x{0xF2 + offset:02X}")
    left = [common[0x66 * 16:0x67 * 16], common[0x67 * 16:0x68 * 16]]
    for offset, key in enumerate(("0x66", "0x67")):
        tiles[key] = entry(left[offset], (0x66 + offset) * 16,
                           "CommonSpritePatterns_rom")

manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=True) + "\n",
                         encoding="ascii")

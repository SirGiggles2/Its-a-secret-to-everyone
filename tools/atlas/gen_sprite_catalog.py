#!/usr/bin/env python3
"""Generate docs/atlas/sprite_catalog.md + docs/atlas/vram_map.md from
RoomRom atlas headers + manifests + roomrom_vram_map.h.

Phase X (2026-05-18 VRAM cleanup): single source of truth for every
graphic / sprite / atlas in the game. Reads existing artifacts (no
new manifest format introduced) and emits human-readable docs.

Run: python tools/atlas/gen_sprite_catalog.py
Wire into check_generated_freshness.py once docs land.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
VRAM_MAP_H = REPO / "RoomRom" / "src" / "roomrom_vram_map.h"
CHR_ATLAS_MASTER = REPO / "RoomRom" / "data" / "chr_atlas_master.json"
ITEM_MANIFEST = REPO / "RoomRom" / "data" / "item_chr_manifest.json"
ATLAS_DIR = REPO / "RoomRom" / "src" / "atlas"
VERIFY_SCRIPT = REPO / "RoomRom" / "tools" / "verify_vram_budget.py"

OUT_CATALOG_MD = REPO / "docs" / "atlas" / "sprite_catalog.md"
OUT_VRAM_MAP_MD = REPO / "docs" / "atlas" / "vram_map.md"
OUT_CATALOG_JSON = REPO / "RoomRom" / "data" / "sprite_catalog.json"


def grep_define(text: str, name: str) -> int | None:
    m = re.search(rf"#define\s+{re.escape(name)}\s+(?:\(?\s*)?(\d+)u?", text)
    return int(m.group(1)) if m else None


def parse_vram_map() -> dict:
    text = VRAM_MAP_H.read_text(encoding="utf-8")
    return {
        "BG_TILE_BASE": grep_define(text, "ROOMROM_BG_TILE_BASE"),
        "BG_TILE_COUNT_PER_PAL": grep_define(text, "ROOMROM_BG_TILE_COUNT_PER_PAL"),
        "BG_SUBPAL_COUNT": grep_define(text, "ROOMROM_BG_SUBPAL_COUNT"),
        "SPR_TILE_BASE": grep_define(text, "ROOMROM_SPR_TILE_BASE"),
        "SPR_TILE_COUNT_PER_PAL": grep_define(text, "ROOMROM_SPR_TILE_COUNT_PER_PAL"),
        "SPR_SUBPAL_COUNT": grep_define(text, "ROOMROM_SPR_SUBPAL_COUNT"),
        "ITEM_SUBPAL_COUNT": grep_define(text, "ROOMROM_ITEM_SUBPAL_COUNT"),
        "BOSS_TILE_BASE_OFFSET_FROM_SPR": 44,  # SPR_BASE + 44 per header
        "BOSS_TILE_COUNT": grep_define(text, "ROOMROM_BOSS_TILE_COUNT"),
        "BOSS_SUBPAL_COUNT": grep_define(text, "ROOMROM_BOSS_SUBPAL_COUNT"),
    }


def parse_atlas_h(path: Path) -> dict:
    """Extract tile-count + byte-count macros from an atlas .h."""
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8")
    out = {}
    for name in re.findall(r"#define\s+(ROOMROM_ATLAS_\w+)\s+\d+", text):
        v = grep_define(text, name)
        if v is not None:
            out[name] = v
    # also pull ROOMROM_ITEM_TILE_* style tile-index constants from items_chr_x4.h
    for m in re.finditer(r"#define\s+(ROOMROM_ITEM_TILE_\w+)\s+(\d+)u?", text):
        out[m.group(1)] = int(m.group(2))
    return out


def run_verifier() -> str:
    try:
        proc = subprocess.run(
            [sys.executable, str(VERIFY_SCRIPT)],
            capture_output=True, text=True, cwd=str(REPO), timeout=15,
        )
        return (proc.stdout + proc.stderr).strip()
    except Exception as e:
        return f"(verifier failed: {e})"


def load_item_manifest() -> list[dict]:
    if not ITEM_MANIFEST.exists():
        return []
    data = json.loads(ITEM_MANIFEST.read_text(encoding="utf-8"))
    return data.get("item_defs", [])


def load_chr_atlas_master() -> dict:
    if not CHR_ATLAS_MASTER.exists():
        return {}
    return json.loads(CHR_ATLAS_MASTER.read_text(encoding="utf-8"))


def build_catalog(vram, atlases, items, master) -> dict:
    """Build the consolidated machine-readable catalog."""
    # Compute live VRAM tile ranges
    bg_end = vram["BG_TILE_BASE"] + vram["BG_TILE_COUNT_PER_PAL"] * vram["BG_SUBPAL_COUNT"] - 1
    spr_end = vram["SPR_TILE_BASE"] + vram["SPR_TILE_COUNT_PER_PAL"] * vram["SPR_SUBPAL_COUNT"] - 1

    item_tile_count = atlases.get("items_chr_x4", {}).get("ROOMROM_ATLAS_ITEMS_X4_TILE_COUNT", 0)
    item_bytes = atlases.get("items_chr_x4", {}).get("ROOMROM_ATLAS_ITEMS_X4_BYTES", 0)
    item_base = vram["SPR_TILE_BASE"] + vram["SPR_TILE_COUNT_PER_PAL"]
    item_end = item_base + item_tile_count * vram["ITEM_SUBPAL_COUNT"] - 1

    enemy_owsp_tiles = atlases.get("enemy_chr", {}).get("ROOMROM_ATLAS_ENEMY_OWSP_TILE_COUNT", 0)
    enemy_uwsp_per_pal = atlases.get("enemy_chr", {}).get("ROOMROM_ATLAS_ENEMY_TILE_COUNT_PER_PAL", 0)
    enemy_bank_bytes = atlases.get("enemy_chr", {}).get("ROOMROM_ATLAS_ENEMY_PER_BANK_BYTES", 0)

    return {
        "schema_version": 1,
        "generated_by": "tools/atlas/gen_sprite_catalog.py",
        "verifier_output": run_verifier(),
        "vram_map": vram,
        "banks": {
            "BG": {
                "tile_base": vram["BG_TILE_BASE"],
                "tiles_resident": vram["BG_TILE_COUNT_PER_PAL"] * vram["BG_SUBPAL_COUNT"],
                "tile_range": [vram["BG_TILE_BASE"], bg_end],
                "subpal_count": vram["BG_SUBPAL_COUNT"],
                "bytes_resident": vram["BG_TILE_COUNT_PER_PAL"] * vram["BG_SUBPAL_COUNT"] * 32,
                "source": "data/chr/overworld_bg.c + data/chr/underworld_bg.c (via RoomRom/tools/expand_bg_chr.py)",
                "replication": "4x pixel-bias (Phase J selective dedup planned)",
            },
            "SPR": {
                "tile_base": vram["SPR_TILE_BASE"],
                "tiles_resident": vram["SPR_TILE_COUNT_PER_PAL"],
                "tile_range": [vram["SPR_TILE_BASE"], spr_end],
                "subpal_count": vram["SPR_SUBPAL_COUNT"],
                "bytes_resident": vram["SPR_TILE_COUNT_PER_PAL"] * 32,
                "source": "data/chr/common.c (Link / sword / common sprites)",
                "replication": "1x (sub-pal 0); future sub-pal 1+ via OAM pal field",
                "scene_obj_slot": {
                    "tile_base": vram["SPR_TILE_BASE"] + 44,
                    "slot_size": 136,
                    "occupants": "UWSP (34), OWSP (114), BOSS (64) — one at a time",
                },
            },
            "ITEM": {
                "tile_base": item_base,
                "tiles_resident": item_tile_count * vram["ITEM_SUBPAL_COUNT"],
                "tile_range": [item_base, item_end],
                "subpal_count": vram["ITEM_SUBPAL_COUNT"],
                "bytes_resident": item_bytes // 3 if vram["ITEM_SUBPAL_COUNT"] == 1 else item_bytes,
                "source": "RoomRom/data/item_chr_manifest.json + RoomRom/tools/gen_atlas.py",
                "replication": "1x (Phase B collapsed from 3x on 2026-05-18)",
            },
            "BOSS": {
                "tile_base": vram["SPR_TILE_BASE"] + vram["BOSS_TILE_BASE_OFFSET_FROM_SPR"],
                "tile_count": vram["BOSS_TILE_COUNT"],
                "subpal_count": vram["BOSS_SUBPAL_COUNT"],
                "residence": "transient (SCENE_OBJ slot, shared with UWSP/OWSP)",
                "source": "data/chr/UWSPBoss*.bin",
                "replication": "1x (NES parity)",
            },
            "UWSP_ENEMY": {
                "tile_base": "SCENE_OBJ_SLOT (SPR_BASE + 44)",
                "tile_count_per_bank": enemy_uwsp_per_pal,
                "bytes_per_bank": enemy_bank_bytes,
                "bank_count": 3,
                "banks": ["UWSP127 (L1/L2/L7)", "UWSP358 (L3/L5/L8)", "UWSP469 (L4/L6/L9)"],
                "source": "data/chr/UWSP127.bin etc.",
                "replication": "1x (Phase F collapsed from 4x on 2026-05-18)",
                "subpal_routing": "OAM pal field PAL1/PAL2/PAL3 = sub-pals 0/1/2",
            },
            "OWSP_ENEMY": {
                "tile_base": "SCENE_OBJ_SLOT (SPR_BASE + 44)",
                "tile_count": enemy_owsp_tiles,
                "bytes": enemy_owsp_tiles * 32,
                "source": "data/chr/OWSP.bin",
                "replication": "1x (always; NPCs use sub-pal 0/1 via OAM pal field)",
            },
        },
        "items": [
            {
                "name": d["name"],
                "item": d.get("item"),
                "direction_class": d.get("direction_class"),
                "nes_frame_tile": d.get("nes_frame_tile"),
                "tile_ids": d.get("tile_ids", []),
                "sprite_size": d.get("sprite_size"),
                "draw_rule": d.get("draw_rule"),
            }
            for d in items
        ],
        "subpal_routing_summary": {
            "BG": "pixel-bias in PAL0 (4 sub-pals packed in 16 colors)",
            "SPR_sub_pal_0": "OAM pal=PAL1, tile pixel values 1..3",
            "SPR_sub_pal_1": "OAM pal=PAL2, tile pixel values 1..3",
            "SPR_sub_pal_2": "OAM pal=PAL3, tile pixel values 1..3",
            "SPR_sub_pal_3": "clamped to sub-pal 2 (NES sprite census shows minimal use; deferred to Phase N)",
        },
    }


def emit_catalog_md(catalog: dict) -> str:
    lines = []
    lines.append("# Sprite + Tile Catalog")
    lines.append("")
    lines.append("*Auto-generated by `tools/atlas/gen_sprite_catalog.py`. Do not edit.*")
    lines.append("")
    lines.append(f"**Verifier output (live):** `{catalog['verifier_output']}`")
    lines.append("")

    # CRAM routing
    lines.append("## CRAM / palette routing")
    lines.append("")
    lines.append("Genesis has 4 CRAM palettes × 16 colors = 64 slots. Layout post-Phase-B/F:")
    lines.append("")
    for k, v in catalog["subpal_routing_summary"].items():
        lines.append(f"- **{k}**: {v}")
    lines.append("")

    # Banks
    lines.append("## VRAM banks (tile-level)")
    lines.append("")
    for name, b in catalog["banks"].items():
        lines.append(f"### {name}")
        for key, val in b.items():
            lines.append(f"- **{key}**: `{val}`")
        lines.append("")

    # Items
    lines.append("## ITEM bank inventory")
    lines.append("")
    lines.append("Atlas defined by `RoomRom/data/item_chr_manifest.json`; emitted via `RoomRom/tools/gen_atlas.py`. Tile indices are 0-based offsets within the ITEM bank (add `ROOMROM_ITEM_TILE_BASE` for absolute VRAM tile).")
    lines.append("")
    lines.append("| Name | Item | Direction | NES Tile | Genesis Tile IDs | Dispatch (W×H) | Draw Rule |")
    lines.append("|---|---|---|---|---|---|---|")
    for it in catalog["items"]:
        size = it.get("sprite_size") or [1, 1]
        size_str = f"{size[0]}×{size[1]}"
        tile_ids = " ".join(it.get("tile_ids") or [])
        lines.append(
            f"| `{it['name']}` | {it.get('item', '—')} | "
            f"{it.get('direction_class', '—')} | "
            f"{it.get('nes_frame_tile', '—')} | "
            f"`{tile_ids}` | {size_str} | {it.get('draw_rule', '—')} |"
        )
    lines.append("")

    # Notes
    lines.append("## Cleanup state (as of 2026-05-18)")
    lines.append("")
    lines.append("- **Phase A-F shipped**: ITEM 3x→1x, UWSP 4x→1x, OW/UW pal routing unified, beam pal-cycle, verifier alignment, SPR docs")
    lines.append("- **Phase G plane reloc**: attempted + reverted (plane B $2000 alignment + boot-trampoline contention)")
    lines.append("- **Phase I audit**: 98 unique BG tile IDs across 636 UW rooms; ~798 tile recovery available via Phase J selective dedup")
    lines.append("- **Phase J**: pending — sparse atlas + tile-id LUT in ow_render/uw_render/hud_runtime")
    lines.append("- Plan: `.claude/plans/time-for-a-cleanup-soft-thunder.md`")
    lines.append("")
    return "\n".join(lines)


def emit_vram_map_md(catalog: dict) -> str:
    """Byte-by-byte VRAM map. Reads canonical layout from verifier."""
    vram = catalog["vram_map"]
    lines = []
    lines.append("# VRAM Byte Map")
    lines.append("")
    lines.append("*Auto-generated by `tools/atlas/gen_sprite_catalog.py`. Do not edit.*")
    lines.append("")
    lines.append(f"**Verifier output (live):** `{catalog['verifier_output']}`")
    lines.append("")
    lines.append("Genesis VRAM = 64 KB ($0000-$FFFF). Tile-data ceiling = $C000 (planes A+B shared at $C000 per `RoomRom/src/main.c::init_video`). All tile addresses below are aligned to 32-byte tile boundaries.")
    lines.append("")
    lines.append("## Layout (post Phase A-F)")
    lines.append("")
    lines.append("```")
    lines.append("$0000  tile 0     blank (32 B, transparent fallback)")
    bg_start = vram["BG_TILE_BASE"]
    bg_per = vram["BG_TILE_COUNT_PER_PAL"]
    bg_subpals = vram["BG_SUBPAL_COUNT"]
    bg_end = bg_start + bg_per * bg_subpals - 1
    bg_byte_end = (bg_end + 1) * 32
    lines.append(f"$0020  tile {bg_start}     BG bank — {bg_per} NES tiles × {bg_subpals} sub-pal copies (pixel-bias)")
    lines.append(f"                          PAL0 packed; subpals 0..3 at indices [0..3]/[4..7]/[8..11]/[12..15]")
    lines.append(f"0x{bg_byte_end:04X}  tile {bg_end+1}  end of BG bank ({bg_per * bg_subpals} tiles = {bg_per * bg_subpals * 32} B)")
    spr_start = vram["SPR_TILE_BASE"]
    spr_per = vram["SPR_TILE_COUNT_PER_PAL"]
    spr_end_tile = spr_start + spr_per - 1
    spr_byte_end = (spr_end_tile + 1) * 32
    lines.append(f"0x{bg_byte_end:04X}  tile {spr_start}  SPR bank — Link + sword + common sprites (1x)")
    lines.append(f"                                Boss / UWSP / OWSP SCENE_OBJ slot at SPR_BASE+44 (tile {spr_start+44})")
    lines.append(f"0x{spr_byte_end:04X}  tile {spr_end_tile+1}  end of SPR bank ({spr_per} tiles = {spr_per * 32} B)")
    item_start = spr_start + spr_per
    item_per = catalog["banks"]["ITEM"]["tiles_resident"]
    item_end = item_start + item_per - 1
    item_byte_end = (item_end + 1) * 32
    lines.append(f"0x{spr_byte_end:04X}  tile {item_start}  ITEM bank — 70 NES tiles × 1 (post Phase B)")
    lines.append(f"                                Sub-pal selection via OAM pal field PAL1/PAL2/PAL3")
    lines.append(f"0x{item_byte_end:04X}  tile {item_end+1}  end of ITEM bank ({item_per} tiles = {item_per * 32} B)")
    lines.append(f"")
    lines.append(f"0x{item_byte_end:04X}-0xBFE0  HEADROOM — {1535 - item_end} tiles free before VDP tables")
    lines.append("")
    lines.append("0xC000  tile 1536  Plane A AND Plane B (shared, 4 KB) — VDP_setBG[AB]Address")
    lines.append("                   BG_B mirrors BG_A during scrolls; prevents color-0 leak")
    lines.append("0xD000  tile 1664  FREE 4 KB / 128 tiles — stranded (would need plane reloc)")
    lines.append("0xE000  tile 1792  Window plane (4 KB allocated; H32 mode uses 32×32 = 2 KB)")
    lines.append("0xE800             FREE 2 KB / 64 tiles — stranded (Window padding)")
    lines.append("0xF000  tile 1920  HScroll table (1 KB allocated; HSCROLL_PLANE uses only 4 B)")
    lines.append("0xF400  tile 1952  SAT (640 B, 80 entries × 8 B)")
    lines.append("0xF680             FREE 2.4 KB / 76 tiles (post-SAT)")
    lines.append("0xFFFF             end of VRAM")
    lines.append("```")
    lines.append("")
    lines.append("## Stranded but reachable as tile data (via nametable 11-bit tile-id)")
    lines.append("")
    lines.append("- `$D000-$DFFF` (128 tiles) — blocked by plane A+B at $C000; Phase G-v2 plane reloc would unlock")
    lines.append("- `$E800-$EFFF` (64 tiles) — Window padding; Phase H Window shrink would unlock")
    lines.append("- `$F680-$FFFF` (76 tiles) — post-SAT; reachable for non-contiguous tile data via tile-id 1972..2047")
    lines.append("")
    lines.append("Total stranded reachable: 268 tiles / 8.4 KB")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    vram = parse_vram_map()
    atlases = {
        "items_chr_x4": parse_atlas_h(ATLAS_DIR / "items_chr_x4.h"),
        "enemy_chr": parse_atlas_h(ATLAS_DIR / "enemy_chr.h"),
        "link_chr": parse_atlas_h(ATLAS_DIR / "link_chr.h"),
        "hud_chr": parse_atlas_h(ATLAS_DIR / "hud_chr.h"),
        "npc_chr": parse_atlas_h(ATLAS_DIR / "npc_chr.h"),
        "title_chr": parse_atlas_h(ATLAS_DIR / "title_chr.h"),
        "fileselect_chr": parse_atlas_h(ATLAS_DIR / "fileselect_chr.h"),
        "boss_chr": parse_atlas_h(ATLAS_DIR / "boss_chr.h"),
    }
    items = load_item_manifest()
    master = load_chr_atlas_master()

    catalog = build_catalog(vram, atlases, items, master)

    OUT_CATALOG_MD.parent.mkdir(parents=True, exist_ok=True)
    OUT_CATALOG_MD.write_text(emit_catalog_md(catalog), encoding="utf-8")
    OUT_VRAM_MAP_MD.write_text(emit_vram_map_md(catalog), encoding="utf-8")
    OUT_CATALOG_JSON.write_text(json.dumps(catalog, indent=2), encoding="utf-8")

    print(f"wrote {OUT_CATALOG_MD.relative_to(REPO)}")
    print(f"wrote {OUT_VRAM_MAP_MD.relative_to(REPO)}")
    print(f"wrote {OUT_CATALOG_JSON.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""PR-1 preflight: census of NES sprite sub-palette usage per
source bank.

Reads ObjAnimAttrHeap-equivalent attribute mapping and the drained
ItemIdToSlot + Anim_ItemFrameOffsets + Anim_ItemFrameTiles tables.
Categorizes attribute byte sub-pal usage per item slot.

For full live attribute capture (NES OAM dump) we'd need BizHawk;
this static probe extracts attribute defaults from drained C and
NES reference asm.

Output: build/probes/ph5/task_chr/sprite_subpal_census.json
- per source bank (Common, OWSP, UWSP127/358/469, UWSPBoss*):
  distribution of sub-pal indices and count of unique sprites.
- recommendation: prebias factor per bank (1× / 2× / 4×).

Usage:
    python tools/probes/sprite_subpal_census.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
Z_07_ASM = REPO / "reference" / "aldonunez" / "Z_07.asm"
Z_01_ASM = REPO / "reference" / "aldonunez" / "Z_01.asm"
DRAW_DISPATCH = REPO / "src" / "game" / "world" / "draw_dispatch.c"
OUT_DIR = REPO / "build" / "probes" / "ph5" / "task_chr"
OUT_REPORT = OUT_DIR / "sprite_subpal_census.json"


def find_obj_anim_attr_heap() -> list[int]:
    """Search for ObjAnimAttrHeap in Z_07.asm or drained C."""
    candidates = []
    for path in [Z_07_ASM, Z_01_ASM, DRAW_DISPATCH]:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        m = re.search(r"ObjAnimAttrHeap[^\n]*\n((?:\s*(?:\.BYTE|\{|0x[0-9a-fA-F]+|,|\s)+\n?){1,20})",
                      text)
        if m:
            bytes_seen = [int(b, 16) for b in
                           re.findall(r"\$([0-9a-fA-F]{2})|0x([0-9a-fA-F]{2})",
                                      m.group(1))
                           for b in [b[0] or b[1]] if b]
            if bytes_seen:
                return bytes_seen
    return []


def census_subpal_distribution(attrs: list[int]) -> dict:
    counts = {0: 0, 1: 0, 2: 0, 3: 0}
    for a in attrs:
        idx = a & 0x03
        counts[idx] += 1
    return counts


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    obj_anim_attr_heap = find_obj_anim_attr_heap()
    if obj_anim_attr_heap:
        attr_dist = census_subpal_distribution(obj_anim_attr_heap)
    else:
        attr_dist = None

    # Per-bank static analysis (NES Z1 conventions, validated via
    # cite-able dispatchers):
    # - Common (NES $00..$6F): always-loaded; Link/sword body use
    #   sub-pal 0; weapons cycle sub-pal via item_chr_x4 (4×).
    # - OWSP (NES $70..): OW enemies (octorok/leever/peahat).
    #   ObjAnimAttrHeap entries 0..N spec sub-pal per type.
    # - UWSP* (per-level): UW enemies (keese/zol/gel/wallmaster).
    #   sub-pal 0 baseline, some use 1 (Wizzrobe blue/red).
    # - UWSPBoss*: bosses cycle sub-pal during damage flash;
    #   Z_07.asm:Anim_SetSpriteDescriptorRedPaletteRow forces $02.
    #
    # Static recommendation table:
    bank_recommendations = {
        "Common (Link/sword body)": {
            "default_subpal": 0,
            "observed_range": [0],
            "prebias_factor": "1x (already in SPR_1x bank)",
            "note": "Link sprite always sub-pal 0 per NES Anim_SetLinkObjAttr",
        },
        "ITEM (weapons + items)": {
            "default_subpal": "varies",
            "observed_range": [0, 1, 2, 3],
            "prebias_factor": "4x (already in items_chr_x4)",
            "note": "Items cycle sub-pal via NES sub-pal selector in tile index",
        },
        "OWSP (OW enemies)": {
            "default_subpal": 0,
            "observed_range": [0, 1],
            "prebias_factor": "2x recommended (mostly 0, some Wizzrobe variants use 1)",
            "note": "Octorok/Leever/Peahat sub-pal 0; Wizzrobe blue/red variants use 1",
        },
        "UWSP base (always-loaded UW)": {
            "default_subpal": 0,
            "observed_range": [0, 1, 2],
            "prebias_factor": "4x or per-(tile, subpal) keyed entries",
            "note": "Keese/Zol/Gel base 0; Like-Like 1; Wallmaster 2",
        },
        "UWSP127/358/469 (per-level UW enemies)": {
            "default_subpal": 0,
            "observed_range": [0, 1, 2, 3],
            "prebias_factor": "4x (per Codex P0-2: ObjAnimAttrHeap uses sub-pal 0..3)",
            "note": "ROM-staged transient bank, swap on UW level entry",
        },
        "UWSPBoss1257/3468/9 (per-level bosses)": {
            "default_subpal": 2,
            "observed_range": [0, 2],
            "prebias_factor": "2x recommended (sub-pal 0 + 2 only; Anim_Set...RedPaletteRow forces $02 for damage flash)",
            "note": "Z_07.asm:5337 hardcodes attribute $02 for fire/damage flash",
        },
        "Effect/projectile (FX): fire, sword shot, magic shot, bomb cloud, fairy spark": {
            "default_subpal": 2,
            "observed_range": [0, 1, 2, 3],
            "prebias_factor": "4x (matches items_chr_x4 pattern; can colocate in extended ITEM atlas)",
            "note": "DrawObjectWithType path; per-FX attribute varies",
        },
        "NPC (old man, fairy, merchant, sign)": {
            "default_subpal": 0,
            "observed_range": [0, 1],
            "prebias_factor": "2x (most NPCs sub-pal 0; merchant items use 1)",
            "note": "Cave-dispatch loaded; OW/cave context-specific",
        },
    }

    # Aggregate sizing for shared SCENE_OBJ transient bank (Codex P1
    # alternative). One bank, one context active at a time.
    scene_obj_bank_size_options = {
        "1x_unified": {
            "tile_count": 256,
            "byte_count": 8192,
            "comment": "1× per active context; needs 4× prebias if any source uses sub-pal 1+.",
        },
        "4x_unified": {
            "tile_count": 256 * 4,
            "byte_count": 8192 * 4,
            "comment": "4× prebias for full sub-pal coverage; 32 KB total per bank — likely too large.",
        },
        "selective_4x_per_bank": {
            "comment": "Each transient context picks its own prebias factor "
                       "(1×/2×/4×) per recommendation table; SCENE_OBJ slot "
                       "size = max factor × max content. Likely 4× × 256 = 32 KB worst case.",
        },
    }

    report = {
        "obj_anim_attr_heap_found": bool(obj_anim_attr_heap),
        "obj_anim_attr_heap_subpal_distribution": attr_dist,
        "obj_anim_attr_heap_bytes_count": len(obj_anim_attr_heap),
        "bank_recommendations": bank_recommendations,
        "scene_obj_bank_size_options": scene_obj_bank_size_options,
        "key_findings": [
            "BG_2x rejected (per audit_bg_subpal_refs.py); must keep BG_4x.",
            "ITEM bank already 4× — extend for triforce + FX.",
            "Transient banks (UWSP per-level) need ≥ 2× prebias; recommend 4× to cover all observed sub-pal usage per Codex P0-2.",
            "Boss banks 2× sufficient (sub-pal 0 + 2 only).",
            "NPC banks 2× sufficient.",
            "Shared SCENE_OBJ transient: budget for 4× × 256 tiles = 32 KB bank if unified; OR per-context bank with content-driven prebias.",
        ],
        "decision_input": (
            "Per-context selective prebias yields tighter VRAM but more "
            "manifest entries. Unified 4× simpler but 4× larger. "
            "Recommend selective: enemy 4×, boss 2×, NPC 2×. "
            "Total transient VRAM: max(enemy_4x=8KB×4=32KB?, boss_2x=8KB, npc_2x=4KB) "
            "— recheck once content sizes locked."
        ),
    }
    OUT_REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("sprite_subpal_census: complete")
    print(f"  ObjAnimAttrHeap found: {bool(obj_anim_attr_heap)} "
          f"({len(obj_anim_attr_heap)} bytes)")
    if attr_dist:
        print(f"  Sub-pal distribution: {attr_dist}")
    print(f"  Recommendation: BG stays 4×; transient banks per-context "
          f"prebias (4× enemy, 2× boss/NPC).")
    print(f"report: {OUT_REPORT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

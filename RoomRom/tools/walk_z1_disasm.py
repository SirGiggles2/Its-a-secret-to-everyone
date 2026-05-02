#!/usr/bin/env python3
"""RoomRom atlas Phase 1a: walk Z_01.asm to extract items-only registry.

Parses reference/aldonunez/Z_01.asm to extract:
  - Anim_ItemFrameOffsets  (37-byte table, item-slot -> frame-start offset)
  - Anim_ItemFrameTiles    (48-byte table, NES tile IDs per frame)

Applies NES dispatch classification from Z_01.asm:5279-5306:
  tile == 0xF3          -> Narrow (1 sprite, 8x8)
  tile in [0x00, 0x20)  -> @Wide  -> Slim  (2 sprites, 1px overlap)
  tile in [0x20, 0x62)  -> Narrow (1 sprite, 8x8)
  tile in [0x62, 0x6C)  -> @Wide  -> Slim
  tile in [0x6C, 0x7C)  -> @Wide  -> Mirrored
  tile in [0x7C, 0xF3) or (0xF3, 0xFF] -> @Wide -> Flippable

Outputs RoomRom/out/atlas_items_registry.json.
Also diffs against gen_item_chr_manifest.py ITEM_DEFS (informational).

Spec: docs/superpowers/specs/2026-05-01-roomrom-z1-full-atlas-design.md
      Section 5.1 (walk_z1_disasm.py) + Section 10 Phase 1a.

Usage: python RoomRom/tools/walk_z1_disasm.py
Exit:  0 always (discrepancies reported but not fatal).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parents[2]
DISASM_Z01 = ROOT / "reference" / "aldonunez" / "Z_01.asm"
OUT_DIR = ROOT / "RoomRom" / "out"
OUT_JSON = OUT_DIR / "atlas_items_registry.json"

# ---------------------------------------------------------------------------
# Dispatch classifier — mirrors Z_01.asm:5279-5306 exactly
# ---------------------------------------------------------------------------

def classify_dispatch(tile: int) -> str:
    """Return the dispatch class for the given NES tile ID.

    Replicates the branch logic at Z_01.asm:5279-5306:
      CMP #$F3 / BEQ @Narrow
      CMP #$20 / BCC @Wide
      CMP #$62 / BCS @Wide
      @Narrow: ...
      @Wide:
        CMP #$6C / BCC @_Slim
        CMP #$7C / BCC Anim_WriteMirroredSpritePair
        JMP Anim_WriteHorizontallyFlippableSpritePair
      @_Slim: (overlap=7px, also Slim for [0x00, 0x20))
    """
    if tile == 0xF3:
        return "Narrow"
    # BCC @Wide means: if tile < 0x20, go Wide
    if tile < 0x20:
        return "Wide_Slim"
    # BCS @Wide means: if tile >= 0x62, go Wide
    if tile < 0x62:
        return "Narrow"
    # @Wide: CMP #$6C / BCC @_Slim
    if tile < 0x6C:
        return "Wide_Slim"
    # CMP #$7C / BCC Mirrored
    if tile < 0x7C:
        return "Wide_Mirrored"
    # tile >= 0x7C (and not 0xF3) -> Flippable
    return "Wide_Flippable"


# ---------------------------------------------------------------------------
# Table parser — reads .BYTE rows following a label in Z_01.asm
# ---------------------------------------------------------------------------

def _parse_byte_table(lines: List[str], label: str) -> Tuple[List[int], int]:
    """Find `label:` in lines, collect all .BYTE rows until a non-.BYTE line.

    Returns (byte_values, first_line_index_of_data).
    Raises ValueError if label not found.
    """
    # Find label line
    label_re = re.compile(rf"^{re.escape(label)}:")
    start_idx: Optional[int] = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if label_re.match(stripped):
            start_idx = i
            break
    if start_idx is None:
        raise ValueError(f"Label not found in disasm: {label}")

    byte_re = re.compile(r"^\s*\.BYTE\s+(.*?)(?:\s*;.*)?$")
    values: List[int] = []
    first_data_line: Optional[int] = None
    for i in range(start_idx + 1, len(lines)):
        line = lines[i]
        # Skip blank lines and comment-only lines
        stripped = line.strip()
        if not stripped or stripped.startswith(";"):
            continue
        m = byte_re.match(line)
        if m is None:
            # Non-.BYTE content after the label: table ends
            break
        if first_data_line is None:
            first_data_line = i
        raw = m.group(1)
        for tok in raw.split(","):
            tok = tok.strip()
            if not tok:
                continue
            if tok.startswith("$"):
                values.append(int(tok[1:], 16))
            else:
                values.append(int(tok, 0))

    if first_data_line is None:
        raise ValueError(f"No .BYTE rows found after label {label}")
    return values, first_data_line


# ---------------------------------------------------------------------------
# Stable item-slot mapping
# Derived from gen_item_chr_manifest.py ITEM_DEFS and Z_01.asm dispatch
# commentary; hand-mapped from NES source.
#
# Format: (slot_index, name, frame_count, category_hint)
# frame_count: how many frames the slot uses (from Anim_ItemFrameOffsets
#              consecutive difference, hand-verified for named items).
# ---------------------------------------------------------------------------

# Each entry: (slot_idx, stable_name, frame_count)
# frame_count derived by: offsets[slot+1] - offsets[slot] for most slots.
# For the last slot (slot 36) we use the observed tile table size boundary.
# Named items are the 8 from gen_item_chr_manifest.py plus others.
# Slot layout per disasm cross-reference (Z_07 item slot assignments):
#   $00 = sword (2 frames: vert tile at offset 0, horz tile at offset 1)
#         offset 0 -> tile $20 (vert), offset 1 -> tile $82 (horz)
#         frame 2 -> tile $3C (unused/beam?  used by sword_beam slot)
#   $01 = bomb (4 frames: 1 bomb + 3 explosion)
#         offset 3 -> $34 (bomb), 4 -> $70, 5 -> $72, 6 -> $74 (explosions)
#   $02 = arrow (3 frames: vert, horz, unused?)
#   $03 = bow (1 frame)
#   $04 = candle (1 frame)
#   $05 = recorder (1 frame)
#   $06 = food (1 frame)
#   $07 = potion/letter (1 frame)
#   ...
# For P1 items scope we fully annotate the 8 from ITEM_DEFS; others get
# auto-named "item_slot_NN".
KNOWN_SLOTS: Dict[int, Tuple[str, int]] = {
    # slot: (stable_name, frame_count_override_or_None)
    # frame_count None = derive from offsets table diff
    0:  ("sword",       3),   # offset 0: frames 0(vert),1(horz),2(beam/shield)
    1:  ("bomb",        4),   # offset 3: frames 0(bomb),1-3(explosion)
    2:  ("arrow",       3),   # offset 7: vert, horz, plus
    3:  ("bow",         1),
    4:  ("candle",      1),
    5:  ("recorder",    1),
    6:  ("food",        1),
    7:  ("letter",      1),
    8:  ("potion",      2),   # offset 15: 2 frames
    9:  ("wand",        1),
    10: ("raft",        1),
    11: ("book",        1),
    12: ("ring",        1),
    13: ("ladder",      1),
    14: ("magickey",    1),
    15: ("bracelet",    1),
    16: ("shield",      1),
    17: ("boomerang",   1),   # slot 17 same offset as 15 (boomerang shares)
    18: ("boomerang2",  1),
    19: ("shield2",     1),
    20: ("heartcontainer", 2),
    21: ("triforce",    1),
    22: ("map",         1),
    23: ("compass",     1),
    24: ("bigkey",      1),
    25: ("sword2",      1),
    26: ("sword3",      1),
    27: ("sword4",      1),
    28: ("map2",        1),   # same as map offset
    29: ("boomerang3",  4),   # boomerang animation (3 spinning frames + extra)
    30: ("sword_beam",  4),   # beam/wide flippable
    31: ("fire",        1),   # $F3 Narrow
    32: ("unknown32",   1),
    33: ("unknown33",   1),
    34: ("boomerang_anim0", 1),
    35: ("boomerang_anim1", 2),
    36: ("boomerang_anim2", 3),
}


def derive_frame_counts(offsets: List[int], tile_table_len: int) -> List[int]:
    """Derive per-slot frame counts from Anim_ItemFrameOffsets."""
    counts: List[int] = []
    for i in range(len(offsets)):
        if i + 1 < len(offsets):
            diff = offsets[i + 1] - offsets[i]
            counts.append(max(1, diff))
        else:
            # Last slot: use remaining entries
            counts.append(max(1, tile_table_len - offsets[i]))
    return counts


# ---------------------------------------------------------------------------
# Main registry builder
# ---------------------------------------------------------------------------

def build_registry(
    z01_lines: List[str],
    offsets: List[int],
    frame_tile_values: List[int],
    first_data_line_offsets: int,
    first_data_line_tiles: int,
) -> List[dict]:
    """Build the items registry from parsed disasm tables."""
    frame_counts = derive_frame_counts(offsets, len(frame_tile_values))

    entries: List[dict] = []
    for slot_idx in range(len(offsets)):
        frame_offset = offsets[slot_idx]
        name, _ = KNOWN_SLOTS.get(slot_idx, (f"item_slot_{slot_idx:02d}", None))

        # Override frame_count from KNOWN_SLOTS if set
        known_fc = KNOWN_SLOTS.get(slot_idx, (None, None))[1]
        if known_fc is not None:
            fc = known_fc
        else:
            fc = frame_counts[slot_idx]

        # Collect tile IDs for this slot
        tile_ids: List[str] = []
        for f in range(fc):
            idx = frame_offset + f
            if idx < len(frame_tile_values):
                tile_ids.append(f"0x{frame_tile_values[idx]:02X}")

        # Dispatch on first frame's tile
        first_tile = frame_tile_values[frame_offset] if frame_offset < len(frame_tile_values) else 0
        dispatch_class = classify_dispatch(first_tile)

        # Compute 1-based line number of the first tile entry for this slot
        # first_data_line_tiles is 0-indexed in lines list; lines are 1-indexed
        tile_line = first_data_line_tiles + 1  # label's first .BYTE row
        tile_line_1based = tile_line + (frame_offset // 8)  # 8 bytes per .BYTE row

        entry = {
            "name": name,
            "category": "items",
            "nes_item_slot": f"0x{slot_idx:02X}",
            "nes_frame_offset": f"0x{frame_offset:02X}",
            "nes_tile_ids": tile_ids,
            "dispatch_class": dispatch_class,
            "disasm_citation": {
                "file": "Z_01.asm",
                "line": tile_line_1based,
                "label": f"Anim_ItemFrameTiles+0x{frame_offset:02X}",
            },
        }
        entries.append(entry)
    return entries


# ---------------------------------------------------------------------------
# Diff against gen_item_chr_manifest.py ITEM_DEFS
# ---------------------------------------------------------------------------

def diff_against_manifest(registry: List[dict]) -> None:
    """Print discrepancies between registry and ITEM_DEFS. Not fatal."""
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "gen_item_chr_manifest",
            ROOT / "RoomRom" / "tools" / "gen_item_chr_manifest.py",
        )
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        item_defs = mod.ITEM_DEFS
    except Exception as e:
        print(f"diff_against_manifest: could not import ITEM_DEFS: {e}", file=sys.stderr)
        return

    # Build a lookup from nes_frame_tile -> registry entry
    tile_to_reg: Dict[int, dict] = {}
    for entry in registry:
        if entry["nes_tile_ids"]:
            first_hex = entry["nes_tile_ids"][0]
            tile_val = int(first_hex, 16)
            tile_to_reg[tile_val] = entry

    print("\n--- diff vs gen_item_chr_manifest.py ITEM_DEFS ---")
    discrepancies = 0
    for idef in item_defs:
        frame_tile = idef["nes_frame_tile"]
        reg_entry = tile_to_reg.get(frame_tile)
        if reg_entry is None:
            print(
                f"  MISSING: ITEM_DEFS '{idef['name']}' (frame_tile=0x{frame_tile:02X}) "
                f"not found in registry by first-tile match"
            )
            discrepancies += 1
            continue

        # Check dispatch_class
        manifest_draw_rule = idef.get("draw_rule", "")
        reg_dispatch = reg_entry["dispatch_class"]

        # Map draw_rule to expected dispatch class
        expected_dispatch_map = {
            "narrow_8x16": "Narrow",
            "narrow_8x8": "Narrow",
            "narrow_8x8_phase_cycle": "Narrow",
            "wide_16x16_hflippable": "Wide_Flippable",
            "mirrored_16x8_phase_cycle": "Wide_Mirrored",
        }
        expected = expected_dispatch_map.get(manifest_draw_rule)
        if expected and expected != reg_dispatch:
            print(
                f"  DISPATCH MISMATCH: '{idef['name']}' tile=0x{frame_tile:02X} "
                f"manifest draw_rule={manifest_draw_rule!r} expects {expected!r} "
                f"but registry has {reg_dispatch!r}"
            )
            discrepancies += 1
        else:
            print(
                f"  OK: '{idef['name']}' tile=0x{frame_tile:02X} "
                f"dispatch={reg_dispatch} matches manifest"
            )

    if discrepancies == 0:
        print("  All ITEM_DEFS match registry dispatch classes.")
    else:
        print(f"  {discrepancies} discrepancy(ies) noted above (informational, not fatal).")
    print("--- end diff ---\n")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> int:
    if not DISASM_Z01.exists():
        print(f"ERROR: disasm not found: {DISASM_Z01}", file=sys.stderr)
        return 1

    lines = DISASM_Z01.read_text(encoding="utf-8", errors="replace").splitlines()
    print(f"Loaded Z_01.asm ({len(lines)} lines)")

    # Parse Anim_ItemFrameOffsets
    try:
        offsets, first_line_offsets = _parse_byte_table(lines, "Anim_ItemFrameOffsets")
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    print(f"Anim_ItemFrameOffsets: {len(offsets)} entries, first={offsets[0]:#04x}")
    if len(offsets) != 37:
        print(
            f"WARNING: expected 37 entries, got {len(offsets)} "
            f"(spec says 37 item slots; parser may have stopped early)",
            file=sys.stderr,
        )

    # Parse Anim_ItemFrameTiles
    try:
        tiles, first_line_tiles = _parse_byte_table(lines, "Anim_ItemFrameTiles")
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    print(f"Anim_ItemFrameTiles: {len(tiles)} entries")
    if len(tiles) < 48:
        print(
            f"WARNING: expected >= 48 entries, got {len(tiles)} "
            f"(parser may have stopped early)",
            file=sys.stderr,
        )

    # Build registry
    registry = build_registry(lines, offsets, tiles, first_line_offsets, first_line_tiles)
    print(f"Registry: {len(registry)} items built")

    # Write JSON
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    output = {
        "schema_version": 1,
        "generator": "RoomRom/tools/walk_z1_disasm.py",
        "source": "reference/aldonunez/Z_01.asm",
        "notes": [
            "Anim_ItemFrameOffsets: 37-byte table at Z_01.asm:5193",
            "Anim_ItemFrameTiles: 48-byte table at Z_01.asm:5201",
            "Dispatch classification: Z_01.asm:5279-5306",
            "frame_count: derived from consecutive offset differences + KNOWN_SLOTS overrides",
        ],
        "anim_item_frame_offsets": {
            "entry_count": len(offsets),
            "values_hex": [f"0x{v:02X}" for v in offsets],
            "disasm_citation": {
                "file": "Z_01.asm",
                "line": first_line_offsets + 1,
                "label": "Anim_ItemFrameOffsets",
            },
        },
        "anim_item_frame_tiles": {
            "entry_count": len(tiles),
            "values_hex": [f"0x{v:02X}" for v in tiles],
            "disasm_citation": {
                "file": "Z_01.asm",
                "line": first_line_tiles + 1,
                "label": "Anim_ItemFrameTiles",
            },
        },
        "items": registry,
    }

    OUT_JSON.write_text(
        json.dumps(output, indent=2, ensure_ascii=True) + "\n",
        encoding="ascii",
    )
    print(f"Wrote {OUT_JSON}")

    # Diff against existing manifest
    diff_against_manifest(registry)

    return 0


if __name__ == "__main__":
    sys.exit(main())

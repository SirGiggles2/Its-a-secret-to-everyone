#!/usr/bin/env python3
"""RoomRom atlas Phase 1a + Phase 2: walk Z1 disasm for all sprite categories.

Phase 1a (items): Parses reference/aldonunez/Z_01.asm Anim_ItemFrameOffsets +
  Anim_ItemFrameTiles tables; outputs atlas_items_registry.json (37 entries).

Phase 2a (enemies): Walks UpdateObject_JumpTable in Z_07.asm; maps object
  types to names; derives tile IDs from ObjAnimations + ObjAnimFrameHeap in
  Z_01.asm; outputs atlas_enemies_registry.json.

Phase 2b (bosses): Same tables, boss object types only (Aquamentus, Dodongo,
  Manhandla, Gleeok, Digdogger, Gohma, Patra, Ganon, Moldorm, Lamnola);
  outputs atlas_bosses_registry.json.

Phase 2c (HUD): Walks FormatHeartsInTextBuf + FormatStatusBarText in Z_01.asm;
  hard-coded HUD tile IDs for hearts, digits, rupee/key/bomb icons;
  outputs atlas_hud_registry.json.

Phase 2d (title + fileselect): Parses InitialTitleSprites in Z_02.asm for
  title sprites; DemoStoryFinalSpriteTiles for story final items; ModeE_CharMap
  for file-select characters; outputs atlas_title_registry.json +
  atlas_fileselect_registry.json.

Phase 2e (NPC): Object types for UnderworldPerson, Grumble, Zelda, PondFairy
  from UpdateObject_JumpTable; outputs atlas_npc_registry.json.

Phase 2f (BG patterns): Walks all .INCBIN directives in Z_*.asm for .dat
  pattern blocks; classifies each as bg/sprite/misc/sound/data per context;
  outputs atlas_bg_registry.json.

Phase 2g (merge): Concatenates all category registries into atlas_master.json.

Spec: docs/superpowers/specs/2026-05-01-roomrom-z1-full-atlas-design.md
      Section 5.1 + Section 10 Phase 2.

Usage: python RoomRom/tools/walk_z1_disasm.py [--phase PHASE]
  PHASE: items|enemies|bosses|hud|title|fileselect|npc|bg|all (default: all)
Exit: 0 always (discrepancies reported but not fatal).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parents[2]
DISASM_DIR = ROOT / "reference" / "aldonunez"
DISASM_Z01 = DISASM_DIR / "Z_01.asm"
DISASM_Z02 = DISASM_DIR / "Z_02.asm"
DISASM_Z03 = DISASM_DIR / "Z_03.asm"
DISASM_Z05 = DISASM_DIR / "Z_05.asm"
DISASM_Z06 = DISASM_DIR / "Z_06.asm"
DISASM_Z07 = DISASM_DIR / "Z_07.asm"
OUT_DIR = ROOT / "RoomRom" / "out"
OUT_JSON_ITEMS = OUT_DIR / "atlas_items_registry.json"
OUT_JSON_ENEMIES = OUT_DIR / "atlas_enemies_registry.json"
OUT_JSON_BOSSES = OUT_DIR / "atlas_bosses_registry.json"
OUT_JSON_HUD = OUT_DIR / "atlas_hud_registry.json"
OUT_JSON_TITLE = OUT_DIR / "atlas_title_registry.json"
OUT_JSON_FILESELECT = OUT_DIR / "atlas_fileselect_registry.json"
OUT_JSON_NPC = OUT_DIR / "atlas_npc_registry.json"
OUT_JSON_BG = OUT_DIR / "atlas_bg_registry.json"
OUT_JSON_MASTER = ROOT / "RoomRom" / "data" / "atlas_master.json"


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
# Table parser — reads .BYTE rows following a label in a disasm file
# ---------------------------------------------------------------------------

def _parse_byte_table(lines: List[str], label: str) -> Tuple[List[int], int]:
    """Find `label:` in lines, collect all .BYTE rows until a non-.BYTE line.

    Returns (byte_values, first_line_index_of_data).
    Raises ValueError if label not found.
    """
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
        stripped = line.strip()
        if not stripped or stripped.startswith(";"):
            continue
        m = byte_re.match(line)
        if m is None:
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
                try:
                    values.append(int(tok, 0))
                except ValueError:
                    pass

    if first_data_line is None:
        raise ValueError(f"No .BYTE rows found after label {label}")
    return values, first_data_line


def _find_label_line(lines: List[str], label: str) -> int:
    """Return 0-based line index of `label:` in lines; -1 if not found."""
    label_re = re.compile(rf"^{re.escape(label)}:")
    for i, line in enumerate(lines):
        if label_re.match(line.strip()):
            return i
    return -1


# ---------------------------------------------------------------------------
# PHASE 1a — Items registry
# ---------------------------------------------------------------------------

# Each entry: (slot_idx, stable_name, frame_count)
KNOWN_SLOTS: Dict[int, Tuple[str, int]] = {
    0:  ("sword",       3),
    1:  ("bomb",        4),
    2:  ("arrow",       3),
    3:  ("bow",         1),
    4:  ("candle",      1),
    5:  ("recorder",    1),
    6:  ("food",        1),
    7:  ("letter",      1),
    8:  ("potion",      2),
    9:  ("wand",        1),
    10: ("raft",        1),
    11: ("book",        1),
    12: ("ring",        1),
    13: ("ladder",      1),
    14: ("magickey",    1),
    15: ("bracelet",    1),
    16: ("shield",      1),
    17: ("boomerang",   1),
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
    28: ("map2",        1),
    29: ("boomerang3",  4),
    30: ("sword_beam",  4),
    31: ("fire",        1),
    32: ("unknown32",   1),
    33: ("unknown33",   1),
    34: ("boomerang_anim0", 1),
    35: ("boomerang_anim1", 2),
    36: ("boomerang_anim2", 3),
}


def derive_frame_counts(offsets: List[int], tile_table_len: int) -> List[int]:
    counts: List[int] = []
    for i in range(len(offsets)):
        if i + 1 < len(offsets):
            diff = offsets[i + 1] - offsets[i]
            counts.append(max(1, diff))
        else:
            counts.append(max(1, tile_table_len - offsets[i]))
    return counts


def build_items_registry(
    z01_lines: List[str],
    offsets: List[int],
    frame_tile_values: List[int],
    first_data_line_tiles: int,
) -> List[dict]:
    frame_counts = derive_frame_counts(offsets, len(frame_tile_values))
    entries: List[dict] = []
    for slot_idx in range(len(offsets)):
        frame_offset = offsets[slot_idx]
        name, _ = KNOWN_SLOTS.get(slot_idx, (f"item_slot_{slot_idx:02d}", None))
        known_fc = KNOWN_SLOTS.get(slot_idx, (None, None))[1]
        fc = known_fc if known_fc is not None else frame_counts[slot_idx]
        tile_ids: List[str] = []
        for f in range(fc):
            idx = frame_offset + f
            if idx < len(frame_tile_values):
                tile_ids.append(f"0x{frame_tile_values[idx]:02X}")
        first_tile = frame_tile_values[frame_offset] if frame_offset < len(frame_tile_values) else 0
        dispatch_class = classify_dispatch(first_tile)
        tile_line_1based = (first_data_line_tiles + 1) + (frame_offset // 8)
        entry = {
            "name": name,
            "category": "items",
            "nes_item_slot": f"0x{slot_idx:02X}",
            "nes_frame_offset": f"0x{frame_offset:02X}",
            "nes_tile_ids": tile_ids,
            "dispatch_class": dispatch_class,
            "frame_count": fc,
            "disasm_citation": {
                "file": "Z_01.asm",
                "line": tile_line_1based,
                "label": f"Anim_ItemFrameTiles+0x{frame_offset:02X}",
            },
        }
        entries.append(entry)
    return entries


def run_items(z01_lines: List[str]) -> List[dict]:
    offsets, first_line_offsets = _parse_byte_table(z01_lines, "Anim_ItemFrameOffsets")
    tiles, first_line_tiles = _parse_byte_table(z01_lines, "Anim_ItemFrameTiles")
    registry = build_items_registry(z01_lines, offsets, tiles, first_line_tiles)
    print(f"  Items: {len(registry)} entries")
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
    OUT_JSON_ITEMS.write_text(
        json.dumps(output, indent=2, ensure_ascii=True) + "\n", encoding="ascii"
    )
    print(f"  Wrote {OUT_JSON_ITEMS}")
    return registry


# ---------------------------------------------------------------------------
# PHASE 2a + 2b — Enemies + Bosses
# ---------------------------------------------------------------------------

# Object type index (1-based from UpdateObject_JumpTable, line 5295 in Z_07.asm)
# Maps (object_type_index, update_routine) -> canonical name
# Index 0 = DoNothing (unused/null). Index 1 = Lynel, etc.
# Source: Z_07.asm:5295-5401 UpdateObject_JumpTable
# Object type index = 0-based position in .ADDR list.
OBJECT_TYPE_MAP: List[Tuple[str, str]] = [
    # (name, update_routine)
    # idx 0x00
    ("null",             "DoNothing"),
    # idx 0x01-0x02 Lynel (red/blue)
    ("lynel_red",        "UpdateLynel"),
    ("lynel_blue",       "UpdateLynel"),
    # idx 0x03-0x04 Moblin (red/blue)
    ("moblin_red",       "UpdateMoblin"),
    ("moblin_blue",      "UpdateMoblin"),
    # idx 0x05-0x06 Goriya (red/blue)
    ("goriya_red",       "UpdateGoriya"),
    ("goriya_blue",      "UpdateGoriya"),
    # idx 0x07-0x0A Octorock (4 variants: slow_red, fast_red, slow_blue, fast_blue)
    ("octorok_slow_red",  "UpdateOctorock"),
    ("octorok_fast_red",  "UpdateOctorock"),
    ("octorok_slow_blue", "UpdateOctorock"),
    ("octorok_fast_blue", "UpdateOctorock"),
    # idx 0x0B-0x0C Darknut (red/blue)
    ("darknut_red",      "UpdateDarknut"),
    ("darknut_blue",     "UpdateDarknut"),
    # idx 0x0D-0x0E Tektite (red/blue)
    ("tektite_red",      "UpdateTektiteOrBoulder"),
    ("tektite_blue",     "UpdateTektiteOrBoulder"),
    # idx 0x0F Blue Leever
    ("leever_blue",      "UpdateBlueLeever"),
    # idx 0x10 Red Leever
    ("leever_red",       "UpdateRedLeever"),
    # idx 0x11 Zora
    ("zora",             "UpdateZora"),
    # idx 0x12 Vire
    ("vire",             "UpdateVire"),
    # idx 0x13 Zol
    ("zol",              "UpdateZol"),
    # idx 0x14-0x15 Gel (two variants)
    ("gel_0",            "UpdateGel"),
    ("gel_1",            "UpdateGel"),
    # idx 0x16 Pols Voice
    ("pols_voice",       "UpdatePolsVoice"),
    # idx 0x17 Like Like
    ("like_like",        "UpdateLikeLike"),
    # idx 0x18 Digdogger (boss, also listed under enemies dispatch)
    ("digdogger",        "UpdateDigdogger"),
    # idx 0x19 (DoNothing placeholder)
    ("placeholder_0x19", "DoNothing"),
    # idx 0x1A Peahat
    ("peahat",           "UpdatePeahat"),
    # idx 0x1B-0x1D Keese (blue/red/black)
    ("keese_blue",       "UpdateKeese"),
    ("keese_red",        "UpdateKeese"),
    ("keese_black",      "UpdateKeese"),
    # idx 0x1E Armos
    ("armos",            "UpdateArmos"),
    # idx 0x1F Boulder Set
    ("boulder_set",      "UpdateBoulderSet"),
    # idx 0x20 Boulder
    ("boulder",          "UpdateTektiteOrBoulder"),
    # idx 0x21 Ghini (graveyard ghost)
    ("ghini",            "UpdateGhini"),
    # idx 0x22 Flying Ghini
    ("flying_ghini",     "UpdateFlyingGhini"),
    # idx 0x23-0x24 Wizzrobe (blue/red)
    ("wizzrobe_blue",    "UpdateBlueWizzrobe"),
    ("wizzrobe_red",     "UpdateRedWizzrobe"),
    # idx 0x25-0x26 Patra Child (two variants)
    ("patra_child_0",    "UpdatePatraChild"),
    ("patra_child_1",    "UpdatePatraChild"),
    # idx 0x27 Wallmaster
    ("wallmaster",       "UpdateWallmaster"),
    # idx 0x28 Rope
    ("rope",             "UpdateRope"),
    # idx 0x29 DoNothing placeholder
    ("placeholder_0x29", "DoNothing"),
    # idx 0x2A Stalfos
    ("stalfos",          "UpdateStalfos"),
    # idx 0x2B-0x2D Bubble (red/blue/black)
    ("bubble_red",       "UpdateBubble"),
    ("bubble_blue",      "UpdateBubble"),
    ("bubble_black",     "UpdateBubble"),
    # idx 0x2E Whirlwind
    ("whirlwind",        "UpdateWhirlwind"),
    # idx 0x2F Pond Fairy (NPC-ish but in enemy table)
    ("pond_fairy",       "UpdatePondFairy"),
    # idx 0x30 Gibdo
    ("gibdo",            "UpdateGibdo"),
    # idx 0x31-0x32 Dodongo (boss)
    ("dodongo_0",        "UpdateDodongo"),
    ("dodongo_1",        "UpdateDodongo"),
    # idx 0x33-0x34 Gohma (boss, red/blue)
    ("gohma_red",        "UpdateGohma"),
    ("gohma_blue",       "UpdateGohma"),
    # idx 0x35 Rupee Stash
    ("rupee_stash",      "UpdateRupeeStash"),
    # idx 0x36 Grumble (NPC)
    ("grumble",          "UpdateGrumble"),
    # idx 0x37 Zelda (NPC)
    ("zelda",            "UpdateZelda"),
    # idx 0x38-0x39 Digdogger parts
    ("digdogger_part_0", "UpdateDigdogger"),
    ("digdogger_part_1", "UpdateDigdogger"),
    # idx 0x3A-0x3B Lamnola (boss, two variants)
    ("lamnola_0",        "UpdateLamnola"),
    ("lamnola_1",        "UpdateLamnola"),
    # idx 0x3C Manhandla (boss)
    ("manhandla",        "UpdateManhandla"),
    # idx 0x3D Aquamentus (boss)
    ("aquamentus",       "UpdateAquamentus"),
    # idx 0x3E Ganon (boss)
    ("ganon",            "UpdateGanon"),
    # idx 0x3F Guard Fire
    ("guard_fire",       "UpdateGuardFire"),
    # idx 0x40 Standing Fire
    ("standing_fire",    "UpdateStandingFire"),
    # idx 0x41 Moldorm (boss)
    ("moldorm",          "UpdateMoldorm"),
    # idx 0x42-0x45 Gleeok (boss, 1-4 heads)
    ("gleeok_1head",     "UpdateGleeok"),
    ("gleeok_2head",     "UpdateGleeok"),
    ("gleeok_3head",     "UpdateGleeok"),
    ("gleeok_4head",     "UpdateGleeok"),
    # idx 0x46 Gleeok Head (detached)
    ("gleeok_head",      "UpdateGleeokHead"),
    # idx 0x47-0x48 Patra (boss, two variants)
    ("patra_0",          "UpdatePatra"),
    ("patra_1",          "UpdatePatra"),
    # idx 0x49-0x4A Trap
    ("trap_0",           "UpdateTrap"),
    ("trap_1",           "UpdateTrap"),
    # idx 0x4B-0x52 Underworld Persons (NPC)
    ("uw_person_0",      "UpdateUnderworldPerson"),
    ("uw_person_1",      "UpdateUnderworldPerson"),
    ("uw_person_2",      "UpdateUnderworldPerson"),
    ("uw_person_3",      "UpdateUnderworldPerson"),
    ("uw_person_4",      "UpdateUnderworldPerson"),
    ("uw_person_5",      "UpdateUnderworldPerson"),
    ("uw_person_money",  "UpdateUnderworldPersonLifeOrMoney"),
    ("uw_person_6",      "UpdateUnderworldPerson"),
    # idx 0x53-0x5A Projectiles (monster shots, fireballs, etc.)
    ("monster_shot_0",   "UpdateMonsterShot"),
    ("monster_shot_1",   "UpdateMonsterShot"),
    ("fireball_0",       "UpdateFireball"),
    ("fireball_1",       "UpdateFireball"),
    ("monster_shot_2",   "UpdateMonsterShot"),
    ("monster_shot_3",   "UpdateMonsterShot"),
    ("monster_shot_4",   "UpdateMonsterShot"),
    ("monster_shot_5",   "UpdateMonsterShot"),
    # idx 0x5B Monster Arrow
    ("monster_arrow",    "UpdateMonsterArrow"),
    # idx 0x5C Arrow/Boomerang (shared)
    ("arrow_or_boomerang", "UpdateArrowOrBoomerang"),
    # idx 0x5D Dead Dummy
    ("dead_dummy",       "UpdateDeadDummy"),
    # idx 0x5E Flute Secret
    ("flute_secret",     "UpdateFluteSecret"),
    # idx 0x5F DoNothing
    ("placeholder_0x5F", "DoNothing"),
    # idx 0x60 Item
    ("room_item",        "UpdateItem"),
    # idx 0x61 Dock
    ("dock",             "UpdateDock"),
    # idx 0x62 Rock/Gravestone
    ("rock_gravestone",  "UpdateRockOrGravestone"),
    # idx 0x63 Rock Wall
    ("rock_wall",        "UpdateRockWall"),
    # idx 0x64 Tree
    ("tree",             "UpdateTree"),
    # idx 0x65-0x66 Rock/Gravestone variants
    ("rock_gravestone_2","UpdateRockOrGravestone"),
    ("rock_gravestone_3","UpdateRockOrGravestone"),
    # idx 0x67 Rock Wall 2
    ("rock_wall_2",      "UpdateRockWall"),
    # idx 0x68 Block
    ("block",            "UpdateBlock"),
    # idx 0x69 DoNothing
    ("placeholder_0x69", "DoNothing"),
]

# Boss type names (those that share boss-specific update routines)
BOSS_UPDATE_ROUTINES = {
    "UpdateAquamentus", "UpdateDodongo", "UpdateManhandla", "UpdateGleeok",
    "UpdateGleeokHead", "UpdateDigdogger", "UpdateGohma", "UpdatePatra",
    "UpdatePatraChild", "UpdateGanon", "UpdateMoldorm", "UpdateLamnola",
}

# NPC type names
NPC_UPDATE_ROUTINES = {
    "UpdateUnderworldPerson", "UpdateUnderworldPersonLifeOrMoney",
    "UpdateGrumble", "UpdateZelda", "UpdatePondFairy",
}


def _load_obj_anim_data(z01_lines: List[str]) -> Tuple[List[int], List[int]]:
    """Load ObjAnimations and ObjAnimFrameHeap tables from Z_01.asm.

    Returns (anim_indices, frame_heap).
    """
    anim_indices, _ = _parse_byte_table(z01_lines, "ObjAnimations")
    frame_heap, _ = _parse_byte_table(z01_lines, "ObjAnimFrameHeap")
    return anim_indices, frame_heap


def _get_enemy_tile_ids(
    obj_type_idx: int,
    anim_indices: List[int],
    frame_heap: List[int],
    num_frames: int = 4,
) -> Tuple[List[str], int]:
    """Derive NES tile IDs for an object type.

    DrawObjectWithType uses anim_index = obj_type_idx + 1.
    ObjAnimations[anim_index] = base offset into ObjAnimFrameHeap.
    ObjAnimFrameHeap[base + frame] = left NES tile ID.
    Right NES tile = left + 2.

    Returns (tile_id_list, anim_index).
    """
    # Anim index = object type + 1 (per Z_01.asm:5008-5012 comment)
    anim_idx = obj_type_idx + 1
    if anim_idx >= len(anim_indices):
        return [], anim_idx
    base_offset = anim_indices[anim_idx]
    tile_ids: List[str] = []
    for frame in range(num_frames):
        heap_offset = base_offset + frame
        if heap_offset >= len(frame_heap):
            break
        left_tile = frame_heap[heap_offset]
        # left_tile 0x00 and 0xFF are sentinels meaning "no data"
        if left_tile == 0xFF:
            break
        tile_ids.append(f"0x{left_tile:02X}")
        tile_ids.append(f"0x{(left_tile + 2) & 0xFF:02X}")  # right sprite tile
    return tile_ids, anim_idx


def _find_anim_table_lines(z01_lines: List[str]) -> Tuple[int, int]:
    """Return 1-based line numbers of ObjAnimations and ObjAnimFrameHeap."""
    anim_line = _find_label_line(z01_lines, "ObjAnimations")
    heap_line = _find_label_line(z01_lines, "ObjAnimFrameHeap")
    return anim_line + 1, heap_line + 1  # convert to 1-based


def build_enemies_and_bosses(z01_lines: List[str]) -> Tuple[List[dict], List[dict]]:
    """Build enemies and bosses registries from UpdateObject_JumpTable data.

    Returns (enemies_list, bosses_list).
    """
    anim_indices, frame_heap = _load_obj_anim_data(z01_lines)
    anim_table_line, heap_table_line = _find_anim_table_lines(z01_lines)

    # Z_07.asm UpdateObject_JumpTable starts at line 5295 (0-based: 5294)
    z07_jt_line = 5295  # 1-based

    enemies: List[dict] = []
    bosses: List[dict] = []

    for obj_idx, (name, update_routine) in enumerate(OBJECT_TYPE_MAP):
        # Skip null, placeholders, non-combat types
        if update_routine == "DoNothing":
            continue
        # Skip items, dock, rocks, blocks (tile objects)
        skip_routines = {
            "UpdateItem", "UpdateDock", "UpdateRockOrGravestone",
            "UpdateRockWall", "UpdateTree", "UpdateBlock",
            "UpdateRupeeStash", "UpdateFluteSecret", "UpdateDeadDummy",
            "UpdateWhirlwind", "UpdateMonsterShot", "UpdateMonsterArrow",
            "UpdateFireball", "UpdateArrowOrBoomerang",
            "UpdateGuardFire", "UpdateStandingFire",
        }
        if update_routine in skip_routines:
            continue

        tile_ids, anim_idx = _get_enemy_tile_ids(obj_idx, anim_indices, frame_heap)
        first_tile_raw = (
            frame_heap[anim_indices[anim_idx]]
            if anim_idx < len(anim_indices) and anim_indices[anim_idx] < len(frame_heap)
            else 0
        )
        dispatch_class = classify_dispatch(first_tile_raw)

        # Determine category
        if update_routine in BOSS_UPDATE_ROUTINES:
            cat = "bosses"
        elif update_routine in NPC_UPDATE_ROUTINES:
            cat = "npc"
        else:
            cat = "enemies"

        entry = {
            "name": name,
            "category": cat,
            "obj_type_index": f"0x{obj_idx:02X}",
            "update_routine": update_routine,
            "nes_tile_ids": tile_ids,
            "dispatch_class": dispatch_class,
            "frame_count": len(tile_ids) // 2 if tile_ids else 0,
            "chr_bank": "level_conditional",  # enemies load per-dungeon bank
            "disasm_citation": {
                "file": "Z_07.asm",
                "line": z07_jt_line + obj_idx + 1,  # 1-based offset into JT
                "label": f"UpdateObject_JumpTable[0x{obj_idx:02X}]",
                "anim_source": {
                    "file": "Z_01.asm",
                    "label": "ObjAnimations",
                    "line": anim_table_line,
                    "anim_index": f"0x{anim_idx:02X}",
                    "heap_label": "ObjAnimFrameHeap",
                    "heap_line": heap_table_line,
                },
            },
        }
        if cat == "enemies":
            enemies.append(entry)
        elif cat == "bosses":
            bosses.append(entry)
        # npc goes in separate phase

    return enemies, bosses


def run_enemies(z01_lines: List[str]) -> List[dict]:
    enemies, _ = build_enemies_and_bosses(z01_lines)
    print(f"  Enemies: {len(enemies)} entries")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    output = {
        "schema_version": 1,
        "generator": "RoomRom/tools/walk_z1_disasm.py",
        "source": ["reference/aldonunez/Z_07.asm", "reference/aldonunez/Z_01.asm"],
        "notes": [
            "UpdateObject_JumpTable: Z_07.asm:5295-5401 (107 entries)",
            "ObjAnimations: Z_01.asm:4884 (121-byte index table)",
            "ObjAnimFrameHeap: Z_01.asm:4902 (200-byte tile ID heap)",
            "Tile pair: left=ObjAnimFrameHeap[ObjAnimations[obj_type+1]], right=left+2",
            "chr_bank: level_conditional (dungeon sprite banks per Z_03.asm PatternBlock* INCBINs)",
            "frame_count: up to 4 walk frames derived from heap; 0xFF or table boundary terminates",
        ],
        "enemies": enemies,
    }
    OUT_JSON_ENEMIES.write_text(
        json.dumps(output, indent=2, ensure_ascii=True) + "\n", encoding="ascii"
    )
    print(f"  Wrote {OUT_JSON_ENEMIES}")
    return enemies


def run_bosses(z01_lines: List[str]) -> List[dict]:
    _, bosses = build_enemies_and_bosses(z01_lines)
    print(f"  Bosses: {len(bosses)} entries")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    output = {
        "schema_version": 1,
        "generator": "RoomRom/tools/walk_z1_disasm.py",
        "source": ["reference/aldonunez/Z_07.asm", "reference/aldonunez/Z_01.asm"],
        "notes": [
            "Boss object types derived from UpdateObject_JumpTable Z_07.asm:5295-5401",
            "Boss update routines imported from separate banks (all .IMPORT in Z_07.asm:140-175)",
            "Tile IDs derived from ObjAnimations + ObjAnimFrameHeap (Z_01.asm:4884/4902)",
            "Boss-specific pattern banks: PatternBlockUWSPBoss1257/3468/9 (Z_03.asm:223-230)",
            "chr_bank: boss-specific (PatternBlockUWSPBoss1257 levels 1,2,5,7; Boss3468 3,4,6,8; Boss9 level 9)",
            "TODO: boss draw routines in imported banks (bank 4) have additional multi-sprite logic not captured here",
        ],
        "bosses": bosses,
    }
    OUT_JSON_BOSSES.write_text(
        json.dumps(output, indent=2, ensure_ascii=True) + "\n", encoding="ascii"
    )
    print(f"  Wrote {OUT_JSON_BOSSES}")
    return bosses


# ---------------------------------------------------------------------------
# PHASE 2c — HUD digits + icons
# ---------------------------------------------------------------------------

# NES Z1 HUD is BG content. Tile IDs are CHR RAM BG tiles.
# Source: Z_01.asm FormatHeartsInTextBuf (line 3161) + FormatStatusBarText (line 2850)
#
# Heart tiles (from Z_01.asm:3233-3246):
#   0xF2 = full heart
#   0x65 = half heart
#   0x66 = empty heart
#
# Blank tile: 0x24
#
# Digit tiles: Z1 uses Nintendo's custom font. From StatusBarTransferBufTemplate
# the digits are rendered as text-tile offsets. The actual character map maps
# decimal digit N to BG tile 0x00+N for the HUD font.
# Per Z_01.asm:849 comment and Z_02.asm ModeE_CharMap:
#   '0'-'9' = tiles 0x00-0x09
#   'A'-'Z' letters: 0x0A-0x23
#   '-' = 0x24 (blank in status bar context)
#   'X' (no item placeholder) = 0x24
#
# Rupee icon: The rupee sprite tile is at 0x84 in CommonSpritePatterns
# (from ObjAnimFrameHeap context; rupee item slot 0x28/0x29 in item tables).
# B-item area: item sprite drawn by DrawStatusBarItemB (Z_07.asm:970)
#   which calls AnimateItemObject -> Anim_WriteItemSprites -> uses item slot tiles.
#
# Map/Compass dots: BG tiles in HUD. Per Z_01.asm:4118 area + triforce rows.
# Level number: LevelNumberTransferBuf in Z_06.asm:454 uses tiles $15,$0E,$1F,...
#   These are letter tiles (L-E-V-E-L 1-9).

def build_hud_registry(z01_lines: List[str]) -> List[dict]:
    """Build HUD digit + icon entries from disasm citations."""

    # Line numbers (1-based) from Z_01.asm
    format_hearts_line = _find_label_line(z01_lines, "FormatHeartsInTextBuf") + 1
    format_status_line = _find_label_line(z01_lines, "FormatStatusBarText") + 1

    entries: List[dict] = []

    # Heart tiles
    heart_tiles = [
        ("hud_heart_full",  "0xF2", "full heart — FormatHeartsInTextBuf:@EmitFullHeart LDA #$F2"),
        ("hud_heart_half",  "0x65", "half heart — FormatHeartsInTextBuf:@EmitHalfHeart LDA #$65"),
        ("hud_heart_empty", "0x66", "empty heart — FormatHeartsInTextBuf:@EmitEmptyHeart LDA #$66"),
    ]
    for name, tile_hex, note in heart_tiles:
        tile_val = int(tile_hex, 16)
        entries.append({
            "name": name,
            "category": "hud",
            "nes_tile_ids": [tile_hex],
            "dispatch_class": classify_dispatch(tile_val),
            "frame_count": 1,
            "chr_target": "bg_table_1",
            "disasm_citation": {
                "file": "Z_01.asm",
                "line": format_hearts_line,
                "label": "FormatHeartsInTextBuf",
                "note": note,
            },
        })

    # Digit tiles (0-9): BG font tiles 0x00-0x09
    # Source: ModeE_CharMap Z_02.asm:1351 maps char indices 0x22-0x2B -> tile $00-$09
    for digit in range(10):
        tile_val = digit  # tiles 0x00-0x09
        entries.append({
            "name": f"hud_digit_{digit}",
            "category": "hud",
            "nes_tile_ids": [f"0x{tile_val:02X}"],
            "dispatch_class": "Narrow",  # single BG tile, 8x8
            "frame_count": 1,
            "chr_target": "bg_table_0",
            "disasm_citation": {
                "file": "Z_02.asm",
                "line": 1351,
                "label": "ModeE_CharMap",
                "note": f"digit {digit} -> tile 0x{tile_val:02X} (FormatDecimalCountByte output)",
            },
        })

    # Blank/space tile
    entries.append({
        "name": "hud_blank",
        "category": "hud",
        "nes_tile_ids": ["0x24"],
        "dispatch_class": "Narrow",
        "frame_count": 1,
        "chr_target": "bg_table_0",
        "disasm_citation": {
            "file": "Z_01.asm",
            "line": format_status_line,
            "label": "StatusBarTransferBufTemplate",
            "note": "blank tile 0x24 used as placeholder in status bar template (Z_01.asm:2805)",
        },
    })

    # Rupee count area (BG text tiles, not sprite)
    entries.append({
        "name": "hud_rupee_count",
        "category": "hud",
        "nes_tile_ids": ["0x00", "0x01", "0x02"],  # 3-digit BG display
        "dispatch_class": "Narrow",
        "frame_count": 1,
        "chr_target": "bg_table_0",
        "disasm_citation": {
            "file": "Z_01.asm",
            "line": format_status_line,
            "label": "FormatStatusBarText",
            "note": "FormatDecimalCountByteInTextBuf for InvRupees -> 3 BG digit tiles at DynTileBuf+0x1B",
        },
    })

    # Key count
    entries.append({
        "name": "hud_key_count",
        "category": "hud",
        "nes_tile_ids": ["0x00", "0x01", "0x02"],
        "dispatch_class": "Narrow",
        "frame_count": 1,
        "chr_target": "bg_table_0",
        "disasm_citation": {
            "file": "Z_01.asm",
            "line": format_status_line,
            "label": "FormatStatusBarText",
            "note": "FormatDecimalCountByteInTextBuf for InvKeys -> 3 BG digit tiles at DynTileBuf+0x08",
        },
    })

    # Bomb count
    entries.append({
        "name": "hud_bomb_count",
        "category": "hud",
        "nes_tile_ids": ["0x00", "0x01", "0x02"],
        "dispatch_class": "Narrow",
        "frame_count": 1,
        "chr_target": "bg_table_0",
        "disasm_citation": {
            "file": "Z_01.asm",
            "line": format_status_line,
            "label": "FormatStatusBarText",
            "note": "FormatDecimalCountByteInTextBuf for InvBombs -> 3 BG digit tiles at DynTileBuf+0x27",
        },
    })

    # Level/dungeon name tiles (from LevelNumberTransferBuf Z_06.asm:454)
    # .BYTE $20,$42,$07,$15,$0E,$1F,$0E,$15,$62,$00,$FF
    # PPU addr $2042, 7 bytes: L(0x15) E(0x0E) V(0x1F) E(0x0E) L(0x15) ' '(0x62) digit(0x00)
    level_name_tiles = [0x15, 0x0E, 0x1F, 0x0E, 0x15]  # L-E-V-E-L letters
    entries.append({
        "name": "hud_level_text",
        "category": "hud",
        "nes_tile_ids": [f"0x{t:02X}" for t in level_name_tiles],
        "dispatch_class": "Narrow",
        "frame_count": 1,
        "chr_target": "bg_table_0",
        "disasm_citation": {
            "file": "Z_06.asm",
            "line": 454,
            "label": "LevelNumberTransferBuf",
            "note": "LEVEL text + digit; BG tiles 0x15=L 0x0E=E 0x1F=V",
        },
    })

    # Minimap/compass dots — BG tiles from triforce row transfer bufs
    # TriforceRow0TransferBuf Z_06.asm:464: .BYTE $2A,$EE,$04,$ED,$E9,$EA,$EE
    # Tiles: 0xED=map_dot, 0xE9=triforce_part, 0xEA=map_border, 0xEE=map_blank
    map_tiles = [
        ("hud_map_dot",     0xED, "map room visited dot"),
        ("hud_map_current", 0xE9, "triforce/current room indicator"),
        ("hud_map_border",  0xEA, "map border tile"),
        ("hud_map_blank",   0xEE, "map empty tile"),
    ]
    for name, tile_val, note in map_tiles:
        entries.append({
            "name": name,
            "category": "hud",
            "nes_tile_ids": [f"0x{tile_val:02X}"],
            "dispatch_class": "Narrow",
            "frame_count": 1,
            "chr_target": "bg_table_0",
            "disasm_citation": {
                "file": "Z_06.asm",
                "line": 464,
                "label": "TriforceRow0TransferBuf",
                "note": note,
            },
        })

    return entries


def run_hud(z01_lines: List[str]) -> List[dict]:
    entries = build_hud_registry(z01_lines)
    print(f"  HUD: {len(entries)} entries")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    output = {
        "schema_version": 1,
        "generator": "RoomRom/tools/walk_z1_disasm.py",
        "source": ["reference/aldonunez/Z_01.asm", "reference/aldonunez/Z_06.asm",
                   "reference/aldonunez/Z_02.asm"],
        "notes": [
            "HUD is BG content (NES nametable rows 0-3, PPU addr $2000-$204F)",
            "Heart tiles: Z_01.asm:3233-3246 FormatHeartsInTextBuf",
            "Digit tiles 0x00-0x09: Z_02.asm:1351 ModeE_CharMap character set",
            "Status bar format: Z_01.asm:2850 FormatStatusBarText / StatusBarTransferBufTemplate",
            "Level name: Z_06.asm:454 LevelNumberTransferBuf",
            "Map tiles: Z_06.asm:464 TriforceRow0TransferBuf",
            "B-item icon: drawn as sprite via DrawStatusBarItemB Z_07.asm:970 (see items category)",
            "TODO: StatusBarStaticsTransferBuf (TransferBufAddrs entry 7) for static HUD graphics",
        ],
        "hud": entries,
    }
    OUT_JSON_HUD.write_text(
        json.dumps(output, indent=2, ensure_ascii=True) + "\n", encoding="ascii"
    )
    print(f"  Wrote {OUT_JSON_HUD}")
    return entries


# ---------------------------------------------------------------------------
# PHASE 2d — Title screen + File Select
# ---------------------------------------------------------------------------

def build_title_registry(z02_lines: List[str]) -> List[dict]:
    """Build title screen sprite entries from Z_02.asm InitialTitleSprites.

    InitialTitleSprites is a sequence of NES OAM records:
      [Y, tile, attr, X] x N sprites
    Source: Z_02.asm:342.
    """
    entries: List[dict] = []

    # Parse InitialTitleSprites
    try:
        sprite_bytes, first_line = _parse_byte_table(z02_lines, "InitialTitleSprites")
    except ValueError as e:
        print(f"  WARNING: InitialTitleSprites parse failed: {e}", file=sys.stderr)
        sprite_bytes = []
        first_line = 342

    # Decode OAM records: 4 bytes each = [Y, tile, attr, X]
    seen_tiles: Dict[int, int] = {}  # tile -> first entry index
    for sprite_num in range(len(sprite_bytes) // 4):
        base = sprite_num * 4
        if base + 3 >= len(sprite_bytes):
            break
        y_pos = sprite_bytes[base]
        tile_id = sprite_bytes[base + 1]
        attr = sprite_bytes[base + 2]
        x_pos = sprite_bytes[base + 3]

        if tile_id in seen_tiles:
            continue  # deduplicate
        seen_tiles[tile_id] = sprite_num

        entries.append({
            "name": f"title_sprite_{sprite_num:02d}_tile{tile_id:02X}",
            "category": "title",
            "nes_tile_ids": [f"0x{tile_id:02X}"],
            "dispatch_class": classify_dispatch(tile_id),
            "frame_count": 1,
            "oam_y": f"0x{y_pos:02X}",
            "oam_x": f"0x{x_pos:02X}",
            "oam_attr": f"0x{attr:02X}",
            "chr_bank": "CommonSpritePatterns + DemoSpritePatterns",
            "disasm_citation": {
                "file": "Z_02.asm",
                "line": first_line + 1,
                "label": f"InitialTitleSprites[{sprite_num}]",
                "note": "NES OAM record: [Y, tile, attr, X]",
            },
        })

    # DemoStoryFinalSpriteTiles: Z_02.asm:407
    try:
        story_tiles, story_line = _parse_byte_table(z02_lines, "DemoStoryFinalSpriteTiles")
        story_attrs, _ = _parse_byte_table(z02_lines, "DemoStoryFinalSpriteAttrs")
    except ValueError:
        story_tiles = []
        story_line = 407
        story_attrs = []

    for i, tile_id in enumerate(story_tiles):
        if tile_id in (0x00, 0x78):
            continue  # unused/filler
        entries.append({
            "name": f"title_story_final_{i:02d}_tile{tile_id:02X}",
            "category": "title",
            "nes_tile_ids": [f"0x{tile_id:02X}"],
            "dispatch_class": classify_dispatch(tile_id),
            "frame_count": 1,
            "chr_bank": "CommonSpritePatterns",
            "disasm_citation": {
                "file": "Z_02.asm",
                "line": story_line + 1,
                "label": f"DemoStoryFinalSpriteTiles[{i}]",
                "note": "Final story frame sprites (Link + Zelda + Triforce)",
            },
        })

    return entries


def build_fileselect_registry(z02_lines: List[str]) -> List[dict]:
    """Build file select sprite entries from Z_02.asm ModeE_CharMap.

    ModeE_CharMap maps character board positions to BG tile IDs.
    Source: Z_02.asm:1351.
    ModeEandFCursorSprites: Z_02.asm:1367 contains cursor sprite OAM data.
    """
    entries: List[dict] = []

    # Parse ModeE_CharMap
    try:
        charmap, charmap_line = _parse_byte_table(z02_lines, "ModeE_CharMap")
    except ValueError as e:
        print(f"  WARNING: ModeE_CharMap parse failed: {e}", file=sys.stderr)
        charmap = []
        charmap_line = 1351

    # Character names derived from tile range context
    char_labels = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ-. 0123456789END")
    for i, tile_id in enumerate(charmap):
        label = char_labels[i] if i < len(char_labels) else f"char_{i}"
        if isinstance(label, str) and len(label) == 1 and label.isalpha():
            name = f"fs_char_{label.lower()}"
        elif isinstance(label, str) and label.isdigit():
            name = f"fs_digit_{label}"
        elif label == "-":
            name = "fs_char_dash"
        elif label == ".":
            name = "fs_char_dot"
        elif label == " ":
            name = "fs_char_space"
        elif label == "END":
            name = "fs_char_end"
        else:
            name = f"fs_char_{i:02d}"

        entries.append({
            "name": name,
            "category": "fileselect",
            "nes_tile_ids": [f"0x{tile_id:02X}"],
            "dispatch_class": "Narrow",  # BG tiles
            "frame_count": 1,
            "chr_target": "bg_table_0",
            "disasm_citation": {
                "file": "Z_02.asm",
                "line": charmap_line + 1,
                "label": f"ModeE_CharMap[{i}]",
                "note": f"character board tile for '{label if isinstance(label, str) else '?'}'",
            },
        })

    # Cursor sprite from ModeEandFCursorSprites: Z_02.asm:1367
    # .BYTE $F3, $03, $43, $F8, $25, $23, $70, $F8, $25, $23, $30
    # Sprite records interleaved with other data; tile at offset 1 = 0x03 (hand cursor)
    try:
        cursor_data, cursor_line = _parse_byte_table(z02_lines, "ModeEandFCursorSprites")
    except ValueError:
        cursor_data = []
        cursor_line = 1367

    if len(cursor_data) >= 2:
        cursor_tile = cursor_data[1]
        entries.append({
            "name": "fs_cursor_hand",
            "category": "fileselect",
            "nes_tile_ids": [f"0x{cursor_tile:02X}"],
            "dispatch_class": classify_dispatch(cursor_tile),
            "frame_count": 1,
            "chr_bank": "CommonSpritePatterns",
            "disasm_citation": {
                "file": "Z_02.asm",
                "line": cursor_line + 1,
                "label": "ModeEandFCursorSprites",
                "note": "hand cursor sprite tile[1]; Y=$F3 marks hidden sprite",
            },
        })

    return entries


def run_title(z02_lines: List[str]) -> List[dict]:
    entries = build_title_registry(z02_lines)
    print(f"  Title: {len(entries)} entries")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    output = {
        "schema_version": 1,
        "generator": "RoomRom/tools/walk_z1_disasm.py",
        "source": "reference/aldonunez/Z_02.asm",
        "notes": [
            "InitialTitleSprites: Z_02.asm:342 — NES OAM 4-byte records [Y,tile,attr,X]",
            "DemoStoryFinalSpriteTiles: Z_02.asm:407 — final story frame (Link+Zelda+Triforce)",
            "CHR source: CommonSpritePatterns (Z_02.asm:147) + DemoSpritePatterns (Z_01.asm:1696)",
            "Title ZELDA logo and Triforce are BG content via GameTitleTransferBuf (Z_06.asm:835)",
            "TODO: waterfall animation sprites (Z_02.asm:990 WaterfallWaveTiles)",
        ],
        "title": entries,
    }
    OUT_JSON_TITLE.write_text(
        json.dumps(output, indent=2, ensure_ascii=True) + "\n", encoding="ascii"
    )
    print(f"  Wrote {OUT_JSON_TITLE}")
    return entries


def run_fileselect(z02_lines: List[str]) -> List[dict]:
    entries = build_fileselect_registry(z02_lines)
    print(f"  File Select: {len(entries)} entries")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    output = {
        "schema_version": 1,
        "generator": "RoomRom/tools/walk_z1_disasm.py",
        "source": "reference/aldonunez/Z_02.asm",
        "notes": [
            "ModeE_CharMap: Z_02.asm:1351 — 43-entry char board tile map",
            "ModeEandFCursorSprites: Z_02.asm:1367 — hand cursor sprite",
            "File select slot template: ModeFSaveSlotTemplateTransferBuf (Z_02.asm:1339) — BG",
            "Title patch: ModeFTitleTransferBuf (Z_02.asm:1324) + ModeFTitlePatchRegister (Z_02.asm:1330)",
            "Character tiles are BG (nametable write via DynTileBuf); cursor is sprite (OAM)",
        ],
        "fileselect": entries,
    }
    OUT_JSON_FILESELECT.write_text(
        json.dumps(output, indent=2, ensure_ascii=True) + "\n", encoding="ascii"
    )
    print(f"  Wrote {OUT_JSON_FILESELECT}")
    return entries


# ---------------------------------------------------------------------------
# PHASE 2e — NPCs
# ---------------------------------------------------------------------------

def build_npc_registry(z01_lines: List[str]) -> List[dict]:
    """Build NPC entries from UpdateObject_JumpTable NPC-type object types."""
    anim_indices, frame_heap = _load_obj_anim_data(z01_lines)
    anim_table_line, heap_table_line = _find_anim_table_lines(z01_lines)
    z07_jt_line = 5295

    entries: List[dict] = []
    for obj_idx, (name, update_routine) in enumerate(OBJECT_TYPE_MAP):
        if update_routine not in NPC_UPDATE_ROUTINES:
            continue
        tile_ids, anim_idx = _get_enemy_tile_ids(obj_idx, anim_indices, frame_heap)
        first_tile_raw = (
            frame_heap[anim_indices[anim_idx]]
            if anim_idx < len(anim_indices) and anim_indices[anim_idx] < len(frame_heap)
            else 0
        )
        dispatch_class = classify_dispatch(first_tile_raw)
        entries.append({
            "name": name,
            "category": "npc",
            "obj_type_index": f"0x{obj_idx:02X}",
            "update_routine": update_routine,
            "nes_tile_ids": tile_ids,
            "dispatch_class": dispatch_class,
            "frame_count": len(tile_ids) // 2 if tile_ids else 0,
            "chr_bank": "CommonSpritePatterns",
            "disasm_citation": {
                "file": "Z_07.asm",
                "line": z07_jt_line + obj_idx + 1,
                "label": f"UpdateObject_JumpTable[0x{obj_idx:02X}]",
                "anim_source": {
                    "file": "Z_01.asm",
                    "label": "ObjAnimations",
                    "line": anim_table_line,
                    "anim_index": f"0x{anim_idx:02X}",
                },
            },
        })

    # Additional NPCs from Z_02.asm demo: AnimateStationaryFairy
    fairy_tile = 0xC6  # from ObjAnimFrameHeap for fairy-type; pond fairy obj type 0x2F
    entries.append({
        "name": "fairy_stationary",
        "category": "npc",
        "obj_type_index": "0x2F",
        "update_routine": "AnimateStationaryFairy",
        "nes_tile_ids": [f"0x{fairy_tile:02X}", f"0x{(fairy_tile+2)&0xFF:02X}"],
        "dispatch_class": classify_dispatch(fairy_tile),
        "frame_count": 2,
        "chr_bank": "CommonSpritePatterns",
        "disasm_citation": {
            "file": "Z_02.asm",
            "line": 858,
            "label": "AnimateStationaryFairy",
            "note": "title/demo screen stationary fairy animation",
        },
    })

    return entries


def run_npc(z01_lines: List[str]) -> List[dict]:
    entries = build_npc_registry(z01_lines)
    print(f"  NPC: {len(entries)} entries")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    output = {
        "schema_version": 1,
        "generator": "RoomRom/tools/walk_z1_disasm.py",
        "source": ["reference/aldonunez/Z_07.asm", "reference/aldonunez/Z_01.asm",
                   "reference/aldonunez/Z_02.asm"],
        "notes": [
            "NPC types: UnderworldPerson (0x4B-0x52), Grumble (0x36), Zelda (0x37), PondFairy (0x2F)",
            "UpdateUnderworldPerson_Full + UpdateGrumble_Full in bank 1 (imported to Z_07)",
            "UpdateZelda in bank 4 (imported); UpdatePondFairy in bank 4",
            "NPC dialog: PersonText.dat INCBIN at Z_01.asm:51 (BG text transfer, not sprites)",
            "Cave persons (type >= 0x6A) dispatch to UpdateCavePerson (bank 1) — not in table",
            "TODO: old man / old woman specific sprites from bank 1 UW person code",
        ],
        "npc": entries,
    }
    OUT_JSON_NPC.write_text(
        json.dumps(output, indent=2, ensure_ascii=True) + "\n", encoding="ascii"
    )
    print(f"  Wrote {OUT_JSON_NPC}")
    return entries


# ---------------------------------------------------------------------------
# PHASE 2f — BG pattern blocks
# ---------------------------------------------------------------------------

# Classification of known .dat pattern blocks
# Source: Z_*.asm .INCBIN directives + their disasm context
BG_BLOCK_DEFS: List[dict] = [
    # ---- Z_02.asm ----
    {
        "label": "CommonSpritePatterns",
        "file": "Z_02.asm",
        "line": 147,
        "dat_file": "dat/CommonSpritePatterns.dat",
        "block_type": "sprite",
        "chr_target_vram": "0x0000",
        "byte_count": 0x0700,
        "referenced_by": ["TransferCommonPatterns (Z_02.asm:69)"],
        "scene": "all",
        "note": "Common sprite patterns: Link walk, all items, enemy walk frames. Always loaded at boot.",
    },
    {
        "label": "CommonBackgroundPatterns",
        "file": "Z_02.asm",
        "line": 150,
        "dat_file": "dat/CommonBackgroundPatterns.dat",
        "block_type": "bg",
        "chr_target_vram": "0x1000",
        "byte_count": 0x0700,
        "referenced_by": ["TransferCommonPatterns (Z_02.asm:69)"],
        "scene": "all",
        "note": "Common BG patterns: HUD font, status bar tiles, common map tiles. Always loaded.",
    },
    {
        "label": "CommonMiscPatterns",
        "file": "Z_02.asm",
        "line": 153,
        "dat_file": "dat/CommonMiscPatterns.dat",
        "block_type": "misc",
        "chr_target_vram": "0x1F20",
        "byte_count": 0x00E0,
        "referenced_by": ["TransferCommonPatterns (Z_02.asm:69)"],
        "scene": "all",
        "note": "Miscellaneous common patterns appended at end of BG table. Always loaded.",
    },
    # ---- Z_01.asm ----
    {
        "label": "DemoSpritePatterns",
        "file": "Z_01.asm",
        "line": 1696,
        "dat_file": "dat/DemoSpritePatterns.dat",
        "block_type": "sprite",
        "chr_target_vram": "0x0000",
        "byte_count": None,
        "referenced_by": ["InitDemo_Phase1 (Z_01.asm:189)", "title/demo mode load"],
        "scene": "title_demo",
        "note": "Demo/title mode sprite patterns loaded over CommonSpritePatterns during title.",
    },
    {
        "label": "DemoBackgroundPatterns",
        "file": "Z_01.asm",
        "line": 1699,
        "dat_file": "dat/DemoBackgroundPatterns.dat",
        "block_type": "bg",
        "chr_target_vram": "0x1000",
        "byte_count": None,
        "referenced_by": ["InitDemo_Phase1 (Z_01.asm:189)", "title/demo mode load"],
        "scene": "title_demo",
        "note": "Demo/title mode BG patterns loaded over CommonBackgroundPatterns during title.",
    },
    # ---- Z_03.asm ----
    {
        "label": "PatternBlockUWBG",
        "file": "Z_03.asm",
        "line": 203,
        "dat_file": "dat/PatternBlockUWBG.dat",
        "block_type": "bg",
        "chr_target_vram": "0x1000",
        "byte_count": None,
        "referenced_by": ["CopyBlock (Z_06.asm:171)", "InitMode2 scene load"],
        "scene": "underworld",
        "note": "Underworld background patterns. Loaded for all dungeon levels.",
    },
    {
        "label": "PatternBlockOWBG",
        "file": "Z_03.asm",
        "line": 206,
        "dat_file": "dat/PatternBlockOWBG.dat",
        "block_type": "bg",
        "chr_target_vram": "0x1000",
        "byte_count": None,
        "referenced_by": ["CopyBlock (Z_06.asm:171)", "InitMode2 scene load"],
        "scene": "overworld",
        "note": "Overworld background patterns. Loaded for overworld map scenes.",
    },
    {
        "label": "PatternBlockOWSP",
        "file": "Z_03.asm",
        "line": 209,
        "dat_file": "dat/PatternBlockOWSP.dat",
        "block_type": "sprite",
        "chr_target_vram": "0x0000",
        "byte_count": None,
        "referenced_by": ["CopyBlock (Z_06.asm:171)", "InitMode2 scene load"],
        "scene": "overworld",
        "note": "Overworld sprite patterns (enemy frames for OW enemies). Loaded for overworld.",
    },
    {
        "label": "PatternBlockUWSP358",
        "file": "Z_03.asm",
        "line": 212,
        "dat_file": "dat/PatternBlockUWSP358.dat",
        "block_type": "sprite",
        "chr_target_vram": "0x0000",
        "byte_count": None,
        "referenced_by": ["CopyBlock (Z_06.asm:171)", "InitMode2 scene load"],
        "scene": "underworld_levels_3_5_8",
        "note": "UW sprite patterns for dungeons 3, 5, 8 (non-boss enemies).",
    },
    {
        "label": "PatternBlockUWSP469",
        "file": "Z_03.asm",
        "line": 215,
        "dat_file": "dat/PatternBlockUWSP469.dat",
        "block_type": "sprite",
        "chr_target_vram": "0x0000",
        "byte_count": None,
        "referenced_by": ["CopyBlock (Z_06.asm:171)", "InitMode2 scene load"],
        "scene": "underworld_levels_4_6_9",
        "note": "UW sprite patterns for dungeons 4, 6, 9 (non-boss enemies).",
    },
    {
        "label": "PatternBlockUWSP",
        "file": "Z_03.asm",
        "line": 218,
        "dat_file": "dat/PatternBlockUWSP.dat",
        "block_type": "sprite",
        "chr_target_vram": "0x0000",
        "byte_count": None,
        "referenced_by": ["CopyBlock (Z_06.asm:171)", "InitMode2 scene load"],
        "scene": "underworld_default",
        "note": "Default UW sprite patterns (dungeons without a specific set).",
    },
    {
        "label": "PatternBlockUWSP127",
        "file": "Z_03.asm",
        "line": 221,
        "dat_file": "dat/PatternBlockUWSP127.dat",
        "block_type": "sprite",
        "chr_target_vram": "0x0000",
        "byte_count": None,
        "referenced_by": ["CopyBlock (Z_06.asm:171)", "InitMode2 scene load"],
        "scene": "underworld_levels_1_2_7",
        "note": "UW sprite patterns for dungeons 1, 2, 7 (non-boss enemies).",
    },
    {
        "label": "PatternBlockUWSPBoss1257",
        "file": "Z_03.asm",
        "line": 224,
        "dat_file": "dat/PatternBlockUWSPBoss1257.dat",
        "block_type": "sprite",
        "chr_target_vram": "0x0000",
        "byte_count": None,
        "referenced_by": ["CopyBlock (Z_06.asm:171)", "boss room load"],
        "scene": "boss_levels_1_2_5_7",
        "note": "Boss sprite patterns for dungeons 1 (Aquamentus), 2 (Dodongo), 5 (Digdogger), 7 (Aquamentus).",
    },
    {
        "label": "PatternBlockUWSPBoss3468",
        "file": "Z_03.asm",
        "line": 227,
        "dat_file": "dat/PatternBlockUWSPBoss3468.dat",
        "block_type": "sprite",
        "chr_target_vram": "0x0000",
        "byte_count": None,
        "referenced_by": ["CopyBlock (Z_06.asm:171)", "boss room load"],
        "scene": "boss_levels_3_4_6_8",
        "note": "Boss sprite patterns for dungeons 3 (Manhandla), 4 (Gleeok), 6 (Gohma), 8 (Moldorm).",
    },
    {
        "label": "PatternBlockUWSPBoss9",
        "file": "Z_03.asm",
        "line": 230,
        "dat_file": "dat/PatternBlockUWSPBoss9.dat",
        "block_type": "sprite",
        "chr_target_vram": "0x0000",
        "byte_count": None,
        "referenced_by": ["CopyBlock (Z_06.asm:171)", "boss room load"],
        "scene": "boss_level_9",
        "note": "Boss sprite patterns for dungeon 9 (Ganon, Patra).",
    },
    # ---- Z_06.asm (BG data via transfer bufs, not pattern blocks) ----
    {
        "label": "StoryTileAttrTransferBuf",
        "file": "Z_06.asm",
        "line": 832,
        "dat_file": "dat/StoryTileAttrTransferBuf.dat",
        "block_type": "bg_attr",
        "chr_target_vram": None,  # attribute table, not pattern data
        "byte_count": None,
        "referenced_by": ["TransferBufAddrs[1] (Z_06.asm:490)", "TransferCurTileBuf"],
        "scene": "title_story",
        "note": "Story screen BG attribute (palette) transfer buffer (nametable attributes, not CHR).",
    },
    {
        "label": "GameTitleTransferBuf",
        "file": "Z_06.asm",
        "line": 835,
        "dat_file": "dat/GameTitleTransferBuf.dat",
        "block_type": "bg_nametable",
        "chr_target_vram": None,  # nametable data, not pattern data
        "byte_count": None,
        "referenced_by": ["TransferBufAddrs[8] (Z_06.asm:498)", "TransferCurTileBuf"],
        "scene": "title",
        "note": "ZELDA title logo BG nametable transfer buffer (tile indices, not CHR bytes).",
    },
]


def build_bg_registry() -> List[dict]:
    """Build BG pattern block registry from BG_BLOCK_DEFS."""
    entries: List[dict] = []
    for defn in BG_BLOCK_DEFS:
        entry = {
            "name": f"bg_{defn['label'].lower()}",
            "category": "bg",
            "label": defn["label"],
            "dat_file": defn["dat_file"],
            "block_type": defn["block_type"],
            "chr_target_vram": defn["chr_target_vram"],
            "byte_count": defn["byte_count"],
            "scene": defn["scene"],
            "referenced_by": defn["referenced_by"],
            "disasm_citation": {
                "file": defn["file"],
                "line": defn["line"],
                "label": defn["label"],
                "note": defn["note"],
            },
        }
        entries.append(entry)
    return entries


def run_bg() -> List[dict]:
    entries = build_bg_registry()
    print(f"  BG patterns: {len(entries)} entries")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (ROOT / "RoomRom" / "data").mkdir(parents=True, exist_ok=True)
    output = {
        "schema_version": 1,
        "generator": "RoomRom/tools/walk_z1_disasm.py",
        "source": [
            "reference/aldonunez/Z_01.asm", "reference/aldonunez/Z_02.asm",
            "reference/aldonunez/Z_03.asm", "reference/aldonunez/Z_05.asm",
            "reference/aldonunez/Z_06.asm",
        ],
        "notes": [
            "NES Z1 uses CHR RAM (iNES header byte5=0); no CHR ROM banks exist.",
            "Pattern blocks live in PRG ROM as .INCBIN data; CPU copies to CHR RAM via PPUDATA.",
            "Common patterns (Z_02.asm:69 TransferCommonPatterns): sprite@0x0000, bg@0x1000, misc@0x1F20.",
            "Scene-specific sprite patterns in Z_03.asm: OW, UW per dungeon, boss per dungeon group.",
            "48 .dat files extracted by extract_z1_prg_chr.py; this registry covers pattern blocks only.",
            "Sound/music dat files (Z_00.asm), room layout dat files (Z_05.asm) are excluded (not CHR).",
            "TODO: verify byte_count for non-common blocks via BizHawk CHR-RAM capture (verify_chr_live.py).",
        ],
        "bg": entries,
    }
    OUT_JSON_BG.write_text(
        json.dumps(output, indent=2, ensure_ascii=True) + "\n", encoding="ascii"
    )
    print(f"  Wrote {OUT_JSON_BG}")
    return entries


# ---------------------------------------------------------------------------
# PHASE 2g — Merge into atlas_master.json
# ---------------------------------------------------------------------------

def run_merge(
    items: List[dict],
    enemies: List[dict],
    bosses: List[dict],
    hud: List[dict],
    title: List[dict],
    fileselect: List[dict],
    npc: List[dict],
    bg: List[dict],
) -> None:
    """Merge all category registries into atlas_master.json."""
    import hashlib

    # Compute sha256 of rom_inputs.lock if it exists
    lock_file = ROOT / "RoomRom" / "data" / "rom_inputs.lock"
    if lock_file.exists():
        sha = hashlib.sha256(lock_file.read_bytes()).hexdigest()
    else:
        sha = "rom_inputs.lock_not_found"

    # Count unique tile IDs across all sprite categories (not bg)
    all_tiles: set = set()
    for cat_list in [items, enemies, bosses, hud, title, fileselect, npc]:
        for entry in cat_list:
            for tid in entry.get("nes_tile_ids", []):
                all_tiles.add(tid)

    total = (len(items) + len(enemies) + len(bosses) + len(hud) +
             len(title) + len(fileselect) + len(npc) + len(bg))

    master = {
        "schema_version": 1,
        "generator": "RoomRom/tools/walk_z1_disasm.py",
        "rom_inputs_lock_sha": sha,
        "categories": {
            "items":      items,
            "enemies":    enemies,
            "bosses":     bosses,
            "hud":        hud,
            "title":      title,
            "fileselect": fileselect,
            "npc":        npc,
            "bg":         bg,
        },
        "stats": {
            "total_entries": total,
            "total_unique_sprite_tiles": len(all_tiles),
            "per_category": {
                "items":      len(items),
                "enemies":    len(enemies),
                "bosses":     len(bosses),
                "hud":        len(hud),
                "title":      len(title),
                "fileselect": len(fileselect),
                "npc":        len(npc),
                "bg":         len(bg),
            },
        },
    }

    out_path = OUT_JSON_MASTER
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(master, indent=2, ensure_ascii=True) + "\n", encoding="ascii"
    )
    print(f"  Wrote {out_path} ({total} total entries, {len(all_tiles)} unique sprite tiles)")


# ---------------------------------------------------------------------------
# Diff against item_chr_manifest.json item_defs (informational)
# ---------------------------------------------------------------------------

def diff_against_manifest(registry: List[dict]) -> None:
    """Print discrepancies between items registry and item_chr_manifest.json item_defs.

    Reads item_defs from RoomRom/data/item_chr_manifest.json directly.
    (gen_item_chr_manifest.py was the legacy source of ITEM_DEFS; it has been
    deleted as part of atlas FU4 cleanup. The manifest JSON is the authority.)
    """
    import json
    manifest_path = ROOT / "RoomRom" / "data" / "item_chr_manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        item_defs = manifest.get("item_defs", [])
    except Exception as e:
        print(f"diff_against_manifest: could not load {manifest_path}: {e}", file=sys.stderr)
        return

    tile_to_reg: Dict[int, dict] = {}
    for entry in registry:
        if entry["nes_tile_ids"]:
            tile_val = int(entry["nes_tile_ids"][0], 16)
            tile_to_reg[tile_val] = entry

    print("\n--- diff vs item_chr_manifest.json item_defs ---")
    discrepancies = 0
    for idef in item_defs:
        raw_frame_tile = idef.get("nes_frame_tile", "")
        # nes_frame_tile may be stored as hex string ("0x20") in the manifest
        try:
            frame_tile = int(raw_frame_tile, 16) if isinstance(raw_frame_tile, str) else int(raw_frame_tile)
        except (ValueError, TypeError):
            print(f"  SKIP: '{idef.get('name', '?')}' — nes_frame_tile unparseable: {raw_frame_tile!r}")
            continue
        reg_entry = tile_to_reg.get(frame_tile)
        if reg_entry is None:
            print(f"  MISSING: item_def '{idef['name']}' (frame_tile=0x{frame_tile:02X})")
            discrepancies += 1
            continue
        manifest_draw_rule = idef.get("draw_rule", "")
        reg_dispatch = reg_entry["dispatch_class"]
        expected_dispatch_map = {
            "narrow_8x16": "Narrow",
            "narrow_8x8": "Narrow",
            "narrow_8x8_phase_cycle": "Narrow",
            "wide_16x16_hflippable": "Wide_Flippable",
            "mirrored_16x8_phase_cycle": "Wide_Mirrored",
        }
        expected = expected_dispatch_map.get(manifest_draw_rule)
        if expected and expected != reg_dispatch:
            print(f"  DISPATCH MISMATCH: '{idef['name']}' tile=0x{frame_tile:02X} "
                  f"manifest={manifest_draw_rule!r} expects {expected!r} but got {reg_dispatch!r}")
            discrepancies += 1
        else:
            print(f"  OK: '{idef['name']}' tile=0x{frame_tile:02X} dispatch={reg_dispatch}")
    if discrepancies == 0:
        print("  All item_defs match registry dispatch classes.")
    else:
        print(f"  {discrepancies} discrepancy(ies) noted (informational, not fatal).")
    print("--- end diff ---\n")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> int:
    phase = "all"
    if "--phase" in sys.argv:
        idx = sys.argv.index("--phase")
        if idx + 1 < len(sys.argv):
            phase = sys.argv[idx + 1].lower()

    valid_phases = {"items", "enemies", "bosses", "hud", "title", "fileselect", "npc", "bg", "merge", "all"}
    if phase not in valid_phases:
        print(f"ERROR: unknown phase {phase!r}. Valid: {sorted(valid_phases)}", file=sys.stderr)
        return 1

    # Load disasm files
    def _load(path: Path) -> List[str]:
        if not path.exists():
            print(f"ERROR: disasm not found: {path}", file=sys.stderr)
            sys.exit(1)
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        print(f"Loaded {path.name} ({len(lines)} lines)")
        return lines

    z01 = _load(DISASM_Z01) if phase in {"items", "enemies", "bosses", "hud", "npc", "all"} else []
    z02 = _load(DISASM_Z02) if phase in {"title", "fileselect", "all"} else []

    items: List[dict] = []
    enemies: List[dict] = []
    bosses: List[dict] = []
    hud_entries: List[dict] = []
    title_entries: List[dict] = []
    fileselect_entries: List[dict] = []
    npc_entries: List[dict] = []
    bg_entries: List[dict] = []

    if phase in ("items", "all"):
        print("\n=== Phase 1a: Items ===")
        items = run_items(z01)
        diff_against_manifest(items)

    if phase in ("enemies", "all"):
        print("\n=== Phase 2a: Enemies ===")
        enemies = run_enemies(z01)

    if phase in ("bosses", "all"):
        print("\n=== Phase 2b: Bosses ===")
        bosses = run_bosses(z01)

    if phase in ("hud", "all"):
        print("\n=== Phase 2c: HUD ===")
        hud_entries = run_hud(z01)

    if phase in ("title", "all"):
        print("\n=== Phase 2d: Title ===")
        title_entries = run_title(z02)

    if phase in ("fileselect", "all"):
        print("\n=== Phase 2d: File Select ===")
        fileselect_entries = run_fileselect(z02)

    if phase in ("npc", "all"):
        print("\n=== Phase 2e: NPC ===")
        npc_entries = run_npc(z01)

    if phase in ("bg", "all"):
        print("\n=== Phase 2f: BG patterns ===")
        bg_entries = run_bg()

    if phase in ("merge", "all"):
        # For merge-only, reload all category JSONs if we didn't just generate them
        if phase == "merge":
            def _load_cat(path: Path, key: str) -> List[dict]:
                if path.exists():
                    return json.loads(path.read_text(encoding="ascii")).get(key, [])
                print(f"  WARNING: {path} not found, using empty list", file=sys.stderr)
                return []
            items = _load_cat(OUT_JSON_ITEMS, "items")
            enemies = _load_cat(OUT_JSON_ENEMIES, "enemies")
            bosses = _load_cat(OUT_JSON_BOSSES, "bosses")
            hud_entries = _load_cat(OUT_JSON_HUD, "hud")
            title_entries = _load_cat(OUT_JSON_TITLE, "title")
            fileselect_entries = _load_cat(OUT_JSON_FILESELECT, "fileselect")
            npc_entries = _load_cat(OUT_JSON_NPC, "npc")
            bg_entries = _load_cat(OUT_JSON_BG, "bg")

        print("\n=== Phase 2g: Merge into atlas_master.json ===")
        run_merge(items, enemies, bosses, hud_entries, title_entries,
                  fileselect_entries, npc_entries, bg_entries)

    print("\nDone.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

# Sprite Roster Audit — Session 6 close
*(2026-05-19, post Phase J/J.2/K continuation #1-3/P/W)*

## Purpose
End-of-cleanup-pass static audit verifying every NES sprite extracted,
labeled, and dispatched correctly. Cross-references
`RoomRom/data/item_chr_manifest.json` (extraction source) →
`RoomRom/src/atlas/items_chr_x4.h` (named constants) →
`src/game/world/render/sprite_render.c` (renderer dispatch) →
`reference/aldonunez/dat/*.dat` (NES CHR ground truth).

## Roster summary

| Category | Count | Status |
|---|---:|---|
| `item_defs` total in manifest | 31 | All have `tile_ids` assigned |
| Variant tile byte coverage (orig) | 82 | All referenced tiles populated |
| Variant tile byte coverage (redux) | 82 | Identical coverage |
| `ROOMROM_ITEM_TILE_*` named constants | 32 | All emitted in `items_chr_x4.h` |
| Room item `item_id` dispatch cases | 15 | All standard UW + OW pickups |

## Per-item roster (sorted by NES Z1 item slot)

| NES `item_id` | Name | Tiles | Size | Sub-pal | NES CHR source | Dispatch |
|---|---|---|---|---|---|---|
| 0x04 | bow | 0x2A/0x2B | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:666 |
| 0x06 | recorder | 0x22/0x23 | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:667 |
| 0x07 | food | 0x40/0x41 | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:668 |
| 0x08 | potion | 0x4A/0x4B | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:669 |
| 0x0A | raft | 0x42/0x43 | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:660 |
| 0x0B | book_of_magic | 0x46/0x47 | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:659 |
| 0x0C | ring | 0x76/0x77 | 1x2 | 0 | **DemoSpritePatterns** | sprite_render.c:663 |
| 0x0D | ladder | 0x2C/0x2D | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:661 |
| 0x0E | magic_key | 0x4E/0x4F | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:664 |
| 0x0F | bracelet | 0x4C/0x4D | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:665 |
| 0x10 | compass | 0x2E/0x2F | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:627 |
| 0x11 | map | 0x32/0x33 | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:639 |
| 0x14 | heart_container | 0x50/0x51 | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:657 |
| 0x18 | big_key | 0x68/0x69 | 1x2 | 0 | CommonSpritePatterns | sprite_render.c:658 |
| 0x1B | triforce_piece | 0x6E-0x71 | 2x2 | 2 | CommonSpritePatterns | sprite_render.c:611 |

Plus non-pickup item sprites in atlas (sword/arrow/bomb/explosion/
boomerang/candle/magic_shot frames + fairy_spark scaffold).

## VRAM bank layout (post Phase J.2)

```
Tile  1   .. 532  : BG sparse atlas (4 variants share LUT)
Tile  533 .. 819  : SPR bank (Link + sword + common + SCENE_OBJ)
Tile  820 .. 917  : ITEM bank (98 tiles, all extracted sprites)
Tile  918 .. 1535 : Headroom (618 tiles free before VDP tables)
Tile  1536+       : VDP tables (planes / window / hscroll / SAT)
```

`verify_vram_budget.py` reports **headroom=618 tiles** = 19.8 KB free
ROM-side CHR space available for future content.

## Phase J sparse LUT coverage

Per `tools/probes/audit_per_tile_subpal.py` (refined attr formula):

| Bank | Unique NES IDs | Sub-pal distribution (1/2/3) |
|---|---:|---|
| UW BG (636 rooms) | 97 | 79 / 16 / 2 (81.4% / 16.5% / 2.1%) |
| OW BG (128 rooms) | 114 | 19 / 42 / 53 (16.7% / 36.8% / 46.5%) |
| **Combined UW+OW** | **129** | 22 / 53 / 54 (17.1% / 41.1% / 41.9%) |

Sparse atlas emits 532 tiles per variant (vs 1024 in legacy 4x mode).
Universal LUT `bg_sparse_tile_lut[256][4]` maps every (NES_tile_id, sub_pal)
combo to Genesis VRAM slot or 0xFFFF sentinel.

## Phase P animation frames

| Sprite | Frames extracted | NES cadence reference |
|---|---:|---|
| candle_fire | 4 (F0/F1/F2/F3) | Z_07.asm:4622 (ObjAnimFrameHeap) |
| fairy_spark | 2 (F0/F1) | Z_04.asm:11508 (DrawFairy, ~every 4 vframes) |

candle_fire wired and live (4-frame cycle in `candle_fire.c::advance_anim`).
fairy_spark renderer scaffold present (`roomrom_sprites_set_fairy_spark`);
caller not yet wired (fairy enemy code not ported).

## Known data issues (deferred)

### K-MF1: heart_container + fairy_spark tile 0x50/0x51 collision
Manifest stores CommonSpritePatterns version of tile 0x50/0x51 (heart
container art). DemoSpritePatterns version (fairy art) is DIFFERENT
bytes:

```
manifest [0x50]: 38 54 FF C7 C7 6E 46 28 44 28 81 B9 B9 52 3A 54  (heart container)
demo     [0x50]: 07 7E FE FC FC FC F8 F8 00 00 00 00 00 00 00 00  (fairy)
```

If `roomrom_sprites_set_fairy_spark` is wired into a live caller, it
will render heart container art instead of fairy art. Fix: extract
fairy_spark_f0/f1 from DemoSpritePatterns into separate atlas slots
(distinct from heart_container tile IDs) before fairy renderer goes
live. Tracked here, not blocking — fairy enemy code currently absent.

### Magic rod animation (NES static — no fix required)
NES Z1 does not animate the magic rod (single static frame per
direction). Manifest correctly has only `magic_shot_v` + `magic_shot_h`
as single-frame entries. Phase P scoped magic rod as
NES-faithful-static.

## Build + visual verification

- `python tools/debug/build_debug.py` → builds clean to
  `builds/Debug.md`
- `tools/probes/check_generated_freshness.py` → all 9 specs match
  sentinels
- BizHawk skip_to_gameplay.lua probe (Phase W) → reaches title + UW +
  OW gameplay screens; all render NES-faithful (see Read tool
  screenshots in session 6 transcript: `w1_title.png`, `w5_settle_2.png`,
  `w7_settle_3.png`)

## ROM-size accounting (cumulative across sessions 1-6)

| Source | Delta |
|---|---:|
| Legacy `expanded_bg_chr.{c,h}` retired | -~158 KB ROM |
| Sparse `bg_sparse_chr.{c,h}` (4 variants + LUT) | +~70 KB ROM |
| Item atlas growth (70 → 98 tiles) | +~3 KB ROM |
| **Net ROM delta** | **~-85 KB ROM** (cleanup wins) |

## Headroom progression

| Snapshot | Verifier headroom |
|---|---:|
| Session 1 start | 14 tiles |
| Session 1 end (Phase B+F) | 154 tiles |
| Session 5 end (Phase J shipped) | 154 tiles (BG bank shrunk internally; SPR/ITEM not shifted) |
| **Session 6 close (Phase J.2 bank shift + Phase K cont. #1-3)** | **618 tiles** |

Net session 1 → session 6: **+604 tiles / +19.3 KB** addressable CHR
budget for future content.

## Status

**Cleanup pass: COMPLETE.**

All planned phases shipped or explicitly deferred with rationale:
- A/B/D/E.0/F/M shipped (sprite/CHR atlas dedup, verifier alignment)
- J/J.2 shipped (BG sparse atlas + bank shift; the headline win)
- K (continuations #1-3) shipped (15 room-pickup items extracted)
- P shipped (candle 4-frame animation, fairy scaffold)
- Q/R shipped (DMA telemetry, transfer_buf batch)
- N/O confirmed (sub-pal 3 probe + enemy priority audit, no fix needed)
- X/Z/AA/CC shipped (organizational: catalog, slot doc, sub-pal API, dead code cull)
- W shipped (skip-to-gameplay Lua probe — savestate replacement)
- G-v2 deferred (618 tile headroom makes +64 marginal gain not worth
  the risk; revisit only if future content exceeds available budget)
- Magic rod animation: NES-faithful static (no extension required)
- Fairy enemy wire-up: pending fairy entity port (out of cleanup scope)

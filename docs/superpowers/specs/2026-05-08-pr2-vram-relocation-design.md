# PR-2 VRAM Relocation — Design (final, post-2026-05-07 lock)

**Date:** 2026-05-08
**Target:** CombinedDebug.md only
**Phase:** Phase 1.x amendment (CHR ownership)
**Decision priority:** PD priority 1 (best long-term outcome)
**Decision lock:** memory project_pr2_vram_relocation; user 2026-05-07

## Problem

64×64 plane mode forces SGDK to place tables at:
- HScroll  @ $A800 (1 KB)
- SAT      @ $AC00 (1 KB; only 640B used)
- Window   @ $B000 (4 KB)
- Plane B  @ $C000 (8 KB)
- Plane A  @ $E000 (8 KB)

Tile budget capped at $A800 = **1344 tiles**. ITEM 4× expansion needs limit ≥ 1461 to land 31×4=124 tiles after SPR bank ends at 1336. Pre-PR-3 layout already collides; verify_vram_budget.py FAILs.

## Options analysis (recap of user 2026-05-07 brief + new findings)

| ID | Approach | Verdict | Reason |
|----|----------|---------|--------|
| A | Move ITEM below $A800 | REJECT | only 7 tiles fit (tile 1330..1336) |
| B-as-stated | Relocate VDP tables out of $A800-$BFFF in 64×64 | INFEASIBLE | planes fill $C000-$FFFF; tables have nowhere to go; user's "available unused $E000+" premise was wrong (plane A occupies $E000-$FFFF) |
| C | BG_2x sub-pal | REJECT | preflight (PR-1) showed UW rooms use 4 sub-pals |
| D | 64×32 plane mode + drop V staging | REJECT alone | breaks ph5.x gates (V scroll exercised in L1Q1) |
| Φ | BG_B addr = BG_A addr (plane B duplicates A) | REJECT | most RoomRom sprites use TILE_ATTR_FULL pri=0; sprites_low render BETWEEN B and A → invisible behind B-as-A duplicate |
| Σ | Disable Window only | INSUFFICIENT | SAT still anchors limit at $AC00 = 1376; SAT cannot move into plane region without tilemap conflict |
| **F** | **64×32 mode + use BG_B for V staging** | **ACCEPT** | clean long-term, 192-tile gain, repurposes currently-dead plane B as functional vertical staging |

## Chosen design: F = 64×32 + BG_B V staging

### New VRAM layout

```
$0000-$BFFF  tile region (48 KB = 1536 tiles)  [+192 vs current]
$C000-$CFFF  plane B (BG_B, 64×32, 4 KB) — vertical staging slot
$D000-$DFFF  Window plane (64×32, 4 KB) — HUD
$E000-$EFFF  plane A (BG_A, 64×32, 4 KB) — current room slot + horizontal staging
$F000-$F3FF  HScroll table (1 KB)
$F400-$F7FF  SAT (1 KB)
$F800-$FFFF  free (2 KB = 64 tiles) — reserved for PR-4/PR-5 transient growth
```

### Staging architecture

**Horizontal scroll (E/W):** unchanged semantics — BG_A 64×32 has two 32-col slots; render incoming room into the OTHER slot, scroll plane A H by 256.

**Vertical scroll (N/S) — NEW:**
- Current room lives in BG_A (in active slot_x).
- Incoming vertical room renders into BG_B at the same slot_x.
- Both planes use VSCROLL_PLANE (independent V scroll per plane).
- During scroll: BG_A V-scrolls down (or up) by ROOMROM_VERTICAL_STRIDE_PX; BG_B V-scrolls in opposite direction so the incoming room slides into view.
- On finalize: copy BG_B contents → BG_A active slot (or simply swap which plane is "active"); reset BG_B for next staging.

**Plane priority:** BG_B priority bit = 0; BG_A priority bit = 0 for room tiles. Both rooms render at same Z-order, sprites_low between them appear behind whichever plane has opaque pixels at that location. Acceptable: during normal play (not mid-scroll), BG_B is invisible (blank tile 0); during scroll, both rooms are partially visible — same as Z1 NES.

### Sprite priority (regression risk)

TILE_ATTR_FULL pri=0 sprites (Link, sword, items, projectiles except candle fire) render **between** BG_B and BG_A in Genesis layer order:
```
backdrop → BG_B_low → spr0 → BG_A_low → BG_B_high → spr1 → BG_A_high
```
With BG_B blank (currently the case outside scroll), spr0 visible against BG_A as expected. **No regression in normal play.**

Mid-scroll, BG_B contains incoming room → spr0 sprites visible in OLD room (still BG_A) but invisible in NEW room (BG_B). Acceptable: NES Z_07.asm `ShowLinkSpritesBehindHorizontalDoors` already hides Link sprite during transitions (handled at main.c:1166 with off-screen pose). Other sprites are inactive during scroll (combat halted, joypad swallowed). **No active sprites mid-scroll → no visible regression.**

### Phase ordering

1. **PR-2a** add BG_B V staging WITH 64×64 mode preserved (gates remain GREEN; no VRAM change).
2. **PR-2b** switch to 64×32 mode + relocate tables to default $F000/$F400 (gates remain GREEN with new staging).
3. **PR-2c** update verify_vram_budget.py + roomrom_vram_map.h with new tile_limit = $C000 = 1536.

Each sub-PR commits independently. PR-2c unblocks PR-3.

## Acceptance gates (PR-2 close)

1. CombinedDebug.bat clean.
2. verify_vram_budget.py PASS with new layout.
3. ph5.4-9 regression gates GREEN.
4. Screenshot probe: HUD intact, room renders, sprites visible.
5. Door-route probe (ph5.5 reproduce) GREEN with N/S transitions.
6. SAT slot probe: SAT now at $F400 (not $AC00); slot 8 candle-fire write reads correctly.

## Rollback path

`git revert` PR-2c → PR-2b → PR-2a. Each commit independent.

## Files touched

- `RoomRom/src/main.c` (init_video, render_room_into_slot, scroll state machine V branch)
- `RoomRom/src/roomrom_vram_map.h` (tile budget constants, comment block)
- `RoomRom/tools/verify_vram_budget.py` (VDP_TABLES + TILE_DATA_LIMIT_BYTES)
- `RoomRom/src/render_adapter_sgdk.c` (render_mode_set_v64 — replace with v32 or new fn)
- `src/abi/render_abi.h` (if mode-set ABI changes)

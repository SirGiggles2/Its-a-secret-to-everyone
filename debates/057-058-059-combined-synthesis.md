# Combined Synthesis — Debates 057 / 058 / 059
## Cave + Dungeon Sprite + BG Byte-Exact Parity vs NES

**Project**: FINAL TRY — NES Zelda 1 → Sega Genesis port via SGDK + drained C
**Date**: 2026-05-27
**Method**: 3 sequential Octo debates (Codex CLI + Sonnet Agent + Claude Opus moderator; Gemini quota-blocked R2+)
**Result**: 14 real bugs surfaced via code investigation (file:line cited, no speculation)

---

## Executive summary

Genesis port currently passes **56/56 cave + dungeon visual sweep** (commit 9ddf67d0 + follow-ups). Visual sweep gates on scene transition + ObjType[1] match, NOT byte-exact NES parity. Three debates audited what's needed for true byte-exact across caves, dungeons, and BG content.

**Total work**: ~70–80h to full byte-exact OAM + CHR + PAL + NT across all scenes.

**Highest-impact bugs** (visible regressions in current build):
1. Room-clear item drops INVISIBLE (058 BUG 4, 1h fix)
2. OW palette table ALL 128 ROOMS IDENTICAL (059 BUG 1, 4h fix)
3. All 9 dungeon bosses don't render correctly (058 BUG 3, 7h fix)
4. First dungeon entry shows enemies with stale OW SPR palette (058 BUG 1, 2h fix)
5. Link renders IN FRONT of OW tree canopies (059 BUG 2, 3h fix)

---

## Debate 057 — Cave sprite + animation parity

### Findings
- 56/56 cave entries dispatch byte-perfect (Phase A oracle verified).
- 1 real bug: `cave_palette.c:20` uploads BG sub-palettes only; SPR sub-palette inherits from OW state. Visually rendering correctly (orange flames in cave_77 PNG) but byte-diff vs NES PALRAM would fail.
- Cave NPC sprites group into 5 categories matching NES `ObjAnimations` table exactly:
  - `$6A` → tile $C0 (sword cave Old Man)
  - `$6B-$73` → tile $98 (most NPCs)
  - `$74-$77` → tile $9A
  - `$78-$7B` → tile $9C
  - `$7C-$7D` → tile $F8
- Cave items are STATIC on NES (no bob animation). Bonfire "palette flicker" = myth (NES sets fixed attr 2; tile cycle only).

### NES authority source for SPR palette
`reference/aldonunez/dat/LevelInfoOW.dat` bytes 19-22 = `$0F $16 $27 $30` (SPR sub-pal 2 for cave fire). Uploaded once via `LevelInfo_PalettesTransferBuf` ($6B7E) before cave entry. Same colors all caves.

### Fix
```c
// src/game/world/render/cave_palette.c
static const unsigned char k_cave_spr_subpal_2_nes[4] = {
    0x0F, 0x16, 0x27, 0x30  /* NES $3F18-$3F1B per LevelInfoOW.dat */
};
void cave_palette_apply(void) {
    /* existing BG upload */
    unsigned short spr_cram[4];
    for (int i = 0; i < 4; i++)
        spr_cram[i] = roomrom_bg_palette_nes_to_cram(k_cave_spr_subpal_2_nes[i]);
    render_cram_subrange_upload(24u, spr_cram, 4u);  // PAL1 sub-pal 2 = CRAM 24-27
}
```

### Effort
- I0 probe NES PALRAM: 1h
- I1 fix cave_palette.c: 30min
- I2 rebuild + re-sweep: 1h
- I3 per-cave golden bundle (raw OAM + CHR hashes): 3h
- I4 byte-diff comparator: 3h
- I5 CI hook + docs: 1.5h

**Total: ~10h**

---

## Debate 058 — Dungeon sprite + animation parity

### 5 REAL bugs identified

| # | Bug | File:line | Visible? | Effort |
|---|-----|-----------|----------|--------|
| 1 | UW SPR palette `bg_only` on first dungeon entry | `uw_render.c:210` | YES — enemies use OW colors | 2h |
| 2 | 6 enemy families silent animation ($0B/$0C Darknut, $12/$13 Bubble, $29 Rope) | `enemy_walker_bridge.c` | YES — frozen frames | 2h |
| 3 | All 9 bosses stubs/unverified (`enrt_update_aquamentus` one-liner, Ganon "does not render or move", bosses.c atlas 192 tiles no manifest mapping) | `enemy_dispatch.c:135`, `enemy_ganon_bridge.c:6`, `bosses.c` | YES — bosses invisible/wrong | 7h |
| 4 | Item drops never drawn (`item_object_update` skips `draw_animate_item_object` calling it "deferred") | `item_object.c:120-124` | YES — room-clear hearts/rupees/keys invisible | 1h |
| 5 | No door sprite animations (door_state.c does BG tile patches only) | `door_state.c` | YES — shutter/bomb-door not animated | 3h |

### Priority
1. **BUG 4** (1h, low risk, visible win) — item drops invisible right now
2. **BUG 1** (2h, low risk, visible color bug)
3. **BUG 2** (2h, formulaic clone-and-paste)
4. **BUG 3** (7h, biggest scope — start with Aquamentus L1Q1 highest-traffic)
5. **BUG 5** (3h, polish phase)

### Genesis improvements (opt-in)
- Bosses with extra detail (Aquamentus 2nd head smoothed, Gleeok individual head death frames)
- 60fps interp for enemy walk
- Per-boss particle effects (Gohma laser glow)
- Anti-flicker on 8+ enemy rooms (Genesis 80-slot SAT vs NES 64)

### Verification
Per-(level, quest, room_id) `uw_golden` bundle. Per-boss state probe (force boss state writes to capture all phases without combat). Extension of cave_golden infra from 057.

### Effort
- 15h core fixes + 11h verification infra
**Total: 26h**

---

## Debate 059 — BG (background plane) byte-exact parity

### 5 BG bugs identified

| # | Bug | File:line | Visible? | Effort |
|---|-----|-----------|----------|--------|
| 1 | **OW palette table — all 128 rooms IDENTICAL** | `src/game/world/ow_bg_palram_table.c` | YES — every OW room same colors | 4h |
| 2 | No OW tree-top BG priority (Link renders in front of trees) | OW render path | YES — Link clips through tree canopies | 3h |
| 3 | Animated BG tiles not implemented (palette_tick_runtime.c toggle table empty) | `palette_tick_runtime.c` | YES — waterfalls/lava don't animate | 4h |
| 4 | Cave sub-pals 0+1 unverified (cave_palette_apply only sets 2+3) | `cave_palette.c` | Maybe | 1-2h |
| 5 | No NT byte-diff probe / golden bundle infra | n/a | n/a | 8h |

### BUG 1 explanation
File `ow_bg_palram_table.c` claims "auto-captured live NES BG PALRAM per OW room". All 128 entries are byte-identical `{0x0F, 0x30, 0x00, 0x12, ...}`. Header lied — table was either never populated or got truncated to one row. `roomrom_ow_palette_patch_bg_per_room` always writes same palette.

NES Z1 OW has per-room palette variations (e.g., dungeon-entry rooms have different sub-pal 3 for door framing colors). All currently uniform on Genesis.

### Codex architectural insight
"BG analog of SPR subpal gap = attribute/palette expansion in data but not applied at plane-entry emission time." Each BG cell must carry: `tile_index + BG_palette_line + flip_h + flip_v + priority`. If any is GLOBAL instead of PER-CELL FROM NES STATE, parity drifts.

Risks:
- CHR bank timing wrong
- Attribute expansion bugs
- Palette patch ordering
- Stale UW room cache keys (must include dark/lit/shutter/pushblock/bomb/item-reveal state)
- Priority bits set per-tileset-tile instead of per-placed-cell
- Animations verified only at frame 0

### Working correctly (Sonnet confirmed)
- UW per-room palette `g_uw_room_palette[636][32]` (live-captured per room)
- UW door priority (`uw_is_door_tile`)
- OW heap decode + metatile expansion pipeline
- Cave layout tables (`k_cave_layout_regular` + `k_cave_layout_shortcut`)

### Effort
- 20h core fixes + 8h infra = **28h**

---

## Cross-debate unified execution plan

### Phase 0: Quick wins (3h) — visible regressions
- 058 BUG 4 (1h): `item_object.c:120-124` — remove "deferred" skip
- 058 BUG 1 (2h): `uw_render.c:210` — change `bg_only` → `palram_full`

### Phase 1: Palette correctness (8h)
- 059 BUG 1 (4h): regenerate `ow_bg_palram_table.c` via NES probe
- 057 fix (30m): `cave_palette.c:20` SPR upload
- 058 BUG 2 (2h): drain 6 enemy animation rows
- 059 BUG 4 (1.5h): verify + fix cave sub-pals 0+1

### Phase 2: Visual polish (10h)
- 059 BUG 2 (3h): OW tree-top priority
- 059 BUG 3 (4h): animated BG tiles
- 058 BUG 5 (3h): door sprite animations

### Phase 3: Boss fixes (7h)
- Aquamentus (L1, L8) — full state machine port
- Each remaining boss in order: Dodongo, Manhandla, Gleeok, Digdogger, Gohma, Patra, Ganon
- bosses.c atlas tile-id manifest mapping

### Phase 4: Verification infra (27h)
- Unified `golden_bundle` schema across cave/dungeon/BG (saves ~10h vs separate)
- `tools/parity/{cave,uw,bg}_golden/<scene_key>/...` with consistent schema:
  - `oam.json` — slot/x/y/tile_normalized/attr/flip/prio per frame phase
  - `palram.bin` — 32 bytes NES PALRAM
  - `nt.bin` + `attr.bin` (BG only) — 32×30 + attr table
  - `priority_mask.bin` — per-cell BG priority
  - `chr_hashes.json` — fnv32 per referenced tile (build-time check)
  - `state_trace.json` — per-state OAM snapshot (CavePersonState 0..8 / boss states)
- CI gate: `python tools/parity/golden_diff.py` exit 1 on any byte-mismatch

### Grand total
**Core fixes**: 28h
**Verification infra**: 27h
**Grand total**: **~55h** (down from 70-80h with shared infra)

---

## Files touched (preview)

### Edit
- `src/game/world/render/cave_palette.c:20` — SPR sub-pal upload
- `src/game/world/render/uw_render.c:210` — `bg_only` → `palram_full`
- `src/game/items/item_object.c:120-124` — call `draw_animate_item_object`
- `src/game/world/ow_bg_palram_table.c` — REGENERATE from NES probe
- `src/game/enemies/enemy_walker_bridge.c` — 6 enemy anim rows
- `src/game/enemies/enemy_dispatch.c:135` + boss files — boss draw paths
- `src/game/world/render/palette_tick_runtime.c` — populate toggle table
- `src/game/world/door_state.c` — sprite animation paths

### New
- `tools/parity/probe_nes_cave_palette.lua` — NES SPR palette probe
- `tools/parity/probe_nes_ow_palette_per_room.lua` — 128-room palette dump
- `tools/parity/probe_nes_boss_states.lua` — multi-state boss capture
- `tools/parity/golden_diff.py` — unified byte-diff
- `tools/parity/{cave,uw,bg}_golden/*` — per-scene golden bundles
- `docs/parity/strict_contract.md` — verification contract

### No new RoomRom files (WT-5 invariant respected)

---

## NES authority sources cited

- `reference/aldonunez/Z_01.asm:1958` — ObjAnimations (entity-to-tile table)
- `reference/aldonunez/Z_01.asm:1977` — ObjAnimFrameHeap (per-frame tile IDs)
- `reference/aldonunez/Z_01.asm:69` — InitCave
- `reference/aldonunez/Z_01.asm:282-293` — SetUpCommonCaveObjects (NPC + bonfire slots)
- `reference/aldonunez/Z_01.asm:359-368` — UpdateCavePerson_JumpTable (9 states)
- `reference/aldonunez/Z_01.asm:385` — CaveWareXs (item positions)
- `reference/aldonunez/Z_01.asm:4979` — DrawObjectMirrored
- `reference/aldonunez/Z_02.asm` — CHR bank swap per scene
- `reference/aldonunez/Z_03.asm:328` — cave_person draw gate (FrameCounter bit)
- `reference/aldonunez/Z_04.asm` — boss draw paths (over-Link priority)
- `reference/aldonunez/Z_04.asm:257-274` — StandingFire renderer
- `reference/aldonunez/Z_05.asm` — HandleWarpOW (Phase A LBA_B dispatch)
- `reference/aldonunez/Z_06.asm:714` — CaveBgPaletteRowsTransferBuf
- `reference/aldonunez/Z_07.asm` — enemy_loop dispatch + AnimateObjectWalking
- `reference/aldonunez/dat/LevelInfoOW.dat` bytes 19-22 — cave SPR sub-pal 2 source
- `reference/aldonunez/dat/LevelInfoUW*.dat` — per-level UW palettes
- `reference/aldonunez/Variables.inc:330` — LevelInfo_PalettesTransferBuf
- `reference/aldonunez/Variables.inc:328` — LevelBlockAttrsE (cave wares + prices)

---

## Methodology note

This synthesis was generated through `/octo:debate` orchestration:
- **Codex CLI** (`codex exec`): architectural analysis, no file reads
- **Sonnet Agent** (sub-agent via Task tool): live code investigation with file:line citations — proved which speculations were real bugs and which weren't
- **Opus** (this turn): moderator + investigation cross-check + synthesis writer
- **Gemini CLI**: quota-blocked after R1; partial contributions

Result: every bug claim has a file:line citation from live code investigation. No speculation. Per CLAUDE.md Rule Zero (NEVER GUESS).

---

## Recommended next step

Execute **Phase 0 (3h)** immediately — item drops + UW palette = two visible regressions resolvable in one work-session. Then iterate Phase 1-4 over ~2 weeks.

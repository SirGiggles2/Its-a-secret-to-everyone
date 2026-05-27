# Round 003 — Pragmatic Implementer (Sonnet)

## Q1: Cave SPR subpal source

`Z_06.asm:714` `CaveBgPaletteRowsTransferBuf` writes 8 bytes at `$3F08` (BG subpals 2+3 only). It does NOT touch sprite palette `$3F10-$3F1F`.

The NES SPR palette in cave comes from the **OW LevelInfo palette** loaded before cave entry. `LevelInfo_PalettesTransferBuf` at `Variables.inc:330` (`$6B7E`) is a 32-byte write to `$3F00-$3F1F`. The OW level info block starts with `3F 00 20` (write 32 bytes at `$3F00`). From `LevelInfoOW.dat` byte-exact:

```
SPR subpal 2 ($3F18): 0F 16 27 30
```
= transparent / red(16) / orange(27) / white(30).

This is **uniform across all cave_ids** — no cave writes a separate SPR palette; the OW SPR palette persists. Palette is NOT per-cave-id.

Fix in `src/game/world/render/cave_palette.c` after line 19:
```c
static const unsigned char k_cave_spr_subpal_2_nes[4] = {
    0x0F, 0x16, 0x27, 0x30   /* OW SPR subpal 2, verified LevelInfoOW.dat */
};
unsigned short spr_cram[4];
unsigned char j;
for (j = 0u; j < 4u; j++)
    spr_cram[j] = roomrom_bg_palette_nes_to_cram(k_cave_spr_subpal_2_nes[j]);
render_cram_subrange_upload(24u, spr_cram, 4u);  /* CRAM 24-27 = SPR subpal 2 */
```

CRAM slot 24 = palette line 1 (sprite), colors 8-11 = SPR subpal 2. No probe needed for the value — it's in the dat file. Verify post-fix via BizHawk CRAM dump showing `CRAM[24..27]` matches `0F 16 27 30` NES-converted.

## Q2: Golden bundle — CHR hashes vs raw OAM

**Sonnet settles: raw OAM only.**

CHR is static per scene (no runtime tile writes in cave). CHR divergence is a build-time extraction error, caught by `check_banned_filename.py` and build gates — NOT a runtime regression. Including CHR hashes in the per-frame golden bundle adds 232 SHA-256 values that never change and cannot diverge frame-to-frame.

Codex's concern (extraction drift) is valid but belongs in a **separate one-time CHR hash manifest** checked at build time, not in the per-cave runtime golden files.

Golden bundle format: `tools/parity/cave_golden/<cave_id_hex>/oam_f{N}.json` containing `[{slot, Y, tile, attr, X}]`. Frames `+0/+6/+12/+30` cover: initial state, first bonfire frame flip, second flip, NPC walk cycle completion. PALRAM snapshot (32 bytes) is separate: `palram.bin` per cave_id — captured once, not per-frame.

Deterministic seed: savestate after `cave_init()` completes (ObjType[1] == cave_id, ObjState[0] == `$40`), advance exactly N frames. Same on Genesis: hook `cave_init()` return, latch local counter.

## Q3: NPC sprite grouping per cave_id

From `draw_dispatch.c:73-90` (k_obj_animations), byte-exact ObjType → heap_start → NES tile:

| ObjType range | k_obj_animations | heap_start | NES tile |
|---|---|---|---|
| `$6B-$73` (9 caves) | 0x58 | 0x58 | **0x98** |
| `$74-$77` (4 caves) | 0x59 | 0x59 | **0x9A** |
| `$78-$7B` (4 caves) | 0x5A | 0x5A | **0x9C** |
| `$7C-$7D` (2 caves) | 0x5B | 0x5B | **0xF8** |
| `$6A` (money game) | 0xCC | OOB | **undefined** |

ObjType `$6A` indexes k_obj_animations[106]=`0xCC` but `k_obj_anim_frame_heap` is 228 bytes (`draw_dispatch.c:93`); index `0xCC`=204 is in range (heap[204]=`0xC0`). The grouping on Genesis **does match NES** — same 4 sprite groups. The OOB concern is wrong; 0xCC < 228.

Corrected: `$6A` heap[0xCC]=`0xC0` (tile `$C0`). That is a separate NPC sprite. Five groups total, not four.

## Q4: Item sprites — atlas gap

`sprites` block: `nes_tile_id_start=0 tile_count=232` → covers NES tiles `$00-$E7`.

`k_anim_item_frame_tiles` (`draw_dispatch.c:164`) max tile = `0xF3`. Two tiles fall outside:

- **Tile `0xF3`** (slot 25, item_id `0x0E` = Ladder)
- **Tile `0xF2`** (slot 27, item_id `0x22` = Fairy)

Both are outside `sprites` (`$E7` ceiling) and outside `common` (`$ED` ceiling). **However:** no NES cave_id stocks Ladder or Fairy as a ware item — `CaveItemIds` is populated from LevelInfo per cave and neither item_id appears in any OW cave's ware table. Atlas gap exists but is **not reachable via any cave ware scenario** in NES Z1. Not a live bug; document and close.

## Q5: Execution sequence — concrete steps

1. **Fix `src/game/world/render/cave_palette.c`** (line 20, after `render_cram_subrange_upload(8u, cram, 8u)`): add 4-color SPR subpal 2 upload to CRAM slot 24 using bytes `{0x0F,0x16,0x27,0x30}`. 30min. Values sourced from `reference/aldonunez/dat/LevelInfoOW.dat` bytes 19-22 of the palette payload.

2. **Build** `Debug.bat`. Verify clean. 10min.

3. **BizHawk probe** — single Lua covering: screenshot, SAT dump (slots 0-3), CRAM dump (slots 16-31). Enter cave `$6B` (sword cave). Confirm CRAM[24..27] = converted `0F 16 27 30`; bonfire SAT entry has attr=`0x02` (SPR subpal 2); tile alternates `$5C/$9E` at +6-frame interval. 1h.

4. **Build NES golden** `tools/parity/cave_golden/gen_nes_cave_oam.lua`: BizHawk NES probe, joypad-automate into caves `$6A-$7D`, savestate at cave_init return, dump OAM slots 0-3 at frames +0/+6/+12/+30 → JSON per cave_id. Also dump PALRAM `$3F00-$3F1F` once per cave_id. 3h.

5. **Build Genesis probe** `tools/parity/cave_golden/gen_cave_sat.lua`: same scene coverage, dump SAT + CRAM[16-31] at same relative offsets. 2h.

6. **Differ** `tools/parity/cave_golden/diff_cave.py`: slot-normalized byte diff (NES OAM → Genesis SAT), exits non-zero on divergence. Hook as `Debug.bat` post-build step. 2h.

Total: ~9h. Bug 1 fix + verify is 2h; golden infra is 7h.

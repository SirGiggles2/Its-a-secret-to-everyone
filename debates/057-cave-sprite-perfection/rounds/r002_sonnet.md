# Round 002 — Pragmatic Implementer (Sonnet)

## Bug 1: SPR subpal not uploaded for cave

**Verified from source**: `src/game/world/render/cave_palette.c:11-19` — `cave_palette_apply()` calls `render_cram_subrange_upload(8u, cram, 8u)`, writing CRAM slots 8-15. These are BG subpals 2+3 only. Genesis CRAM slots 16-31 = sprite subpals 0-3. Slot 24-27 = SPR subpal 2 (fire). Never touched.

**(a) VERIFY probe**: BizHawk NES probe at RAM $0015 (FrameCounter) = any; dump PALRAM $3F08-$3F1F at first cave entry (cave_id $6A). Bytes $3F18-$3F1B = SPR subpal 2. Compare against Genesis CRAM slots 24-27 via XGM probe.

**(b) FIX** — `src/game/world/render/cave_palette.c`: add SPR subpal 2 after existing BG upload:

```c
/* NES SPR subpal 2 ($3F18-$3F1B): transparent / $16 / $27 / $18 */
static const unsigned char k_cave_spr_subpal_2_nes[4] = {
    0x0F, 0x16, 0x27, 0x18   /* fire: black, red, orange, tan */
};
/* In cave_palette_apply(), after render_cram_subrange_upload(8u,...): */
unsigned short spr_cram[4];
for (i = 0u; i < 4u; i++)
    spr_cram[i] = roomrom_bg_palette_nes_to_cram(k_cave_spr_subpal_2_nes[i]);
render_cram_subrange_upload(24u, spr_cram, 4u);  /* CRAM 24-27 = SPR subpal 2 */
```

NOTE: actual NES bytes must be probed — $3F18-$3F1B values above are placeholder pending BizHawk PALRAM dump. Do not ship until confirmed.

**(c) Effort**: 1h probe + 30min fix.

---

## Bug 2: z07_animate_object_walking cadence

**Verified from source**: `src/oracle/world/sprite_runtime.c:104-117` — `sprrt_animate_object_walking` at line 107 uses `COMBAT_WEAPON_SLOT = 6`. NES `AnimateObjectWalking` at `reference/aldonunez/Z_07.asm:5056` uses `LDA #$06`. These match — the 6-frame reload is byte-identical.

However: the Gen shim ignores `OBJ_DIR` entirely for speed selection. NES `AnimateObjectWalking` uses a fixed 6-frame counter regardless of DIR; the DIR field only affects the H-flip/frame index path (`Z_07.asm:5065-5087`). Gen shim replicates that at lines 111-116.

**Conclusion**: cadence shim is CORRECT. No bug here. The 6-frame reload matches NES; the bonfire DIR=$08 path hits the `dir != 0` branch (line 112) → calls `sprrt_anim_set_obj_hflip` → frame toggles via `OBJ_ANIM_CNTR` rollover at correct rate.

**(a) VERIFY probe** (to confirm, not to find a bug): BizHawk NES — dump OAM slot 2 tile byte at FrameCounter $0015 = 0, 6, 12. Expect tile alternation $5C→$9E→$5C. Same on Genesis SAT slot for bonfire. Expected: already correct.

**(b) FIX**: None required. Mark CLOSED.

**(c) Effort**: 30min verification probe only.

---

## Bug 3: State 2 ware visibility after purchase

**Verified from source**: `cave_dispatch.c:397` — on purchase, `RAM(0x0422 + i) = 0xFFu` (sets ware to sentinel). `cave_draw_items` at line 306-309 gates on `item != 0x3Fu` — sentinel $FF masked `& 0x3F` = $3F, so the draw is skipped. The item disappears correctly on the NEXT frame when `cave_draw_items` runs.

The show-items flag path (`cave_flags_get() & 0x04u`, line 296) is not cleared in state 2 on purchase. NES `Z_01.asm` clears the show-items bit via `core_cue_transfer_buf_and_advance_state` → `cave_clear_prices_flag_inline` clears bit $08 (show-prices) but NOT bit $04 (show-items). That matches NES behavior: the empty slot position is still drawn (just no item tile because sentinel check passes). No bug.

**(a) VERIFY probe**: BizHawk NES — dump OAM slots 17-19 (ware draw slot = 19 per NES convention) at FrameCounter immediately after purchase (state transitions 2→3). Expect slot 19 Y = $F8 (hidden). Confirm Genesis SAT slot for ware slot Y = $F8 (sentinel write triggers hide via draw_animate_item_object returning early for $3F item).

**(b) FIX**: None required structurally. The `0xFF & 0x3F = 0x3F` sentinel mask is correct. Mark CLOSED.

**(c) Effort**: 30min probe to confirm.

---

## Codex Data Architecture

**Golden bundle format**: raw OAM bytes ONLY. CHR hashes are redundant — CHR is static per scene; OAM bytes capture tile ID + attr + position, which is all that can diverge at runtime. Store `{frame, slot, Y, tile, attr, X}` per entry. One JSON per cave_id ($6A-$7D = 20 files).

**FrameCounter deterministic seed**: NES $0015 (FrameCounter) increments every NMI. To seed deterministically: BizHawk probe must savestate immediately after cave_init completes (cave_id matched, slot 1 ObjType = cave_id, ObjState[0] = $40), then advance exactly N frames before OAM dump. Both NES and Genesis probes use N=0/6/12 relative to that savestate entry point — not absolute frame count. This eliminates boot-sequence frame variance. Genesis side: hook after `cave_init()` returns, latch a local frame-relative counter, dump SAT at +0/+6/+12 ticks.

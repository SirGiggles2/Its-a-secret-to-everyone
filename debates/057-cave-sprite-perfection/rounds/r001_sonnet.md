# Round 001 — Pragmatic Implementer

## 1. CHR Coverage (atlas gap analysis)

MANIFEST.json blocks: `sprites` (232 tiles, Gen VRAM 512-743), `common` (238 tiles, 936-1173), `demo` (274 tiles, 1174+). No `cave`-specific block. Cave sprite tiles must live in `sprites` or `common`.

Critical unknowns (not guessable — require BizHawk NES OAM probe):
- StandingFire: ObjAnimFrameHeap[8..9] = `$5C/$9E` (NES tile IDs). Atlas block `sprites` covers NES tiles 0-231 at Gen VRAM 512+. Tile $5C = VRAM 512+92 = 604. Tile $9E = VRAM 512+158 = 670. Both in range if `sprites` was extracted from the NES sprite CHR page. Confirm via CHR extract source — `data/chr/sprites.c` must contain pixels at offsets 0x5C*16 and 0x9E*16.
- Cave NPC (old man/merchant/woman/moblin): OBJ_TYPE = cave_id $6A-$7D. k_obj_animations[cave_id+1] indexes the frame heap. E.g. cave_id $6A → anim_idx = $6B (107 dec) → k_obj_animations[107] = `0x55u` (see draw_dispatch.c:87). k_obj_anim_frame_heap[0x55] = `0xACu`. NES tile $AC/2 = tile $56, right tile $57. These must be in sprites block.
- Ware items (slot 19): X from CaveWareXs `$58/$78/$98` (Z_01.asm:385), Y=`$98`. Drawn via draw_cave_items → DrawItemBySlot path, not ObjAnimations — uses k_anim_item_frame_offsets. Tiles depend on specific item id stored in CaveItemIds. All 63 possible item types ($00-$3E) must be in atlas.

**Effort**: 2h — write BizHawk probe that visits cave_id $6A and dumps NES OAM full cycle (16 frames) capturing all tile IDs, then cross-ref against MANIFEST block offsets. **Risk**: HIGH — any tile in `common` not in `sprites` block is invisible on Genesis.

## 2. OAM Byte-Exact (slot order, X/Y, tile, attr)

NES OAM structure for cave scene (Z_01.asm:282-293 SetUpCommonCaveObjects):
- Slot 0: Link (halted, state $40, normal walk-pose frame 6)
- Slot 1: NPC at ($78, $80), OBJ_TYPE = cave_id
- Slot 2/3: StandingFire at ($48/$A8, $80), OBJ_TYPE = $40

Genesis cave_init.c:116-133 matches NES slot layout. cave_draw_person:699 mirrored/not gate at $7B matches Z_01.asm:376-383 `CPY #$7B / BCS :+`.

**KNOWN BUG**: `enrt_update_standing_fire` (enemy_walker_runtime.c:146-154) calls `c_draw_object_not_mirrored_with_frame(0, slot)` — frame hardcoded 0. NES Z_04.asm:257-274 also hardcodes frame 0 via `LDA #$00`. That's correct. BUT: `z07_animate_object_walking` advances the animation counter each frame, which drives the frame heap index. On NES this produces the 2-tile cycle ($5C→$9E). Verify Genesis advances the same counter at the same rate.

**Effort**: 3h — probe NES OAM at frames 0/8/16 in cave $6A, compare slot X/Y/tile/attr bytes against Genesis SAT output at same frames. **Risk**: MEDIUM — Gen SAT slot ordering may differ from NES OAM ordering (link-chain vs sequential scan).

## 3. Palette

cave_palette.c:6-9 — NES subpal 2+3 = `{0F,30,00,12} / {0F,07,0F,17}`. This is BG palette only. NES sprite palette (OAM attr bits 0-1) is independent. StandingFire attr from k_obj_anim_attr_heap[8] = `0x02` (row 2). NES SPR palette row 2 = $3F19-$3F1B.

**MISSING**: Sprite palette row 2 for cave scene (fire colors). Z_06.asm:714 cited in context.md covers BG only. NES fire uses SPR subpal 2, which may not be uploaded by cave_init. NEED: BizHawk PALRAM dump at cave $6A, bytes $3F08-$3F1F (sprite pals 0-3). Compare against Genesis CRAM slots 16-31 (sprite pals).

**Bonfire palette flicker**: Z_04.asm:259 `LDA #$02 / JSR Anim_SetSpriteDescriptorAttributes` — sets fixed row 2 every frame. No per-frame palette modulation. The context.md claim of "bonfire flicker palette" is WRONG per the asm — the NES bonfire does NOT flicker palette. Only the tile index animates (2 frames via AnimateObjectWalking).

**Effort**: 1h — BizHawk PALRAM probe in cave scene. **Risk**: HIGH — if Gen doesn't upload SPR subpal 2 for cave, fire color is wrong every frame.

## 4. Animation Cadence

StandingFire: `z07_animate_object_walking(slot)` → advances OBJ_ANIM_TIMER by `OBJ_DIR`-indexed speed. Dir=$08 (up) → speed from AnimWalkSpeeds table. NES AnimateObjectWalking with DIR=$08 uses rate-10 advance (standard walking). At 60fps, frame toggles at frame 5/10 = 2-frame cycle at ~6Hz.

k_obj_animations[0x41] = k_obj_animations[65] = `0x08u` (draw_dispatch.c:82, counting from 0: line 74 row 0 has indices 0-7, row 75 has 8-15... index 64=`0x08u`, 65=`0x08u`). Heap start = 8. Frame 0 → heap[8]=`$5C`, frame 1 → heap[9]=`$9E`. Two-frame loop. Confirmed byte-exact IF AnimateObjectWalking counter rate matches NES.

**Genesis risk**: `z07_animate_object_walking` is a shim. If the shim uses a different speed table row for DIR=8, frame cadence diverges. Need probe at frames 0/5/10 to confirm tile IDs match.

**Effort**: 2h for bonfire cadence probe. Item animation (ware bob/shine): item tiles use k_anim_item_frame_offsets path, not ObjAnimations. NES items in cave do NOT animate — they are static per Z_01.asm:388-430 DrawCaveItems (no frame advance call). Genesis DrawCaveItems must match.

## 5. State Machine — CavePersonState 0-8

NES UpdateCavePerson_JumpTable (Z_01.asm:359-368) — 9 states:
- 0: TransferPrices (init price display)
- 1: Textbox
- 2: TalkOrShopOrDoorCharge
- 3: CueTransferBlankPersonWares
- 4: DelayThenHide
- 5: HintOrMoneyGame
- 6: CueTransferBlankPersonWares (same as 3)
- 7: Textbox (same as 1)
- 8: DoNothing

Genesis cave_dispatch.c:543 cave_update_cave_person dispatches same 9 states. States 1/3/6/7 = textbox states — sprites unchanged (NPC stays static, bonfires keep animating). State 4 = every-other-frame draw skip (Z_01.asm:305-309). Genesis implements this at cave_dispatch.c:549-561. State 8 = no-op.

**Missing sprite change**: State 2 (TalkOrShopOrDoorCharge) — after purchase, NPC state transitions and items become invisible (ObjY+19 = $F8 or similar). Verify Genesis hides ware sprites on purchase.

**Effort**: 1h audit of state 2-5 ware visibility transitions. **Risk**: MEDIUM.

## 6. Genesis Improvements (without breaking NES feel)

Three viable upgrades, ordered by implementation risk:

**A. No-flicker bonfires** (LOW risk, 2h): NES has 64-sprite limit so cave bonfires can flicker when Link + items push past 8 sprites/scanline. Genesis SAT has 80 slots and no per-scanline limit. Bonfires never flicker on Genesis by default. Zero code change needed — already better.

**B. 16-color sprite palette** (MEDIUM risk, 4h): Genesis SPR palette is 16 colors per line (4 sub-pals × 4 colors). NES SPR palette row 2 is 3 colors + transparent. On Genesis we can give the bonfire its own sub-pal with 15 unique colors — smooth orange-to-white gradient instead of 3-color NES palette. Requires new CRAM upload in cave_init; fire tiles need multi-color copy in VRAM.

**C. 60fps anim interpolation** (LOW-MEDIUM risk, 3h): NES bonfire toggles tile every ~10 frames (6Hz). Genesis can add a third intermediate tile (blended frame) for smoother 20fps toggle. Requires one extra CHR tile per fire frame (CHR budget permitting). Keep 10-frame base so phase still matches NES for any timing-sensitive logic.

## 7. Verification Infra — Long-Term Golden Bundle

**Architecture**: per-cave golden OAM bundle = 20 files (one per cave_id $6A-$7D). Each file: `{frame, slot, Y, tile, attr, X}[N_sprites][16_frames]`. Generated by BizHawk Lua probe in NES Z1, committed to `tools/parity/cave_golden/`.

**Genesis CI probe**: Lua script enters each cave, dumps SAT at frames 0/8/16, normalizes (NES OAM row → Gen SAT slot via slot mapping), byte-diffs vs golden. Fails build if any byte diverges.

**One-time cost**: 4h write probe + 2h generate all 20 golden files. **Ongoing CI cost**: ~30s per build. **Risk**: LOW after golden files exist — regression is caught immediately.

**Step sequence**:
1. Write `tools/parity/cave_golden/gen_nes_cave_oam.lua` — BizHawk NES probe, visits all 20 caves via joypad automation, dumps OAM+PALRAM 16 frames each → JSON.
2. Commit golden JSON files.
3. Write `tools/parity/cave_golden/gen_cave_sat.lua` — BizHawk Genesis probe, same scene coverage → JSON.
4. Write `tools/parity/cave_golden/diff_cave.py` — slot-normalized byte diff, CI exit code.
5. Hook into `Debug.bat` post-build step.

**Effort**: 10h total for full infra. Eliminates all future "56/56 PASS via bypass" ambiguity for cave scenes.

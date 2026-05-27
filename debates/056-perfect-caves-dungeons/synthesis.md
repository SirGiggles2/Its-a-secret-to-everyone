# Final Synthesis (after R3): Byte-exact path locked

## R3 ANSWERED 5 next-layer questions

1. **SAT order**: Matches NES. Both use RollingSpriteIndex@$0341 + sprite_offsets. OAM byte-diff catches reorder. CAVEAT: Genesis static sprites (Link/sword/weapons) use separate VDP_setSpriteFull slot pool, not FIFO. Static + enemy sprites both end in OAM mirror $0200, flushed to SAT in order. Match.

2. **PALETTE**: ONE fixed palette per `cave_palette.c:6` (k_cave_subpal_2_3_nes[8]) sourced from Z_06.asm:714. NES authoritative. Orange NPC/bonfire = sub-pal 3 entry 3 ($17 orange). No per-cave_id dispatch (none in NES either).

3. **ITEMS**: LBA_E (item/price) lives in NES SRAM $6A7E populated at runtime by InitMode2Load. NOT in repo .dat files. MUST probe to know each cave's items. Cave $6A likely 0 items (Old Man only, "secret to everybody"). `draw_animate_item_object` handles all item_ids correctly per existing k_obj_animations.

4. **Q2 INTERIORS**: Q-independent. Z_06.asm:241-246 patches only LevelBlockAttrsB (OW entry routing), NOT LevelBlockAttrsE (cave items). 20 cave scenarios cover both quests. No 40-split.

5. **NES capture STRATEGY**: Force-state via Lua. Cells: GameMode=$0B@$0012, RoomId@$00EB, ObjType+1@$0350=cave_id, ObjX/Y+1@$0071/$0085, PersonState@$00AD=0. Advance 3 frames for InitCaveContinue to populate $0422-$0424 (items) + $0430-$0432 (prices) from SRAM. Verify SRAM valid (nes_ram[$6A7E] != $FF) — if not, OW frame first then force.

# Final Synthesis (after R2): Byte-exact path

## R2 verdict — CODE IS ALREADY NES-AUTHORITATIVE

All 4 voices converge in R2:

- 🟠 **Sonnet**: cave_draw_person at cave_dispatch.c:685 uses `OBJ_TYPE(slot=1) = cave_id` indexing `k_obj_animations[$6B..$7E]`. Exactly mirrors NES Z_01.asm:5011 DrawObjectWithType. **4 sprite-group descriptors + 2 BG layouts** is NES-authoritative (regular cave $6A..$7A → k_cave_layout_regular; shortcut $7B..$7D → k_cave_layout_shortcut at ow_render.c:522-538). NES has NO per-cave_id flat sprite table beyond ObjAnimations grouping.

- 🐙 **Opus** (verified by code read): k_obj_animations[127] at draw_dispatch.c:73 ported verbatim from NES Z_01.asm:1958 ObjAnimations. Per-cave dispatch chain: cave_draw_person → draw_object_mirrored → DRAW_ANIM_INDEX = cave_id+1 → k_obj_animations[cave_id+1] → k_obj_anim_frame_heap[tile_idx] → tile rendered.

- 🔴 **Codex retracted**: "replacing cave_draw_person is probably wrong." Still flags NT/text as needing byte-diff to confirm. Falls back to "byte-diff first, typed CaveLayout only if oracle shows generic NT remains."

- 🟡 **Gemini**: hit quota, no R2 output.

## Resolution

**Sonnet's path wins.** Don't replace dispatch. Don't extract per-cave layout table. Just:

1. Fix structural bugs (CAVE_ID_MAX, s_link_grid_offset)
2. Build NES baseline + byte-diff verifier
3. Iterate per-FAIL class

## FINAL EXECUTION PLAN (6 steps, 13-25h)

### H0 (5 min, zero risk)
**Fix CAVE_ID_MAX off-by-one.**
- Edit `src/game/cave/cave_dispatch.c:71` — `#define CAVE_ID_MAX 0x7Cu` → `0x7Du`
- Update comment line 69
- Rebuild Debug.md
- Verify: cave_7D bundle ObjType1 = $7D (currently $38)

### H1 (2h, medium risk)
**Locate s_link_grid_offset symbol + force-zero in probe.**
- Run `m68k-elf-nm builds/Debug.out | grep grid_offset` to find symbol address (or read build log BSS layout)
- Add `force_grid_offset_zero()` to `probe_one_gen.lua` next to `force_mode_walk()` — same address-write pattern
- Test on dungeon_L1Q1_enter — expect s_scene=UW, s_room_id=$73 (level 1 start_room)

### H2 (30 min, low risk)
**Fix scenarios.json cave_78 ow_room_id.**
- Read `tools/parity/warp_routes_expected.json`, find row where cave_id=$78
- Patch `tools/parity/dungeon_visual_sweep/scenarios.json` line 159 to that ow_room_id

### H3 (4h, low risk)
**Build NES baseline GDMP probe.**
- New `tools/parity/dungeon_visual_sweep/probe_nes_cave.lua` — mirrors probe_one_gen.lua structure for NES core
- Per-scenario joypad scripts to navigate NES Z1 ROM at `C:\Users\Jake Diggity\Documents\GitHub\Legend of Zelda, The (USA).nes`
- GDMP-format bundle per scenario at `C:/tmp/g_sweep/nes_<sid>.bin`: blocks OAM_(256) + PAL_(32) + CIRA(2048) + STAT(32) + INPUT + META + PNG
- New `run_nes_sweep.py` orchestrator (clone of run_sweep.py)

### H4 (6h, high risk — surfaces real divergences)
**Strict byte-diff verifier.**
- Extend `verify_sweep.py` with:
  - `cmp_cram_exact_after_lut(nes_pal, gen_cram)` — EXACT after NES→Gen color LUT (src/game/world/render/cave_palette.c k_cave_subpal_2_3_nes)
  - `cmp_sat_oam_functional(nes_oam, gen_sat)` — normalize 4-byte OAM → 8-byte SAT, EXACT after tile_id translation via `data/chr/MANIFEST.json`, ±1px tolerance on position
  - `cmp_planea_exact_after_lut(nes_ciram, gen_planea)` — tile_id translate, EXACT 32×30 grid
  - `cmp_charstream(nes_ram, gen_ram, $0302..$030F)` — EXACT transfer buffer
- Per-scenario `reports/<sid>/{summary.md, oam_diff.txt, pal_diff.txt, nt_diff.txt, ram_diff.txt}`
- First-failure report: scenario + domain + frame + expected/actual + owning C function

### H5 (variable, depends on # FAILs)
**Per-scenario triage loop.**
```
1. python tools/parity/dungeon_visual_sweep/run_sweep.py --scenario <sid>
2. python tools/parity/dungeon_visual_sweep/verify_sweep.py <sid>
3. Read reports/<sid>/summary.md
4. Pick FIRST failing domain. Don't fix multiple at once.
5. Grep src/game/ for owning function. Patch SMALLEST change.
6. Rebuild Debug.md.
7. Goto 1.
```

**Per-FAIL class:**
- `FAIL_CRAM` → palette LUT mismatch → fix cave_palette.c entry
- `FAIL_SAT` → sprite tile/position → grep sprite descriptor writer
- `FAIL_PLANE` → nametable tile_id → CHR extraction gap → add to MANIFEST.json
- `FAIL_CHARSTREAM` → text bytes → check PersonTextAddrs[] entry
- `FAIL_STATE` → state cell mismatch → trace state writer

**Discipline (Codex)**: "Do not close a scenario from screenshots. Close only when verifier says all required domains pass."

## Total effort

- Structural PASS (scene+STAT match): H0+H1+H2 = 2.5 hr
- Byte-exact PASS (every domain): +H3+H4+H5 = 10-22 hr
- **Grand total: 13-25 wall-clock hours.**

## Files touched

**Edit:**
- `src/game/cave/cave_dispatch.c:71` (CAVE_ID_MAX)
- `tools/parity/dungeon_visual_sweep/probe_one_gen.lua` (force_grid_offset_zero)
- `tools/parity/dungeon_visual_sweep/scenarios.json` line 159
- `tools/parity/dungeon_visual_sweep/verify_sweep.py` (per-domain comparators)
- per-FAIL: smallest owning C function

**New:**
- `tools/parity/dungeon_visual_sweep/probe_nes_cave.lua`
- `tools/parity/dungeon_visual_sweep/run_nes_sweep.py`
- `tools/parity/dungeon_visual_sweep/nes_baselines/*.bin` (56 files)
- `tools/parity/dungeon_visual_sweep/reports/<sid>/*` (56 folders)

**No new RoomRom files** (WT-5 invariant).

## Verification sentinel

Tag when 56/56 byte-exact: `caves-and-dungeons-pixel-perfect-2026-MM-DD`.

Per CLAUDE.md "fail loud": no PASS until every domain byte-equal vs NES.
Per memory `feedback_no_deferrals`: don't punt steps.

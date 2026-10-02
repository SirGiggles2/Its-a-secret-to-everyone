# T-171 handoff: source audit sweep (new direction, user 2026-09-30)

Current ownership and queue: `docs/TRACKER.md` row T-171 (Claude + Codex). This document is handoff context, not a second live board. The original Claude handoff and older evidence below remain historical.

## Latest reviewed work (2026-10-01)

T-178 drop-color repair follows NES item descriptor/flash index $0F, avoiding stale monster hit timers. Manhandla1155/1155 + four screens exact; bomb401/401, both ring192/192 + sprites4/4. Latest frozen ROM2ED27FFB; `T-178_drop_heart_palette.md`. Six Manhandla early extra-frame ticks unchanged before/after, tracked T-172. Next Codex T-177 harness completion/immutable identity; Claude retains broader T-172.

Latest review now through `a5d6190d`: Claude flute/whirlwind/pond and bait/potion changes landed; Codex Patra optimization committed by Claude as `71fc7a50`, then Claude finished palette-3 item-copy and UW load budgets. Independent final Patra 1533/1533 and OW 2187/2187 GATE plus LAG PASS; eight Patra screens exact on frozen ROM DDA0092E. See `T-172_patra_budget.md`. T-176 filled seven missing Patra room inputs (Original 349/349); Patra timer repair `93bc570c` is accepted at staged red-fight scope, not blue variant/re-entry/SRAM/connected L9. The previous performance failures below are historical. T-172 stays open for broader headroom/pause/continue; T-177 harness completion/identity and T-178 drop-heart colors are in the sole live tracker.

Claude commits `3b2416f2..4e287baa` add staged L1–L4 boss fights and repair Link shove-facing, Manhandla survival/count/timer, and Gleeok death/head animation/invincibility. Claude reports 73/73 before the following focused Windows changes; do not apply that full-suite claim to a later ROM.

- `74c101cc`: explicit heart helper call-before-scratch-read ordering. Dodongo pickup 1150/1150 plus fairy refill 1364/1364, unchanged baselines, four Dodongo screens exact. See `T-171_heart_helper_order.md`.
- `60c59fd8`: Digdogger renderer now follows resident CHR bank after split; final draw survives cleared parent type. Staged L5 flute/child fight/heart pickup/north departure 1454/1454; split/child/reward/departure screens exact, early sprite-overlap differences accepted at their documented scope. Named Aquamentus 1300/1300 and Gleeok 1474/1474 consumers plus final screens PASS. See `T-171_digdogger_flute.md`.
- T-174: explicit reward roles add 11 missing Original Triforce rooms; Gohma arrow rejection/open-eye kill/reward/departure 1087/1087, Q2 L8 reward entry 480/480 and destination screens PASS. Sparse BG atlas 677; reservation guard and freshness 9/9 PASS. See `T-174_reward_room_coverage.md`. T-175 subsequently fixes blue pause ring grade palette with existing item helper: both grades RAM 192/192, sprites 4/4, opaque colors 39/39 exact; see `T-175_pause_ring_palette.md`. Red-grade T-121 remains valid.
- The Windows ROM includes existing Claude flute/whirlwind WIP. Those unrelated uncommitted files remain preserved. Latest exact build identity and active task are in the tracker; no connected quest, three-child Digdogger, or SRAM acceptance follows from these staged fights.

## Codex progress after handoff (2026-09-30)

- Q1 L3–L9 entry presets added; 7/7 gated PASS, 480/480 KEY frames each.
  See `docs/audit/T-171_level_entry_coverage.md`.
- Q1 boss idle probes added for L1–L9, now 9/9 gated PASS. Initial L4/L8
  `$56` shot failures and L6/L9 non-KEY cells were fixed against NES source.
  The probes do not yet establish combat, rewards or departure.
- L5 room `$24` exposed absent statue fireballs. NES `UpdateStatues` was
  drained but not called by the linked underworld play tail. Promoted it;
  L5 KEY 750/750, tick-350 NES/Genesis room and shot frames checked.
  See `docs/audit/T-171_boss_probe_sweep.md`.
- Windows `Debug.bat` PASS; full gated suite 67/67 PASS. Current local
  `builds/Debug.md` SHA-256:
  `453E489908A2F1B635EA4FB3250BD4F6C309A487D7B41625FE886129A4809A17`.
  The full 67/67 run preceded the Gleeok sprite-order correction; the
  intervening ROM passed Q1 L1–L9 boss idle gates 9/9. The current ROM
  passed all 11 route baselines affected by the dungeon-entrance repair.
- Gleeok fireball was mostly hidden by its neck despite matching RAM.
  NES OAM put shot slot 28 ahead of neck slots 29..55; Genesis put the
  native shot last. Boss SAT now emits native fireballs first. L4 live
  tick-350 screen shows the red/orange shot; see boss sweep audit.
- NES `HandleWarpOW` `$0065` raw entrance tile now mirrored at the owning
  OW→dungeon transition. Eleven affected baselines were refreshed after
  passing; `$0065` left the queue. See `docs/audit/T-171_warp_tile_followup.md`.
- Mismatch report now has 26 open / 13 accepted across 67 baselines.
  Next: `$049E` collision scratch, interactive boss attack/vulnerability/
  reward/departure routes, then other Quest 1 systems.

## The new direction (user, verbatim intent)

- Stop doing one-bug-at-a-time from user reports. **Audit the port against
  the NES source and fix everything** in one sweep.
- **Rules:**
  1. NES-exact function is the spec: gameplay, RAM logic, timing that a
     player can feel.
  2. **If the Genesis runs BETTER, that is GOOD — keep it.** (no slowdown,
     no flicker, faster loads, native pause menu.) "The Genesis can run
     better!"
  3. **If it runs WORSE or plays DIFFERENTLY: fix it.**
  4. Don't touch systems already proven working (gate suite).
  5. Intentional Genesis differences stay (title/file select, faster
     loads, VBlank palettes, no sprite flicker, T-165 pause menu is judged
     on function not NES memory).
- Memory: `feedback_faster_is_fine.md` (2026-09-30 sweep rule).

## Method (works; keep using it)

The lockstep harness already finds the mismatches. Don't read 10k lines by
eye; mine the evidence:

1. **Queue = accepted baseline cells.** Every
   `tools/lockstep/baselines/<preset>.json` lists non-KEY RAM cells that
   differ from the NES and the first tick they do. Pool them:
   `python tools/audit/baseline_mismatch_report.py --md docs/audit/baseline_mismatch.md`
   -> "Open" (bug candidates) and "Accepted" (registry `ACCEPTED` /
   `ACCEPTED_ONSETS` in that script, each with a reason). Never accept a
   cell without a written reason.
2. For one open cell: find the onset tick, then per-frame trace both sides:
   `python tools/lockstep/run_lockstep.py tools/lockstep/presets/<p>.json --full --frame-dump`
   and read `<plat>.fram` (2 KB per video frame) + `<plat>.frtick`
   (big-endian u16 tick per frame). Small helpers used:
   `build/scratch/onset.py <preset> <slot> <tick>` (per-tick slot view),
   `build/scratch/triage_slots.py` (slot-array cells: live slot vs dead
   slot).
3. Read the NES routine in `reference/aldonunez/*.asm`, find the Genesis
   code, fix to NES order. RULE ZERO: probe, byte-diff, then code.
4. Build `cmd /c .\Debug.bat` (PowerShell), then
   `python tools/lockstep/run_suite.py <tag>` must stay 51/51; the
   `improved=` total says how many cells now match.
5. Re-bless all baselines after a batch (tightens the ratchet so fixes
   can't regress):
   `python -c "import glob,os;print('\n'.join(os.path.basename(f)[:-5] for f in glob.glob('tools/lockstep/baselines/*.json')))" > build/scratch/bless_list.txt`
   then `xargs -P 8` over `run_lockstep.py ... --full --bless` (see the
   T-171 commits). Regenerate the report, commit.
6. Object dispatch audit: `python tools/audit/object_dispatch_map.py`
   (every NES object type -> Genesis handler; only `$5E` flute secret and
   `$61` dock are unwired = T-055 / T-056).

## Done in this sweep (commits on main)

`87abcb1c` T-169 L1 block sprite. `9af13cdd`, `caee270b`, `5070cb3c`,
`f7244f4a`, `4dc69650` T-171. Open cells 92 -> 27; ~600 RAM cells now
match the NES that did not; suite 51/51 throughout.

- Staged level warp: any level via `CurLevel` + GameMode 2 (generic
  `mode2_init_tick`), preset `t171_warp_l2` (L2, KEY 480/480). Use this to
  build L2-L9 routes and boss presets (T-014..T-022, T-040).
- Link: InitMode5Play animate; Link_EndMoveAndDraw reaches AnimateLinkBase
  (`roomrom_combat_animate_link_base`); cave exit undoes the whole move.
- Rooms: every room entry is a real InitMode_EnterRoom (maze loops, cave
  exit, continue); level loads defer objects to mode 4; ObjTimer kept on
  entry; tile-object init `$5F-$69`; OW door/next-room bookkeeping;
  HandleWarpOW tile; @LoadLevel level/target at the stairs.
- Enemies: Red Leever surfacing, cloud-end animate+collide,
  EmptyMonsterSlot, HP table byte for `$68/$69`, push timer in NES cell.
- Caves: IsUpdatingMode / UndergroundExitType / ObjInputDir per NES.
- Save: NES pointer scratch end state in `$C0-$CF`.

## Progress log after the handoff (Claude kept going, user 2026-09-30)

- HandleWarpOW record is one helper (`record_warp_tile_ow`, main.c): NES
  gate, runs on the play tick AND on the InitMode5Play tick after a scroll
  (t111 t32, t054 t668), restores ObjCollidedTile `$49E` like @CheckWarps
  (Genesis left the stood-on tile there every tick; that cell hid in the
  tick-0 bucket).
- Cave exit tick: no Link_EndMoveAndAnimate after CheckCaveEdge
  (`s_lvl_phase != LVL_CAVE_EXIT` gate) (t134 t443).
- cave_fade: Link's stairs/walk-in animation now runs NES AnimateLinkBase
  on `$3D0/$3E4` (`animate_link_nes`), no fixed seeds; InitMode10 frame
  and the settle frame do not animate; Sub8 first frame counter 4. t012
  descent 72/72 frame states equal (was off by one from t140).

- 2026-10-01 Claude (resumed after reviewing Codex 5bcf08a4..ec053496;
  committed Codex's transition.c `$49E` WIP as 2d19819a, suite 67/67).
- Dungeon room exit lagged 2 frames on Genesis (t131_uw_ndoor/t114 tick
  1056/1044 `$03E4` "mismatch"): the per-tick RAM sample landed mid-tick.
  `--pc-profile` showed `roomrom_uw_room_render_set_live_door_priority`
  doing 704 uncached VRAM reads on the destination rows, which NES-scroll
  mode hasn't drawn yet. Skipped in NES-scroll mode. Edge tick now one
  frame, animates like NES; whole room change 141 frames vs NES 142.
- METHOD NOTE: a per-tick mismatch that "heals" next tick may be Genesis
  LAG, not logic. Check `<plat>.fram` FrameCounter ($15) per frame: a
  repeated FC on Genesis where NES advances = lag frame = "runs worse",
  fix the cost (`run_lockstep --pc-profile F0:F1` + `pc_profile.py
  <dir>/gen.pcprof`).

- LAG is part of the sweep (runs worse = fix): `tools/lockstep/lag_scan.py`
  compares video frames per game tick NES vs Genesis over `--frame-dump`
  runs. Found: OW room $38 at 100% CPU (now 0 overruns; margin thin), level
  load +3 frames, pause open +3, continue +5. Tracked as T-172.

- 2026-10-01: GAMEPLAY BUG fixed: Genesis left CurObjIndex ($340) at the
  object loop's last slot; NES sets $0B after the loop (and at
  InitMode_EnterRoom). CheckHasLivingMonsters scans CurObjIndex+1..1, so
  Genesis declared rooms with live monsters clear (L1 room $52: shutter
  trigger + door command fired with 3 keese alive, t013_route t5413).
  CheckUnderworldSecrets now UW-only like NES @CheckUW (RoomAllDead
  counted up in the OW). Dungeon door exit writes InitMode7_Sub1 /
  EndGameMode12 cells (t132 t911). These hid in the tick-0 bucket of the
  report: also scan cells that differ from boot when a value looks wrong.

- 2026-10-01 RAM QUEUE EMPTY: baseline report 0 open / 13 accepted, and
  `tools/audit/rediverge_scan.py` (cells that match then split again,
  which the first-tick baselines file under boot state) 0 cells, over all
  67 gated presets. Last fixes: NES DestroyMonster everywhere, UET 2 on
  every level exit, StatusBarMapTrigger consumed, ShootLimited $59, Link
  q-speed in the NES cell. NEXT (no RAM evidence left in these presets):
  (1) visual byte-diff sweep (`tools/lockstep/screen_diff.py` at sampled
  ticks of every preset: RAM can match while pixels differ, e.g. T-170),
  (2) coverage: interactive L2-L9 routes and boss fights (Codex's idle boss
  presets), (3) T-097 death mode stubs, Wallmaster grab, (4) T-172 lag.

- 2026-10-01 VISUAL SWEEP (`tools/lockstep/screen_sweep.py --md
  docs/audit/screen_sweep.md`: settled play ticks, per-pixel CRAM diff).
  T-097 death mode done (ccd3fd3b). Ring tunic fixed: the room palette
  loaded in `roomrom_debug_enter` before the save set InvRing, and the
  captured palettes all carry green `$29`. Now: `$3F11` comes from the
  level palette byte `$6B92` (`roomrom_bg_palette_load_palram_full`),
  which `room_patch_level_palette_link_color` (InitMode3_Sub1 patch half,
  LinkColors[InvRing] into the slot's menu row) sets after every LevelInfo
  install and after the File Select / debug-unlock profile load
  (`a4_probe_main.c`). t121_ring1/ring2/q2_ow 95 px -> MATCH.
- Boss rooms: InitMode5Play row-7 cues (SpecialBossPaletteObjTypes) +
  drain buffers $06/$08/$0A/$20/$22/$24/$36/$7A/$7C; UW attributes from
  LevelBlockAttrsA/B like FillPlayAreaAttrs (blob wrong in 4/331 rooms);
  Gleeok body table 18 bytes; boss OAM sweep reads slots 0-15 (heads);
  boss PAL2 override removed; Manhandla / little Digdogger pass the frame;
  InitMode3 leaves a dark room lit. All boss screens MATCH or overlap-only.
- T-170 done: sub-palette 3 pair cache (VRAM 1125..1188) for all sprites.
- MEMORY BUG: SGDK boot VDP_loadFont overruns its heap buffer below
  $FF8000; with more .bss it spills into NES RAM. Any .bss growth could
  change gameplay. a4_probe_main.c now clears NES RAM and cuts the heap at
  $FF7FFE. Tool: `run_lockstep --write-watch FF7FFE` (writer PC + stack).
- screen_diff: NES PPUMASK grayscale (bomb flash) modelled; OVERLAP line
  counts diff pixels under >= 2 NES sprites (OAM rotation, accepted).
- HUD: status-bar map waits for selector $44 like the NES; map dot moves
  at InitMode_EnterRoom from RoomId; a taken room item stays drawn that
  frame. UW name-table writes keep the room attribute palette.
- Sweep now: 29/408 screens differ, all overlap-order or t129 staging
  artifacts (staged-away Like-Like left over-Link OAM; Gohma staged into
  L1 without a boss bank). NEXT: compare scroll/transition frames
  (`--vframes`), interactive L2-L9 + boss fights, Wallmaster grab stub,
  T-172 headroom (room $38 worst tick line $DE).

- 2026-10-01 T-057 (ce44c1cf): food bait (WieldFood + food branch of
  UpdateBoomerangOrFood, monsters chase it), potion on B (Paused 2 heart
  fill), Grumble Link animation + single Link draw, Goriya boomerang
  palette. Presets t057_food_bait / food_leave / grumble / potion; see
  `docs/audit/drain_findings/t057-food-potion-grumble.md`. Parallel work
  with Codex live in main: build in a separate worktree, then apply the
  patch to main's index only (`git apply --cached` + `git apply`).

## Original open queue at handoff (historical; now empty)

Work top-down. Each line = cell, presets@first tick, what is known.

1. `$0065` UndergroundEntranceTile — t111/t123@32, t054/t114@668. HandleWarpOW
   gate now exact for the stand-still case; remaining onsets are other
   CheckWarps paths (UW? after scroll) — trace.
2. `$03D0/$03E4` Link anim — t134@443/t011@709 (cave exit mode A frames:
   check after the 4dc69650 fix, rows may be gone after re-bless),
   t012/t013@140 (`$03E4`, early OW), t114@1044, t131_ndoor@1056 (UW).
3. `$005A/$00EE/$00EC/$0521` — t132_uw_exit@911: dungeon -> OW exit path
   (level exit = mode $12/2/3 + LVL_STEP_OUT). Door/next-room/UET cells on
   the UW->OW exit.
4. t013_route@5413: `$0027` DoorTimer, `$0054` TriggeredDoorCmd, `$04CE`
   ShutterTrigger — L1 shutter door open sequence (link_doorway.c /
   door_state.c vs NES).
5. t013_route dead-slot shove/metastate (`$C1-$C5`, `$D4-$D8`,
   `$406-$40A` @4620/6734/6773/7467): live=0 per triage (dead slots after a
   kill). Check NES leaves values Genesis zeroes on death; usually harmless
   but verify the slot is re-initialized before reuse.
6. `$0052` ProcessedNarrowObj (t121@106, t013@4111), `$04E5`
   StatusBarMapTrigger (t013@6987), `$03BC` Moldorm bounce (t111@1108),
   `$042D` Gleeok head (t129@6400), `$0059` (t129@4829: another shooter
   path without FindEmptyMonsterSlot — grep `ENEMY_TYPE(y) == 0u` loops).

## Not covered by RAM baselines (also part of the sweep)

- Known unfinished code: `src/game/world/mode_death.c` 4 stubs (T-097,
  death -> continue, Quest-1 critical); Wallmaster grab
  `wm_link_end_move_and_animate_bank4_stub` in
  `src/game/enemies/enemy_special_bridge.c` (needs a Wallmaster-room
  preset; use `roomrom_combat_animate_link_base` / end_move_and_animate).
- T-170: sprites on NES sub-palette 3 (gels) drawn with sub-palette 1
  colors (VRAM budget decision).
- Coverage gap: presets only exercise OW, L1 and caves. Use the
  `t171_warp_l2` staging pattern (`wr(0x10,N) wr(0x11,0) wr(0x12,2)
  wr(0x13,0)`) to add one preset per level L2-L9 + each boss room, bless,
  then mine those baselines the same way. That is where most remaining
  Quest-1 bugs will be.

## Gotchas

- Build only via PowerShell `cmd /c .\Debug.bat`. Editing
  `RoomRom/src/roomrom_vram_map.h` needs
  `python tools/atlas/gen_sprite_catalog.py` +
  `python tools/probes/check_generated_freshness.py --gen --only sprite_catalog`.
- rtk hook mangles `grep`/`ls` output: use `rtk proxy grep` or python.
  Don't pipe `ls` into xargs (size tokens).
- Lua probes need review before running (RULE V2).
- `ObjPushTimer` slot 11 (`$41D`) is shared by the UW block and OW
  rocks/armos: only touch it while slot 11 is the block (`$68`).
- Genesis file select is custom: lockstep can't run through it; use
  `--nes-only` probes for NES behavior past mode 0.

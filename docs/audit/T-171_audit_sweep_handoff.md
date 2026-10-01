# T-171 handoff: source audit sweep (new direction, user 2026-09-30)

Current owner: Codex. Live task state and newest evidence: `docs/TRACKER.md`
row T-171. Original Claude handoff below is historical context.

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
  `2FF4A959444BB28F9196B476AD6721260D7F6DE2749C7759BDE80EADCE54CE46`.
  The full 67/67 run preceded the Gleeok sprite-order correction; the
  current ROM passed the affected Q1 L1–L9 boss idle gates 9/9.
- Gleeok fireball was mostly hidden by its neck despite matching RAM.
  NES OAM put shot slot 28 ahead of neck slots 29..55; Genesis put the
  native shot last. Boss SAT now emits native fireballs first. L4 live
  tick-350 screen shows the red/orange shot; see boss sweep audit.
- Mismatch report remains 27 open / 13 accepted across 67 baselines.
  Next: interactive boss attack/vulnerability/reward/departure routes,
  then remaining open RAM-cell queue and other Quest 1 systems.

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

## Open queue (from docs/audit/baseline_mismatch.md, 27 cells)

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

# TRACKER — single source of truth for who is doing what

Read this file first, every session. Everything else (`docs/plans/*`, Prime Directive status,
completion JSON) is history or evidence, not the work queue.

## 60-second protocol (both agents)

1. `git log --oneline -5` and read **Current state** + the last 3 **Handoff log** entries.
2. Pick the top `TODO` task you can do (see **Agents**). Set it `ACTIVE`, put your name in Owner,
   list the files you will touch in Scope. Commit that one-line change: `[T-###] claim`.
3. Work only inside your Scope. Need a file in someone else's Scope? Log it and wait or pick another task.
4. Finish = acceptance met with evidence. Commit code + evidence path + board row + one handoff
   entry together: `[T-###] <what>`. Status `DONE` (or `REVIEW` if the other agent must verify).
5. Stopping mid-task: commit WIP as `[T-###] wip: <state>`, handoff entry says exactly where you stopped.
   **Never end a session with uncommitted work.** (13 days of work sat uncommitted once; a stale
   `.git/index.lock` from 2026-09-14 blocked every commit and nobody noticed.)

Rules: one ACTIVE task per agent. New work found mid-task becomes a new `TODO` row, not scope creep.
Evidence rules, NES-first capture rules and task IDs `P#.#` from `docs/plans/2026-09-10-project-completion.md`
and `CLAUDE.md` still apply. Handoff entries: newest on top, max 5 lines, facts only.

## Agents

| Agent | Runs on | Can | Cannot |
|---|---|---|---|
| **Astra** | Windows host | `Debug.bat`, BizHawk NES+GPGX probes, live captures, play builds | — |
| **Claude (Cowork)** | Linux VM on the same folder via bridge | Code edits, Python generators/extractors, ROM data analysis, host-gcc syntax + symbol check (`tools/audit/host_link_check.py`), git, reviews, tracker upkeep | `Debug.bat` / BizHawk (Windows toolchain) unless given computer use |

Git from the VM: `git -c core.checkStat=minimal -c core.trustctime=false -c core.autocrlf=input …`
(index stat info is Windows-written; without these, status re-hashes every file).

## Current state

- **Branch:** `main` (local; not pushed). `main` = recovery work (Sep 11–24) + merged `feat/cave-entry-transition-parity` (Aug).
  Old main preserved at `codex/recovery-baseline-20260911-074018` (= f513b997).
- **Last verified ROM:** `f3a38e2b…` merged tree (T-001, `builds/reports/recovery/t001-merged/result.json`). Claude now runs on the Windows host: builds + BizHawk.
- **Generated data:** freshness 8/8 OK. UW blob 649 rooms. Room generator reproduces 330/331 original rooms byte-exact; only L9Q1 `$42` (Ganon) differs → T-004.
- **Music:** deferred to last by user direction.

## Board

Status: `TODO` · `ACTIVE` · `BLOCKED` · `REVIEW` · `DONE`. Plan ref = task ID in the 2026-09-10 plan.

### S0 — Consolidate (blocks everything)

| ID | Task | Plan ref | Status | Owner | Scope | Acceptance / evidence |
|---|---|---|---|---|---|---|
| T-001 | Build + boot the merged tree | P0.2 | DONE | Claude (Windows host) | build only | `Debug.bat` clean; regression matrix GREEN 12/12; Ganon→Zelda `reward.lua` passes; Aquamentus consumer passes; File Select→New Game; save survives hard reset (`probe_save_persistence.lua`). Record ROM SHA here. Any failure → new T row, fix before S1 |
| T-002 | Quest 2 LevelInfo patch (was missing from the active install path) | P0.12 | REVIEW | Claude → Astra | done | **Found:** `level_info_install_uw` ignored quest, so every Q2 dungeon ran with Q1 LevelInfo from $6BA7 on (start room, map, triforce, cellars, boss room, map mask). **Fixed:** `level_info_apply_q2_patch` (NES `UpdateMode2Load_Full`, Sizes+1 bytes) from the ROM-extracted blob; `room_dispatch` Q2 branch uses it, hardcoded tables deleted. **Offline evidence:** `python tools/audit/test_q2_levelinfo.py` → 18/18 byte-exact vs ROM pointers (Python mirror of the C). **Astra:** after T-001, boot Q2 (X+Y+Z), enter L1: start room $77, pause map matches NES |
| T-003 | World-flag regions (`$067F` OW, `$06FF` L1–6, `$077F` L7–9) | P7.2 / P5.4 | REVIEW | Claude → Astra | `level_info_install.c`, `save_game.c`, `save_serializer.c` | Code: new game zeroes all three, SRAM save/load keeps all three. Runtime (Astra): kill Digdogger + Patra, leave, re-enter → no respawn; OW secret still open after a dungeon **Claude 2026-09-24:** save/load of all three regions done in T-100 (world flags `$67F–$7FE` = OW `$67F`, L1–6 `$6FF`, L7–9 `$77F`; round trip byte-exact). New-game zeroing for an empty slot rides on T-092. Runtime Digdogger/Patra revisit still open |
| T-004 | Room generator: Ganon room `$42` | P0.14 | TODO | Claude | `tools/builder/gen_uw_room_tiles.py` | Generator output for L9Q1 `$42` byte-equal to the live capture in `uw_room_blob.c` (240 NT bytes differ today). Then 331/331 → builder no longer needs live captures |
| T-005 | Triforce/pause tint after palette LUT change | P7.1a | TODO | Astra | `tools/extract_misc.py` | Aug CRAM overrides `$17/$36/$37` were dropped for the Sep NES-reference LUT. Byte-compare triforce + L1 pause palette vs NES; fix in generator if wrong |
| T-007 | Q2 overworld LevelBlock patch in active path | P9.2 | DONE | Claude | `level_info_install.c` | `level_info_install_ow` ignores quest; NES `@PatchQ2Rooms` (8 AttrsB bytes + 7 fixed writes) only exists in unlinked `room_dispatch` path. Apply on OW install for Q2; offline byte test like T-002. **Done:** `level_info_apply_q2_ow_patch` (ROM tables from blob `$1920/$1928`, 7 NES immediates) on the active OW install when quest=2; room_dispatch hardcoded copy removed. `tools/audit/test_q2_ow_patch.py` PASS (tables + immediates == ROM code at PRG `$1813B`). Runtime: lockstep `q2_ow` OW LevelBlock 768 + LevelInfo 256 bytes = 0 diffs vs NES Q2 (NES Q1↔Q2 differ in 13 cells, so the check discriminates) |
| T-006 | Retire competing trackers | — | DONE | Claude | `.claude/skills/primedirective`, `docs/superpowers/prime_directive_*` | PD skill reads `docs/TRACKER.md` for next action; its Phase 8 "next action" pointer no longer claims authority |

### S0b — Ship-path hygiene (finish plan Phase 1)

| ID | Task | Status | Owner | Acceptance |
|---|---|---|---|---|
| T-090 | Runtime `debug_session` gate: set only by title A+B+C / X+Y+Z chord; all gameplay debug inputs (X/Y/MODE/C/Z+START/B+Z+C/A+B+C+START in `RoomRom/src/main.c`) require it | DONE | Claude | `builds/reports/recovery/t092-newgame-hud/SUMMARY.md`; acceptance: FS New Game: every debug input inert (RAM trace) |
| T-091 | Boot probes (options/persistence/serializer/warp/roundtrip/metadata) run only when armed; none write SRAM on normal boot | DONE | Claude | **Was corrupting play:** `save_serializer_probe_run` left `$30..$57` in Items `$0657..$067E` on every New Game (write-watch PCs → symbols). Gated on `ROOMROM_DEBUG_PROBE_SELFTEST $08`. After: 0 probe writes on FS New Game, entry 229 frames sooner; armed self-tests 5/5, 22/22, 10/10, 34/34, 8/8, warp 0/128, roundtrip 0/18 (`builds/reports/recovery/t091-selftest-gate/`) |
| T-092 | NES new-game init on FS path: no seeded sword, keys 0, no default B-item, NES start facing; B-item only via pause | DONE | Claude | `builds/reports/recovery/t092-newgame-hud/SUMMARY.md`: newgame Items block $656-$67F = NES; HUD A/B boxes exact vs NES OAM (sword 0-3, boomerang); item atlas table regenerated (42/76 were wrong) |
| T-121 | Verify ring item tile ($76/$77) atlas mapping against a live NES capture with the ring drawn (pause screen) | TODO | | verify_sprites.py exact on a ring-owned pause capture |
| T-094 | Music driver state at fixed `$FFE000/$FFE100` = `nes_ram[$6000/$6100]` (NES SaveRAM) under A4 `$FF8000`: save wrote `$5A/$A5` into `m_song/m_song_req` | DONE | Claude | `builds/reports/recovery/t094-music-sram/`: before = overlap, after = save image stable + music state at linker symbol `$FF00EC`; save persistence 7/7 |
| T-101 | FrameCounter/Random/StunCycle parity | DONE | Claude | Not a game bug: Genesis starts them at gameplay entry (custom title/FS). Harness now syncs on first live tick and copies NES `$15/$18-$24/$26` at sync; then 266/266 frames byte-equal → per-frame port verified |
| T-102 | Play-tick order: Genesis ran weapons+enemies BEFORE Link moved (NES `UpdateMode5Play`: UpdatePlayer → chase target → weapons → objects) | DONE | Claude | `builds/reports/recovery/t102-tick-order/SUMMARY.md`: Link X/Y/Dir/State/AnimCounter/Frame/Grid equal to NES same frame in 25/29 presets (rest = enemy-contact RNG + t114 staging), compensations removed, weapons 0 diffs, OW-scroll Link animation per NES submodes |
| T-103 | Link turn between grid points (`Link_ModifyDirOnGridLine`): opposite input reverses now; perpendicular <4px reverses to grid point with mirrored offset | DONE | Claude | Lockstep `newgame` f189: GEN now steps right 1px to `$38` then up (was 7px left to `$30`), identical to NES |
| T-104 | OW collision sampler used HUD origin `$38` + one column; NES `GetCollidableTile` = origin `$40`, two columns vertical | DONE | Claude | OW now uses shared NES sampler. Lockstep `newgame`: GEN stops at Y `$5D` on tile `$DE` like NES (was walking to `$55`) |
| T-105 | OW room scroll: trigger Y `$39` vs NES `$3D`; GEN stays GameMode `$05` (NES `$07`); ~32 vs ~80 frames; arrival Y `$CD` vs NES `$DD`; grid offset not re-phased → Link off-grid after every vertical change (walks through walls after) | DONE | Astra (landed by Claude) | **Finding for Astra (Claude, lockstep `tektite_jump`, build without your WIP):** during Genesis horizontal scroll FrameCounter `$15`/Random/timers freeze (12 frames no tick from f121) while NES keeps ticking in modes 6/7 → RNG desync after every room change. Scope: `src/game/world/ow_scroll.*`, required scroll call-site glue in `RoomRom/src/main.c`, `tools/debug/build_debug.py`, focused `tools/lockstep/` verification, `docs/audit/drain_findings/t105-scroll.md`, task evidence.  Lockstep `ow_walk` equal through room `$77`→`$67` and after |
| T-106 | User report: "enemy half stuck in HUD top-left" = minimap position marker. It used VRAM `SPR_TILE_BASE+$3E` (tile `$2BC`), inside the SCENE_OBJ overlay (`SPR+44`, 136 tiles), so OW enemy CHR replaced the NES `$3E/$3F` dot | DONE | Claude | Marker pair uploaded from ROM-extracted `common_chr` to protected tiles 1312–1313 (VRAM budget gate registers it). Lockstep `hud_marker`: GEN tile pixels == NES `$3E/$3F`, same X/Y/size; before/after in `builds/reports/recovery/t106-hud-marker/`. Built in an isolated worktree so Astra's T-105 WIP was not built |
| T-108 | Tektite (`$0D/$0E`) jump: horizontal pick used Link X with inverted test (NES: ChaseTargetX, right when >=); `Jumper_MoveY` clamp missed `Jumper_ResetVSpeedFrac` (descent 3,2,3 vs NES 2,2,2) | DONE | Claude | Lockstep `tektite_jump` (staged: Tektite under each console's chase target, fractions zeroed): takeoff/arc/landing/X identical f381–404. Post-landing wait differs only because RNG already desynced at scroll (see T-105) |
| T-107 | NES chase decoy (`$4A/$60–$62`, Z_07:1879–1915) | DONE | Claude | Not missing: `enemy_loop_tick` port matches NES line-for-line. Divergence was start phase: NES spends first Mode 5 frame in InitMode (no chase update), Genesis toggles on its first tick with unseeded RNG → flag inverted all run. Harness now seeds `$4A/$60–$62`; `newgame` then equal f0–131, rest = T-102 1-frame Link lag. Real fix for the init frame → T-095 |
| T-109 | Debug sentinels written into NES `$07E0–$07FF` (= WorldFlags L7–9 `$077F–$07FE`) every frame (joypad, Link X/Y/room, markers) → L7–9 room flags + saves corrupted | DONE | Claude | Moved to linker-owned `g_debug_sentinel[32]` (`DBG_SENTINEL(i)`, i = old addr − `$07E0`); 4 probes read via `@SYM:g_debug_sentinel@`. Found by `save_roundtrip` (9 byte diffs → 0). `main.c` change committed through an index-only patch; Astra's T-105 WIP untouched |
| T-093 | Macro redefinitions (were 65 warnings) | DONE | Claude | 0 redefinitions, 27 warnings total. Real bugs found: (1) `enemy_state.h` `LINK_X/Y`=ChaseTarget `$61/$62` vs `world_state.h` `LINK_X/Y`=ObjX `$70/$84`; first include won per file. Renamed enemy alias to `CHASE_TARGET_X/Y` (NES meaning; per-file audit `tools/audit/macro_audit.py` shows all prior `$61` users unchanged). (2) `room_load_runtime.c` redefined `CUR_LEVEL` to the address `$10` mid-file, so Mode 2 loaders read level=16 (unlinked today, T-099 will wire them). `OBJ_STATE`/`NES_OBJ_INV_TIMER_BASE` single-owner; SGDK `RAM` constant `#undef` (unused). `builds/reports/recovery/t093-macros/` |
| T-110 | Bombs / candle fire were Genesis-only objects (60-frame fuse, 48 px fire) never written to NES slots `$10/$11` → bombs/fire could not hurt enemies or trigger secrets. Port WieldBomb/UpdateBomb/DrawClouds/UpdateBombFlashEffect, WieldCandle/UpdateFire into NES slots; sprites via enemy_render weapon cache; PPUMASK grayscale consumer | DONE | Claude | `builds/reports/recovery/t110-bomb-fire/SUMMARY.md`: slot RAM identical vs NES over 240/200 ticks except T-102 one-tick input/Link-order cells (3); enemy kill identical; SAT == NES OAM for bomb/clouds/fire; tile pixels byte-match; grayscale CRAM 29/30 (miss = pre-existing sub-pal 3). UW bombable wall unverified → T-114 |
| T-111 | UW dark rooms: NES darkens by palette (FadeCycle/AnimateWorldFading) and the candle brightens via UpdateCandle/CandleState; Genesis darkened the plane and relit instantly on any candle press | DONE | Claude | `builds/reports/recovery/t111-dark-rooms/SUMMARY.md`: lockstep t111_dark_candle (L5 $76 -> dark $66, candle): fade/candle cells equal per frame, BG palette 16/16 in light, dark and relit states, plane 704/704 |
| T-126 | OW mazes (Lost Hills $1B, Lost Woods $61) not run: Genesis scrolled straight to the next room | DONE | Claude | CheckMazes on every OW crossing; t111_dark_candle room sequence equal ($1B x3 loop, $0B on 4th Up) |
| T-127 | (user 2026-09-26) Sword swing plays the beam sound. Genesis SFX layer is ad hoc: no consumer for SampleRequest $0601 / EffectRequest $0603 / Tune0 $0604 / Tune1 $0602; placeholder DMC samples (boss roars) used for enemy hit/death, item pickup, key, parry, arrow, boomerang | DONE | Claude | Every NES request cell consumed like Z_00 DriveSample/DriveEffect/DriveTune0/1: noise effects and square tunes rendered from the Z_00 tables; per-event request trace vs NES — `builds/reports/recovery/t127-sfx/SUMMARY.md` |
| T-128 | (user) UW collision: Link can partly walk onto unwalkable bricks/blocks | DONE | Claude | Two causes: every gameplay sprite drew 7 rows below NES (Genesis frame = NES frame minus its top 8 lines; sprite Y must be OAM Y - 7, like the pause screen), so Link overlapped the brick row below; walkability now NES GetCollidingTileMoving vs $34A. `t128_uw_blocks` ($74): Link stops at X $30 against the block like NES; static Link framebuffer 0 px vs NES. `builds/reports/recovery/t131-uw-doors/SUMMARY.md` |
| T-129 | (user) Some enemies are invisible | DONE | Claude | Dungeon monsters drawn from NES PatternBlockUWSP (tiles $8E-$9D: keese, zol/gel, bubble...) were blank: the block was extracted (data/chr/sprites.c) but never uploaded. Now loaded after every dungeon enemy-bank swap (scene_load.c). Lockstep t129_enemy_sweep (each type $01-$48 staged in L1 $73): keese $1B-$1D, zol/gel $14/$15, bubbles $2B-$2D now drawn like NES (were SAT entries on empty tiles). Caves: T-133. Types flagged but not dungeon enemies of L1: OW monsters and bosses staged outside their CHR bank |
| T-130 | (user) Key sprite broken | DONE | Claude | Drawn by the NES item writers (was a boomerang placeholder) + Z_07 MoveAndDrawRoomItem: a like-like/stalfos/gibdo in slot 1 carries the room item (room $74 key follows the stalfos). Same SUMMARY |
| T-131 | (user) UW room transitions: Link's look while going through doors is wrong, especially east/west doors | DONE | Claude | NES CheckDoorway/Link_FilterInput/TouchDoor/CheckScreenEdge on NES RAM; UW modes 6/7/4 on the native scroll machine (timing = NES; Genesis 3 frames faster only in InitMode7 where NES lags); Link two 8x16 halves with the NES behind-BG rule + high-prio edge columns (W/E doors); X=0 sprite masking = NES 8-sprite rows under N/S frames. Framebuffer + SAT evidence in `builds/reports/recovery/t131-uw-doors/SUMMARY.md` |
| T-132 | Dungeon entry/exit not NES: Genesis entered the level at once with Link mid-room (Y $85) and walked out of the start room into a non-existent room $83 | DONE | Claude | Entry: mode $10 stairs (cell-exact f1300-1388, descent framebuffer 0 px), load, curtain (16 steps x 5 frames), HUD static-only until mode 4/5 (0 px), mode 4 walk-in 13 frames. Exit: NextRoomId >= $80 -> EndGameMode12 -> OW curtain -> StepOutside (1 px / 4 frames). Link-behind-BG stamp fixed for the scrolled 64x64 plane (caves too). `builds/reports/recovery/t132-level-entry/SUMMARY.md` |
| T-133 | Caves: the cave person and the floor items were not drawn and each cave fire was drawn twice | DONE | Claude | Person updated in the object loop like NES UpdateObject (types >= $6A); the object phase cleared the sprite cache after the old input-stage draw. cave_init wrote ObjAttr to $3A5 instead of $4BF: NES RAM has $81 on the person and both fires (attr bit 0 = no generic draw). t120_cave_person: 0 unpaired NES sprites, no extra Genesis sprite; screenshot shows man, fires, sword like NES (remaining verify pixel fails = fire/Link animation phase) |
| T-112 | Rod / magic shot is Genesis-only (3 px/frame, private state, never slot `$0E`); NES UpdateSwordShotOrMagicShot + book-of-magic fire (WieldCandle with UsedCandle bypass, Z_07:3505) not ported | DONE | Claude | Lockstep: slot `$0E` + fire slot cells equal vs NES — done in T-116: `t116_rod_*` / `t116_book_fire` slot $0E/$12/$10 0 diffs |
| T-113 | Link shove distance (+4 px): Obj_Shove read a stale Link ObjGridOffset ($394) and its grid edits were overwritten by the end-of-tick publish; $3BC never published | DONE | Claude | `builds/reports/recovery/t113-link-shove/SUMMARY.md`: `t110_fire` f77-137 Link $70/$84/$394/$3A8/$3BC/$C0/$D3 540/540 equal to NES (was 421/540) |
| T-120 | Link movement does not run NES CheckTileObjectsBlocking / CheckPersonBlocking (split from T-113) | DONE | Claude | `builds/reports/recovery/t120-tile-objects/SUMMARY.md`: t120_rock_block Link + rock equal every frame; t120_cave_person Link stops at Y $8D like NES |
| T-114 | Verify UW bombable wall (bomb.c `bomb_check_wall`) vs NES. Needs both consoles in the same UW room: blocked by T-105 route divergence / no NES UW staging | DONE | Claude | Lockstep in L1 bombable-wall room: door opened bit + tiles vs NES |
| T-115 | OW nametable sub-palette: `ow_render.c` forces sub-pal 2 for every OW room (2026-05-23 assumption from one probe); NES room $79 uses sub-pal 3 (brown). Genesis draws it green | DONE | Claude | `verify_plane.py t050_rock_push`: tile identity 704/704, sub-palette 0/704 → must be 704/704 exact in $76/$78/$79 + a sweep |
| T-116 | Weapons port: sword $0D, sword shot $0E, boomerang $0F, arrow/rod $12 as NES objects (were Genesis-native: 8-frame swing without NES state 1, 3 px/frame arrow, 64-frame boomerang) | DONE | Claude | `builds/reports/recovery/t116-sword/SUMMARY.md`: sword, arrow, boomerang, sword shot + spread, rod, magic shot, book fire: slot cells 0 diffs vs NES (lag 0), 21/21 sprite checkpoints exact (presets `t116_*`). Shot GridOffset after a monster hit differs (scratch $0E, T-102) |
| T-122 | Link_ModifyDirAtGridPoint / diagonal input: Genesis used an H-over-V rule at grid points; NES scans inputs, counts walkable ones and turns perpendicular once (Link_GoStraightWhenDiagInput $56) | DONE | Claude | Lockstep tmp_boomUR (diagonal hold + throw): Link $98/$3F8/$70/$84/$394 equal to NES every frame, boomerang slot 0 diffs / 91 frames; 9 movement presets unchanged (no diagonal input there) |
| T-123 | InitLinkSpeed: Link q-speed $30 on OW tiles $74/$75 (ObjCollidedTile $49E, position fraction reset on change); Genesis always $60 | DONE | Claude | Lockstep `t123_slow_tiles` (route $77->$17, walk column 4 over $74/$75): $3BC/$3A8/$84/$394/$49E equal to NES every frame f1630-1692 (`builds/reports/recovery/t123-t124/SUMMARY.md`) |
| T-124 | Room entry + OW object tail not NES: (1) InitMode_EnterRoom ClearRam0300UpTo $051F missing (stale ZoraActive $514 etc.); (2) SetupObjRoomBounds never called (RoomBound $346-$349 = 0 outside the harness seed: shots never bounded); (3) CheckZora never ported (no Zoras); (4) UpdateMode5Play tail heart warning / sea sound missing; (5) object loop ran slots 1..$B, NES $B..1 | DONE | Claude | `t123-t124/SUMMARY.md`: Zora $11 spawns in the NES slot on the NES frame (lag 1) in $48/$38/$28/$27/$17, fireball $55 path equal to NES, bounds = NES; suite enemy-slot agreement up (t050_layout_plain 33->63%, secret 17->54%, t114 23->32%), verdict cells down 25-35 per room preset |
| T-125 | Busy-frame lag over NES: `t123_slow_tiles` GEN 17 / NES 16 (t114 now 36/37 after T-102) (f1027/f1029, room $38: 6 octoroks + Zora + fireball). No single hotspot (pc_profile: sprite emit, anim_write_sprite_pair, move/collision) | TODO | | Suite lag per preset <= NES; cave entry load `t120_cave_person` GEN 9 / NES 2 lag frames (Genesis still 23 frames faster overall). T-131: the HUD code invalidated the gameplay sprite cache every frame (now only on pause edges) and door masks are write-on-change: UW lag t131_uw_doors 40->31 (NES 40), t128_uw_blocks 91->32 (NES 40), t114 44->38 (NES 37) |
| T-117 | UW PlayAreaTiles (`$6530`) never published on Genesis (lockstep `t114_uw_wall` room $53: 6/704 cells match NES; stale OW data). Drained collision (enemies, shots) reads it in UW | DONE | Claude | `uw_render.c` mirrors every UW raw tile write (blob fill, scroll column fill, door faces, push blocks) into `$6530`. `verify_play_area.py` on `t114_uw_wall`: $73 704/704, $53 before bomb 704/704, $53 after bombable wall 704/704; $63 700/704 = south key door face (door state, T-119) |
| T-119 | UW door state is not NES UpdateDoors: (1) opening a key/bomb door must also flag the opposite door in the next room (Z_05:5170-5186; Genesis `s_persist` marks one side only -> `$63` S key door drawn locked after unlocking `$73` N); (2) scroll entry sets CurOpenedDoors to the entering doorway (InitMode7_Sub1 / SetEnteringDoorwayAsCurOpenedDoors) and issues close cmd 2 for shutters (Z_05:1620-1636); (3) TriggeredDoorCmd 2/3/6/7 two-stage animation with DoorTimer 8, door sound, Link timer $30 (UpdateDoors Z_05:5006); (4) door flags live in private `s_persist`, not NES room flags (`GetRoomFlags`/`LevelMasks`), so saves lose them | DONE | Claude | `builds/reports/recovery/t119-doors/SUMMARY.md`: room flags $73/$63/$53 = NES ($28/$24/$28), $63 PlayAreaTiles 704/704, door cmd/DoorTimer sequence matches (GEN 1 frame late, T-102). Acceptance was: Lockstep `t114_uw_wall` $63: `$EE` + PlayAreaTiles 704/704 + door VRAM per frame vs NES through key open and shutter close |
| T-118 | Frame budget: Genesis dropped frames on event spikes in busy rooms (HUD redraw, bomb flash, door open, explosion) and at transitions | DONE | Claude | `builds/reports/recovery/t118-frame-budget/SUMMARY.md`: lag frames t114_uw_wall 89 -> 36 (NES 37), t105_scroll 2 (NES 2), t110_bomb 0 (NES 0); bar = Genesis lag <= NES (faster is fine) |

### S0c — Native game-mode spine (finish plan Phase 2)

| ID | Task | Status | Owner | Acceptance |
|---|---|---|---|---|
| T-095 | `src/game/modes/mode_machine.c` owns frame; Mode 5 = play tick extracted from `roomrom_debug_tick`. Must reproduce NES init-then-update (first Mode 5 frame = InitMode, no object/chase update; T-107) and NES play order (T-102) | TODO | | GameMode/Submode trace matches NES across boot→play |
| T-096 | Modes 4/6/7/$10 wrap `transition.c`/`cellar_meta.c` with NES mode values | TODO | | Mode trace byte-diff on scroll, cave, stairs |
| T-097 | Mode $11 death (CurSaveSlot `$16`, DeathCounts `$630`, visuals) + $08 continue→3/D/0 | TODO | | Death→continue/save/retry RAM trace vs NES |
| T-098 | Mode $12 end-level exit; Mode $13 ending text/draw/credits/reset | TODO | | Trace + VRAM diff vs NES ending |
| T-099 | Modes 0–3 load/unfurl; $E/$F register/elimination in custom FS; real slot occupancy | DONE (FS) | Claude | File Select now: real slot names/hearts/death counts from NES slot info; empty slot → NES Mode $E name board (44 NES chars, A writes, B skips, Start registers; blank = no file; "ZELDA…" = quest 2); ERASE = NES DeleteSlot; COPY SAVE (custom feature) copies file A. Full hearts/NES glyphs uploaded from ROM `common_chr` (FS Redux capture lacks `$F2–$FF`, `$62/$63/$2B`; digit 0 was blanked). **Evidence** `builds/reports/recovery/t099-fs/`: register→continue 11/11 (cart file A = NES new-file bytes, profile hearts $22 / max bombs 8 / no sword), copy+erase 10/10, fs_entry 5/5 (now registers first, as NES), save round trip still 0/1328. Modes 2/3 (load/unfurl animation) move to T-095/T-096 |
| T-100 | Full NES SaveRAM profile per slot (name, inventory, quest, deaths, world flags), versioned | DONE | Claude | Genesis save format = NES format: `nes_ram[$6000–$652F]` persisted byte-for-byte at cart SRAM `$000`; NES CalculateFileAChecksum/FormatFileA/Mode0 Sub1+Sub2/@ChoseSlot/ModeD Sub0+CopyFileBToFileA ported (`save_serializer.c`, `save_game.c`). Old 43-byte format (slot 2 overlapped PlayAreaTiles) retired; fake FS markers removed. **Evidence:** lockstep `save_roundtrip` (same card, same play, Mode $0D on both): NES Battery RAM vs Genesis cart SRAM **0/1328 bytes differ**; codec self-test 5/5; persistence across hard reset 7/7; FS entry 5/5; newgame load: Items/WorldFlags/slot info equal NES at f0. Save → GameMode 0 (NES) still returns to Play → T-097 |

### S1 — Quest 1 route (the test driver; controller-only; checkpoint with SRAM saves, not savestates)

| ID | Segment | Plan ref | Status | Owner | Acceptance |
|---|---|---|---|---|---|
| T-010 | Boot → file create → OW start | P2.1, P7.4 | TODO | | Recorded input file replays to OW start |
| T-011 | Sword cave → sword → exit | P2.2 | TODO | | Sword owned, HUD updated, correct exit spot |
| T-012 | OW → L1 entrance (combat, room crossings) | P2.3–2.4 | TODO | | Enters L1 with no staging |
| T-013 | L1 full → Aquamentus → heart + triforce → exit | P2.5, P1.1–1.7 | TODO | | Real fight, reward, exit; save/reload once (P2.6) |
| T-014 … T-021 | L2 … L9 (one row each, add when reached) | P8.1–8.2 | TODO | | Entry, key items, boss, reward, exit |
| T-022 | Ganon → Zelda → ending | P6.1, P8.3 | TODO | | Unassisted fight; ending mode + credits (renderer stubs → T-051) |

Each failure inside a segment = new `T-1xx` bug row (owner fixes at the owning function, re-runs that segment only).

### S2 — Breadth not on the route

| ID | Task | Plan ref | Status | Owner |
|---|---|---|---|---|
| T-030 | Enemy families: one natural encounter each, per `docs/audit/enemy_parity/INDEX.md` open rows | P3.3–3.5 | TODO | |
| T-040 | Bosses: Dodongo, Manhandla, Gleeok, Digdogger, Gohma, Patra, Moldorm/Lanmola — one real kill each + variant diffs | P6.2–6.4 | TODO | |
| T-050 | Unwired object dispatch rows: `$2F` pond fairy, `$5E` flute secret, `$61–$68` OW objects | P4 | DONE | Claude |
| T-051 | Ending renderer stubs (sprites, credits, finalize) | P7.4 / P8.3 | TODO | |
| T-052 | Items/secrets table | P4.1–4.3 | TODO | |
| T-053 | Death/continue lifecycle | P7.3 | TODO | |
| T-054 | OW/UW secret objects `$61–$68` (dock, rocks/graves, bomb walls, tree, UW push block) + bombs open UW bombable doors | P4.3/P5.3 | TODO | |
| T-055 | Flute: whirlwind `$2E`, FluteTimer `$3C`, `$5E` update (Digdogger, L7 entrance) | P4 | TODO | |
| T-056 | `Link_EndMoveAndAnimate`: ladder, raft, water | P4 | TODO | |
| T-057 | Bait object, potion on B, candle relight | P4 | TODO | |
| T-058 | Cellar pairs + push-block rows for all 18 dungeons generated from ROM (only L1Q1 today) | P5.3 | TODO | |
| T-059 | HUD map/compass/visited overlay; remaining cave-person/text states; boss death cry; placeholder item art | P5.4/P7.1 | TODO | |

### S3 — Quest 2 · S4 — Audio (last) · S5 — Release

| ID | Task | Plan ref | Status |
|---|---|---|---|
| T-060 | Q2 connected route (X+Y+Z boot) | P9 | TODO |
| T-070 | Audio: `audio_init` not called on active boot; event wiring before driver changes | P7.5 | TODO (after S1–S3) |
| T-071 | Audio request cells `$0600–$0604` consumed while XGM owns chip; fix wrong writers (death/GameOver `$89/$8B`, Gleeok `$10`), L9/Ganon/Zelda song selection | P7.5 | TODO |
| T-072 | User song slot table: `songs/<id>_<name>.vgm` → xgmtool → linked by NES song ID, NES fallback. **User supplies songs; SFX stay NES** | P7.5 | TODO |
| T-075 | Redux as Options row (replace debug C toggle); fix `gen_redux_roomrom.py` path → `reference/Zelda1-Redux`. More enhancements only after Q1+Q2 run | P11 | TODO |
| T-080 | Builder: clean-staging build from user ROM, no live captures, drag-and-drop shell, reproducibility | P10 | TODO |

## Handoff log (newest first)

**2026-09-25 · Claude** — Astra: your T-105 WIP was preserved as branch `astra/t105-wip` (bced3fce) and, on the user's
instruction, landed on main after verify_scroll PASS x3 + full regression (evidence `t105-scroll/`). main.c is now open for
the Link-state work (T-113, T-102, T-092). Next: perf hitches (T-080), UW PlayAreaTiles publish (T-117).

**2026-09-25 · Claude** — T-114 done: L1 $53 bombed wall 704/704 vs NES. Fixed UW single-tile writes (slot mapping), ported
LayOutDoors door faces, fixed transposed UW atlas collector, published $EE. Evidence `t114-uw-wall/`.

**2026-09-25 · Claude** — T-115 done: OW rooms use NES outer/inner sub-palettes (LevelBlockAttrsA/B & 3); 93/128 rooms
were wrong. BG atlas +18 secret-square combos (637->655, SPR base 656). Evidence `t115-ow-subpal/`.

**2026-09-25 · Claude** — T-050 done: pond fairy $2F (UpdatePondFairy + World_FillHearts + orbiting hearts) byte-matched vs NES in
room $39; $F3 heart tile routed to the ITEM atlas; NES room-entry q-speed $20 default for slots 1-11. Next: T-115 (OW sub-palette).

**2026-09-25 · Claude** — T-050 part 1: OW tile objects $62-$67 (rock/grave push, bomb wall, burnable tree), layout secret
substitution + CheckShortcut, live square changes on the plane (DynTileBuf vertical/repeat records), ObjInputDir published.
Evidence `t050-tile-objects/`. Found T-115 (OW sub-palette). T-050 stays ACTIVE for pond fairy $2F (needs World_FillHearts).

**2026-09-24 · Claude** — T-110 done: bombs/fire now NES objects in slots `$10/$11` (bomb.c/candle_fire.c), drawn via
enemy_render weapon cache, bomb flash = CRAM grayscale (bg_palette.c). Byte evidence in `t110-bomb-fire/`. New rows T-111..T-114.
Lockstep stage can now set the Genesis B item (`gen_b_item`). Resuming T-050 (OW tile objects; rock wall now sees bomb state `$13`).

**2026-09-24 · Claude** — T-099 FS done: register name / erase / copy / real slot display, all NES-format through
`save_game.c`. New Game now = register on an empty slot (as NES) → NES new-file stats. `probe_fs_entry.lua` registers first.
Blocked on main.c for T-092 remainder (debug seeds) and T-095 mode spine — waiting for Astra's T-105 commit.

**2026-09-24 · Claude** — T-100 DONE: saves now ARE the NES save file (cart SRAM $000–$52F = NES $6000–$652F); NES vs
Genesis save bytes identical after the same play (0/1328). T-109 DONE: debug sentinels no longer overwrite L7–9 world flags.
Astra: `RoomRom/src/main.c` sentinel lines (31) committed via index patch — rebase/merge your WIP normally; no overlap with your hunks.

**2026-09-24 · Claude** — T-007 DONE: Q2 overworld room patch now applied on the active install (ROM-derived), byte-exact
vs NES Q2 (1024 bytes, 0 diffs). Lockstep capture now dumps NES Battery RAM + full 68K RAM; preset `gen_entry: "xyz"` boots
Genesis Q2 via the debug chord (disclosed). Next: T-002 runtime (Q2 L1 LevelInfo/pause map) with the same method.

**2026-09-24 · Claude** — T-093 DONE (0 macro redefinitions; LINK_X vs ChaseTarget ambiguity and CUR_LEVEL=16 bug removed).
T-108 DONE: Tektite jump direction + fall speed now match NES frame-for-frame (lockstep staging hook `stage_at`/`stage` in presets).
New T-107 (chase decoy missing). Astra: see finding on T-105 row (scroll freezes FC/RNG/timers).

**2026-09-24 · Claude** — T-106 DONE (minimap marker showed enemy art; now NES `$3E/$3F` in protected VRAM 1312–1313).
Lockstep capture now also dumps full video state at end (NES OAM/PAL/CHR/CIRAM, GEN VRAM/CRAM/VSRAM). Astra: your T-105 WIP in
`main.c`/`build_debug.py`/`ow_scroll.*` untouched and uncommitted; my commit only stages my files. Rebuild before your next capture.

**2026-09-24 · Claude** — Lockstep-driven fixes: T-103 turn-between-grid rule and T-104 OW collision origin/2-column sampler (both
byte-verified vs NES). T-101 closed as harness artifact (seed alignment added). New: T-102 tick order, T-105 room scroll
(trigger/arrival/length/grid phase), found by new preset `ow_walk`. Next: T-105.

**2026-09-24 · Claude** — Lockstep differ live: `python tools/lockstep/run_lockstep.py tools/lockstep/presets/newgame.json`
(NES save-file cheat card + Genesis slot, per-frame 2 KB RAM on both, named diff). First runs found T-091 (self-tests corrupting
Items on New Game, fixed) and T-101 (FrameCounter/RNG). Shared probe entry `tools/debug/probes/lib/enter_gameplay.lua`; 5 self-test
probes were silently broken since Title START → File Select; fixed. 2 stale options tests aligned with load-resets-defaults.

**2026-09-24 · Claude** — T-094 DONE: audio driver RAM moved from fixed `$FFE000/$FFE100` (aliased NES SaveRAM `$6000/$6100`)
to linker-owned `audio_music_state`/`audio_dmc_state` (aligned 4). Proven live before/after. New `tools/debug/run_probe.py`
(isolated BizHawk + `@SYM:name@` ELF address substitution) replaces per-folder runners. Next: lockstep differ + presets.

**2026-09-24 · Claude (Windows host)** — T-001 DONE. Merged tree builds (`f3a38e2b…`). Freshness gate failed only because `sorted(Path)`
is case-insensitive on Windows; fixed with POSIX-relpath sort (`9c6a04a1`). Matrix GREEN 12/12. Ganon→Zelda→Mode13, Aquamentus
consumer, map/compass consumer, FS→New Game and save/hard-reset (Items only) all PASS. `probe_save_persistence.lua` entry was broken
(false ready on title `$EB`); fixed. New: T-093 macro warnings; T-092 new-game hearts/Link visibility. Next: T-002 runtime check, then S0b.

**2026-09-24 · Claude** — T-002: Q2 dungeons were installing Q1 LevelInfo (patch existed only in an unlinked drained path with
hardcoded game bytes). Added `level_info_apply_q2_patch` from the ROM blob (+18-byte addr table so the NES's one-byte overrun is exact),
`tools/audit/test_q2_levelinfo.py` 18/18 PASS. Found T-007 (same bug for Q2 overworld). Needs Astra runtime check after T-001.

**2026-09-24 · Claude** — Committed 13 days of uncommitted Sep work (`2dffd36f`), removed stale `.git/index.lock` (2026-09-14).
Merged `feat/cave-entry-transition-parity` (`3586d1e3`): SRAM saves, linked File Select, builder gates, room generator.
Replaced captured tables with ROM LevelInfo reads (offsets `$20/$2D–$30` verified against ROM for Q1). Removed the Aug world-flags
override (it aimed dungeons at OW flags). Generated data regenerated and byte-checked; host-gcc 198/198 syntax-clean, no symbol conflicts.
**Not built on Windows yet — Astra: T-001 first.** Created this tracker, `AGENTS.md`, `tools/audit/host_link_check.py`.

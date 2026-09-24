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
| T-003 | World-flag regions (`$067F` OW, `$06FF` L1–6, `$077F` L7–9) | P7.2 / P5.4 | TODO | Claude → Astra | `level_info_install.c`, `save_game.c`, `save_serializer.c` | Code: new game zeroes all three, SRAM save/load keeps all three. Runtime (Astra): kill Digdogger + Patra, leave, re-enter → no respawn; OW secret still open after a dungeon |
| T-004 | Room generator: Ganon room `$42` | P0.14 | TODO | Claude | `tools/builder/gen_uw_room_tiles.py` | Generator output for L9Q1 `$42` byte-equal to the live capture in `uw_room_blob.c` (240 NT bytes differ today). Then 331/331 → builder no longer needs live captures |
| T-005 | Triforce/pause tint after palette LUT change | P7.1a | TODO | Astra | `tools/extract_misc.py` | Aug CRAM overrides `$17/$36/$37` were dropped for the Sep NES-reference LUT. Byte-compare triforce + L1 pause palette vs NES; fix in generator if wrong |
| T-007 | Q2 overworld LevelBlock patch in active path | P9.2 | TODO | Claude | `level_info_install.c` | `level_info_install_ow` ignores quest; NES `@PatchQ2Rooms` (8 AttrsB bytes + 7 fixed writes) only exists in unlinked `room_dispatch` path. Apply on OW install for Q2; offline byte test like T-002 |
| T-006 | Retire competing trackers | — | DONE | Claude | `.claude/skills/primedirective`, `docs/superpowers/prime_directive_*` | PD skill reads `docs/TRACKER.md` for next action; its Phase 8 "next action" pointer no longer claims authority |

### S0b — Ship-path hygiene (finish plan Phase 1)

| ID | Task | Status | Owner | Acceptance |
|---|---|---|---|---|
| T-090 | Runtime `debug_session` gate: set only by title A+B+C / X+Y+Z chord; all gameplay debug inputs (X/Y/MODE/C/Z+START/B+Z+C/A+B+C+START in `RoomRom/src/main.c`) require it | TODO | | FS New Game: every debug input inert (RAM trace) |
| T-091 | Boot probes (options/persistence/serializer/warp/roundtrip/metadata) run only when armed; none write SRAM on normal boot | DONE | Claude | **Was corrupting play:** `save_serializer_probe_run` left `$30..$57` in Items `$0657..$067E` on every New Game (write-watch PCs → symbols). Gated on `ROOMROM_DEBUG_PROBE_SELFTEST $08`. After: 0 probe writes on FS New Game, entry 229 frames sooner; armed self-tests 5/5, 22/22, 10/10, 34/34, 8/8, warp 0/128, roundtrip 0/18 (`builds/reports/recovery/t091-selftest-gate/`) |
| T-092 | NES new-game init on FS path: no seeded sword, keys 0, no default B-item, NES start facing; B-item only via pause. **Lockstep `newgame` diff (after T-091):** GEN Items[0] sword `01` (NES `00`), HeartValues `$33` (NES `$22`), MaxBombs `00` (NES `08`); preset slot not loaded on GEN (check SRAM write timing vs load). Also FrameCounter `$15` frozen at 0 and Random `$18+` unseeded on GEN → new T-101 | TODO | | Inventory + Link RAM byte-diff vs NES new-game capture |
| T-094 | Music driver state at fixed `$FFE000/$FFE100` = `nes_ram[$6000/$6100]` (NES SaveRAM) under A4 `$FF8000`: save wrote `$5A/$A5` into `m_song/m_song_req` | DONE | Claude | `builds/reports/recovery/t094-music-sram/`: before = overlap, after = save image stable + music state at linker symbol `$FF00EC`; save persistence 7/7 |
| T-101 | FrameCounter/Random/StunCycle parity | DONE | Claude | Not a game bug: Genesis starts them at gameplay entry (custom title/FS). Harness now syncs on first live tick and copies NES `$15/$18-$24/$26` at sync; then 266/266 frames byte-equal → per-frame port verified |
| T-102 | Play-tick order: Genesis runs weapons+enemies BEFORE Link moves and mirrors `$70/$84` at tick start (NES `UpdateMode5Play`: UpdatePlayer → chase target → weapons → objects). Enemies/NES code see Link 1 frame stale | TODO | | Fold into T-095 `mode_play.c` in NES order; lockstep `ObjX/ObjY` equal same frame |
| T-103 | Link turn between grid points (`Link_ModifyDirOnGridLine`): opposite input reverses now; perpendicular <4px reverses to grid point with mirrored offset | DONE | Claude | Lockstep `newgame` f189: GEN now steps right 1px to `$38` then up (was 7px left to `$30`), identical to NES |
| T-104 | OW collision sampler used HUD origin `$38` + one column; NES `GetCollidableTile` = origin `$40`, two columns vertical | DONE | Claude | OW now uses shared NES sampler. Lockstep `newgame`: GEN stops at Y `$5D` on tile `$DE` like NES (was walking to `$55`) |
| T-105 | OW room scroll: trigger Y `$39` vs NES `$3D`; GEN stays GameMode `$05` (NES `$07`); ~32 vs ~80 frames; arrival Y `$CD` vs NES `$DD`; grid offset not re-phased → Link off-grid after every vertical change (walks through walls after) | ACTIVE | Astra | **Finding for Astra (Claude, lockstep `tektite_jump`, build without your WIP):** during Genesis horizontal scroll FrameCounter `$15`/Random/timers freeze (12 frames no tick from f121) while NES keeps ticking in modes 6/7 → RNG desync after every room change. Scope: `src/game/world/ow_scroll.*`, required scroll call-site glue in `RoomRom/src/main.c`, `tools/debug/build_debug.py`, focused `tools/lockstep/` verification, `docs/audit/drain_findings/t105-scroll.md`, task evidence.  Lockstep `ow_walk` equal through room `$77`→`$67` and after |
| T-106 | User report: "enemy half stuck in HUD top-left" = minimap position marker. It used VRAM `SPR_TILE_BASE+$3E` (tile `$2BC`), inside the SCENE_OBJ overlay (`SPR+44`, 136 tiles), so OW enemy CHR replaced the NES `$3E/$3F` dot | DONE | Claude | Marker pair uploaded from ROM-extracted `common_chr` to protected tiles 1312–1313 (VRAM budget gate registers it). Lockstep `hud_marker`: GEN tile pixels == NES `$3E/$3F`, same X/Y/size; before/after in `builds/reports/recovery/t106-hud-marker/`. Built in an isolated worktree so Astra's T-105 WIP was not built |
| T-108 | Tektite (`$0D/$0E`) jump: horizontal pick used Link X with inverted test (NES: ChaseTargetX, right when >=); `Jumper_MoveY` clamp missed `Jumper_ResetVSpeedFrac` (descent 3,2,3 vs NES 2,2,2) | DONE | Claude | Lockstep `tektite_jump` (staged: Tektite under each console's chase target, fractions zeroed): takeoff/arc/landing/X identical f381–404. Post-landing wait differs only because RNG already desynced at scroll (see T-105) |
| T-107 | NES chase decoy: `UpdateMode5Play` sets `ChaseOtherTarget $60` + decoy `ChaseTargetX/Y` on `ChaseLongTimer` (Z_07:1879–1915); Genesis target stays Link (`tektite_jump` f380: NES other=01 target `$0F,$72`, GEN other=00 = Link) | TODO | | Lockstep `$60–$62` equal over a room visit |
| T-093 | Macro redefinitions (were 65 warnings) | DONE | Claude | 0 redefinitions, 27 warnings total. Real bugs found: (1) `enemy_state.h` `LINK_X/Y`=ChaseTarget `$61/$62` vs `world_state.h` `LINK_X/Y`=ObjX `$70/$84`; first include won per file. Renamed enemy alias to `CHASE_TARGET_X/Y` (NES meaning; per-file audit `tools/audit/macro_audit.py` shows all prior `$61` users unchanged). (2) `room_load_runtime.c` redefined `CUR_LEVEL` to the address `$10` mid-file, so Mode 2 loaders read level=16 (unlinked today, T-099 will wire them). `OBJ_STATE`/`NES_OBJ_INV_TIMER_BASE` single-owner; SGDK `RAM` constant `#undef` (unused). `builds/reports/recovery/t093-macros/` |

### S0c — Native game-mode spine (finish plan Phase 2)

| ID | Task | Status | Owner | Acceptance |
|---|---|---|---|---|
| T-095 | `src/game/modes/mode_machine.c` owns frame; Mode 5 = play tick extracted from `roomrom_debug_tick` | TODO | | GameMode/Submode trace matches NES across boot→play |
| T-096 | Modes 4/6/7/$10 wrap `transition.c`/`cellar_meta.c` with NES mode values | TODO | | Mode trace byte-diff on scroll, cave, stairs |
| T-097 | Mode $11 death (CurSaveSlot `$16`, DeathCounts `$630`, visuals) + $08 continue→3/D/0 | TODO | | Death→continue/save/retry RAM trace vs NES |
| T-098 | Mode $12 end-level exit; Mode $13 ending text/draw/credits/reset | TODO | | Trace + VRAM diff vs NES ending |
| T-099 | Modes 0–3 load/unfurl; $E/$F register/elimination in custom FS; real slot occupancy | TODO | | FS shows real slots; copy/erase works |
| T-100 | Full NES SaveRAM profile per slot (name, inventory, quest, deaths, world flags), versioned | TODO | | SRAM decode vs NES SaveRAM decode after save/reset/continue |

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
| T-050 | Unwired object dispatch rows: `$2F` pond fairy, `$5E` flute secret, `$61–$68` OW objects | P4 | TODO | |
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

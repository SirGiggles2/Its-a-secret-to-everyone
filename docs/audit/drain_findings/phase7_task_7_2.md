# Phase 7 Task 7.2 — Enemy Slot Iterator + Spawn Pipeline + Dispatch Shell

- **NES source**: `reference/aldonunez/Z_07.asm` InitObject (line 5466) + InitObject_JumpTable preamble; ObjType/ObjX/ObjY/Dir/ObjStateTimer/ObjAttr arrays per RAM map
- **Drained C**:  `src/oracle/enemies/enemy_walker_runtime.c` (enrt_init_walker, enrt_init_slow_octorock_or_ghini, etc.) + `src/oracle/enemies/enemy_common_runtime.c` (state-timer scaffolding)
- **Coverage**:   PARTIAL (iterator + force_spawn cell-write path FULL; per-family enrt_init_* dispatch + per-family enrt_update_* tick deferred to 7.3-7.7)
- **Stance**:     EXTEND (slot-iterator framework wraps drained cell layout; dispatch tables NULL until family wiring lands per Drain Rule D1)

## Verified parity (in-ROM probe `enemy_loop_probe_run`)

**Step 2 (commit ca2aae13):** 10/10 PASS — iterator + cell-write framework only.

**Step 3 (this commit):** 14/14 PASS — INIT dispatch row $07 wired. Probe pre-pins LINK_X=LINK_Y=$80 so the enrt_init_walker DIR computation is deterministic, then verifies all cells written by enrt_octorock_common (WALK_SPEED, MOVE_TIMER, ANIM_TIMER, OBJ_STATE) plus enrt_init_walker (DIR). Result: `docs/audit/drain_findings/phase7_task_7_2_step3_probe.txt`.

Probe MMIO: `$FF7E00` (`ENEMY_LOOP_PROBE_BASE`); reader `tools/debug/probes/probe_walker_parity.lua` writes `/c/tmp/probe_walker_parity.txt`.

| NES behavior | NES anchor | Genesis impl | Probe check | Status |
| --- | --- | --- | --- | --- |
| Slot pool cleared at room enter (12 slots, all dead) | NES `ClearObjects` preamble | `enemy_loop_room_init` zeroes all slots via `clear_slot_scratch` | `[0] alive_before_spawn=0` | ✅ |
| `alive_count` reflects live slot mask | NES `CountActiveObjects` | `enemy_loop_alive_count` walks slots, sums `ENEMY_ALIVE_FLAG(i)` | `[1] alive_after_spawn=1` | ✅ |
| `ObjType[slot]` set on init | `Z_07.asm:5466` InitObject preamble | `ENEMY_TYPE(1) = 0x07` | `[2] TYPE(1)=$07` | ✅ |
| `ObjX[slot]` set on init | NES init pos arg | `ENEMY_X(1) = 0x80` | `[3] X(1)=$80` | ✅ |
| `ObjY[slot]` set on init | NES init pos arg | `ENEMY_Y(1) = 0x80` | `[4] Y(1)=$80` | ✅ |
| `Dir[slot]` set on init (caller arg) | NES init dir arg | `ENEMY_DIR(1) = 0` | `[5] DIR(1)=$00` | ✅ |
| `ObjStateTimer[slot]` = slot index | `Z_07.asm:5466` (`STA ObjStateTimer,X` after `LDX CurObjIndex`) | `ENEMY_STATE_TIMER(1) = 1` | `[6] STATE_TIMER(1)=$01` | ✅ |
| Slot alive flag set | NES `ObjType[X] != 0` lives | `ENEMY_ALIVE_FLAG(1) = 1` | `[7] ALIVE_FLAG(1)=$01` | ✅ |
| Public type accessor matches direct cell read | N/A (Genesis abstraction) | `enemy_loop_get_type(slot) == ENEMY_TYPE(slot)` | `[8] get_type(1)=$07` | ✅ |
| Empty slots stay zeroed | NES `ObjType[X]=0 → dead` | `enemy_loop_get_type(2) == 0` | `[9] get_type(2)=$00` | ✅ |
| WALK_SPEED set by init | `Z_07.asm` SlowOctorock branch (LDA #$20 STA WalkSpeed,X) | `enrt_octorock_common(slot, 32)` | `[10] WALK_SPEED(1)=$20` | ✅ step3 |
| MOVE_TIMER set by init | NES `(slot+1)<<4` seed | `enrt_octorock_common` writes `(slot+1)<<4` | `[11] MOVE_TIMER(1)=$20` | ✅ step3 |
| ANIM_TIMER set by init | NES `LDA #$06 STA AnimTimer,X` | `enrt_octorock_common` writes 6 | `[12] ANIM_TIMER(1)=$06` | ✅ step3 |
| OBJ_STATE zeroed by init | NES `JSR ResetObjState` in InitObject | `z07_reset_obj_state` forwarder → `core_reset_obj_state` (drain at `core_runtime.c:327`) | `[13] OBJ_STATE(1)=$00` | ✅ step3 |
| DIR computed by enrt_init_walker | NES walker init dir-by-larger-diff | `enrt_init_walker(slot)` reads LINK vs OBJ pos | `[5] DIR(1)=$02` (h_dir) | ✅ step3 |
| STATE_TIMER overlaps OBJ_STATE | NES $AC slot mapping | Same OBJ($AC,slot) macro; init zeroes both via z07_reset_obj_state | `[6] STATE_TIMER(1)=$00` (post-init) | ✅ step3 |

## Architecture decision (D2 4-way debate, 2026-05-09)

`debates/2026-05-09-phase7-task-7-2-design/synthesis.md` resolves the 5-Q design space:

- **Q1 (spawn data)**: hardcoded 1-2-octorok test table (Option B) — fastest path to first probe; full ObjLists port deferred to 7.8.
- **Q2 (tick placement)**: `enemy_loop_tick` at end of `roomrom_debug_tick` after scroll-state finalize, before sprite draw (Option B).
- **Q3 (dispatch shape)**: function-pointer table indexed by `ENEMY_TYPE` (Option B) — mirrors NES `InitObject_JumpTable` at `Z_07.asm:5601`.
- **Q4 (probe room)**: deferred — step 2 verifies framework only, no live tick yet.
- **Q5 (substrate)**: none — RoomRom-only edits + 1 `RoomRom/src/main.c` include line, plus new files under `src/game/enemies/` per WT-5.

## Why dispatch tables are NULL in step 2

Wiring even one walker entry (`enemy_init_fns[0x07] = enrt_init_slow_octorock_or_ghini`) retains `oracle_enemy_walker.o` past `--gc-sections`, which pulls in 30+ unresolved `c_*` / `z01_*` / `z07_*` / `enrt_animate_*` shims not linked into Debug.md. Per Drain Rule D1 we don't stub the shims (would silently no-op the drained behavior). Tasks 7.3-7.7 wire dispatch entries one family at a time, paired with their shim plumbing.

## Deferred (Task 7.3-7.7)

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Walker family dispatch (slow/fast octorock, gel, rope, leever) | `Z_07.asm:5601` InitObject_JumpTable + UpdateObject branches | Needs c_walker_move + z01_check_link_collision shim plumbing | Task 7.3 |
| Wanderer family dispatch (zora, peahat, traps) | `Z_07.asm` UpdateWandererCommon | Same shim plumbing | Task 7.4 |
| Flyer / jumper / charger families | NES per-family Init/Update | Per-family drain link | Task 7.5-7.7 |
| Real spawn data (NES ObjListAddrs.inc + ObjLists.inc port) | `reference/aldonunez/dat/ObjLists.inc` | Step 2 uses test seed only | Task 7.8 |
| In-game tick: `enemy_loop_tick` from `roomrom_debug_tick` | RoomRom main loop | Tick is no-op until any dispatch is non-NULL; wiring-induced no-op confirmed via dead probe | Task 7.3 (first wired family) |
| Per-frame parity oracle vs NES | NES RAM cells $0341/$0070/$008B per slot | Needs live tick to diff | Phase 7 exit (Gate 2) |
| Per-scenario oracle (room load → enemy spawn → death) | NES room transitions | Phase milestone | Phase 7 milestone tag (Gate 3) |

## Probe / contract

- `src/game/enemies/probes/enemy_loop_probe.{h,c}` — in-ROM verifier; publishes 10 (actual,expected) u16 pairs at `$FF7E00` after `enemy_loop_room_init` + `enemy_loop_force_spawn_slow_octorock`.
- `tools/debug/probes/probe_walker_parity.lua` — BizHawk Lua reader; writes results to `/c/tmp/probe_walker_parity.txt`.
- Result evidence: `/c/tmp/probe_walker_parity.txt` (10/10 PASS, run 2026-05-09 commit ca2aae13).

## Gate

- 4-line task header: filled.
- Gate 1 (per-function diff): N/A for step 2 (iterator framework only; per-family diff comes with 7.3+).
- Gate 2 (per-RAM-cell trace): cell layout verified via in-ROM probe (10/10 PASS); per-frame trace deferred to phase exit per task scope.
- Gate 3 (per-scenario oracle): deferred to milestone tag.

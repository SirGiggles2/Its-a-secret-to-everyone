# Phase 8 Task 8.2 — Aquamentus

- **NES source**: `reference/aldonunez/Z_07.asm:5601` (InitObject_JumpTable
                  row $3D → SwitchBank #$01 + JMP InitAquamentus);
                  `reference/aldonunez/Z_07.asm:5295` (UpdateObject_JumpTable
                  row $3D → UpdateAquamentus); legacy bank Z_04:
                  `Z_04.asm:5594-5607` (UpdateAquamentus),
                  `Z_04.asm:5612` (Aquamentus_Move ~70 lines),
                  `Z_04.asm:5684` (Aquamentus_Shoot ~60 lines),
                  `Z_04.asm:5764` (Aquamentus_Draw ~80 lines, 6-sprite
                  render); tables `Z_04.asm:5609` (AquamentusSpeeds
                  `{$01,$FF}`), `Z_04.asm:5754` (AquamentusTiles, 12
                  bytes / 2 anim frames × 6 sprites), `Z_04.asm:5758`
                  (AquamentusSpriteOffsetsY), `Z_04.asm:5761`
                  (AquamentusSpriteOffsetsX).
- **Drained C**:  `src/oracle/enemies/enemy_boss_runtime.c:102`
                  `enrt_init_aquamentus`; `…:109` `enrt_update_aquamentus`.
                  Primitives `c_aquamentus_{move,shoot,draw}` are NOT
                  drained — legacy Z_04 bank is not linked into
                  `Debug.md` via `c_shims.asm`.
- **Coverage**:   FULL — INIT (invincibility=$E2, sfx_boss_cry=16,
                  X=$B0, Y=$80) + UPDATE (movement / fireball pattern /
                  hitbox / draw / boss-hit-cry) all live in the linked
                  `enemy_loop` dispatch table; native bridge bodies for
                  `c_aquamentus_{move,shoot,draw}` resolve every
                  primitive `enrt_update_aquamentus` calls.
- **Stance**:     ADOPT for the dispatch wiring (calls drained
                  `enrt_init_aquamentus` / `enrt_update_aquamentus`
                  directly); EXTEND for `c_aquamentus_{move,shoot,draw}`
                  bridge bodies (per-line transcribe of NES asm,
                  legacy Z_04 unlinked). No GREENFIELD.

## Already-shipped surface (carry-over from Phase 7 Task 7.4)

Phase 7 Task 7.4 step 10 (commit subject "phase 7 task 7.4 step 10 —
Aquamentus boss INIT + UPDATE") landed every Task 8.2 master-plan
checkbox before Phase 8 opened. Inventory:

| Master-plan checkbox | Implementation | Source |
|---------------------|----------------|--------|
| Movement | `c_aquamentus_move` (random distance + 8-frame cadence + edge clamps + AquamentusSpeeds[Dir-1] step) | `src/game/enemies/enemy_boss_bridge.c:155` |
| Fireball pattern | `c_aquamentus_shoot` (3-fireball burst @ ObjTimer==0; +Y drift via ENEMY_BOUNCE_FLAGS for already-flying shots every other frame) | `src/game/enemies/enemy_boss_bridge.c:189` |
| Hitbox | `c_check_monster_collisions(slot)` inside `enrt_update_aquamentus` | `src/oracle/enemies/enemy_boss_runtime.c:115` |
| Death | `enrt_play_boss_hit_cry_if_needed(slot)` (Z_04 PlayBossDeathCry routing) | `src/oracle/enemies/enemy_boss_runtime.c:116` |
| Render | `c_aquamentus_draw` (6-sprite, 2-frame anim every $10 frames; open-mouth tile $C0 substituted for face when ObjTimer<$20) | `src/game/enemies/enemy_boss_bridge.c:235` |
| Dispatch INIT | `enemy_init_fns[0x3D] = enrt_init_aquamentus` | `src/game/enemies/enemy_loop.c:271` |
| Dispatch UPDATE | `enemy_update_fns[0x3D] = enrt_update_aquamentus` | `src/game/enemies/enemy_loop.c:532` |

## Phase 8 close-of-task additions

This pass wraps the Phase 7 carry-over with the Phase 8 evidence
contract:

1. Drain Rule D1 4-line header (above) + per-primitive line citations.
2. Tracker note that Task 8.2 closes against existing code — no new
   primitive drain, no new bridge body.
3. Build verification per `Debug.bat` invariant.

No code changes — every NES asm line in `Aquamentus_{Move,Shoot,Draw}`
already maps to a concrete native body in `enemy_boss_bridge.c` per
Task 7.4 step 10.

## Live-room probe deferral

`Z_05.asm:8154` `CreateRoomObjects` (Phase 8 Task 8.1) populates room
matrix; `InitMode_EnterRoom` (`Z_05.asm:1700-1820`) drives the per-slot
init dispatch on real room entry. The Debug.md harness exercises
debug-spawn paths via the A+B+C chord, not the `InitMode_EnterRoom`
flow that gates Level 1 boss-room entry. A live-emulator Level 1 probe
requires the gameplay state machine to be wired through scroll / pause
/ shutter — same caveat noted on Phase 7 Task 7.7 close. Tracked under
Phase 8 Task 8.11 (Boss Matrix), which probes every boss room end-to-end
once the gameplay-mode wiring lands.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Unchanged from Task 8.1 close — Aquamentus dispatch + bridge bodies
already in the link set; Task 8.2 adds no new TUs.

## Status

CLOSE — Task 8.2 Aquamentus carries over completed Phase 7 Task 7.4
step 10 implementation with a Phase 8 evidence header. Probe deferred
to Task 8.11 Boss Matrix per the InitMode_EnterRoom gameplay-machine
gate.

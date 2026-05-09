# Phase 7 Task 7.2 — Walker UPDATE-side dispatch wiring strategy

**Stance:** Drain Rule D1 = EXTEND (drained C exists).

## Project context

- Sega Genesis Zelda 1 NES port. SGDK pinned. Sole build target = `builds/Debug.md` via `Debug.bat`. Frontend ROM retired (2026-05-08).
- 433 drained C functions across 7 subsystems (cave/combat/enemies/hud/items/room/world).
- Drain Rule D1: drained C in `src/oracle/enemies/*_runtime.c` is PRIMARY implementation evidence; NES asm `reference/aldonunez/*.asm` is SECONDARY (final authority for ties). `Stance: GREENFIELD` is illegal when a drain candidate row exists in `tools/audit/drain_coverage.json`.
- 3-gate verification: per-function diff (every commit) → per-RAM-cell parity oracle trace (phase exit) → per-scenario oracle (milestone tag).

## Current state

- Phase 7 Task 7.2 step 3 just committed (HEAD): `enemy_init_fns[$07] = enrt_init_slow_octorock_or_ghini`. INIT-only. UPDATE side `enemy_update_fns[*]` still all-NULL.
- 14/14 PASS in-ROM probe at boot (A+B+C chord → `enemy_loop_room_init` → `enemy_loop_force_spawn_slow_octorock` → init body executes; verifies WALK_SPEED, MOVE_TIMER, ANIM_TIMER, OBJ_STATE, DIR, etc.).
- `z07_reset_obj_state` resolved via one-line forwarder calling already-linked `core_reset_obj_state` (drain at `src/core/core_runtime.c:327`).

## What walker UPDATE bodies need

`src/oracle/enemies/enemy_walker_runtime.c` (drained, linked but update fns gc'd) calls:

| Symbol | Status |
|---|---|
| `c_walker_move` | `src/c_shims.asm:4455` (vasm 5650 lines, NOT linked) |
| `c_check_monster_collisions` | `src/c_shims.asm:3656` (vasm) |
| `c_check_link_collision` | `src/c_shims.asm:4235` (vasm) |
| `c_draw_object_not_mirrored_with_frame` | `src/c_shims.asm:4377` (vasm) |
| `c_wanderer_target_player` | `src/c_shims.asm:4475` (vasm) |
| `z07_anim_advance_and_fetch` | `src/gen/z_07.c` forwarder (NOT linked) → translated asm chain |
| `z01_anim_set_sprite_desc_attrs` | `src/gen/z_01.c` forwarder (NOT linked) → translated asm chain |
| `z01_abs` | `src/gen/z_01.c` forwarder (NOT linked) |

`src/zelda_translated/{z_04,z_05,z_06,z_07}.asm` totals 27,517 lines.

## Build environment

- `tools/debug/build_debug.py` uses GCC m68k toolchain. `compile_asm` = `-x assembler-with-cpp -Wa,--register-prefix-optional --bitwise-or` (gas dialect).
- `c_shims.asm` is written for vasm. Syntax friction unknown.
- `-ffunction-sections -fdata-sections -Wl,--gc-sections` active. Per-function GC works.

## Master plan Task 7.2 checklist

- [ ] Implement octorok
- [ ] Implement moblin
- [ ] Implement stalfos
- [ ] Implement goriya walking
- [ ] Implement darknut base walking if non-boss
- [ ] Add projectile hook where needed
- [ ] Probe movement and collision
- [ ] Probe damage/death/drop
- [ ] Commit family

Init alone does NOT satisfy this checklist. UPDATE wiring is required.

## Options

- **A) LINK c_shims.asm + z_*.asm chain.** Bring `c_shims.asm` (5650 lines vasm), `src/gen/z_07.c`, `src/gen/z_01.c`, and transitively-needed `zelda_translated/z_*.asm` into Debug.md build. Risk: massive symbol surface, vasm/gas syntax friction, unknown count of dragged-in NES RAM cell remap symbols.
- **B) NATIVE DRAIN UpdateOctorock + every called primitive** (c_walker_move, c_wanderer_target_player, c_check_monster_collisions, c_draw_object_not_mirrored_with_frame, z07_anim_advance_and_fetch, z01_anim_set_sprite_desc_attrs, z01_abs). Per Drain Rule D1 long-term best. Risk: weeks of native drain work before any walker moves on screen. The drain candidates may already exist for some of these primitives — would need audit.
- **C) ASM BRIDGE (thin shim).** A single new `src/game/enemies/walker_link_bridge.c` that defines the missing externs as forwarders to drained C primitives where they exist + minimum NES asm trampolines for what's still asm. Smaller surface than A.
- **D) DEFER walker UPDATE entirely.** Redefine Phase 7 Task 7.2 milestone as "init-side dispatch verified for all walker types" (octorok / moblin / stalfos / goriya / darknut / rope / gel). Push UPDATE wiring + master-plan-checklist completion to Task 7.5 or a successor phase. Push the link-strategy decision until more drained primitives land naturally.

## Question

Pick A/B/C/D. Justify against Drain Rule D1 + master plan Task 7.2 checklist + 1-3 day vs weeks-of-work tradeoff. Identify wrong assumptions, ordering risks, gotchas. Be terse — under 300 words.

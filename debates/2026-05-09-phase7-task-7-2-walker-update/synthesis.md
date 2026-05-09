# Synthesis — Phase 7 Task 7.2 walker UPDATE-side wiring

**Verdict: Option C (thin forwarder layer), corrected.**

## Round 1 tally

| Voice  | Pick     | Quality              |
|--------|----------|----------------------|
| Opus   | A→B hybrid | Insightful but heavier than needed |
| Gemini | C        | Right answer, light evidence |
| Sonnet | C        | Right answer + decisive new evidence |
| Codex  | (empty)  | CLI failed — `--full-auto` deprecation only |

## Decisive evidence (Sonnet r001, verified)

Context table claimed 7 walker UPDATE primitives are vasm-only. Grep
confirms 6 of 7 already exist as drained native functions, linked into
`builds/Debug.md`:

| Walker call                              | Drained native (verified)                                                                |
|------------------------------------------|------------------------------------------------------------------------------------------|
| `c_check_monster_collisions`             | `link_collision_check_monster_collisions` — `src/game/combat/link_collision_dispatch.c:263` |
| `c_check_link_collision` *(Sonnet error)*| `link_collision_check_link_collision` — `src/game/combat/link_collision_dispatch.h:42`   |
| `c_draw_object_not_mirrored_with_frame`  | `draw_object_not_mirrored_with_frame` — `src/game/world/draw_dispatch.c:426`             |
| `c_wanderer_target_player`               | `enrt_wanderer_target_player` — `src/oracle/enemies/enemy_wanderer_runtime.c:63`         |
| `z07_anim_advance_and_fetch`             | `sprite_anim_advance_and_fetch` — `src/game/world/sprite_dispatch.c:105`                 |
| `z01_anim_set_sprite_desc_attrs`         | `core_anim_set_sprite_desc_attrs` — `src/game/core/core_dispatch.c:155` (or `corert_*`)  |
| `z01_abs`                                | trivial native one-liner                                                                  |

**Correction to Sonnet:** `c_check_link_collision` and
`c_check_monster_collisions` are **distinct**. Both have separate native
drains. Sonnet's collapse of them into one call is a hallucination.
Forward each to its own drain.

## Only real gap

`c_walker_move` → `Walker_Move` at `src/zelda_translated/z_07.asm:3763`.
~80 lines of grid/door/tile movement. Genuine drain candidate but not
required to wire dispatch — stub it as PLACEHOLDER for the first commit;
animation, palette, collision, and draw all run with stubbed movement.

## Why A is wrong

Linking `c_shims.asm` (5650 vasm lines) + `zelda_translated/z_*.asm`
(27.5 K lines) for one missing leaf body (`Walker_Move`) drags vasm/gas
syntax friction, NES RAM remap symbols, and an unbounded transitive
chain. Disproportionate when 6 of 7 primitives are already drained.

## Why B (right now) is wrong

Native drain of `Walker_Move` is the *follow-up* commit, not the
unblock. C delivers wired dispatch + 14-cell parity probe today; B
alone defers all probes by 1–2 days for one function.

## Why D is wrong

Master plan Task 7.2 explicitly requires "probe movement and collision."
Init-only dispatch is a statue. D abandons the checklist.

## Apply

Filename collision: `src/game/enemies/enemy_dispatch.c` already exists
(Phase 4 trivial leaves). New file: **`src/game/enemies/enemy_walker_bridge.c`**.

Contents:

```c
#include "combat/link_collision_dispatch.h"
#include "world/draw_dispatch.h"
#include "world/sprite_dispatch.h"
#include "core/core_dispatch.h"
#include "enemy_runtime.h"  /* enrt_wanderer_target_player */

/* PLACEHOLDER — Walker_Move drain candidate at z_07.asm:3763 */
void c_walker_move(unsigned int slot) { (void)slot; }

void c_check_monster_collisions(unsigned int slot)
    { link_collision_check_monster_collisions(slot); }

void c_check_link_collision(unsigned int slot)
    { link_collision_check_link_collision(slot); }

void c_draw_object_not_mirrored_with_frame(unsigned int frame, unsigned int slot)
    { draw_object_not_mirrored_with_frame((unsigned char)frame, slot); }

void c_wanderer_target_player(unsigned int slot)
    { enrt_wanderer_target_player(slot); }

void z07_anim_advance_and_fetch(unsigned int val, unsigned int slot)
    { sprite_anim_advance_and_fetch(val, slot); }

unsigned char z01_anim_set_sprite_desc_attrs(unsigned int val)
    { return core_anim_set_sprite_desc_attrs(val); }

unsigned char z01_abs(unsigned char v)
    { return (v < 128u) ? v : (unsigned char)(-(signed char)v); }
```

Wire `enemy_update_fns[0x07] = enrt_update_rope` (or first walker
UPDATE in family). Add bridge to `tools/debug/build_debug.py`
`ROOMROM_C_SOURCES` as `("src/game/enemies/enemy_walker_bridge.c",
"game_enemy_walker_bridge.o")`.

## Follow-up

Drain `Walker_Move` from `zelda_translated/z_07.asm:3763` into native
`walker_move_native(slot)` in `enemy_walker_bridge.c`. Replace stub.
Probe movement Gate 1 diff vs NES.

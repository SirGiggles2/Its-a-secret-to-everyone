# r001 — Sonnet (pragmatic implementer)

**Vote: C (ASM Bridge / thin forwarder layer in `src/game/enemies/enemy_dispatch.c`)**

---

## What the option list gets wrong

The context table says `c_walker_move`, `c_check_monster_collisions`,
`c_check_link_collision`, `c_draw_object_not_mirrored_with_frame`, and
`c_wanderer_target_player` are vasm shims "NOT linked". That framing is
misleading about what work is actually left:

**Already drained and linked into Debug.md:**

| Symbol oracle calls | Already-linked native equivalent |
|---|---|
| `c_check_monster_collisions` | `link_collision_check_monster_collisions` — `src/game/combat/link_collision_dispatch.c:263` (already in `collision_dispatch.o` + `link_collision_dispatch.o`) |
| `c_check_link_collision` | same module |
| `c_draw_object_not_mirrored_with_frame` | `draw_object_not_mirrored_with_frame` — `src/game/world/draw_dispatch.c:426` (already in `draw_dispatch.o`) |
| `c_wanderer_target_player` | `enrt_wanderer_target_player` — `src/oracle/enemies/enemy_wanderer_runtime.c:63` (already linked as `oracle_enemy_wanderer.o`) |
| `z07_anim_advance_and_fetch` | `sprite_anim_advance_and_fetch` — `src/game/world/sprite_dispatch.c:105` (already in `sprite_dispatch.o`) |
| `z01_abs` | trivially native (one-liner) |

The **only symbol without a drained native body** is `c_walker_move` → `Walker_Move`
at `src/zelda_translated/z_07.asm:3763`. That's ~80 lines of grid/door/tile movement
logic — a real drain, but one function, not a family.

## Why A is wrong

Option A proposes bringing in all 5,650 lines of `c_shims.asm` (vasm syntax, gas
dialect friction) plus `zelda_translated/z_07.asm` (27 K lines total with z_04–z_07).
But 6 of 7 needed symbols are *already in native C in the build*. Dragging in the
entire asm chain for one symbol is wildly disproportionate and risks register-prefix
conflicts (`-x assembler-with-cpp --register-prefix-optional` in build_debug.py vs
vasm `xref`/`xdef` dialect).

## Why B is wrong right now

`Walker_Move` is ~80 lines of grid/boundary/door logic — a legitimate drain candidate.
But B as scoped says "every called primitive." That's a misread — most primitives *are
already drained*. The real B-subset is: drain `Walker_Move` only. That's 1–2 days,
not weeks. But C is still faster because forwarders compile in an hour.

## Why D is wrong

The master plan checklist explicitly requires UPDATE wiring, movement probes, and
collision probes in Task 7.2. `enemy_update_fns` is all-NULL now. Deferring abandons
the checklist and pushes observable octorok movement into some hypothetical Task 7.5
with no forcing function.

## C: what the commit actually looks like

Add `src/game/enemies/enemy_dispatch.c` (new file in `src/game/`, WT-5 compliant):

```c
/* c_walker_move → stub returning immediately (movement-only gate, first probe) */
void c_walker_move(unsigned int slot)  { (void)slot; }    /* PLACEHOLDER */

/* All other symbols: thin forwarders to already-linked drained C */
void c_check_monster_collisions(unsigned int slot)
    { link_collision_check_monster_collisions(slot); }

void c_check_link_collision(unsigned int slot)
    { link_collision_check_monster_collisions(slot); } /* same underlying call */

void c_draw_object_not_mirrored_with_frame(unsigned int frame, unsigned int slot)
    { draw_object_not_mirrored_with_frame((unsigned char)frame, slot); }

void c_wanderer_target_player(unsigned int slot)
    { enrt_wanderer_target_player(slot); }

unsigned char z01_abs(unsigned char v) { return v < 128 ? v : (unsigned char)(-v); }
```

Wire `z07_anim_advance_and_fetch` via the existing `z_07.c` forwarder (already calls
`sprite_anim_advance_and_fetch` when `NATIVE_SPRITE` is set — confirm the define is
active in `build_debug.py` CFLAGS, or add a one-liner in `enemy_dispatch.c`).

This gets `enemy_update_fns[0x07]` wired and `enrt_update_rope` ticking in one commit.
The `c_walker_move` stub means octoroks don't translate yet but all other state
(animation, collision, draw) runs. That's immediately probeable.

**Follow-up commit** (1–2 days later): drain `Walker_Move` from
`zelda_translated/z_07.asm:3763` into a native `walker_move_native(slot)` in
`src/game/enemies/enemy_dispatch.c`, replace the stub. Gate 1 diff vs NES asm is
already identified.

## Build gotcha

`src/oracle/enemies/c_wanderer.c` declares `extern void c_wanderer_target_player` but
calls the symbol that the new `enemy_dispatch.c` will define. `enemy_runtime_private.h`
also declares `extern void c_walker_move`. Both will resolve cleanly once the new TU
is in `ROOMROM_C_SOURCES`. Add it as `("src/game/enemies/enemy_dispatch.c", "game_enemy_dispatch.o")`.

**Bottom line:** C is not "weeks." 5 of 7 symbols are already native — they just need
forwarders. The `c_walker_move` stub is honest: label it PLACEHOLDER in the comment,
write the drain next commit. Octoroks animate and take hits on day 1, move on day 2.

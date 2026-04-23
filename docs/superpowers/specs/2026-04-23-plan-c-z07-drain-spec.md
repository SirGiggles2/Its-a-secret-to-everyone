# Plan C — z_07 drain specification

**Goal:** Promote every non-forwarder function body in `src/gen/z_07.c`
into its long-term owning runtime module. After Plan C, `src/gen/z_07.c`
holds only thin forwarders, and the `emit_gen_wrappers.py` drift gate
owns the whole forwarder block.

**Hard invariant:** ROM hash
`688d95213da3691e09a1b758abdea737a9790ca55b032ff363daaa0b4c6f0bfc`
(baseline `builds/reports/rom_baseline_plan_w.sha256`) stays
byte-identical throughout Plan C unless a batch explicitly documents a
behavior change.

**Depends on:** Plan W complete (tag `plan-w-complete`). All RAM symbol
headers (`enemy_state.h`, `combat_state.h`, `world_state.h`,
`progress_state.h`, etc.) must already exist. Plan B (`z_05`) NOT a
prerequisite — Plan C touches disjoint files.

---

## Current `src/gen/z_07.c` inventory (390 lines, HEAD b3c7fe17)

`tools/gen_wrappers/z_07_manifest.json` is empty (0 forwarders) — Plan W
manifest counted z_07 as 0 because the bank's body shapes don't match
the `{ delegate(args); }` single-call forwarder pattern. Plan C must
both (a) drain the bodies into runtime modules AND (b) populate the
manifest with the new forwarder shells.

Non-forwarder real-logic functions (the **Plan C drain set**, 33 items
+ statics):

| Symbol                                          | Owning module               |
|-------------------------------------------------|-----------------------------|
| `z07_hide_all_sprites`                          | sprite_runtime              |
| `z07_clear_room_history`                        | room_runtime                |
| `z07_reset_player_state`                        | room_player_runtime         |
| `z07_ensure_object_aligned`                     | room_object_runtime         |
| `z07_mark_room_visited`                         | room_runtime                |
| `z07_set_shot_spreading_state`                  | combat_runtime              |
| `z07_roll_over_anim_counter`                    | enemy_common_runtime        |
| `z07_decrement_invincibility_timer`             | combat_runtime              |
| `z07_update_dead_dummy`                         | enemy_common_runtime        |
| `z07_set_shove_info_with0`                      | combat_runtime              |
| `z07_reset_obj_metastate`                       | enemy_common_runtime        |
| `z07_anim_set_obj_hflip`                        | enemy_common_runtime        |
| `z07_reset_obj_metastate_and_timer`             | enemy_common_runtime        |
| `z07_init_flute_secret`                         | enemy_common_runtime        |
| `z07_deactivate_shot`                           | enemy_projectile_runtime    |
| `z07_deactivate_link_shot`                      | enemy_projectile_runtime    |
| `z07_walker_alt_dir_end_loop`                   | enemy_walker_runtime        |
| `z07_reset_shove_info`                          | combat_runtime              |
| `z07_go_to_next_mode`                           | core_runtime                |
| `z07_destroy_monster`                           | enemy_common_runtime        |
| `z07_set_type_and_clear_object`                 | enemy_common_runtime        |
| `z07_init_tile_obj_or_item`                     | room_object_runtime         |
| `z07_anim_advance_and_fetch`                    | enemy_common_runtime        |
| `z07_go_to_next_mode_play_level_song`           | core_runtime                |
| `z07_go_to_next_mode_reset_grid_offset`         | core_runtime                |
| `z07_reverse_obj_dir`                           | enemy_common_runtime        |
| `z07_patch_and_cue_level_palettes_transfer`     | room_transfer_runtime       |
| `z07_do_nothing`                                | (keep as bank-local stub — body is `{}`) |
| `z07_init_grumble`                              | enemy_common_runtime        |
| `z07_init_rupee_stash`                          | item_runtime                |
| `z07_init_mode3_sub1`                           | core_runtime                |
| `z07_animate_object_walking`                    | enemy_common_runtime        |
| `static animate_link_obj_state`                 | room_player_runtime (static)|
| `static const walkable_count`                   | enemy_walker_runtime (move with walker_alt_dir_end_loop) |

Categorization derives from name + cross-reference to existing
`*_runtime.c` symbol prefixes. Verify ownership during Task 0 before
batching.

---

## Drain mechanics (per function)

For each non-forwarder `z07_foo(args) { BODY }`:

1. Pick runtime module per table above.
2. Inside that module's `.c`, add:
   ```c
   <ret> <prefix>_foo(<args>) {
       BODY;
   }
   ```
   where `<prefix>` matches the module:
   - `roomrt_`     → `room_runtime.c`
   - `roompl_`     → `room_player_runtime.c`
   - `roomobj_`    → `room_object_runtime.c`
   - `roomxf_`     → `room_transfer_runtime.c`
   - `core_`       → `core_runtime.c`
   - `combat_`     → `combat_runtime.c`
   - `enemyc_`     → `enemy_common_runtime.c`
   - `enemyw_`     → `enemy_walker_runtime.c`
   - `enemyp_`     → `enemy_projectile_runtime.c`
   - `sprite_`     → `sprite_runtime.c`
   - `item_`       → `item_runtime.c`

   Verify the prefix used by each module by reading its existing exports
   before drain — the table above is the *intended* prefix; if a module
   already uses a different convention (e.g. `obj_` instead of
   `enemyc_`), follow what's there.
3. Declare in the module's `.h`.
4. Replace the old body in `src/gen/z_07.c` with a single-call
   forwarder: `void z07_foo(...) { <prefix>_foo(...); }`.
5. Add forwarder `z07_foo` entry to `tools/gen_wrappers/z_07_manifest.json`.
6. `static animate_link_obj_state` moves verbatim as `static` to
   `room_player_runtime.c`. Rename if a collision exists.
7. `static const walkable_count` moves with `walker_alt_dir_end_loop`
   into `enemy_walker_runtime.c` (file-static).
8. Every RAM access inside the moved body MUST use symbolic names from
   `nes_abi.h` / `*_state.h`. If a raw `RAM(0xNNN)` or `nes_ram[0xNNN]`
   is present, either reuse the existing name or add a new one to the
   matching `*_state.h` header in the SAME commit as the drain.
9. Owned C rule: **owned modules do the real work.** Do not leave a
   thin runtime function that forwards straight back into bank code.

## Batching

Batches grouped by owning module, ordered by ROM-risk (smallest /
single-target first):

1. **C0 — survey & verify ownership table** (no code change). Read each
   z07_ body. Confirm the proposed module owner makes sense given
   actual RAM use. Update spec inline if any owner needs changing.
   **Commit:** none (spec edit only, fold into C1 if needed).

2. **C1 — sprite + room residual** (3 fns):
   `hide_all_sprites`, `clear_room_history`, `mark_room_visited`.
   Owners: sprite_runtime, room_runtime. Lowest blast radius.

3. **C2 — combat / shove / invincibility** (4 fns):
   `set_shot_spreading_state`, `decrement_invincibility_timer`,
   `set_shove_info_with0`, `reset_shove_info`. Owner: combat_runtime.

4. **C3 — projectile / weapon** (2 fns):
   `deactivate_shot`, `deactivate_link_shot`. Owner: enemy_projectile_runtime.

5. **C4 — core / mode flow** (4 fns):
   `go_to_next_mode`, `go_to_next_mode_play_level_song`,
   `go_to_next_mode_reset_grid_offset`, `init_mode3_sub1`.
   Owner: core_runtime.

6. **C5 — walker + transfer + load** (3 fns):
   `walker_alt_dir_end_loop` (+ `walkable_count` static),
   `patch_and_cue_level_palettes_transfer`, `init_tile_obj_or_item`.
   Owners: enemy_walker_runtime, room_transfer_runtime, room_object_runtime.

7. **C6 — player + room object residual** (3 fns):
   `reset_player_state` (+ `animate_link_obj_state` static),
   `ensure_object_aligned`, `init_flute_secret` (if owner clarifies as
   player; else move to enemy_common in C7).

8. **C7 — enemy_common bulk drain** (≈14 fns):
   `roll_over_anim_counter`, `update_dead_dummy`, `reset_obj_metastate`,
   `anim_set_obj_hflip`, `reset_obj_metastate_and_timer`,
   `destroy_monster`, `set_type_and_clear_object`,
   `anim_advance_and_fetch`, `reverse_obj_dir`, `init_grumble`,
   `animate_object_walking`. Owner: enemy_common_runtime. Largest batch
   — split if any single drain raises ROM diff for triage.

9. **C8 — item residual** (1 fn): `init_rupee_stash`. Owner: item_runtime.

10. **C9 — manifest backfill + marker insert**:
    Insert Plan W marker comments into `src/gen/z_07.c` (per Task 9
    Plan W). Re-emit forwarder block via
    `python tools/emit_gen_wrappers.py --bank z_07`. Confirm
    `--check --bank z_07` exits 0. Remove `z_07` from any deferred-list
    note in `tools/gen_wrappers/README.md`.

## Per-batch verification (non-negotiable)

1. `cmd.exe /c ".\build.bat"` passes green.
2. `[gate] OK` appears in build output.
3. `sha256sum builds/whatif.md` == baseline hash from
   `builds/reports/rom_baseline_plan_w.sha256`.
4. `python -m unittest tools.gen_wrappers.test_emit_gen_wrappers` →
   15/15 pass.
5. One commit per batch:
   `promote: z_07 Cn drain of <family> into <module> (Plan C)`.

If any batch produces a ROM diff: STOP, inspect, do not advance. Likely
causes: (a) wrong nes_abi alias for a moved offset, (b) forwarder lost
a return value, (c) static symbol collision silently rebound to a
different `static` of the same name in destination module. All three
recoverable inside the offending batch.

## Post-C completion

- `src/gen/z_07.c` is 100% forwarders inside the auto-wrappers marker
  region (excluding `z07_do_nothing` if kept as bank-local).
- `tools/gen_wrappers/z_07_manifest.json` populated with all
  forwarders.
- `--check --bank z_07` exits 0.
- Tag `plan-c-complete`.
- Update `MEMORY.md` north-star entry to record drain progress.

## Parallelism

Plan C touches `src/gen/z_07.c` + the listed `*_runtime.c` modules.
Safe parallel with Plan B (z_05 → room_*_runtime) provided each batch
commits sequentially on the shared branch and Plan B / Plan C don't
both edit the same runtime module at the same time. Conflict surface:
- `room_runtime.c`     — both plans add to it (C1, B6). Sequence by commit.
- `room_player_runtime.c`  — both (C6, B1).
- `room_transfer_runtime.c` — both (C5, B3).
- `room_object_runtime.c`  — both (C5, B2).
- `core_runtime.c`     — Plan C only.
- `combat_runtime.c`   — Plan C only.
- `enemy_*_runtime.c`  — Plan C only.

If Plan B is running in parallel: Plan C agent should pause batches
that touch `room_*_runtime` until Plan B advances past the
corresponding batch.

## Non-goals

- Behavioral changes. Plan C is a pure refactor with zero ROM drift.
- Renaming existing `z07_*` symbols. Bank-level symbols stay as
  compatibility wrappers forever.
- Touching `src/zelda_translated/z_07.asm`. Plan C is C-side only.
- Fixing the t=172 wall-collision regression. That is its own
  workstream; Plan C cannot be blocked on it because Plan C is
  ROM-identical.

---

## Execution model

Plan C is a candidate for `superpowers:subagent-driven-development` or
for delegating to `codex:codex-rescue`. Per Plan B execution attempt
(2026-04-23): Codex agent dispatched to Plan B did not produce source
changes. For Plan C, prefer either (a) inline execution by the main
session for tight feedback, or (b) re-dispatch with a tighter brief
that includes the per-batch verification commands inline. If Codex
silently stalls again, fall back to inline.

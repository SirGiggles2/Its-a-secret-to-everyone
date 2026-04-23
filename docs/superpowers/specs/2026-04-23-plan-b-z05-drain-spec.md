# Plan B — z_05 drain specification

**Goal:** Promote every non-forwarder function body in `src/gen/z_05.c` into
its long-term owning `room_*_runtime` module. After Plan B, `src/gen/z_05.c`
holds only thin forwarders, and the `emit_gen_wrappers.py` drift gate owns
the whole forwarder block.

**Hard invariant:** ROM hash `c4dd5fe2c2adbf0c10d473b1af1672cc10e6845333fd0218355cf037f0ed2b55`
(baseline `builds/reports/rom_baseline_plan_w.sha256`) stays byte-identical
throughout Plan B unless a batch explicitly documents a behavior change.

**Depends on:** Plan W complete (tag `plan-w-complete`). Plan W delivered
symbolic RAM names (`nes_abi.h`, `room_state.h`, `object_state.h`, etc.),
the `emit_gen_wrappers.py` tool + `z_05_manifest.json` (84 forwarders), and
the build-time drift gate.

---

## Current `src/gen/z_05.c` inventory (497 lines, HEAD 2689e5a8)

Captured in `tools/gen_wrappers/z_05_manifest.json`:

- **84 forwarders**: single-expression bodies `{ roomXX_foo(args); }` or
  `{ return roomXX_foo(args); }`. Already covered by Plan W's manifest —
  NOT in Plan B scope.

Non-forwarder real-logic functions (the **Plan B drain set**, ~25 items):

| Lines       | Symbol                                                | Owning module              |
|-------------|-------------------------------------------------------|----------------------------|
| 19-48       | `z05_copy_column_to_tilebuf`                          | room_transfer_runtime      |
| 50-83       | `z05_copy_row_to_tilebuf`                             | room_transfer_runtime      |
| 91-99       | `static get_room_flags`                               | room_runtime (static)      |
| 101-109     | `static has_item_by_level`                            | room_runtime (static)      |
| 137-139     | `z05_write_and_enable_sprite0`                        | room_runtime               |
| 141-143     | `z05_put_link_behind_background`                      | room_runtime               |
| 149-151     | `z05_cycle9_in_direction`                             | room_runtime               |
| 153-155     | `z05_copy_column_or_row_to_tilebuf`                   | room_transfer_runtime      |
| 157-159     | `z05_init_mode_a_sub_a_go_to_mode4`                   | room_mode_runtime          |
| 161-163     | `z05_reset_inv_obj_state`                             | room_object_runtime        |
| 165-167     | `z05_mask_cur_ppu_mask_grayscale`                     | room_runtime               |
| 169-171     | `z05_fill_play_area_attrs`                            | room_transfer_runtime      |
| 173-175     | `z05_setup_obj_room_bounds`                           | room_object_runtime        |
| 177-179     | `z05_init_link_speed`                                 | room_player_runtime        |
| 181-183     | `z05_update_mode7_scroll_sub2`                        | room_mode_runtime          |
| 185-187     | `z05_update_mode7_scroll_sub7`                        | room_mode_runtime          |
| 189-191     | `z05_fetch_tile_map_addr`                             | room_load_runtime          |
| 193-195     | `z05_copy_play_area_attrs_half`                       | room_transfer_runtime      |
| 197-203     | `z05_inc_submode`, `z05_inc_2_submodes`               | room_mode_runtime          |
| 205-207     | `z05_init_mode4_go_to_sub0`                           | room_mode_runtime          |
| 209-211     | `z05_trigger_open_door`                               | room_runtime               |
| 213-215     | `z05_update_mode11_death_sub6`                        | room_mode_runtime          |
| 217-219     | `z05_reset_vscroll_lo`                                | room_runtime               |
| 221-223     | `z05_select_transfer_buf`                             | room_transfer_runtime      |
| 225-227     | `z05_touch_door_wall`                                 | room_runtime               |
| 229-231     | `z05_select_transfer_buf_and_inc_state`               | room_transfer_runtime      |
| 233-235     | `z05_block_at_wall`                                   | room_player_runtime        |
| 237-243     | `z05_get_player_coords_for_direction`                 | room_player_runtime        |
| 245-247     | `z05_copy_next_row_to_transfer_buf`                   | room_transfer_runtime      |
| 249-251     | `z05_copy_next_row_advance_submode`                   | room_transfer_runtime      |
| 255-257     | `z05_is_distance_safe_to_spawn`                       | room_object_runtime        |
| 259-261     | `z05_set_fade_cycle_and_advance_submode`              | room_mode_runtime          |
| 263-267     | `z05_set_moving_dir_and_switch_to_player_slot`        | room_player_runtime        |
| 269-273     | `z05_link_modify_dir_in_doorway`                      | room_player_runtime        |
| 275-285     | `z05_update_mode11_death_sub_c`                       | room_mode_runtime          |
| 286-292     | `z05_update_mode7_scroll_sub6`                        | room_mode_runtime          |
| 294-297     | `z05_cue_transfer_play_area_attrs_half_and_advance_submode` | room_transfer_runtime |
| 299-307     | `z05_update_mode11_death_sub2`                        | room_mode_runtime          |
| 309-311     | `z05_init_mode10`                                     | room_mode_runtime          |
| 313-315     | `z05_setup_tile_object_ow`                            | room_object_runtime        |
| 317-323     | `z05_world_fill_hearts`                               | room_runtime               |
| 324-339     | `z05_update_menu_common{2,3,4}`, `z05_update_menu5_ow`| room_mode_runtime          |
| 340-342     | `z05_l1433a_inc_submode`                              | room_mode_runtime          |
| 344-349     | `z05_init_mode7_finish`                               | room_mode_runtime          |
| 350-353     | `z05_switch_to_nt1`                                   | room_runtime               |
| 354-371     | `z05_update_mode11_death_{set_timer,sub4,sub5,sub9}`  | room_mode_runtime          |
| 372-374     | `z05_wield_nothing`                                   | room_runtime               |
| 375-378     | `z05_end_prepare_mode`                                | room_mode_runtime          |
| 379-381     | `z05_init_mode9_transfer_attrs`                       | room_transfer_runtime      |
| 383-386     | `z05_start_filling_hearts`                            | room_runtime               |
| 387-391     | `z05_init_mode_b_sub1`                                | room_mode_runtime          |
| 395-397     | `z05_trigger_shutters`                                | room_runtime               |
| 401-421     | `z05_check_secret_trigger_{all_dead,last_boss,money_or_life,block_door,ringleader}` | room_runtime |
| 422-423     | `z05_touch_door_open` (empty body)                    | room_runtime               |
| 424-429     | `z05_touch_door_bombable`                             | room_runtime               |
| 430-437     | `z05_dec_submenu_scroll`                              | room_mode_runtime          |
| 438-445     | `z05_block_until_time`                                | room_player_runtime        |
| 446-457     | `z05_init_mode3_sub{2,6,7}`                           | room_mode_runtime          |
| 458-461     | `z05_update_mode12_end_level_sub1`                    | room_mode_runtime          |
| 462-469     | `z05_touch_door_false`                                | room_runtime               |
| 470-473     | `z05_init_mode_a_sub1`                                | room_mode_runtime          |
| 474-477     | `z05_end_game_mode12`                                 | room_mode_runtime          |
| 478-481     | `z05_touch_door_shutter`                              | room_runtime               |
| 486-497     | `z05_init_mode3_sub{3,4,5}`                           | room_mode_runtime          |

Final Codex pass MUST re-derive this table from current HEAD. The counts
above are snapshotted at HEAD 2689e5a8 and may drift if other work lands
first.

---

## Drain mechanics (per function)

For each non-forwarder `z05_foo(args) { BODY }`:

1. Pick runtime module per table above.
2. Inside that module's `.c`, add:
   ```c
   <ret> roomXX_foo(<args>) {
       BODY;
   }
   ```
   where `roomXX_` prefix matches the module:
   - `roomrt_`  → `room_runtime.c`
   - `roomld_`  → `room_load_runtime.c`
   - `roommd_`  → `room_mode_runtime.c`
   - `roomxf_`  → `room_transfer_runtime.c`
   - `roompl_`  → `room_player_runtime.c`
   - `roomobj_` → `room_object_runtime.c`
3. Declare in the module's `.h`.
4. Delete the old body from `src/gen/z_05.c`.
5. Add forwarder `z05_foo` entry to `tools/gen_wrappers/z_05_manifest.json`.
6. Static helpers (`get_room_flags`, `has_item_by_level`) move verbatim
   as `static` to the destination module, renamed only if a collision exists.
7. Every RAM access inside the moved body MUST use symbolic names from
   `nes_abi.h` / `*_state.h`. If a raw `RAM(0xNNN)` or `nes_ram[0xNNN]` is
   present, either reuse the existing name or add a new one to the matching
   `*_state.h` header in the SAME commit as the drain.
8. Owned C rule: **owned modules do the real work.** Do not leave a thin
   `roomXX_foo` that forwards straight back into bank code.

## Batching

Batches are grouped by owning module. Each batch is one commit, ordered by
ROM-risk (smallest first):

1. **B1 — room_player** (4 fns): `init_link_speed`, `block_at_wall`,
   `get_player_coords_for_direction`, `set_moving_dir_and_switch_to_player_slot`,
   `link_modify_dir_in_doorway`, `block_until_time`.
2. **B2 — room_object** (4 fns): `reset_inv_obj_state`, `setup_obj_room_bounds`,
   `is_distance_safe_to_spawn`, `setup_tile_object_ow`.
3. **B3 — room_transfer** (≈10 fns): `copy_column_to_tilebuf`, `copy_row_to_tilebuf`,
   `copy_column_or_row_to_tilebuf`, `fill_play_area_attrs`, `copy_play_area_attrs_half`,
   `select_transfer_buf{,_and_inc_state}`, `copy_next_row_to_transfer_buf`,
   `copy_next_row_advance_submode`, `cue_transfer_play_area_attrs_half_and_advance_submode`,
   `init_mode9_transfer_attrs`.
4. **B4 — room_mode** (≈25 fns): all `init_mode*`, `update_mode*`,
   `update_menu*`, `inc_submode`, `inc_2_submodes`, `end_game_mode12`,
   `l1433a_inc_submode`, `end_prepare_mode`, `dec_submenu_scroll`.
5. **B5 — room_load** (1 fn): `fetch_tile_map_addr`.
6. **B6 — room_runtime (residual)**: everything else (`write_and_enable_sprite0`,
   `put_link_behind_background`, `cycle9_in_direction`, `mask_cur_ppu_mask_grayscale`,
   `trigger_open_door`, `reset_vscroll_lo`, `touch_door_{wall,open,bombable,shutter,false}`,
   `world_fill_hearts`, `switch_to_nt1`, `wield_nothing`, `start_filling_hearts`,
   `trigger_shutters`, `check_secret_trigger_{all_dead,last_boss,money_or_life,block_door,ringleader}`,
   static `get_room_flags`, `has_item_by_level`).

## Per-batch verification (non-negotiable)

1. `cmd.exe /c ".\build.bat"` passes green.
2. `[gate] OK` appears in build output.
3. `sha256sum builds/whatif.md` == baseline hash from
   `builds/reports/rom_baseline_plan_w.sha256`.
4. `python -m unittest tools.gen_wrappers.test_emit_gen_wrappers` → 15/15 pass.
5. One commit per batch: `promote: z_05 Bn drain of <family> into room_*_runtime (Plan B)`.

If any batch produces a ROM diff: STOP, inspect, do not advance. A drift
here is either (a) a macro/name that subtly changed semantics (e.g. wrong
nes_abi alias) or (b) the wrapper forgot to forward a return value. Both
are recoverable only if caught inside the offending batch.

## Post-B completion

- `src/gen/z_05.c` is 100% forwarders inside the auto-wrappers marker
  region.
- Insert marker comments into `src/gen/z_05.c` per Task 9 of Plan W.
- Remove the "z_05 (no marker region yet)" SKIP branch from gate output by
  editing `tools/gen_wrappers/README.md` to drop z_05 from the deferred list.
- Final commit regenerates the file via `python tools/emit_gen_wrappers.py --bank z_05`
  and confirms `--check --bank z_05` exits 0.
- Tag `plan-b-complete`.

## Parallelism with other agents

Plan B and Plan C (z_07 drain) touch disjoint bank files. Codex working
Plan B in parallel with a Plan C agent is safe as long as each batch commits
in sequence on the shared branch. Do NOT overlap batches inside the same
file — stick to the batch order above.

## Non-goals

- Behavioral changes. Plan B is a pure refactor with zero ROM drift.
- Renaming existing `z05_*` symbols. Bank-level symbols stay as
  compatibility wrappers forever.
- Touching `src/zelda_translated/z_05.asm`. Plan B is C-side only.
- Fixing the pre-existing T34 Genesis parity regression. That is its own
  workstream; Plan B cannot be blocked on it because Plan B is ROM-identical.

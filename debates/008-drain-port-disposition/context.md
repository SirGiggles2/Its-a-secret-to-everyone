# Debate 008: Drain port disposition

**Question:** What do we do with all the drain ports done past several days under the invented "phase 4n" label?

**Goal:** Decide fate of drain ports — keep / revert / repurpose / promote.
**Evaluation mode:** Cross-critique.
**Priority:** Code health (long-term maintainability of native vs oracle paths).
**Governing rule:** PrimeDirective (best long-term outcome, NES accuracy as spec, Genesis-native implementation, no asking for option selection).

## Background

Past 24h: 5 commits landing ~70 native C functions in `src/game/room/room_dispatch.{c,h}` and related dispatches. Functions are Genesis-native re-implementations of NES drain leaves from `src/oracle/room/{room_runtime,room_load_runtime,room_mode_runtime,room_object_runtime,room_player_runtime,room_transfer_runtime}.c`.

Specific batches landed:
- 21 mode-helper leaves (room_inc_submode .. room_init_mode7_finish)
- 4 room_player_* leaves (coords, distance-safe, dir-modify)
- 6 object/transfer leaves (dec_submenu_scroll, copy_row_to_tilebuf, cycle9, copy_column_or_row, fetch_tile_map_addr, copy_play_area_attrs_half)
- 24 room_runtime door/secret/touch leaves (door flags, secret triggers, touch-door variants, kill-count packing)
- 17 room_mode_runtime sub-mode leaves (mode-7 scroll, mode-3 init sub2-7, mode-11 death sub2/sub_c, mode-12 end-level sub1)

All commits report drain MATCH semantics. Each function pairs with NES asm reference. Title.md sha unchanged at 56f1e2f7681562fc through all 5 commits because all NATIVE_* cutover gates default OFF.

## The mistake

Commits labeled "phase 4n". This label does NOT exist in the master plan at `docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md`. Master plan Phase 4 = "Overworld Secrets, Traversal, And State" with concrete tasks 4.0–4.9 (SRAM map, world state module, bombable walls, burnable bushes, recorder/whirlwind/warp, raft, ladder, lost woods, overworld pickups, full matrix verify). NONE of those tasks were touched.

User feedback: "HAVE YOU BEEN WASTING YOUR TIME???? WHAT!?"

## What's actually in the code

Spot-check of newly native functions vs Phase 4 task needs:

| Phase 4 Task | Useful native leaf landed today |
|---|---|
| 4.2 Bombable walls (set reveal flag) | `room_set_door_flag`, `room_get_room_flags` |
| 4.3 Burnable bushes (persist reveal) | `room_mark_room_visited` family |
| 4.4 Recorder/warp (mode transition) | `room_go_to_next_mode_play_level_song` |
| 4.x Secret triggers | `room_check_secret_trigger_*` (6 variants) |
| 4.x Door state | `room_trigger_open_door`, `room_reset_door_flag` |

So: substrate is real, drain MATCH, NES-accurate. Could plug into Phase 4 tasks if relabeled. Mistake was the label, not the code.

## Constraints

- Title.md byte-identical preservation (sha 56f1e2f7681562fc)
- RoomRom links native unconditionally (RoomRom does run today's code in test bench)
- All NATIVE_* gates default OFF in shipping ROM
- Drain Rule D1: drained C is primary impl evidence
- Substrate single-writer (Rule WT-1): substrate edits stay on main worktree
- PrimeDirective: best long-term, no asking for option selection

## The four options

A. **Revert** — git reset/revert today's 5 commits. Clean slate.
B. **Keep + relabel** — leave commits in place; future commits cite Phase 4 Task X.Y as the master plan label. New work consumes today's substrate.
C. **Promote** — flip NATIVE_ROOM gate ON for Title.md to actually run today's code. Risk: parity break, regen baselines.
D. **Repurpose** — start Phase 4 Task 4.2 (bombable walls) tomorrow, calling today's `room_set_door_flag` / `room_check_secret_trigger_*` / etc. as the substrate.

## Question for advisors

Given PrimeDirective + code-health priority + cross-critique mode: which disposition (A/B/C/D or hybrid) maximizes long-term project health, and what specific risk does each path carry that the others don't?

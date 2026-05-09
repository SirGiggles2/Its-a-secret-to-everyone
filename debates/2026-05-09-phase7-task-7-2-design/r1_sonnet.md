# Round 1 — Sonnet verdict
# Phase 7 Task 7.2 step 2 — enemy loop framework

## Q1 — Spawn data source: **(b) Hardcoded test table**

A 40-LOC `enemy_test_spawns.c` with 1-2 slow octoroks is the correct first move. Option (a)'s failure mode is premature generalization: porting the full ObjListAddrs+ObjLists corpus before the iterator, shim stack, and OAM routing are verified buries real bugs under data complexity. Option (c) fails worse — grafting enemy arrays onto `overworld.c` blob couples spawn-data lifetime to room-render state, which is semantically wrong and will require untangling later.

## Q2 — Iterator placement: **(c) Scroll-stable branch only**

Enemy ticks must be gated on `s_scroll_state == SCROLL_NONE` to match NES `IsSprite0CheckActive` behavior at Z_07.asm:496. Option (a) is the weakest: ticking enemies immediately after `level_chr_swap_tick` but before scroll finalization lets walkers move and draw during a mid-transition frame where BG coordinates are in flux — the resulting OAM writes land at the wrong pixel coordinates and produce a one-frame ghost visible in screenshots.

## Q3 — Type dispatch: **(a) Switch statement**

A switch on `ENEMY_TYPE` is the correct shape for the current drain coverage. The function-pointer table (option b) is the long-term NES-mirror shape but its failure mode right now is index-out-of-bounds silence: with only the walker family drained, entries 0-$40+ are null; a stray slot with an undrained type silently calls address 0. The hybrid (c) adds an extra dispatch layer with no current payoff. Start with switch; promote to table at Gate 3 when all 70+ entries are drained.

## Q4 — First probe room: **(c) Overworld $7C**

OW $7C has a slow octorok column, matches `enrt_init_slow_octorock_or_ghini`, and produces observable walker movement within ~10 frames of spawn — the shortest path to a meaningful parity screenshot. Option (a) has no enemies natively, making it a dead probe. Option (b) requires UW teleport debug scaffolding and introduces stalfos/goriya that need undrained families — it would force GREENFIELD stances that Rule D1 bans.

## Q5 — Substrate edit: **(b) Reserve enemy sprite-slot range in `roomrom_vram_map.h`**

Reserving a slot range is the minimal adjacent edit that prevents SGDK's sprite allocator from handing out the same slots the enemy system writes. Option (a) — no substrate touch — will produce invisible or corrupted sprites the moment `z01_anim_set_sprite_desc_attrs` writes SAT entries that conflict with Link's SGDK-managed slots; this is the shim-collision risk the topic flags explicitly. Option (c) is premature: adding a CHR bank dispatch hook before the first octorok even renders pulls PR-4b scope forward with no verified consumer.

## Integrated framework recommendation

Wire a minimal `enemy_debug_tick(void)` function into `roomrom_debug_tick` inside the `s_scroll_state == SCROLL_NONE` gate, after `level_chr_boss_tick`. This function iterates slots 1..11, checks `ENEMY_TYPE(slot)` in a switch, and dispatches to `enrt_init_slow_octorock_or_ghini` on first frame then `enrt_update_common_wanderer` each subsequent frame. Spawn data is a 2-entry static array in `RoomRom/data/enemy_test_spawns.c` seeded for OW $7C, written once on room-load. Before the first build, add one line to `roomrom_vram_map.h` reserving SAT slots N..N+3 for enemy use so SGDK's allocator cannot collide. The Gate 1 drain-findings doc for this task must include a per-function diff of `enrt_init_walker` and `enrt_update_common_wanderer` against Z_07.asm:5466-5680 before the commit lands — option (b) hardcoded spawns and option (c) scroll-gate together keep that diff tight and the failure surface narrow enough to read in a single BizHawk screenshot.

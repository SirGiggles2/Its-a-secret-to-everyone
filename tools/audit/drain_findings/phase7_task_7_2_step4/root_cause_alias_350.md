# Phase 7 Task 7.2 step 4 — root-cause finding

## Symptom (pre-fix)

`probe_walker_tick_trace.lua` reported G4 + G5 FAIL across 13 samples
spanning 120 frames:
- `ENEMY_TYPE(1)` read $00 in every per-frame tick despite the init
  probe at boot writing $07 and the 14/14 init probe verifier passing.
- `ENEMY_ANIM_TIMER(1)` and `ENEMY_DRAW_FRAME(1)` never advanced — the
  type=0 caused the slot dispatch in `enemy_loop_tick()` to fall through
  the NULL check (`if (t >= ENEMY_LOOP_TYPE_MAX) continue;` actually
  passes for $00, but `enemy_update_fns[0] == NULL` skips the call).

## Diagnostic ladder

1. Confirmed publisher fired (`magic 'TK'`) and frame_counter advanced —
   tick path is hot.
2. Adjacent slot-1 cells survived: `ALIVE_FLAG(1)=1`, `X(1)=$80`,
   `Y(1)=$80`, `DIR(1)=$02`, `ANIM_TIMER(1)=6`, `WALK_SPEED(1)=$20`.
   Wholesale slot wipe ruled out — clear was *targeted* to `$0350`.
3. Added `enemy_loop_probe_publish_pre()` at start of `enemy_loop_tick()`.
   Pre and post both showed type=$00 — clear happened BEFORE the first
   tick, not inside it.
4. Added Lua-side raw absolute read of `$FF0350` and a probe-side raw
   pointer read. Confirmed cell read $00 across all four sources at the
   first tick.
5. Grep for writes to `ENEMY_TYPE`, `NES_OBJ_TYPE_BASE`, and `RAM(0x0350)`
   surfaced `src/state/cave_state.h:83`:
   ```c
   static inline void cave_room_type_set(uint8_t v) { RAM(0x0350) = v; }
   ```
6. `cave_exit()` at `src/game/cave/cave_dispatch.c:104` calls
   `cave_room_type_set(0u)` — writes 0 to the same byte that
   `ENEMY_TYPE(1)` aliases.

## NES alias rationale (why this is correct, not a bug)

NES Zelda 1 RAM cell `$0350`:
- `CaveRoomType` (cave gamemode) — `src/state/cave_state.h:82-83`,
  derived from `reference/aldonunez/Z_01.asm:80`.
- `ObjType+1` = `ENEMY_TYPE(1)` (gameplay gamemode) —
  `src/abi/platform_abi.h:80` (`NES_OBJ_TYPE = 0x034F`),
  `src/state/enemy_state.h:19` (`ENEMY_TYPE(slot) = OBJ(NES_OBJ_TYPE, slot)`).

NES intentionally aliases these because cave and gameplay gamemodes are
mutually exclusive at runtime. The alias is a documented invariant
per `reference/aldonunez/ObjVars.inc` and the project's
`docs/audit/enemy_alias_table.md`.

## Fix (root-cause, not bypass)

`RoomRom/src/main.c:1206-1218` — reorder boot init so cave smoke
(`cave_init/cave_tick/cave_exit`) runs BEFORE `enemy_loop_probe_run()`,
not after. Probe seed must be the LAST init op so its writes survive
into the per-frame tick window.

Per Drain Rule D1: this is `Stance: EXTEND`. The cave smoke and the
enemy probe seed both legitimately write `$0350`; the ordering is what
matters. NES never has both live simultaneously, so cave_exit clearing
$0350 is correct cave-side teardown — but in our boot smoke the cave
runs to completion (init→tick→exit) before any enemy is spawned, so
moving probe_run after cave_exit restores the NES invariant: only one
gamemode owns $0350 at any time.

## Verification

`probe_walker_tick_trace_PASS.txt`:
- G1 magic 'TK' (publisher fired) — PASS
- G2 frame_counter advanced (19 → 75) — PASS
- G3 ENEMY_ALIVE_FLAG(1) stays 1 — PASS
- G4 ENEMY_TYPE(1) stays $07 — PASS (was FAIL pre-fix)
- G5 anim_timer OR draw_frame advanced — PASS (was FAIL pre-fix)
  - anim_timer cycle: 7→2→7→3→8→4→9→4→10→5→10→6→1
  - draw_frame toggle: $00↔$01

UPDATE chain confirmed end-to-end:
`enemy_loop_tick` → dispatch table `enemy_update_fns[$07]` →
`enrt_update_rope` → `c_walker_move` (PLACEHOLDER) +
`z07_anim_advance_and_fetch` → `sprite_anim_advance_and_fetch` (advances
ANIM_TIMER, flips DRAW_FRAME) + `z01_anim_set_sprite_desc_attrs` +
`c_draw_object_not_mirrored_with_frame` (no oam_router yet — visual
gap separately tracked) + `c_check_monster_collisions`.

## Open observation (deferred — not blocking)

Trace shows `type(pre/post/raw/lua)=$07/$07/$00/$00`. C-side macro
reads (via A4-pinned `nes_ram` register) report $07; the absolute
pointer reads at `$FF0350` (both probe-side `*(volatile unsigned char *)
0x00FF0350UL` and BizHawk Lua `memory.read_u8(0x0350, "68K RAM")`)
report $00.

Implication: `nes_ram` (A4) is NOT pinned at `$FF0000` in the Debug.md
build despite `src/genesis_shell.asm:34` setting it there. The cell that
backs `ENEMY_TYPE(1)` lives somewhere else in 68K RAM (possibly a BSS
array — the `ROOMROM_BUILD`-gated `roomrom_nes_ram[0x800]` from
`RoomRom/src/boot/nes_ram_init.c`, even though Debug.md doesn't define
`ROOMROM_BUILD`).

Not blocking step 4 — game logic uses the macro, which is consistent.
But probes that read raw `$FF0350` (or any other A4-relative cell) are
reading garbage. Worth a follow-up audit of where `nes_ram` actually
points in Debug.md before any future absolute-address probe.

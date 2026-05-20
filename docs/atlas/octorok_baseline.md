# Octorok Parity Baseline — Room $67

Captured 2026-05-19 via `build/probes/nes_octorok_baseline.lua` + `gen_octorok_baseline.lua`.
NES = `roms/Legend of Zelda, The (USA).nes`. Genesis = `builds/Debug.md`.

Room $67 (overworld, 4 slow red octoroks ObjType $07).

## Frame 0 (room enter)

| slot | NES ObjType | NES X | NES Y | NES dir | GEN ObjType | GEN X | GEN Y | GEN dir |
|------|-------------|-------|-------|---------|-------------|-------|-------|---------|
| 1    | $07         | $67   | $43   | $06     | $07         | $64   | $31   | $00     |
| 2    | $07         | $77   | $00   | $11     | $07         | $52   | $00   | $08     |
| 3    | $07         | $70   | $00   | $0D     | $07         | $90   | $00   | $08     |
| 4    | $07         | $80   | $00   | $0B     | $07         | $80   | $49   | $00     |

## Divergences

**D1 — Spawn X positions wrong.** Slot 1 NES $67 vs GEN $64; slot 2 NES $77 vs GEN $52; slot 3 NES $70 vs GEN $90. Off-by-arbitrary-margin = wrong spawn list / wrong index in spawn_pos_lists.

**D2 — Slot 4 enters visible instead of waiting offscreen.** NES Y=$00 (uninitialized, waiting to enter via UpdateObject + FindNextEdgeSpawnCell). Genesis Y=$49 (already on-screen). Substrate gap per `obj_lists.c:387-399`: NES per-frame UpdateObject loop checks `ObjUninitialized` and calls FindNextEdgeSpawnCell (Z_05.asm:3406) each frame until a walkable edge cell found. Genesis short-circuits to spawn_pos_list_0 fallback, pre-placing all enemies at room load.

**D3 — ObjDir wrong across all 4 slots.** NES init dir values: $06, $11, $0D, $0B (per-slot Wanderer_TargetPlayer output). Genesis: $00, $08, $08, $00 (initialized to default-or-stale-value). Could be `enrt_init_walker` (enemy_walker_runtime.c) not computing dir per NES InitObject path.

**D4 — Visual explosion sprite in Genesis screenshot.** Genesis renders one octorok as "exploded" tile (red splat). Possible ObjState/ObjFrame routing bug; one octorok mis-classified as dying.

## Matches

**M1 — ObjType $07 consistent across 4 slots.** Room load → spawn list parse → enemy_init_fns dispatch chain delivers correct type. obj_lists.c:226-291 load_objects PASSES this audit.

**M2 — ObjQSpeedFrac $26 on both.** Slow octorok base speed value matches. (Note: fast octorok speed mismatch hypothesized at $40 vs $60 is for ObjType $08 — not testable in room $67 which has only $07.)

## Fix priority

1. **D2 + D1** = same root cause (substrate gap). Port `FindNextEdgeSpawnCell` from Z_05.asm:3406. Task O4 in master plan, ~2-4 hr.
2. **D3** = investigate `enrt_init_walker` in `src/oracle/enemies/enemy_walker_runtime.c`. Compare to NES InitSlowOctorockOrGhini (Z_04.asm:1864) — Wanderer_TargetPlayer dir-compute logic.
3. **D4** = ObjState routing audit; likely cascade from D1/D2 (wrong position → spawn-as-dying inference somewhere).

## Capture artifacts

- `C:/tmp/octorok_baseline_nes.txt` + `.png`
- `C:/tmp/octorok_baseline_gen.txt` + `.png`
- Probes: `build/probes/nes_octorok_baseline.lua`, `build/probes/gen_octorok_baseline.lua`

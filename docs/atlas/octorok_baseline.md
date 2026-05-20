# Octorok Parity Baseline — Room $67

Captured 2026-05-19 via `build/probes/nes_octorok_baseline.lua` + `gen_octorok_baseline.lua`.
NES = `roms/Legend of Zelda, The (USA).nes`. Genesis = `builds/Debug.md`.

Room $67 (overworld, 4 slow red octoroks ObjType $07).

**ADDR FIX 2026-05-19**: prior baseline used wrong RAM addresses for ObjY
($0028 was ObjTimer, not ObjY) and ObjDir ($0008 was random ZP). Per
`reference/aldonunez/Variables.inc`: ObjY = $0084, ObjDir = $0098,
ObjState = $00AC, ObjTimer = $0028, ObjQSpeedFrac = $03BC,
ObjAnimFrame = $03E4. All addresses below corrected.

## Frame 0 (room enter)

| slot | NES type/X/Y/dir/timer/qspd/aFr | GEN type/X/Y/dir/timer/qspd/aFr |
|------|----------------------------------|----------------------------------|
| 1    | $07 $67 $5D $01 $43 $20 $03      | $07 $64 $5D $02 $31 $20 $03      |
| 2    | $07 $77 $9D $01 $00 $20 $03      | $07 $52 $5D $01 $00 $20 $00      |
| 3    | $07 $70 $87 $04 $00 $00 $00      | $07 $90 $67 $04 $00 $20 $03      |
| 4    | $07 $80 (later)                  | $07 $80 (later)                  |

LBA_F[$67] = $40 on BOTH (bit 3 CLEAR). So edge-spawn branch NOT taken —
both ROMs use normal spawn loop with `is_safe_to_spawn`.

## Divergences (post addr-fix)

**D1 — Slot 2 + 3 spawn positions WAY off.**
- Slot 2: NES X=$77 Y=$9D vs GEN X=$52 Y=$5D ($25 X diff, $40 Y diff)
- Slot 3: NES X=$70 Y=$87 vs GEN X=$90 Y=$67
- Slot 1 minor ($67 vs $64, X off-by-3) — could be one walker-step difference

Both ROMs use the same `is_safe_to_spawn` loop (LBA_F bit3 CLEAR). Different spawn_pos_list cycle index OR `is_safe_to_spawn` semantics drift produces different placement.

**D2 — Slot 1 dir WRONG.** NES $01 (Right) vs Gen $02 (Left). Same Link facing → same spawn list, so dir-init diverges. Look at `enrt_init_walker` direction-compute logic vs NES `InitWalker` (Z_04.asm).

**D3 — Slot 3 over-initialized on Genesis.** NES has qspd=$00 aFr=$00 (not yet init'd); Gen has qspd=$20 aFr=$03 (InitSlowOctorock already ran). Suggests Genesis enemy_init_fns dispatch order/timing differs — fires all N inits at room load, NES staggers via spawn cloud timer.

**D4 — Visual "explosion" sprite in Genesis screenshot.** Cascades from D3: Gen slot 3 fully initialized but at wrong position → may render with anim-frame inconsistent with state.

## Matches

**M1 — ObjType $07 consistent across 4 slots.** Room load → spawn list parse → enemy_init_fns dispatch chain delivers correct type. obj_lists.c:226-291 load_objects PASSES this audit.

**M2 — ObjQSpeedFrac $26 on both.** Slow octorok base speed value matches. (Note: fast octorok speed mismatch hypothesized at $40 vs $60 is for ObjType $08 — not testable in room $67 which has only $07.)

## Fix priority (revised post addr-fix)

1. **D1** = spawn position drift via `is_safe_to_spawn` semantics OR
   `DUNGEON_SPAWN_CYCLE` value differs at room enter. Investigate
   `obj_lists.c:332 is_safe_to_spawn` vs NES `IsSafeToSpawn`
   (Z_05.asm:2006) byte-for-byte. Check `DUNGEON_SPAWN_CYCLE`
   persistence across room transitions.
2. **D3** = staggered init via spawn-cloud `ObjTimer = (slot+1)*16`.
   NES holds enemy in cloud state until timer expires, then triggers
   per-slot init. Genesis fires `enemy_init_fns` synchronously at room
   load. Either:
   - Defer init via per-slot timer in enemy_loop, OR
   - Run InitSlowOctorock then mark "in cloud" via ObjState to delay
     visible-active state.
3. **D2** = small dir diff cascades from D1 (different position → different Wanderer init direction). Fix D1 first.
4. **D4** = cascades from D3 (wrong-anim-frame on partially-init slot).

Substrate gap (edge-spawn LBA_F bit3) is NOT applicable for room $67 — both ROMs use same path. Original suspicion in plan v1 invalidated.

## Capture artifacts

- `C:/tmp/octorok_baseline_nes.txt` + `.png`
- `C:/tmp/octorok_baseline_gen.txt` + `.png`
- Probes: `build/probes/nes_octorok_baseline.lua`, `build/probes/gen_octorok_baseline.lua`

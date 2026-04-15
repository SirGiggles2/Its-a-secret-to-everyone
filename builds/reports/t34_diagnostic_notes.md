# T34 Movement Parity — Diagnostic Notes

**Status:** 5/8 gates PASS, 3 FAIL. Infrastructure complete. Root-cause diagnosis below.

## Gate results

| Gate | Result | Detail |
|------|--------|--------|
| T34_NES_CAPTURE_OK | PASS | 361 frames captured |
| T34_GEN_CAPTURE_OK | PASS | 361 frames captured |
| T34_NO_GEN_EXCEPTION | PASS | no exception |
| T34_BASELINE_PARITY | PASS | both cores spawn at (x=$78, y=$8D, dir=$00) |
| T34_OBJINPUTDIR_PARITY | PASS | `$03F8` matches across all 361 frames |
| **T34_HELD_BUTTONS_PARITY** | **FAIL** | first diff t=211 (Left phase start): NES=$02 Gen=$00 |
| **T34_OBJX_PARITY** | **FAIL** | first diff t=211, cascades from held-bit miss |
| **T34_OBJY_PARITY** | **FAIL** | first diff t=172 (Down phase): NES=$BD Gen=$BE |

## Key findings

### 1. `$F8` is **newly-pressed**, not held
Both cores show `$F8 = $01` at t=61 (first frame of Right) then `$00` in subsequent frames despite button still held. `ReadOneController` at [z_07.asm:1787](../../src/zelda_translated/z_07.asm) computes:
```
$F8 = (new_held ^ $FA) & new_held    ; = new_held & ~prev_held
$FA = new_held                         ; prev for next frame
```

### 2. Directional inputs observed on Gen
- Right ($01) at t=61: PASS
- Down ($04) at t=136: PASS
- **Left ($02) at t=211: FAIL (read as $00)**
- Up ($08) at t=286: PASS

ObjInputDir ($03F8) is populated correctly on all 4 directions — `Link_HandleInput` reads from a path that bypasses the `$F8` newly-pressed mask.

### 3. Root cause hypothesis for Left-bit failure
Gen's `$FA` (previous-held mask) must contain the Left bit at t=210, so newly = new & ~prev = $02 & ~$02 = $00. Possible sources:
- `$FA` uninitialized on Gen boot with Left bit set
- Accumulated state in `$F8` from pre-capture boot sequence leaking into `$FA`
- `ReadOneController` debounce loop ($03+D2 counter) reacts differently when Gen's controller bits don't perfectly match NES's 3-frame-same requirement

### 4. Down-phase Y divergence (t=172)
Y advances 1 pixel further on Gen than NES at t=172. Independent of Left-bit issue. Likely:
- `MoveObject` / `Walker_Move` speed table or carry-flag inversion in transpiled Y+ branch
- Collision detection differs by 1 tile boundary

## Next steps

1. **Add `$FA` + `$00` tracing** to Gen capture to pinpoint when prev-mask picks up Left bit
2. **Inspect _ctrl_strobe / ReadOneController debounce** interaction with BizHawk 3-button controller emulation
3. **Rewrite `ReadOneController` natively** per `feedback_full_native_rewrite` — the original 6502 "three reads in a row" debounce was for noisy real NES hardware; on Genesis with synthesized latch it just adds frames of delay and state pollution
4. **Separate diagnostic probe** for Down speed to isolate from Left-bit issue

## Artifacts

- `builds/reports/t34_movement_nes_capture.{json,txt,png}` — NES reference trace (361f)
- `builds/reports/t34_movement_gen_capture.{json,txt,png}` — Genesis trace (361f, no exception)
- `builds/reports/t34_movement_parity_report.{json,txt}` — 8-gate comparator output
- `tools/t34_input_scenario.lua` — shared scripted D-pad sequence
- `tools/bizhawk_t34_movement_nes_capture.lua` — NES capture probe
- `tools/bizhawk_t34_movement_gen_capture.lua` — Gen capture probe (+exception guard +SAT checkpoints)
- `tools/compare_t34_movement_parity.py` — byte-parity comparator

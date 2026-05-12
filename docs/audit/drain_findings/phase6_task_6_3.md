# Phase 6 Task 6.3 - Sword Verification

- **NES source**: `reference/aldonunez/Z_05.asm` WieldSword; `reference/aldonunez/Z_07.asm` UpdateSwordOrRod (line 4337 PlayerToWeaponOffsets); `Z_07.asm` UpdateSwordShotOrMagicShot + MakeSwordShot (line 4581)
- **Drained C**:  N/A - sword/beam are RoomRom-native (`RoomRom/src/roomrom_combat.c`)
- **Coverage**:   FULL (sword/beam timings, full-HP beam gate, speed, despawn, and palette flash mirrored)
- **Stance**:     ADOPT (NES state-machine timings + sword-tip offsets + beam speed + bounds despawn all mirrored)

## Verified parity

| NES behavior | NES anchor | RoomRom impl | Status |
| --- | --- | --- | --- |
| Sword swing 16-frame total window (5+8+1+1+1) | `Z_05.asm` WieldSword + `Z_07.asm` UpdateSwordOrRod | `RoomRom/src/roomrom_combat.c` COMBAT_STATEn_FRAMES; state 1 reduced to 0 per documented BizHawk verification (NES sword sprite first appears at extend, not windup) | PASS (with 5-frame visual delta documented) |
| Stab state machine (idle to active to state 1..5 to idle) | `Z_07.asm` UpdateSwordOrRod state dispatch | `combat_state_t` + `compute_state(frame)` + per-state sprite render | PASS |
| Sword-tip offsets per face per state | `Z_07.asm:4337` PlayerToWeaponOffsetsX/Y | `sword_offset_x` / `sword_offset_y` tables | PASS |
| Animation: state-1 windup vertical no-flip (UP regardless of face) | `Z_07.asm` UpdateSwordOrRod state 1 | Unreachable because state 1 = 0 frames | SKIPPED to match observed NES behavior |
| Body pose swap during swing (states 1..4 attack, state 5 walk) | `Z_05.asm` WieldSword body-tile swap | `roomrom_sprites_set_link_attack_pose` | PASS |
| Re-swing locked through full active window | NES `s_state != IDLE` guard | `roomrom_combat_try_swing` uses `if (s_state != COMBAT_IDLE) return;` | PASS |
| Beam spawn at end of state 2 | `Z_07.asm` MakeSwordShot trigger | `BEAM_FRAME_SPAWN` | PASS |
| Beam speed 3 px/frame (q-speed $C0) | `Z_07.asm` UpdateSwordShotOrMagicShot | `BEAM_SPEED_PX 3` | PASS |
| Beam direction = sword facing | `Z_07.asm` MakeSwordShot inherits ObjDir | `s_beam_face = s_face` in `spawn_beam` | PASS |
| Beam color flash (FrameCounter & 3 -> sub-pal index) | `Z_07.asm:3459` ATTR \| (FrameCounter & 3) | `s_beam_palette_phase` cycle 0..3 + CRAM rewrite (Genesis cannot bank-switch via attr bits) | PASS |
| Beam despawn off-screen | NES bound check vs PlayfieldRect | RoomRom bounds despawn | PASS |
| OW Y-bias (-2) vs UW (0) sword/beam draw | `Z_07.asm:3320` Link draw increments Y twice in OW only | `s_uw_y_bias` | PASS |
| Redux ALttP-style 8-frame arc swing (option mode) | New | Separate state machine | PASS (option toggle) |
| Beam spawn gated on full HP (`ObjHP[0] == MaxHP`) | `Z_07.asm` UpdateSwordShotOrMagicShot HP check | `sword_style_allows_beam()` uses `options_consumer_get_sword_style()`: vanilla requires `heart_values_cur(hv) == heart_values_max(hv)` and `g_inventory.heart_partial == 0u`; option modes can suppress or always allow beams | PASS |

## Deferred (Task 6.3-followup)

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Beam collision with enemies | `Z_07.asm` SwordShot vs ObjType collision | Combat collision is roomrom_combat dispatch territory; enemy slots wired in Task 6.4 | Task 6.4 (Combat) |

## Probe / contract

- `tools/debug/test_sword_contract.py` - static contract: asserts the
  active swing window, beam spawn frame, beam speed, bounds, palette flash,
  and the vanilla full-HP beam gate plus option overrides.

## Gate

- 4-line task header: filled.
- Gate 1 per-function diff: not applicable (RoomRom-native).
- Gate 2 RAM-cell trace: deferred to phase exit.
- Gate 3 scenario oracle: deferred to milestone tag.

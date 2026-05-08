# Phase 6 Task 6.3 — Sword Verification

- **NES source**: `reference/aldonunez/Z_05.asm` WieldSword; `reference/aldonunez/Z_07.asm` UpdateSwordOrRod (line 4337 PlayerToWeaponOffsets); `Z_07.asm` UpdateSwordShotOrMagicShot + MakeSwordShot (line 4581)
- **Drained C**:  N/A — sword/beam are RoomRom-native (`RoomRom/src/roomrom_combat.c`)
- **Coverage**:   PARTIAL (HP-gated beam deferred to Task 6.11, otherwise FULL)
- **Stance**:     ADOPT (NES state-machine timings + sword-tip offsets + beam speed + bounds despawn all mirrored)

## Verified parity

| NES behavior | NES anchor | RoomRom impl | Status |
| --- | --- | --- | --- |
| Sword swing 16-frame total window (5+8+1+1+1) | `Z_05.asm` WieldSword + `Z_07.asm` UpdateSwordOrRod | `RoomRom/src/roomrom_combat.c:41-48` COMBAT_STATEn_FRAMES; state 1 reduced to 0 per documented BizHawk verification (NES sword sprite first appears at extend, not windup) | ✅ (with 5-frame visual delta documented) |
| Stab state machine (idle → active → state 1..5 → idle) | `Z_07.asm` UpdateSwordOrRod state dispatch | `combat_state_t` + `compute_state(frame)` + per-state sprite render | ✅ |
| Sword-tip offsets per face per state | `Z_07.asm:4337` PlayerToWeaponOffsetsX/Y | `sword_offset_x` / `sword_offset_y` tables, lines 220-242 | ✅ |
| Animation: state-1 windup vertical no-flip (UP regardless of face) | `Z_07.asm` UpdateSwordOrRod state 1 | `roomrom_combat.c:418-421` (currently unreachable since state 1 = 0 frames) | ⚠ skipped to match observed NES behavior |
| Body pose swap during swing (states 1..4 attack, state 5 walk) | `Z_05.asm` WieldSword body-tile swap | `roomrom_combat.c:404-408` `roomrom_sprites_set_link_attack_pose` | ✅ |
| Re-swing locked through full 16-frame window | NES `s_state != IDLE` guard | `roomrom_combat_try_swing` line 256 | ✅ |
| Beam spawn at end of state 2 (frame 13) | `Z_07.asm` MakeSwordShot trigger | `BEAM_FRAME_SPAWN` line 65 | ✅ |
| Beam speed 3 px/frame (q-speed $C0) | `Z_07.asm` UpdateSwordShotOrMagicShot | `BEAM_SPEED_PX 3` line 66 | ✅ |
| Beam direction = sword facing | `Z_07.asm` MakeSwordShot inherits ObjDir | `s_beam_face = s_face` in `spawn_beam` | ✅ |
| Beam color flash (FrameCounter & 3 → sub-pal index) | `Z_07.asm:3459` ATTR \| (FrameCounter & 3) | `s_beam_palette_phase` cycle 0..3 + CRAM rewrite (Genesis can't bank-switch via attr bits) | ✅ |
| Beam despawn off-screen | NES bound check vs PlayfieldRect | RoomRom bounds despawn lines 299-304 | ✅ |
| OW Y-bias (-2) vs UW (0) sword/beam draw | `Z_07.asm:3320` Link draw INC twice OW only | `s_uw_y_bias` line 87 | ✅ |
| Redux ALttP-style 8-frame arc swing (option mode) | New | `roomrom_combat.c:350-400` separate state machine | ✅ (option toggle) |

## Deferred (Task 6.3-followup)

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Beam spawn gated on full HP (`ObjHP[0] == MaxHP`) | `Z_07.asm` UpdateSwordShotOrMagicShot HP check | RoomRom has no HP system yet — `players[0].hp` cell exists (Task 6.1) but no producer/consumer; `s_redux` swing currently always spawns beam | Phase 6 Task 6.11 (Damage, Death, Drops) — HP system lands there; gate becomes `players[0].hp == g_link_max_hp` |
| Beam collision with enemies | `Z_07.asm` SwordShot vs ObjType collision | Combat collision is roomrom_combat dispatch territory; enemy slots wired in Task 6.4 | Task 6.4 (Combat) |

The hp gate's home is line 446 of `roomrom_combat.c` (currently `if (s_frame == BEAM_FRAME_SPAWN && !s_beam_active)`), which becomes
`if (s_frame == BEAM_FRAME_SPAWN && !s_beam_active && players[0].hp == g_link_max_hp)` once 6.11 introduces the constant.

## Probe / contract

- `tools/debug/test_sword_contract.py` — static contract: asserts the
  16-frame total window, beam spawn at frame 13, beam speed 3 px,
  bounds, and that the deferred HP gate point is documented in source.

## Gate

- 4-line task header: filled.
- Gate 1 per-function diff: not applicable (RoomRom-native).
- Gate 2 RAM-cell trace: deferred to phase exit.
- Gate 3 scenario oracle: deferred to milestone tag.

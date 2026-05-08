# Phase 6 Task 6.2 — NES-Faithful Movement Verification

- **NES source**: `reference/aldonunez/Z_05.asm` Link_HandleInput / InitLinkSpeed; `reference/aldonunez/Z_07.asm` MoveObject
- **Drained C**:  `src/game/world/world_runtime.c` (peripheral) — Link movement is RoomRom-native, no per-function drain candidate
- **Coverage**:   N/A (RoomRom is the implementation; NES asm is the spec)
- **Stance**:     ADOPT (NES constants + behavior mirrored byte-for-byte where present)

## Verified parity

| NES behavior | NES asm anchor | RoomRom impl | Status |
| --- | --- | --- | --- |
| Walking speed (default) — `ObjQSpeedFrac = $60` | `Z_05.asm:7092` InitLinkSpeed | `RoomRom/src/main.c:235` `LINK_QSPEED 0x60u` | ✅ |
| Grid alignment +/-8 limits on Link slot 0 | `Z_07.asm:2720-2728` MoveObject | `RoomRom/src/main.c:234` `LINK_GRID_SIZE 8` | ✅ |
| QSpeed applied 4x per frame (high nibble = whole px, low nibble fraction accumulator) | `Z_07.asm:2733-2735` | `link_nes_add_qspeed` / `link_nes_sub_qspeed` + 4x apply loop | ✅ |
| Direction bitfield: RIGHT=$01, LEFT=$02, DOWN=$04, UP=$08 | `Z_07.asm:2737-2778` | `link_nes_move_object` switch on `link_dir_t` (RoomRom enum maps to bitfield via raw literals at the boundary) | ✅ |
| Single-axis movement; H>V on diagonal pad input | `Z_05.asm` Link_ModifyDirAtGridPoint | `RoomRom/src/main.c:1620-1737` input handling | ✅ |
| Walkability check at grid offset 0 | NES room collision read at grid alignment | RoomRom `link_walkable_at` gate when `s_link_grid_offset == 0` | ✅ |
| Stop on input release | `Z_05.asm` Walker_Move @ChooseObjDirOrInputDir | RoomRom input idle path leaves `moving_dir` cleared | ✅ |
| Room-edge transitions | NES edge-load handler | RoomRom `edge_load_or_clamp` | ✅ |
| Underworld doorway nudge | NES UW corridor entry alignment | RoomRom UW doorway nudge in input handler | ✅ |

## Deferred (Task 6.2-followup)

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Mountain-stair slow speed — `QSpeed = $30` on tiles `$74` / `$75` | `Z_05.asm:7100-7115` InitLinkSpeed branch | RoomRom OW collision tagging does not yet flag stair tiles; needs OW tile-class table promotion | Phase 6 Task 6.2-followup or first OW polish pass |
| Knockback — `ObjShoveDir` / `ObjShoveDistance` application | `Z_07.asm` ShoveObject (no direct symbol — inline in damage path) | LinkState carries `shove_dir` + `shove_distance` (Task 6.1) but no producer/consumer wired yet; combat damage (Task 6.4+) is upstream prerequisite | Phase 6 Task 6.4 (Combat) once damage frames trigger shove |

Both deferrals are tracked because the LinkState shape (Task 6.1) already
reserves the byte cells. No struct rewrite needed when these land.

## ALTTP / free-movement note

ALTTP-style 8-directional pixel movement is explicitly an **option mode**,
not the default. NES single-axis grid movement is the spec. Any future
ALTTP toggle lives behind a runtime flag, not a `#define` swap, so the
NES path stays dominant.

## Probe / contract

- `tools/debug/test_movement_contract.py` — static contract: asserts
  `LINK_QSPEED == 0x60`, `LINK_GRID_SIZE == 8`, the 4x apply helpers
  exist, and `players[0]` has fully replaced the legacy `s_link_*`
  globals. Run as part of regression matrix.

## Gate

- 4-line task header: filled (above).
- Per-function diff (Gate 1): not applicable — RoomRom is the
  implementation, not a drained subsystem.
- Per-RAM-cell trace (Gate 2): deferred to phase exit; Task 6.2 covers
  movement only and does not touch RAM cells outside the LinkState
  struct landed in 6.1.
- Per-scenario oracle (Gate 3): deferred to milestone tag.

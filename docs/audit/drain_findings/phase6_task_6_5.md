# Phase 6 Task 6.5 — Bomb Verification

- **NES source**: `reference/aldonunez/Z_01.asm:3804` WieldBomb; `reference/aldonunez/Z_07.asm:4758` UpdateBombOrFire / `:4770` UpdateBomb / `:4806` Bomb_CheckState4 / `:4869` DrawBomb / `:4912` DrawCloud / `:4936` DrawOtherBombClouds; `Z_07.asm:4749` BombTimes ($30/$18/$0C/$06); `Z_07.asm:4752-4756` BombableWallHotspotsX/Y
- **Drained C**:  N/A — RoomRom-native (`RoomRom/src/roomrom_bomb.c`, `RoomRom/src/roomrom_sprites.c:605` set_bomb / `:653` set_explosion)
- **Coverage**:   PARTIAL (dual-bomb slot $10/$11, InvBombs decrement, bombable-wall trigger, 4-cluster cloud layout, flash effect deferred)
- **Stance**:     ADOPT (state machine + sub-pal blue + tile $34 bomb / $70-$74 cloud cycle lifted from NES; gaps tracked below)

## Verified parity

| NES behavior | NES anchor | RoomRom impl | Status |
| --- | --- | --- | --- |
| Sub-pal 1 (blue) for bomb + cloud | `Z_07.asm:4912` DrawCloud, Y=1 | `ROOMROM_BOMB_SUBPAL 1u` line 5 | ✅ |
| Bomb tile $34 (8x16 fuse+cap / body) | `Z_01.asm` ItemFrameTiles[$03] = $34 | `ROOMROM_ITEM_TILE_BOMB` + `SPRITE_SIZE(1,2)` line 612 | ✅ |
| Cloud tile $70/$72/$74 cycle (3 phases) | `Z_07.asm:4912` DrawCloud frames 1-3 | `set_explosion` phase = elapsed / 6, modulo 3 lines 660-664 | ✅ |
| Cloud 16x16 mirrored pair | `Z_01.asm:5304` Anim_WriteMirroredSpritePair | atlas LT/LB/RT/RB = tile/tile+1/hflip/hflip+1 lines 640-644 | ✅ |
| Re-throw lock while active | NES slot $10/$11 occupancy | `s_state != BOMB_IDLE` guard line 32 | ✅ (single-bomb only) |
| Place offset 16px facing dir | `Z_01.asm:3873` PlaceWeapon $10 | `BOMB_PLACE_OFFSET 16` lines 38-41 | ✅ |
| Lifecycle = fuse → explode | `Z_07.asm:4770` state $11..$15 | FUSE → EXPLODE → IDLE lines 57-75 | ✅ (timing diverges) |

## Timing comparison

| State | NES (frames) | RoomRom (frames) | Notes |
| --- | --- | --- | --- |
| Pre-detonation hold | $30 = 48 | `BOMB_FUSE_FRAMES 60u` | RoomRom +12f longer fuse |
| Bomb visible | $18 = 24 | (folded into FUSE) | NES splits state 1→2; RoomRom collapses |
| First cloud | $0C = 12 | (folded into EXPLODE) | NES sfx + state advance |
| Wall-break check | $06 = 6 | `BOMB_EXPLODE_FRAMES 24u` | Single explode window |
| **Total lifecycle** | **90 frames** | **84 frames** | -6f from NES |

## Deferred (Task 6.5-followup)

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Dual simultaneous bombs (slot $10/$11) | `Z_01.asm:3811-3839` slot alloc | RoomRom uses single static — simpler, matches early-Z1 inventory throughput | Task 6.10 (Inventory + Pause) — when InvBombs > 1 logic lands, lift slot count |
| `InvBombs` decrement / inventory gate | `Z_01.asm:3807,3843` | Inventory subsystem not yet wired in RoomRom | Task 6.10 |
| Bombable wall trigger ($18 px hotspot, UW only) | `Z_07.asm:4806` Bomb_CheckState4 | Bombable walls are room-state Task 6.7-ish territory; needs `BombableWallHotspotsX/Y` per-room and `TriggeredDoorCmd` | Task 6.8 (UW door state) |
| 4-cluster cloud layout (BombCloudOffsetsX1/Y1, X2/Y2, every-other-frame swap) | `Z_07.asm:4924-4974` DrawOtherBombClouds | RoomRom draws single 16x16 cluster centered on bomb origin (visual sufficiency for v8) | Task 6.5-followup (post-inventory) |
| Bomb flash effect | `Z_07.asm:4890` UpdateBombFlashEffect | Polish — sub-pal flash during pre-detonation | Task 6.5-followup |
| State-3 explosion sfx (`PlayEffect #$10`) | `Z_07.asm:4793-4794` | Audio integration deferred (no SongRequest hook for FX in RoomRom yet) | Task 6.5-followup (audio scaffold) |
| Bombs blocked in cellars (mode 9) | `Z_07.asm:4819-4821` | Cellar mode not implemented | Phase 7+ (Cellars) |

## Probe / contract

- Static contract goal (Task 6.5-followup): `tools/debug/test_bomb_contract.py` —
  fuse=60, explode=24, place offset=16, sub-pal=1, single-instance lock,
  3-phase cloud cycle (phase = elapsed/6 mod 3), face-direction offsets.
- Visual probe (deferred): `tools/debug/probes/probe_bomb_visual.lua` once
  inventory grants `B_ITEM_BOMB`. Z-cycle reliability blocked Task 6.4
  visual probe; same blocker applies here.

## Gate

- 4-line task header: filled.
- Gate 1: not applicable (RoomRom-native).
- Gate 2: deferred to phase exit.
- Gate 3: deferred to milestone tag.

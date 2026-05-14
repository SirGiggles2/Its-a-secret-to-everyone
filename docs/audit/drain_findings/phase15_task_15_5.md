# Phase 15 Task 15.5 — VRAM Residency Optimization

- **NES source**: NES CHR-ROM bank swap per scene. Genesis equivalent
                  = VRAM tile residency per scene.
- **Drained C**:  `RoomRom/src/atlas/roomrom_scene_vram_contracts.c`
                  + `RoomRom/src/atlas/level_chr_swap.c` +
                  `RoomRom/src/atlas/boss_chr.c` +
                  `RoomRom/src/atlas/enemy_chr.c` +
                  `RoomRom/src/atlas/items_chr_x4.c`. Tile base
                  contracts generated from `roomrom_vram_map.h`.
- **Coverage**:   PARTIAL — per-scene residency tables exist
                  per-subsystem; unified no-overlap verifier + stale-CHR
                  probe NOT yet shipped. Memory `feedback_nes_chr_bank_swap`
                  confirms per-scene swap discipline is tracked.
- **Stance**:     PARTIAL — residency tables ADOPT; verifier work
                  deferred.

## Deferral

`phase15_vram_residency_verifier` — no-overlap verifier across every
scene residency table + stale-CHR probe for scene transitions.

## Status

CLOSE (with verifier deferral).

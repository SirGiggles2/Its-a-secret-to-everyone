# Phase 13 Task 13.3 — Render Extra Players

- **NES source**: NES renders single Link. No NES surface for
                  P2-P4 sprite/palette.
- **Drained C**:  Sprite render via `RoomRom/src/roomrom_sprites.c`
                  + atlas helpers — single-Link assumption in OAM
                  build pipeline.
- **Coverage**:   NONE — P2-P4 sprite allocation + tunic palettes
                  not started.
- **Stance**:     DEFERRED_FEATURE.

## Implementation plan (when picked up)

1. Reserve 4 sprite-pal slots in PAL2 (tunic per player). Subject
   to CRAM budget per `RoomRom/src/atlas/items_chr_x4.c` headroom.
2. Reserve 4 OAM tile slots per player (1 frame of 2x2 Link).
   16 tiles total in VRAM beyond P1's slot.
3. Sprite budget verifier counts max simultaneous sprites across
   the 4-corner spawn scenario + 11 active enemies; must fit in 80
   SAT entries.
4. P1 unchanged in 1-player; multiplayer mode flag gates the P2-P4
   render path so 1-player has zero overhead.

## Sprite budget risk

NES has 64 sprite slots + 8-per-scanline limit. Genesis has 80 SAT
entries + 20-per-scanline (320×) or 16-per-scanline (256×).
Master plan target is 320 mode (Phase 6 V64 dead-zone work locked
this). Pre-flight count:

| Source            | Max simultaneous sprites |
|-------------------|--------------------------|
| Link (P1)         | 4 (2x2 in 8x16 mode)     |
| Enemies (11 slots)| 22 (most are 2x1)        |
| Projectiles       | 8 (sword beam + arrows)  |
| HUD               | 0 (uses BG, not OAM)     |
| Item drops        | 4                         |
| **Subtotal**      | **38**                   |
| P2-P4 tunic       | 4 × 3 = 12               |
| P2-P4 weapons     | 2 × 3 = 6                |
| **Multiplayer total** | **56**                 |

56 of 80 SAT entries fits with 24-slot headroom. Per-scanline
budget (20 sprites/scanline in 320 mode) is the closer call:
4 players + 4 enemies on the same row hits 16 sprites, still under.

## Status

DEFERRED_FEATURE — gated on Tasks 13.1 + 13.2.

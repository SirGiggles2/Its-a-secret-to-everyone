# Phase 6 Task 6.6 — Bow And Arrows Verification

- **NES source**: `reference/aldonunez/Z_05.asm:2945` WieldArrow; `reference/aldonunez/Z_07.asm:3813` UpdateArrowOrBoomerang / `:3908` DrawArrow / `:4322` UpdateRodOrArrow dispatch; `Z_07.asm:3804` RDirectionToWeaponBaseAttribute; `Z_05.asm:2962-2968` InvRupees + RupeesToSubtract gate; `Z_05.asm:2978-2980` ObjQSpeedFrac $C0
- **Drained C**:  N/A — RoomRom-native (`RoomRom/src/roomrom_arrow.c`, `RoomRom/src/roomrom_sprites.c` set_arrow)
- **Coverage**:   PARTIAL (Bow inv requirement, InvRupees gate, silver-arrow tier, MoveShot wall-block, sprite hflip-on-LEFT, monster-arrow palette row 6, blocked-state $20/$30 spark deferred)
- **Stance**:     ADOPT (qspeed $C0 = 3 px/frame + sub-pal 0 + facing-direction spawn lifted from NES; gaps tracked below)

## Verified parity

| NES behavior | NES anchor | RoomRom impl | Status |
| --- | --- | --- | --- |
| Q-speed $C0 = 3 px/frame | `Z_05.asm:2978-2980` | `ARROW_SPEED_PX 3` line 8 | ✅ |
| Sub-pal 0 (RDirectionToWeaponBaseAttribute = 0) | `Z_07.asm:3804,3927` | `ROOMROM_ARROW_SUBPAL 0u` line 6 | ✅ |
| Spawn at Link, offset facing dir | `Z_01.asm:3873` PlaceWeapon $10 | offset 8 px in face dir lines 36-39 | ✅ (NES is 16 px; see gap below) |
| Re-fire lock while active | NES slot $12 occupancy check | `s_state != ARROW_IDLE` line 29 | ✅ |
| Linear movement in 4 cardinal dirs | `Z_07.asm:3839-3866` MoveShot per-axis | LINK_FACE_UP/DOWN/LEFT/RIGHT switch lines 54-59 | ✅ |
| Despawn off-screen | NES wall-block → state $20 → spark | bounds rect ARROW_BOUND_X/Y_MIN/MAX lines 60-65 | ✅ (mechanism diverges; see gap) |

## Diverges from NES

| Aspect | NES | RoomRom | Impact |
| --- | --- | --- | --- |
| Spawn offset | 16 px (PlaceWeapon `LDA #$01`/`#$F0`) | 8 px | Arrow appears closer to Link; cosmetic |
| Despawn trigger | wall-block via MoveShot or grid-offset limit | screen-bounds rect (-16..272, -16..240) | RoomRom flies off-screen instead of sparking on walls |
| Wall-impact spark (state $20→$30) | shown 8f as splash sprite | none | No "thunk" feedback |

## Deferred (Task 6.6-followup)

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Bow item requirement | `Z_05.asm:2948-2949` `LDA Bow / BEQ` | RoomRom debug fires unconditionally — inventory not wired | Task 6.10 (Inventory + Pause) — inventory.bow boolean gate `roomrom_arrow_fire` |
| `InvRupees` check + `RupeesToSubtract` | `Z_05.asm:2962-2968` | Currency subsystem absent | Task 6.10 (Inventory) — also Task 6.11 (Drops) for rupee accumulation |
| Silver arrow tier | `Z_05.asm` Items table — silver overrides wood; +damage | RoomRom has single arrow tier | Task 6.10 + Phase 8 boss verification (Ganon needs silver) |
| MoveShot wall-block | `Z_07.asm:3847,3861` MoveShot returns blocked flag in [0E] | RoomRom has no tile-collision grid | Task 6.7 (UW collision, room state) — once block-grid exists, swap bounds-rect for MoveShot equivalent |
| Wall-impact spark state $20/$30 | `Z_07.asm:3898-3901` HandleArrowOrBoomerangBlocked | Visual polish — needs spark sprite + $10 timer | Task 6.6-followup (post-collision) |
| Monster-arrow palette row 6 (+2 attr) | `Z_07.asm:3930-3932` "+2 to sprite attributes" | Player arrow only in Phase 6 | Phase 7 (Enemies — Aquamentus / Goriya / etc. shoot arrows) |
| Enemy damage on hit | `Z_07.asm` AnimateAndCheckCollision-style | Enemy infrastructure not present | Phase 7 + Phase 8 Task 8.7 Gohma |

## Probe / contract

- Static contract goal (Task 6.6-followup): `tools/debug/test_arrow_contract.py` —
  speed = 3, sub-pal = 0, single-instance lock, facing-direction offset,
  bounds-rect despawn, deferral-comment grep on roomrom_arrow.c.
- Visual probe (deferred): `tools/debug/probes/probe_arrow_visual.lua` once
  inventory grants `B_ITEM_ARROW`. Z-cycle reliability blocker continues
  from Task 6.4 / 6.5 visual probes.

## Gate

- 4-line task header: filled.
- Gate 1: not applicable (RoomRom-native).
- Gate 2: deferred to phase exit.
- Gate 3: deferred to milestone tag (silver-arrow Ganon kill).

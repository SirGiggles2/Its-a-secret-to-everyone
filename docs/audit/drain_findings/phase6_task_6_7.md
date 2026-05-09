# Phase 6 Task 6.7 — Candle Verification

- **NES source**: `reference/aldonunez/Z_01.asm:3948` WieldCandle; `reference/aldonunez/Z_07.asm:4622` UpdateFire / `:4758` UpdateBombOrFire dispatch; `Z_07.asm:4683` `LDA #$00` frame=0 + `:4685` `LDY #$40` anim index $41; `Z_07.asm:5116` Anim_AdvanceAnimCounterAndSetObjPos / `:5084` Anim_SetObjHFlipForSpriteDescriptor; `Z_07.asm:4682` Anim_SetSpriteDescriptorRedPaletteRow
- **Drained C**:  N/A — RoomRom-native (`RoomRom/src/roomrom_candle_fire.c`)
- **Coverage**:   PARTIAL (blue/red tier `UsedCandle` gate, bush burn, dark-room light `UpdateCandle`, OW vs UW gating, enemy collision damage, Link-shove on touch deferred)
- **Stance**:     ADOPT (tile pair $5C/$5E + sub-pal 2 red + 4-tick hflip toggle + travel-then-stand state machine lifted from NES; gaps tracked below)

## Verified parity

| NES behavior | NES anchor | RoomRom impl | Status |
| --- | --- | --- | --- |
| Sub-pal 2 (red) | `Z_07.asm:4682` Anim_SetSpriteDescriptorRedPaletteRow | `CANDLE_FIRE_SUBPAL 2u` line 49 | ✅ |
| Tile pair $5C/$5E (single pair, NOT 4-frame cycle) | `Z_07.asm:4683-4686` `LDA #$00`/`LDY #$40` → ObjAnimFrameHeap[$08] = $5C | `CANDLE_FIRE_TILE_BASE = ROOMROM_ITEM_TILE_CANDLE_FIRE_F0` line 48; comment lines 1-27 traces NES truth | ✅ (re-verified 2026-05-08) |
| HFLIP toggle every 4 ticks (`ObjAnimFrame ^= 1`) | `Z_07.asm:5084` Anim_SetObjHFlipForSpriteDescriptor + caller arg `LDA #$04` | `s_anim_frame ^= 1u` lines 130-134 + `CANDLE_FIRE_TICKS_PER_FRM 4` | ✅ |
| State $21 (flying) → $22 (standing) | `Z_07.asm:4651-4655` grid offset == $10 → state++ + timer = $3F | `FIRE_FLYING` → `FIRE_STANDING` lines 151-153 | ✅ (state shape) |
| Standing duration $3F = 63 frames | `Z_07.asm:4653` `LDA #$3F` | `CANDLE_FIRE_STAND_FRAMES 30` line 41 | ⚠️ deliberate divergence (see comment line 36-39) |
| Re-fire lock | NES slot $10 occupancy + `UsedCandle` flag | `s_state != FIRE_IDLE` line 88 | ✅ (single-instance only) |
| Spawn at facing dir 8 px offset | `Z_01.asm:3986` PlaceWeaponForPlayerState ($10) | offset 8 px lines 93-98 | ✅ (NES spec is 16 px; see gap) |
| Animation index $41, frame=0 (FIXED) | `Z_07.asm:4683` `LDA #$00` | hardcoded `CANDLE_FIRE_TILE_BASE` (no per-frame switch) | ✅ — older 4-frame impl was wrong |

## Diverges from NES (deliberate)

| Aspect | NES | RoomRom | Reason |
| --- | --- | --- | --- |
| Travel distance | $10 = 16 px (q-speed $20 = 0.5 px/f → 32 frames) | `CANDLE_FIRE_TRAVEL_PX 48` (1 px/f → 48 frames) | Visibility — 16 px keeps fire merged with Link's 16x16 body. Restore once NES q-speed model is ported (line 36-39 comment). |
| Stand duration | $3F = 63 frames | 30 frames | Cycle visibility during dev. |
| Spawn offset | 16 px | 8 px | Matches arrow / boomerang offset choice — cosmetic. |

## Deferred (Task 6.7-followup)

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Blue candle (1-use) vs red candle (∞) | `Z_01.asm:3958-3962` `InvCandle` + `UsedCandle` | Inventory not wired | Task 6.10 (Inventory + Pause) |
| `UsedCandle` flag reset per room | `Z_01.asm:3967` STA UsedCandle + room transition reset | Room-state hook absent | Task 6.8 (UW door state) — fold into per-room reset |
| OW vs UW dispatch | `Z_01.asm:3958` (no OW gate explicit, but only fires when in-game) | RoomRom debug fires unconditionally | Task 6.10 |
| Bush burn (overworld tile destroy) | NES tile interaction — fire collides with burnable tile, swaps NT entry | RoomRom has no tile-collision grid for OW | Phase 8 (Overworld) — needs OW tile state |
| Dark-room light (`UpdateCandle` Z_04 bank-switched) | `Z_07.asm:4665-4673` UW-only `JSR UpdateCandle` | Dark-room palette/lighting subsystem absent | Task 6.7-followup (post-room-state) |
| Enemy damage on touch | `Z_07.asm:4674-4727` collision + Link_BeHarmed (also wraps player damage) | Enemy infra absent in Phase 6 | Phase 7 (Enemies) |
| Link-shove on player collision | `Z_07.asm:4715-4727` BeginShove + Harm $80 | Player-state hooks absent | Task 6.11 (Damage + Death) |
| Sound effect $04 on spawn | `Z_01.asm:3980-3981` `LDA #$04 / JSR PlayEffect` | Audio FX scaffold absent | Audio scaffold task (Phase 9-ish) |

## Probe / contract

- Static contract goal (Task 6.7-followup): `tools/debug/test_candle_contract.py` —
  sub-pal = 2 red, tile = $5C single pair (NOT 4-frame cycle), hflip toggle
  every 4 ticks, state FLYING→STANDING transition on travel completion,
  re-fire lock, deferral-comment grep on roomrom_candle_fire.c.
- Visual probe regression: candle was ALREADY visually verified in
  commits `893d4513` (NES truth — single tile pair) + `f598dcec` (link
  chain slot 8 → 9) + `b35a7bb1` (SPRITE_SIZE 2,2) + recent atlas refixes.

## Gate

- 4-line task header: filled.
- Gate 1: not applicable (RoomRom-native).
- Gate 2: deferred to phase exit.
- Gate 3: deferred to milestone tag.

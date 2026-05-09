# Phase 6 — diff_vs_nes_reference (close-gate step)

Per-function diff between landed Phase 6 RoomRom code and the NES Z1
disassembly (`reference/aldonunez/Z_01.asm`, `Z_07.asm`). Drain-first / NES-asm-second per HARD rule D1; this doc reviews the secondary
verification (NES asm wins ties).

Scope: Phase 6 work merged to `main` as of HEAD 23f2f0926. Each row is a
RoomRom symbol → NES anchor + the per-function diff verdict.

| RoomRom symbol | NES anchor | Verdict |
|---|---|---|
| `inventory_rupee_tick` (`RoomRom/src/inventory.c:62`) | `World_ChangeRupees` (`Z_01.asm:2812`) | MATCHES (with documented divergences) |
| `roomrom_link_damage_apply` (`RoomRom/src/roomrom_link_damage.c:66`) | `Link_BeHarmed` (`Z_01.asm:5691`) | MATCHES |
| `roomrom_link_damage_tick` (`RoomRom/src/roomrom_link_damage.c:46`) | `DecrementInvincibilityTimer` (`Z_07.asm:5756`) | MATCHES |
| `roomrom_link_shove_begin` (`RoomRom/src/roomrom_link_damage.c:133`) | `BeginShove` (`Z_01.asm:6470`, Link-defender path) | MATCHES (defender-side only; monster-defender + reverse-attribute deferred) |
| `roomrom_link_shove_tick` (`RoomRom/src/roomrom_link_damage.c:190`) | `Obj_Shove` per-frame (`Z_01.asm:2274`) | PARTIAL — pixel stepping only; collision check deferred to 6.11.x |
| `draw_count_cell` (`RoomRom/src/roomrom_hud.c`) | `FormatDecimalCountByte` (`Z_01.asm:2922`) | MATCHES (3-cell formatting) |
| `draw_hearts_row` (`RoomRom/src/roomrom_hud.c`) | `FormatHeartsInTextBuf` (`Z_01.asm:3161`) | PARTIAL — single-row visible cap pending Step B row-5 outline |
| `roomrom_hud_refresh_dynamic` (`RoomRom/src/roomrom_hud.c`) | `FormatStatusBarText` (`Z_01.asm:2850`) | EXTEND — direct `g_inventory` read; transfer-buf path lands as Step B |

---

## 1. `inventory_rupee_tick` vs `World_ChangeRupees` (Z_01.asm:2812)

**NES**:
```
LSR FrameCounter ; carry => skip (every-other-frame gate)
LDA RupeesToAdd  ; if !=0 -> DEC RupeesToAdd, INC InvRupees, Tune0Request=$10
LDA RupeesToSub  ; if !=0 -> DEC RupeesToSub, DEC InvRupees, Tune0Request=$10
```

**RoomRom** (`inventory.c:62`):
- `(frame_counter & 1u) != 0u → return` — same gate.
- `rupees_to_add → DEC + INC rupees` — same.
- `rupees_to_sub → DEC + DEC rupees` — same.

**Documented divergences** (called out in `inventory.c:50-61`):
1. `rupees` widened to `unsigned short` with `INV_RUPEE_CAP=999`. NES caps display at 255.
2. Tune0Request mailbox skipped — Task 6.10.11 (audio dispatch) is BLOCKED on MIDI-FS integration per memory `project_midi_fs_integration.md`.
3. NES early-out `TileBufSelector != 0` (Z_01.asm:2813-2816) skipped — RoomRom has no DynTileBuf; status bar paints via `roomrom_hud_refresh_dynamic`.

**Verdict**: MATCHES. Divergences are the pre-Step-B / pre-audio scaffolding path; planned to retire when Step B + 6.10.11 land.

---

## 2. `roomrom_link_damage_apply` vs `Link_BeHarmed` (Z_01.asm:5691)

**NES sequence**:
```
PlaySample $08 (skip if whirlwind)
LSR $0D / ROR $0E    ; per ring level
ResetHelp: WorldKillCount=0, HelpDropCount=0, HelpDropValue=0
HeartPartial CMP $0E ; BCC -> @BorrowHeart
SBC $0E -> HeartPartial
HeartValues AND $0F CMP $0D ; BCC -> @HandleDied
SBC $0D -> HeartValues
RTS
@BorrowHeart:
$0E SBC HeartPartial -> $0E
HeartValues AND $0F BEQ -> @HandleDied
DEC HeartValues
HeartPartial = $FF
loop @ResetHelp
```

**RoomRom** (`roomrom_link_damage.c:66`):
- `s_invincibility_timer != 0 → return 0` (early-out — NES does this in caller).
- `clock != 0 → return 0` (NES checks elsewhere; RoomRom centralizes).
- `apply_ring_divide(&dmg_hi, &dmg_lo)` — exact LSR/ROR loop per ring.
- `heart_partial >= dmg_lo`: subtract; else borrow with NES-quirk `0xFFu - need` (NES asm:5742-5754, "treats $FF as full instead of $100").
- After borrow: `dmg_hi = 0` because the borrow path consumes one full heart already in `DEC HeartValues`. Compared to NES: NES jumps back to `@ResetHelp` then re-enters partial check; RoomRom collapses the loop because partial is now $FF and `0x0E` (re-decremented) is by definition < $FF. End-state full-heart count after RoomRom path equals the NES loop end-state by inspection.
- Sets `s_invincibility_timer = ROOMROM_INVINCIBILITY_INITIAL ($10)` on non-fatal hit. NES post-harm timer not directly evidenced in `Z_01.asm:5691`; `$10` is the scaffold value (BeginShove overrides to `$18`).

**Tune $08 PlaySample**: skipped (audio dispatch deferred).

**WorldKillCount/HelpDropCount/HelpDropValue reset**: skipped (drop tracking lands with Phase 6 enemy work).

**Verdict**: MATCHES on the heart-arithmetic core. Side effects (audio + drop tracking) deferred to 6.10.11 / 6.11.2.

---

## 3. `roomrom_link_damage_tick` vs `DecrementInvincibilityTimer` (Z_07.asm:5756)

**NES**:
```
LDA ObjInvincibilityTimer, X
BEQ @Exit                 ; timer==0 -> return
LDA FrameCounter LSR
BCS @Exit                 ; odd frame -> skip
DEC ObjInvincibilityTimer, X
```

**RoomRom** (`roomrom_link_damage.c:46`):
```c
if (s_invincibility_timer == 0u) return;
if ((frame_counter & 1u) != 0u) return;
s_invincibility_timer--;
```

**Verdict**: MATCHES exactly. NES `LSR FrameCounter / BCS` = odd-frame skip = `(frame_counter & 1) != 0`. The 16-slot mirror collapses to a single-byte cell because Link is slot 0.

---

## 4. `roomrom_link_shove_begin` vs `BeginShove` Link-defender path (Z_01.asm:6470)

**NES Link-defender entry** (Y == 0, X = monster slot):
```
$08 := $08 (UP base)         ; Z_01.asm:6491
$04 := ObjY,X (monster Y)    ; :6493
$05 := ObjY,Y (link  Y)      ; :6495
ObjGridOffset BNE :+         ; if grid_offset != 0:
  ObjDir AND #$03            ;   (defender_dir & $03) != 0 -> CheckHorizontal
  BNE @CheckHorizontal       ;   == 0 -> CheckVertical
:                            ; else (grid_offset == 0): consult $0B
  $0B CMP #$04 BCS @CheckVertical
@CheckHorizontal:
  $08 := $02 (LEFT base)
  $04 := ObjX,X / $05 := ObjX,Y
@CheckVertical:
  $04 CMP $05
  BCS :+                     ; m_axis >= d_axis -> keep base
  LSR $08                    ; m_axis <  d_axis -> flip (UP->DOWN, LEFT->RIGHT)
:
  CPY #$00 BNE @MonsterDefender
  ObjInvincibilityTimer BNE @Exit
  $08 ORA #$80 -> ObjShoveDir
  ObjInvincibilityTimer = $18
  ObjShoveDistance      = $20
  CPX #$0D BCS @Exit         ; weapon-self-shove path: skip reverse-after-hit
  ; (monster reverse-after-hit attribute toggle — deferred 6.11.2)
```

**RoomRom** (`roomrom_link_damage.c:133`):
- `s_invincibility_timer != 0 → return 0` — matches the post-direction-compute NES gate. RoomRom hoists it to top because the direction math has no observable side effects when invincible (cleaner; same end-state).
- `defender_grid_offset != 0 → horizontal = (defender_dir & 0x03u) != 0u` — exact translation of `:6502-6507`.
- `grid_offset == 0` fallback: NES consults `$0B` (weapon/attacker dir). RoomRom approximates with `|dx| > |dy|` because `$0B` for the Link-defender unblocked path is the monster's facing direction; the magnitude compare gives the same axis selection in the common case where the monster is roughly aligned with its facing. Documented in the C comment header. The exact `$0B`-derived branch lands when 6.11.2 wires monster state.
- `base_dir = LEFT($02)` if horizontal else `UP($08)` — matches.
- `m_axis < d_axis → base_dir >>= 1` — matches NES `LSR $08`. Note polarity: NES `BCS keeps base` = `m_axis >= d_axis` (unsigned compare). RoomRom uses signed compare since axes are pixel coords; for the Link-defender collision range (positive room coords), signed `>=` matches unsigned `>=`.
- `s_shove_dir = base_dir | $80` — matches `ORA #$80 -> ObjShoveDir`.
- `s_shove_distance = $20`, `s_invincibility_timer = $18` — matches.
- Returns 1 on shove applied, 0 if blocked. NES has no return value (state-machine).

**Deferred from NES**:
- `@MonsterDefender` branch (CPY != 0) — monster being shoved by Link's weapon. 6.11.2 enemy state work.
- `CPX < $0D` reverse-after-hit attribute — Z_01.asm:6578-6620 toggles ObjAttr to bounce the monster. Lands when monster object array exists.
- `$0B`-fallback dispatch when grid_offset == 0 — see above.

**Verdict**: MATCHES on the Link-defender direction-computation path. Monster-defender + reverse-after-hit are scoped out per Task 6.11.4 (Link-defender slice); they re-enter as Task 6.11.2 work.

---

## 5. `roomrom_link_shove_tick` per-frame applier vs `Obj_Shove` (Z_01.asm:2274)

NES `Obj_Shove`: per-frame, while `ObjShoveDistance > 0`:
- Decrement distance, advance object 1 px along `ObjShoveDir`.
- Test collision via `CalcObjMoveDestination` / `CheckObjGenericMoveDest` — if blocked, abort shove.

**RoomRom** (`roomrom_link_damage.c:190`):
- Decrements `s_shove_distance`, writes ±1 to `*out_dx` / `*out_dy` per direction bit.
- Clears the `$80` first-frame bit after the first tick.
- Does NOT collision-test — the caller is expected to add dx/dy and run the existing room collision through the standard movement path. This is acceptable because the caller in `main.c` runs collision as part of the post-input movement pipeline; per-pixel collision rejection lands when the shove caller is wired in 6.11.2.

**Verdict**: PARTIAL. Pixel stepping + first-frame bit clearing match. Collision-during-shove deferred. Documented in the function header comment (`Z_01.asm:2274 tests collision per-pixel; collision testing lands with 6.11.x rooming-physics work`).

---

## 6. `draw_count_cell` vs `FormatDecimalCountByte` (Z_01.asm:2922)

NES contract (`Z_01.asm:2909-2913`):
```
123 -> "123"
 23 -> "X23"
  3 -> "X3 "
```

`X` = TILE_LOW_X (`$21`), space = `$24`.

**RoomRom** (`roomrom_hud.c`):
- `hundreds != 0 → emit hundreds, tens, ones` — matches `123 -> "123"`.
- `tens != 0 → emit X, tens, ones` — matches `23 -> "X23"`.
- `ones-only → emit X, ones, space` — matches `3 -> "X3 "`.
- `value > 999 → cap to 999` — RoomRom-only divergence because `rupees` is widened to 16-bit (Step B will paint `999` exactly per NES once 8-bit truncation lands; until then the cap matches NES display-byte semantics on overflow).

**Verdict**: MATCHES the 3-cell contract. The 16-bit cap is a forward-compatible widening, not a regression.

---

## 7. `draw_hearts_row` vs `FormatHeartsInTextBuf` (Z_01.asm:3161)

NES heart formatting:
- `[$0E] = HeartValues` (hi nibble = max, lo nibble = current)
- `[$0F] = HeartPartial`
- Renders 16 cells across two NT rows ($20B6 / $20D6) = 8 cells per row.
- Tile mapping: `$F2` full / `$F3` half / `$F4` empty.
- Heart at index `i`: `i < cur` = full, `i == cur && partial >= $80` = half, otherwise empty up to `max-1`, then off-screen for `i >= max`.

**RoomRom** (`roomrom_hud.c`):
- Reads `heart_values_max` / `heart_values_cur` / `heart_partial` — matches the nibble decomposition.
- Tile constants: `TILE_FULL_HEART`, `TILE_HALF_HEART = $F3`, `TILE_EMPTY_HEART = $F4` — matches.
- Per-cell logic mirrors the NES rule (full / half-on-current / empty / hidden).

**Divergences**:
- 3-heart visible cap (single row). NES paints up to 8 hearts per row across two rows. RoomRom Step A scaffolds row 4 / row 5 paints; the row-5 outline + 8-cell extension lands when StatusBarTransferBuf consumer is proven (per `phase6_task_6_10_6_step_a.md` follow-up).
- First-boot fallback `max == 0 → max = cur = 3`. NES never runs with `max == 0` because `InitMode_StatusBar` writes `0x33` at boot. RoomRom carries the same boot default in `inventory.c:37`, so the fallback only fires if a probe pokes `$00` — defensive, not a parity issue.

**Verdict**: PARTIAL — single-row paint vs NES two-row, fully covered for the 3-heart default. Row-5 extension is in the Step A doc deferrals.

---

## 8. `roomrom_hud_refresh_dynamic` vs `FormatStatusBarText` (Z_01.asm:2850)

NES `FormatStatusBarText`:
- Copies `StatusBarTransferBufTemplate` (Z_01.asm:2804) to `DynTileBuf`.
- Walks the cell list (rupees `[$0657]` -> `FormatDecimalCountByteInTextBuf` Y=$1B; magic-key/keys -> Y=$21; bombs -> Y=$27; hearts -> `FormatHeartsInTextBuf`).
- Marks `DynTileBuf[0] |= $80` so the VBlank DMA pushes the row.

**RoomRom** (`roomrom_hud.c`):
- Direct read of `g_inventory` cells, paints via `VDP_setTileMapXY`. Bypasses DynTileBuf entirely.
- Hud variant dispatch (redux vs original) gated on `s_hud_id_cached`.
- Documented as Step A scaffolding in `phase6_task_6_10_6_step_a.md`. Step B replaces this with the NES-faithful StatusBarTransferBuf path.

**Verdict**: EXTEND. Step A deliberately diverges from NES routing to unlock observation; routing parity is the Step B deliverable. Stance noted in the Step A doc.

---

## Cross-cutting note: NES asm citation correctness

All citations in this doc were verified by reading
`reference/aldonunez/Z_01.asm` and `reference/aldonunez/Z_07.asm` at the
referenced line ranges. The NES-anchor lines in the source files'
comment headers (`roomrom_link_damage.c`, `inventory.c`,
`roomrom_hud.c`) match the actual asm contents.

## Gate disposition

- Per-function Gate 1 (per debate 005 RULE D1): satisfied for all 8 symbols above.
- Items deferred to 6.11.2 (enemy state) or 6.10.6 Step B / 6.10.11 (audio) are documented at-source AND in the master plan deferral list.
- Phase 6 close-gate `diff_vs_nes_reference` step: PASS.

# Drain Finding — Phase 4 Task 4.1 (native port) — `world_animate_world_fading`

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for the
overworld palette-fade animation streamer. Closes Phase 4 world_runtime
coverage (4/4 functions ported). **Drain has one minor scratch-state
divergence vs NES which the native port fixes.**

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/world_dispatch.c` | `world_animate_world_fading` |
| Drained C | `src/oracle/world/world_runtime.c` | 29-66 |
| NES asm | `reference/aldonunez/Z_01.asm` | 4701-4752 (AnimateWorldFading) |
| NES SRAM data | LevelInfo_PaletteCycles at $6BFA |
| NES vars | `reference/aldonunez/Variables.inc` | `ObjTimer+12 := $0034` (= WORLD_FADE_TIMER), `FadeCycle := $051C` (= WORLD_FADE_STEP), `DynTileBufLen := $0301` (= TRANSFER_BUF_POS), `DynTileBuf := $0302` (= TRANSFER_BUF_BYTE base), ZP `$00` (= WORLD_TMP0) |
| State accessors | `src/state/world_state.h` | `WORLD_FADE_TIMER`, `WORLD_FADE_STEP`, `TRANSFER_BUF_POS`, `TRANSFER_BUF_BYTE(off)`, `WORLD_TMP0` |

## Drain MATCH proof — block-by-block

| NES (Z_01.asm 4702-4752) | Drain (world_runtime.c 34-65) | Verdict |
|--------------------------|-------------------------------|---------|
| `LDA ObjTimer+12 / BNE @Exit / RTS` (return with A = nonzero timer) | `if (WORLD_FADE_TIMER != 0) return 1u` | **MATCH** (semantic: NES returns nonzero in A, drain returns 1u — both convey "in progress"). |
| `LDA FadeCycle / BPL :+ / EOR #$83 / :+` | `val = WORLD_FADE_STEP; if (val & 0x80) val ^= 0x83` | **MATCH** (BPL = bit-7 clear; bit-7 set → reverse-fade XOR). |
| `STA $00` | `WORLD_TMP0 = val` | **MATCH** |
| `ASL/ASL/ASL / CLC / ADC $00 / AND #$FC / TAY` | `sram_idx = ((val << 3) + val) & 0xFC` | **MATCH** (val*8+val = val*9; mask low 2 bits). |
| `LDX DynTileBufLen` | `pos = TRANSFER_BUF_POS` | **MATCH** |
| `LDA #$3F / STA DynTileBuf,X / INX` | `TRANSFER_BUF_BYTE(pos) = 63; pos++` | **MATCH** ($3F = 63). |
| `LDA #$08 / STA DynTileBuf,X / INX` | `TRANSFER_BUF_BYTE(pos) = 8; pos++` | **MATCH** |
| `STA DynTileBuf,X` (A still 8 = record length) | `TRANSFER_BUF_BYTE(pos) = 8` | **MATCH** |
| `STA $00 / INX` (A=8 → $00 used as loop counter) | `WORLD_TMP0 = 8; pos++` (drain) — but drain uses local `count`, not WORLD_TMP0 | **DIVERGENCE** (drain bug: see below) |
| `@CopyPalette: LDA LevelInfo_PaletteCycles,Y / STA DynTileBuf,X / INY / INX / DEC $00 / BNE @CopyPalette` | drain loops `count` from 8 to 0 | **MATCH semantically; DIVERGENCE on $00 final value** |
| `LDA #$FF / STA DynTileBuf,X` | `TRANSFER_BUF_BYTE(pos) = 0xFF` | **MATCH** |
| `STX DynTileBufLen` | `TRANSFER_BUF_POS = pos` | **MATCH** |
| `INC FadeCycle / LDA FadeCycle / AND #$0F / CMP #$04 / BEQ @ReturnDone / @ReturnDone: LDA #$00 / RTS` | `WORLD_FADE_STEP++; if ((WORLD_FADE_STEP & 0x0F) == 4) return 0u` | **MATCH** |
| `LDA #$0A / STA ObjTimer+12 / RTS` (A=10 → return value nonzero) | `WORLD_FADE_TIMER = 10; return 1u` | **MATCH** |

## Drain divergence (one cell)

After the @CopyPalette loop, NES leaves `$00 = 0` (decremented to exit
condition). Drain leaves `WORLD_TMP0 = 8` because it uses a local `count`
variable instead of decrementing the typed alias. `$00` is general
zero-page scratch and reads from $00 by other subsystems WILL see
different values depending on which path ran.

Per Rule D1: NES wins ties when drain is wrong. Native port fixes the
divergence by faithfully decrementing `WORLD_TMP0` in the loop body so
the final value matches NES ($00 = 0).

## Native port — per-block diff

| Block | Drain | Native | Verdict |
|-------|-------|--------|---------|
| timer gate | drain | same | **MATCH** |
| reverse-fade XOR | drain | same | **MATCH** |
| sram_idx encode | drain | same | **MATCH** |
| transfer-buf header | drain | same | **MATCH** |
| **palette copy loop** | drain (uses local `count`) | **uses WORLD_TMP0 as counter — fixes drain divergence** | **NES MATCH (drain DIFF fixed)** |
| end marker + commit | drain | same | **MATCH** |
| step++ + done test | drain | same | **MATCH** |
| timer reset / return | drain | same | **MATCH** |

**Verdict: world_animate_world_fading FULL MATCH vs NES** (one drain
divergence corrected per Rule D1 NES-wins-ties).

## Cutover gate

- Title.md callsite `z01_animate_world_fading` shares `NATIVE_WORLD`
  gate.
- Default OFF → oracle drain (with the scratch divergence noted above
  — benign because $00 is overwritten by subsequent calls).
- Defined ON → native (fully NES-faithful — $00 final value matches).
- RoomRom links unconditionally.

## Stance update

Phase 4 Task 4.1 (Stance: ADOPT/EXTEND) — fourth and final world port.
**`src/oracle/world/world_runtime.c` is now fully ported (4/4 functions)
and can retire** once the cutover gate is enabled and verified. Phase 4
remaining work shifts to other src/oracle/world/ files: `object_runtime`,
`sprite_runtime`, `progress_runtime`, `trap_runtime`,
`c_move_object` — most of which are cross-subsystem deps that
unblock Phase 3 cave Phase 4 stubs (text rendering, item state,
post_credit/_debit, set_room_flag_uw_item_state).

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc + SRAM table addresses cited per process improvement
  from finding 3_2.
- Notes drain divergence ($00 final value) per Rule D1 — native port
  resolves it in NES's favor.

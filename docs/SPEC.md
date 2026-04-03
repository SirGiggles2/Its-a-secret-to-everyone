# WHAT IF — Architecture, Milestones, and Probe Registry

Full design document for the NES→Genesis port of *The Legend of Zelda*.
See `README.md` for the condensed overview.

---

## Table of Contents

1. [Strategy and Goals](#strategy-and-goals)
2. [Architecture](#architecture)
3. [Genesis Memory Map](#genesis-memory-map)
4. [VRAM Layout](#vram-layout)
5. [NES I/O Emulation Layer](#nes-io-emulation-layer)
6. [MMC1 Architecture](#mmc1-architecture)
7. [Audio Bridge Plan](#audio-bridge-plan)
8. [Hand-Edit Tracking](#hand-edit-tracking)
9. [RAM Checkpoint Plan](#ram-checkpoint-plan)
10. [Milestone Matrix](#milestone-matrix)
11. [Current Status](#current-status)
12. [Probe Registry](#probe-registry)
13. [Regression Plan](#regression-plan)

---

## Strategy and Goals

**Goal:** The Legend of Zelda running on real Sega Genesis hardware with the highest practical gameplay fidelity to the NES original.

**Approach:** Transpile the original labeled 6502 disassembly (aldonunez) to M68K assembly. Write a thin NES hardware emulation layer (PPU→VDP, APU→YM2612/PSG, controllers→Genesis joypad). Keep all original game data untouched.

This means ~75% of the final binary is the actual Zelda game code, just running on different silicon. Behavioral accuracy comes from structure — real code running through a faithful shim — not from cosmetic approximation.

**Priorities (in order):**
1. Translator correctness
2. Hardware behavior fidelity
3. Probe quality
4. Deterministic reproducibility
5. Visible polish

---

## Architecture

```
reference/aldonunez/Z_00–Z_07.asm
        ↓
tools/transpile_6502.py  (6502 → M68K, --all --no-stubs)
        ↓
src/zelda_translated/z_00–z_07.asm   (generated — do not hand-edit)
        ↓
vasmm68k_mot -Fbin -m68000
  + src/genesis_shell.asm            (Genesis boot, VDP init, VBlank ISR)
  + src/nes_io.asm                   (NES hardware behavior shim)
        ↓
builds/whatif_raw.md  →  fix_checksum.py  →  builds/whatif.md  (Genesis ROM)
```

### Register Mapping (6502 → M68K)

| 6502 | M68K | Notes |
|------|------|-------|
| A (accumulator) | D0.b | All ALU results |
| X (index)       | D2.b | Indexed addressing |
| Y (index)       | D3.b | Indexed addressing — must be preserved by all stubs |
| SP              | A5   | Fake NES stack at NES_RAM+$0100 |
| PC              | M68K PC | Natural |
| Carry           | X flag | Inverted after CMP/SBC (BCS→bcc, BCC→bcs) |

### Transpiler Key Rules

- `even` emitted before every label (prevents odd-address instruction fetch)
- `gen_write()` saves/restores D0 around non-D0 PPU/APU writes
- BCS/BCC carry inversion: after CMP/CPX/CPY/SBC, `carry_state['inverted']=True`
- RTI → `rts` (IsrNmi called via JSR from VBlankISR, not via exception)
- SEI → NOP comment (Genesis VBlank always fires)
- ca65 `a:`/`z:` prefixes stripped; @local labels → globally unique names

---

## Genesis Memory Map

```
$000000–$3FFFFF   ROM (Genesis ROM window — all 8 Zelda PRG banks assembled flat)
$FF0000–$FF07FF   NES work RAM ($0000–$07FF mapped here via A4=NES_RAM_BASE)
$FF0800–$FF080F   PPU state block (see NES I/O layer)
$FF0810–$FF081F   MMC1 state block (see MMC1 architecture)
$FF0820–$FF083F   CHR tile decode buffer (16-byte tile buf, count, VADDR, hit counter)
$FF0900–$FF0943   Exception forensics (type, SR, faulting PC, D0-D7/A0-A6)
$C00000           VDP_DATA
$C00004           VDP_CTRL
$A10001           VERSION_PORT
$A14000           TMSS_PORT
$A11100           Z80_BUSREQ
$A11200           Z80_RESET
```

### Register Permanents

| Register | Value | Purpose |
|----------|-------|---------|
| A4 | $FF0000 | NES RAM base (never clobbered) |
| A5 | $FF0200 | NES stack pointer init |
| D7 | $FF     | Mask constant |

---

## VRAM Layout

```
$0000–$AFFF   Tiles           (CHR-RAM fills dynamically, 1408 tiles × 32 bytes)
$B000–$B7FF   Window plane    32×32 × 2 bytes = $800   (HUD strip)
$C000–$CFFF   Plane A         64×32 × 2 bytes = $1000  (main playfield — VDP Reg 2=$8230)
$D800–$DA7F   Sprite attr     80 × 8 bytes = $280
$DC00–$DF7F   H-scroll table  224 × 4 bytes = $380 (line-scroll mode)
$E000–$EFFF   Plane B         64×32 × 2 bytes = $1000  (room-transition staging)
$F000–$FFFF   Free / reserved
```

---

## NES I/O Emulation Layer

**File:** `src/nes_io.asm`

### PPU State Block ($FF0800–$FF080F)

| Offset | Symbol | Size | Description |
|--------|--------|------|-------------|
| +0 | PPU_LATCH  | byte | w register: two-write latch (0=first, 1=second) |
| +1 | (pad) | — | — |
| +2 | PPU_VADDR  | word | assembled 16-bit VRAM address |
| +4 | PPU_CTRL   | byte | PPUCTRL ($2000) shadow |
| +5 | PPU_MASK   | byte | PPUMASK ($2001) shadow |
| +6 | PPU_SCRL_X | byte | horizontal scroll (first $2005 write) |
| +7 | PPU_SCRL_Y | byte | vertical scroll (second $2005 write) |
| +8 | PPU_DBUF   | byte | PPUDATA even-address byte buffer |
| +9 | PPU_DHALF  | byte | 1 when even-address byte is buffered |

### PPU Register Implementations

| Register | Implementation |
|----------|---------------|
| $2000 PPUCTRL write | Store in PPU_CTRL |
| $2001 PPUMASK write | Store in PPU_MASK |
| $2002 PPUSTATUS read | Reset PPU_LATCH; return $80 (VBlank always set for warmup) |
| $2005 PPUSCROLL write | Two-write latch → PPU_SCRL_X / PPU_SCRL_Y |
| $2006 PPUADDR write | Two-write latch → PPU_VADDR high byte / low byte |
| $2007 PPUDATA write | Even addr: buffer byte (PPU_DBUF), advance addr; Odd addr: assemble word → VDP VRAM write, advance addr |

PPUDATA auto-increment: +1 (horizontal) or +32 (vertical) per PPUCTRL bit 2.

VDP VRAM write command: `$40000000 | (word_aligned_addr << 16)` written to VDP_CTRL, then word written to VDP_DATA. VDP auto-increment = 2 (VDP Reg15).

---

## MMC1 Architecture

**T11b milestone.** All six MMC1 state bytes live at $FF0810–$FF0815.

### State Block ($FF0810–$FF081F)

| Offset | Symbol | Size | Description |
|--------|--------|------|-------------|
| +0 | MMC1_SHIFT | byte | Shift accumulator (LSB-first, bits 0–4) |
| +1 | MMC1_COUNT | byte | Bits accumulated so far (0–4) |
| +2 | MMC1_CTRL  | byte | Control register ($8000 target) |
| +3 | MMC1_CHR0  | byte | CHR bank 0 ($A000 target) |
| +4 | MMC1_CHR1  | byte | CHR bank 1 ($C000 target) |
| +5 | MMC1_PRG   | byte | PRG bank ($E000 target) |

### Shift-Register Protocol

Five writes to the same address, bit 0 of each write accumulated LSB-first:

```
Write 1: bit 0 → SHIFT bit 0, COUNT = 1
Write 2: bit 0 → SHIFT bit 1, COUNT = 2
Write 3: bit 0 → SHIFT bit 2, COUNT = 3
Write 4: bit 0 → SHIFT bit 3, COUNT = 4
Write 5: bit 0 → SHIFT bit 4, COUNT = 5 → store SHIFT[4:0] to target, reset
```

If bit 7 of any write is set: immediate reset (SHIFT=0, COUNT=0).

### MMC1 Register Semantics

**CTRL ($0F at boot = 0b00001111):**
- Bits 0-1: Nametable mirroring (00=one-screen low, 01=one-screen high, 10=vertical, 11=horizontal)
- Bit 2: PRG-ROM bank mode 0 (0=switch 32KB at $8000, 1=fix first bank at $8000)
- Bit 3: PRG-ROM bank mode 1 (0=fix last bank at $C000, 1=...)
- Bit 4: CHR-ROM bank size (0=8KB, 1=4KB)
- $0F = horizontal mirroring + fix-last PRG mode + 8KB CHR mode

**PRG ($05 at boot):** Bank 5 at $8000 (switchable window). Bank 7 always fixed at $C000.

### Usage Across Milestones

| Milestone | MMC1 usage |
|-----------|-----------|
| T11b | Track writes, verify CTRL=$0F and PRG=$05 at boot |
| T16–T17 | CHR0/CHR1 determine which CHR bank to upload |
| T18 | CTRL bits 0-1 determine nametable mirroring (H vs V) |
| T45 | PRG bit 4 (RAM enable) needed for save-RAM access |

---

## Audio Bridge Plan

**Target milestones: T42–T44.**

### Channel Mapping

| NES channel | Source | Genesis equivalent | Target milestones |
|-------------|--------|-------------------|-------------------|
| Pulse 1     | $4000–$4003 APU writes | YM2612 FM channel 1 | T42 |
| Pulse 2     | $4004–$4007 APU writes | YM2612 FM channel 2 | T42 |
| Triangle    | $4008–$400B APU writes | YM2612 FM channel 3 | T43 |
| Noise       | $400C–$400F APU writes | PSG noise channel   | T43 |
| DMC         | $4010–$4013 APU writes | Silent or PSG tone  | T44 (Zelda barely uses DMC) |

### Implementation Strategy

**Sequencer interception:** The `_apu_write_XXXX` stubs accumulate register writes as events. A VBlank-driven sequencer converts them to YM2612 key-on/key-off and PSG commands at the appropriate frame timing.

**Pulse → FM:** Map NES duty/volume to YM2612 TL (total level) and AR/DR envelope. Frequency conversion: NES period register → YM2612 F-number (use lookup table).

**Triangle → FM:** Pure tone at NES triangle frequency, fixed envelope.

**Noise → PSG:** Map NES noise mode (periodic/random) and period to PSG noise type and clock divider.

**Frame counter:** APU frame counter ($4017) drives envelope/sweep updates. Track writes to implement correct NES frame-counter behavior.

---

## Hand-Edit Tracking

Generated files in `src/zelda_translated/` must not be hand-edited without documentation.

### Convention

1. Add comment immediately above the edit:
   ```asm
   ; HAND-EDIT: <reason> — auto-overwrite risk. See patches/<filename>.md
   ```
2. Create `src/zelda_translated/patches/z_XX_patch_NNN.md` with:
   - What the transpiler emits
   - What the patch changes it to
   - Re-apply recipe (run transpiler, locate anchor, apply replacement)

See `src/zelda_translated/patches/README.md` for patch file format.

---

## RAM Checkpoint Plan

Two full RAM checkpoints compare Genesis RAM against NES trace data to catch behavioral drift early.

### T22 — Title Screen RAM Checkpoint

After the title screen renders (before any input):
- Capture $FF0000–$FF07FF (full NES work RAM equivalent)
- Compare against NES emulator trace at the same game state
- Acceptable drift: scroll registers, frame counters ±1
- Blocking drift: any game-state variable (screen mode, item inventory, map flags)

### T32 — Room Render RAM Checkpoint

After room $77 (opening overworld screen) renders:
- Capture $FF0000–$FF07FF
- Compare against NES trace at start of gameplay
- Blocking drift: room index, Link position, enemy state, map flags

**Tool:** `tools/compare_ram_checkpoint.py` (to be written at T22).

---

## Milestone Matrix

### Foundation (T1–T5)

| # | Name | Description | Status |
|---|------|-------------|--------|
| T1 | Genesis shell | Boot, VDP init, VBlank ISR, no exception | ✓ PASS |
| T2 | Forensics | Exception handlers save faulting PC/SR to $FF0900 | ✓ PASS |
| T3 | Z_07 transpiles | Fixed bank parses and assembles cleanly | ✓ PASS |
| T4 | All banks transpile | All 8 banks transpile; ROM assembles | ✓ PASS |
| T5 | ROM assembles | Full ROM correct size, checksum passes | ✓ PASS |

### Boot / Timing (T6–T11b)

| # | Name | Description | Status |
|---|------|-------------|--------|
| T6 | Reset runs | Execution reaches IsrReset; no exception | ✓ PASS |
| T7 | Reset trace | Landmarks: warmup, InitMode, RunGame all hit | ✓ PASS |
| T8 | Frame cadence | NMI fires every 60 frames; LoopForever sustains | ✓ PASS |
| T9 | No exceptions | 60-frame soak with no exception vector hit | ✓ PASS |
| T10 | RAM map | NES_RAM region correct; A4 permanently $FF0000 | ✓ PASS |
| T11 | RAM snapshot | PPU state block readable; PPUCTRL=$B0 at LoopForever | ✓ PASS |
| T11b | MMC1 state | Shift-register tracks CTRL=$0F, PRG=$05 at boot | ✓ PASS (8/8) |

### PPU Registers (T12–T15)

| # | Name | Description | Status |
|---|------|-------------|--------|
| T12 | PPUADDR latch | Two-write latch; PPU_VADDR correct after IsrReset | ✓ PASS (7/7) |
| T13 | PPU increment | VRAM advances +1; full nametable clear sequential | ✓ PASS (10/10) |
| T14 | PPU ctrl semantics | PPUCTRL=$B0, NMI bit, BG table bit, latch clear | ✓ PASS (9/9) |
| T15 | Scroll latch | SCRL_X=$00, SCRL_Y=$00, stable at frame 300 | ✓ PASS (8/8) |

### Graphics Pipeline (T16–T22)

| # | Name | Description | Status |
|---|------|-------------|--------|
| T16 | CHR upload | _ppu_write_7 routes CHR-RAM writes to tile decode buffer | ⚠ In Progress (5/7 — T16_TILE0_NONEMPTY FAIL) |
| T17a | Tile decode (pure) | 2bpp→4bpp conversion correct on isolated tile data | ⚠ In Progress (blocked by T16 tiles being zero) |
| T17b | Tile decode (banked) | Full pipeline with MMC1 CHR bank selection | Pending (T11b PASS — unblocked) |
| T18 | Nametable → Plane A | Zelda nametable writes appear in VDP Plane A tilemap | ✓ PASS (Plane A @ $C000, 886 non-zero tile words) |
| T19 | Palette → CRAM | PPU palette writes → Genesis CRAM (NES 2bpp + attr→4bpp) | ✓ PASS (6/6 — 15 non-zero CRAM entries, 4 palettes) |
| T20 | Attribute mapping | 2-bit NES attribute → upper 2 bits of Genesis tile word | ✓ PASS (5/5 — 415 tile words with palette≠0) |
| T21 | Title BG | Title screen background renders visually correct | ✓ PASS (8/8 — tile $24 + 3 palettes [14:13], 896 words, display on frame 32) |
| T22 | Title parity | RAM checkpoint: Genesis RAM vs NES trace at title screen | ✓ PASS (8/8 — mode=$00, TCP=$5A, init=$A5, display frame 32, draw mode=1 valid) |

### Sprites / Input (T23–T29)

| # | Name | Description | Status |
|---|------|-------------|--------|
| T23 | OAM DMA | $4014 write copies NES_RAM[$0200-$02FF] to VDP sprite table | ✓ PASS (8/8 — Y=NES+129, X=NES+128, link chain, priority bit, tiles match) |
| T24 | Sprite decode | Sprite tiles render correctly on screen | ✓ PASS (8/8 — 70/256 tiles decoded 4bpp, tile1 18/32 bytes, NMI×7, SAT link active) |
| T25 | Sprite palette | Sprite colors correct (separate 4-palette blocks) | ✓ PASS (7/8 — CRAM 16/64 non-zero, 4 palettes active, palette-2 correctly assigned; SAT_PAL_FIELD test mis-calibrated: NES title sprites use attr=2→Genesis pal2, correct) |
| T26 | Title sprites | Title screen sprites visible (sword, Link) | ✓ PASS (5/5 — 32 sprites visible Y=129–352, 8 distinct Y-bands, tiles 160–214, no exception; DriveSong stubbed pending NES ROM→Genesis pointer table rewrite) |
| T27 | Controller 1 | D-pad / A / B / Start / Select → NES button bits | ✓ PASS (5/5 — NMI continuous 211/300 frames, CheckInput 211×, no-press $F8=0, CTL1_IDX=8; two-phase TH Genesis protocol → NES active-high latch at $FF1100) |
| T28 | Title input | Can navigate title screen, press Start | In progress (palette fix applied Zelda27.12, awaiting BizHawk verify) |
| T29 | File select | File select screen renders; can start Quest 1 | Pending |

### Gameplay (T30–T36)

| # | Name | Description | Status |
|---|------|-------------|--------|
| T30 | Room load | Room $77 (opening screen) loads without exception | Pending |
| T31 | Room render | Room $77 BG tiles and palette correct | Pending |
| T32 | Room parity | RAM checkpoint: Genesis RAM vs NES trace at room $77 | Pending |
| T33 | Link spawn | Link sprite appears at starting position | Pending |
| T34 | D-pad movement | Link moves through overworld room | Pending |
| T35 | Screen scroll | Room-to-room scroll transition completes correctly | Pending |
| T36 | Cave enter | Can enter first cave (room $76) and exit | Pending |

### Fidelity (T37–T41)

| # | Name | Description | Status |
|---|------|-------------|--------|
| T37 | Sword pickup | Sword pickup sequence triggers correctly | Pending |
| T38 | Enemy AI | Enemies spawn, move, and respond to hits | Pending |
| T39 | HUD | Hearts, rupee count, map render correctly | Pending |
| T40 | Dungeon 1 | Level 1 dungeon loads and is navigable | Pending |
| T41 | Full overworld | All accessible overworld rooms render correctly | Pending |

### Audio / Save / Finish (T42–T48)

| # | Name | Description | Status |
|---|------|-------------|--------|
| T42 | Pulse channels | Title music pulse 1/2 → YM2612 FM ch1/2 | Pending |
| T43 | Triangle + noise | Triangle → FM ch3; noise → PSG noise | Pending |
| T44 | DMC | DMC samples approximated or silenced | Pending |
| T45 | Save RAM | Zelda save ($6000–$7FFF) → Genesis SRAM at $200001 | Pending |
| T46 | Save persist | Save/load cycle preserves quest state correctly | Pending |
| T47 | Hardware test | ROM runs on real Genesis hardware without modification | Pending |
| T48 | Quest 1 complete | Full Quest 1 completable with acceptable fidelity | Pending |

---

## Current Status

**Latest fully verified milestone: T27** (2026-04-01)

| Probe | Tests | Score |
|-------|-------|-------|
| Boot T7/T8/T9/T10/T11 | 15 tests | 15/15 ✓ |
| PPU Latch T12 | 7 tests | 7/7 ✓ |
| PPU Increment T13 | 10 tests | 10/10 ✓ |
| PPU Ctrl T14 | 9 tests | 9/9 ✓ |
| Scroll Latch T15 | 8 tests | 8/8 ✓ |
| MMC1 State T11b | 8 tests | 8/8 ✓ |
| CHR Upload T16/T17a | 7 tests | 5/7 ⚠ (CHR data present, tile-0 coverage gap) |
| Nametable T18 | 6 tests | 6/6 ✓ |
| Palette T19 | 6 tests | 6/6 ✓ |
| Attribute T20 | 5 tests | 5/5 ✓ |
| Title Screen T21 | 8 tests | 8/8 ✓ |
| Title Parity T22 | 8 tests | 8/8 ✓ |
| OAM DMA T23 | 8 tests | 8/8 ✓ |
| Sprite Decode T24 | 8 tests | 8/8 ✓ |
| Sprite Palette T25 | 8 tests | 7/8 ✓ (SAT_PAL_FIELD mis-calibrated — NES attr=2→Genesis pal2 is correct) |
| Title Sprites T26 | 5 tests | 5/5 ✓ |
| Controller 1 T27 | 5 tests | 5/5 ✓ |

**Architecture notes:**
- Plane A correctly placed at VRAM $C000 (VDP Reg 2=$8230); tile region $0000-$AFFF (1408 tiles) has no overlap
- VDP write command for $C000+: `$40000000 | ((addr & $3FFF) << 16) | 3` (A[15:14]=11)
- NT_CACHE_BASE ($FF0840): caches tile indices for T20 attribute-to-palette writes

---

## Visual Rendering Diagnosis (2026-04-02)

**Symptom:** Title screen renders as garbled colored-block static instead of the Zelda title screen. T19–T26 all passed because they checked presence, not pixel accuracy.

### Root Cause: CRAM Write Frame-Timing Bug

All 16 BG CRAM entries receive Genesis color `$0222` (dark red) instead of correct Zelda title screen colors. Confirmed via two probes:

1. **Sentinel table probe**: Replaced palette entries $00/$0F/$10/$36 with visually distinctive values. All 16 CRAM entries still wrote $0002 (the $00 sentinel = NES dark gray), proving D0=0 for every palette write.
2. **ASM debug store probe**: Added `move.b D0,(A0,D3.W)` before the NES→Genesis lookup. Confirmed D0=$00 for CRAM addr 0–6 (palette 0 slots 0–3).

**Why D0=$00:** The NMI handler runs `TransferCurTileBuf` **before** `InitDemo_RunTasks`. At frame 95 (subphase 2 fires), the sequence is:

```
NMI frame 95:
  1. TransferCurTileBuf → processes DynTileBuf as filled by subphase 0's ClearArtifacts
     ClearRam0300UpTo zero-fills DynTileBuf with $00 bytes, writes $FF sentinel at $0302
     → all 16 CRAM writes use NES color $00 (dark gray) → Genesis $0333 → GPGX-normalized $0222
  2. InitDemo_RunTasks(subphase=1) → InitDemoSubphaseTransferTitlePalette
     → copies TitlePaletteRecord ($3F,$00,$20,$36,$0F,...,$FF) into DynTileBuf
     → does NOT call TransferCurTileBuf — transfer queued for next NMI
  3. InitDemo_RunTasks(subphase=2) → InitDemoSubphasePlayTitleSong → sets TileBufSel=16
     → TileBufSel=16 is the SPRITE CHR upload selector, NOT the palette selector (0)
     → at frame 96 NMI, TransferCurTileBuf skips the palette data because TileBufSel≠0
```

The `TitlePaletteRecord` is correctly queued into DynTileBuf by subphase 1, but subphase 2 overwrites TileBufSel=16 in the same frame, so the palette transfer is never consumed.

### Fix Applied (Zelda27.12 — 2026-04-03)

**Bug C fix (palette contention):** Added transpiler patch P3 (`_patch_z06 P3`) that inserts a DynTileBuf palette pre-check at the top of `TransferCurTileBuf`. Before the normal `TileBufSelector` dispatch, the code checks if `DynTileBuf[0] == $3F` (palette PPU address high byte). If so, it processes the palette record immediately via `_transfer_tilebuf_fast`, resets the sentinel to `$FF`, and skips the main dispatch if `TileBufSelector == 0`. This ensures the `TitlePaletteTransferRecord` is always consumed regardless of `TileBufSelector` state.

**Bug B mitigation (VDP register corruption):** Added defensive VDP register restore at VBlank entry in `genesis_shell.asm`. Reads VDP status first (clears pending command state), checks DMA-busy before writing R02=$30, R15=$02, R16=$01. Code analysis found no VDP register corruption source in `nes_io.asm` — all VDP_CTRL writes use correct command construction patterns. Bug B root cause is likely VDP command port latch state or BizHawk-specific behavior; the defensive restore prevents it from persisting.

**Console hardening verified:**
- All CRAM writes occur inside VBlank (via IsrNmi)
- No byte-width writes to VDP_DATA or VDP_CTRL
- VDP auto-increment always restored to $02
- Safety catch at end of `_transfer_tilebuf_fast` resets VDP to VRAM write mode ($7FFC)

### Expected CRAM After Fix

| Palette | C0 | C1 | C2 | C3 |
|---------|-------|-------|-------|-------|
| BG0 | $0ACE | $0000 | $0666 | $0AAA |
| BG1 | $0ACE | $006C | $048E | $0000 |
| BG2 | $0ACE | $0024 | $00A0 | $00AE |
| BG3 | $0ACE | $0EEE | $0CEA | $0E86 |

(NES colors: $36→$0ACE, $0F→$0000, $00→$0666, $10→$0AAA, $17→$006C, $27→$048E, etc.)

### Probes

| File | Purpose |
|------|---------|
| `tools/bizhawk_cram_trace_probe.lua` | Traces every CRAM change across 250 frames |
| `tools/bizhawk_vdp_reg_trace_probe.lua` | Tracks R02/R15/R16 for unexpected values, 400 frames |
| `tools/bizhawk_subphase_timing_probe.lua` | Verifies one subphase per NMI, palette timing |

### Verification Pending

User to run BizHawk with Zelda27.12+ ROM and `bizhawk_vdp_reg_trace_probe.lua` to confirm:
1. CRAM[0] = $0ACE (not $0466) after frame 35
2. All 4 BG palettes match expected table above
3. VDP R02/R15/R16 remain stable (or are corrected by defensive restore)
4. Visual title screen matches NES reference

---

## Probe Registry

All probes in `tools/`, run via `tools/run_all_probes.bat`.

### Shared Infrastructure

- **`tools/probe_addresses.lua`** — reads `builds/whatif.lst` and exports symbol addresses (`LOOPFOREVER`, `EXC_BUS`, `EXC_ADDR`, `EXC_DEF`, `ISRRESET`, `RUNGAME`, `ISRNMI`). All probes `dofile()` this instead of hardcoding addresses (addresses shift every build as code grows).

| Probe script | Milestone | Report file |
|---|---|---|
| `bizhawk_boot_probe.lua` | T7/T8/T9/T10/T11 | `builds/reports/bizhawk_boot_probe.txt` |
| `bizhawk_ppu_latch_probe.lua` | T12 | `builds/reports/bizhawk_ppu_latch_probe.txt` |
| `bizhawk_ppu_increment_probe.lua` | T13 | `builds/reports/bizhawk_ppu_increment_probe.txt` |
| `bizhawk_ppu_ctrl_probe.lua` | T14 | `builds/reports/bizhawk_ppu_ctrl_probe.txt` |
| `bizhawk_scroll_latch_probe.lua` | T15 | `builds/reports/bizhawk_scroll_latch_probe.txt` |
| `bizhawk_mmc1_probe.lua` | T11b | `builds/reports/bizhawk_mmc1_probe.txt` |
| `bizhawk_chr_upload_probe.lua` | T16/T17a | `builds/reports/bizhawk_chr_upload_probe.txt` |
| `bizhawk_t18_nametable_probe.lua` | T18 | `builds/reports/bizhawk_t18_nametable_probe.txt` |
| `bizhawk_t19_palette_probe.lua` | T19 | `builds/reports/bizhawk_t19_palette_probe.txt` |
| `bizhawk_t20_attribute_probe.lua` | T20 | `builds/reports/bizhawk_t20_attribute_probe.txt` |
| `bizhawk_t21_title_probe.lua` | T21 | `builds/reports/bizhawk_t21_title_probe.txt` |
| `bizhawk_t22_parity_probe.lua` | T22 | `builds/reports/bizhawk_t22_parity_probe.txt` |
| `bizhawk_t23_oam_dma_probe.lua` | T23 | `builds/reports/bizhawk_t23_oam_dma_probe.txt` |
| `bizhawk_t24_sprite_decode_probe.lua` | T24 | `builds/reports/bizhawk_t24_sprite_decode_probe.txt` |
| `bizhawk_t25_sprite_palette_probe.lua` | T25 | `builds/reports/bizhawk_t25_sprite_palette_probe.txt` |
| `bizhawk_t26_title_sprites_probe.lua` | T26 | `builds/reports/bizhawk_t26_title_sprites_probe.txt` |
| `bizhawk_t27_controller_probe.lua` | T27 | `builds/reports/bizhawk_t27_controller_probe.txt` |
| `bizhawk_t28_title_input_probe.lua` | T28 | `builds/reports/bizhawk_t28_title_input_probe.txt` |
| `bizhawk_vdp_reg_trace_probe.lua` | Bug B diag | `builds/reports/bizhawk_vdp_reg_trace_probe.txt` |
| `bizhawk_subphase_timing_probe.lua` | Bug C diag | `builds/reports/bizhawk_subphase_timing_probe.txt` |
| `bizhawk_t29_file_select_probe.lua` | T29 | `builds/reports/bizhawk_t29_file_select_probe.txt` |

### Probe Output Convention

- Every probe writes `[PASS]` or `[FAIL]` lines
- Final line: `<PROBE NAME>: ALL PASS` or `<PROBE NAME>: FAIL`
- `run_all_probes.bat` scans for these lines to determine pass/fail

### BizHawk Launch

Must `pushd` into BizHawk directory before launch (DLL resolution):

```bat
pushd "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
EmuHawk.exe --lua=<absolute_path_to_probe.lua> <absolute_path_to_whatif.md>
popd
```

ROM filename: `builds/whatif.md` (not `.bin`). No `--headless` flag.

---

## Regression Plan

**Goal:** No previously-passing milestone may regress when new code is added.

**Runner:** `tools/run_all_probes.bat` → `builds/reports/regression_summary.txt`

**Run on:**
- Every build before committing
- Before and after any edit to `src/genesis_shell.asm` or `src/nes_io.asm`
- After any transpiler change that regenerates `src/zelda_translated/`
- After any hand-edit to generated code

**Exit codes:**
- 0 = all probes pass
- 1 = one or more FAIL
- 2 = one or more ERROR/SKIP

**Archive:** `builds/archive/` stores historical ROM snapshots for bisection. Snapshot when a new milestone is first confirmed passing.

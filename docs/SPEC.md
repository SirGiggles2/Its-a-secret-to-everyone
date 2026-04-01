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
$C000–$CFFF   Plane A         64×32 × 2 bytes = $1000  (main playfield)
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
| T18 | Nametable → Plane A | Zelda nametable writes appear in VDP Plane A tilemap | Pending |
| T19 | Palette → CRAM | PPU palette writes → Genesis CRAM (NES 2bpp + attr→4bpp) | Pending |
| T20 | Attribute mapping | 2-bit NES attribute → upper 2 bits of Genesis tile word | Pending |
| T21 | Title BG | Title screen background renders visually correct | Pending |
| T22 | Title parity | RAM checkpoint: Genesis RAM vs NES trace at title screen | Pending |

### Sprites / Input (T23–T29)

| # | Name | Description | Status |
|---|------|-------------|--------|
| T23 | OAM DMA | $4014 write copies NES_RAM[$0200-$02FF] to VDP sprite table | Pending |
| T24 | Sprite decode | Sprite tiles render correctly on screen | Pending |
| T25 | Sprite palette | Sprite colors correct (separate 4-palette blocks) | Pending |
| T26 | Title sprites | Title screen sprites visible (sword, Link) | Pending |
| T27 | Controller 1 | D-pad / A / B / Start / Select → NES button bits | Pending |
| T28 | Title input | Can navigate title screen, press Start | Pending |
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

**Latest fully verified milestone: T15 + T11b** (2026-04-01)

| Probe | Tests | Score |
|-------|-------|-------|
| Boot T7/T8/T9/T10/T11 | 15 tests | 15/15 ✓ |
| PPU Latch T12 | 7 tests | 7/7 ✓ |
| PPU Increment T13 | 10 tests | 10/10 ✓ |
| PPU Ctrl T14 | 9 tests | 9/9 ✓ |
| Scroll Latch T15 | 8 tests | 8/8 ✓ |
| MMC1 State T11b | 8 tests | 8/8 ✓ |
| CHR Upload T16/T17a | 7 tests | 5/7 ⚠ (in progress) |

**Active issue — T16 TILE0_NONEMPTY FAIL:**
- VDP VRAM $0000–$01FF (sprite tiles 0–15) all zero after 180 frames
- VRAM $2000 has $24 — ambiguous: could be BG CHR data ($1000→VRAM $2000) or nametable value ($24 = blank tile written by ClearNameTable to wrong address). Wide VRAM scan needed to disambiguate.
- `CHR_HIT_COUNT` debug counter added to `_ppu_write_7` CHR path — need probe re-run to confirm whether CHR path is entered at all
- Hypothesis A: Zelda's sprite CHR tiles ($0000–$0FFF) are genuinely blank at boot (game hasn't loaded them yet)
- Hypothesis B: CHR path not entered (PPU_VADDR never in $0000–$1FFF range during tested frames)

**Immediate next steps:**
1. Run CHR upload probe with new `CHR_HIT_COUNT` log to confirm hypothesis A vs B
2. If hit count = 0: determine when/whether Zelda writes sprite CHR at boot
3. If hit count > 0: VDP write address computation is wrong — audit `.chr_convert_upload`
4. T17b (banked decode) and T18 (nametable→Plane A) after T16 resolves

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

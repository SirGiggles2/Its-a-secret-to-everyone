# WHAT IF — *The Legend of Zelda* NES → Sega Genesis Port

An accuracy-first port of Nintendo's *The Legend of Zelda* (1986, NES) to the Sega Genesis / Mega Drive.

This is a **port by translation and emulation of expectations**, not a from-scratch rewrite. The goal is to preserve as much of the original game's logic and data as possible, translate the CPU-side code to Motorola 68000 assembly, and reproduce the NES hardware assumptions through a Genesis-side compatibility layer.

---

## Strategy

1. **Transpile** the original labeled Zelda 6502 disassembly into M68K assembly
2. **Shim** NES hardware expectations through a Genesis compatibility layer
3. **Preserve original data** as much as possible
4. **Validate behavior continuously** with scripted probes and parity checks

This keeps the original game logic at center and moves the hard work into two places: the **translator** (`tools/transpile_6502.py`) and the **NES-on-Genesis hardware behavior layer** (`src/nes_io.asm`).

For the full design rationale, architecture notes, and milestone definitions, see [`docs/SPEC.md`](docs/SPEC.md).

---

## Project Structure

```text
FINAL TRY/
├── README.md                           ← you are here
├── build.bat                           ← build script (transpile → assemble → checksum)
│
├── src/
│   ├── genesis_shell.asm               ← Genesis startup, vector table, VDP init, VBlank ISR
│   ├── nes_io.asm                      ← NES hardware-behavior compatibility shim
│   └── zelda_translated/               ← GENERATED — do not hand-edit (see SPEC.md § Hand-Edit Tracking)
│       ├── z_00.asm through z_07.asm
│       └── patches/                    ← tracked hand-edit recipes
│
├── tools/
│   ├── transpile_6502.py               ← 6502 → M68K transpiler
│   ├── fix_checksum.py                 ← patches Genesis ROM header checksum
│   ├── run_all_probes.bat              ← regression: runs all milestone probes in sequence
│   ├── probe_addresses.lua             ← shared: reads whatif.lst, exports symbol addresses for all probes
│   ├── bizhawk_*_probe.lua             ← BizHawk Lua probe scripts (see SPEC.md § Probe Registry)
│   └── run_bizhawk_*_probe.bat         ← launcher scripts for each probe
│
├── reference/
│   ├── aldonunez/                      ← original Zelda 6502 source (Z_00.asm–Z_07.asm)
│   └── sega2f_files/                   ← Genesis hardware reference material
│
├── builds/
│   ├── whatif.md                       ← latest built ROM (Genesis .md format)
│   ├── whatif.lst                      ← assembly listing / symbol addresses
│   ├── reports/                        ← probe output
│   └── archive/                        ← historical build snapshots
│
└── docs/
    ├── SPEC.md                         ← full architecture, milestones, probes, risks
    ├── NES_DESIGN_MAP.md               ← Zelda frame/NMI structure notes
    ├── NES_CONVERTER.md                ← general NES → Genesis conversion guide
    └── progress.md                     ← development log and decisions
```

---

## How to Build

### Prerequisites

- **vasm** (`vasmm68k_mot.exe`) — Motorola 68000 assembler
- **Python 3.9+** — for transpiler and checksum tool
- **The Legend of Zelda (USA).nes** — at repo root; not committed
- **BizHawk 2.11+** *(optional for building; required for milestone validation and regression testing)* — runs automated probe scripts

### Build

```bat
build.bat
```

Pipeline: transpile (`transpile_6502.py --all --no-stubs`) → assemble (`vasmm68k_mot -Fbin -m68000`) → checksum (`fix_checksum.py`).

### Run Regression Probes

```bat
tools\run_all_probes.bat
```

Runs every milestone probe in sequence and writes a combined pass/fail summary to `builds/reports/regression_summary.txt`.

---

## Current Status

**Completed through T35 + T11b + T42–T44 audio tier** (2026-04-16, Zelda27.184). T36 cave entry at 8/9 (1-frame phase residual parked). T39 HUD PASS after Stage C row guard. T37 sword pickup infra built, pickup trigger unresolved. T28 (title story-soak) and T29 (NMI threshold) tracked as known-yellow.

| Milestone | Status |
|---|---|
| T1–T5 | ✓ Foundation complete (shell, forensics, transpiler, ROM assembly) |
| T6–T11b | ✓ Boot/timing/memory + MMC1 state tracking |
| T12–T15 | ✓ PPU register semantics complete (latch, increment, ctrl, scroll) |
| T16–T22 | ✓ Graphics pipeline (CHR upload, nametable, palette, attribute, title, parity) |
| T23–T27 | ✓ Sprites + controller (OAM DMA, decode, palette, title sprites, input) |
| T28–T29 | ⚠ Title/file-select tracked as known-yellow (story-soak stall f2107; NMI threshold) |
| T30–T35 | ✓ Room load/render/parity/link spawn/D-pad movement/left scroll parity |
| T36 | ⚠ Cave entry 8/9 (1-frame phase residual parked, user-accepted) |
| T37 | ⚠ Sword pickup infra built; pickup trigger unresolved |
| T38–T41 | Pending (enemy AI, HUD polish, Dungeon 1, full overworld) |
| T42–T44 | ✓ Audio tier complete (native YM2612+PSG player, DMC streamer) |
| T45–T48 | Pending (SRAM save, hardware test, Quest 1 completion) |

Full milestone matrix with pass/fail evidence: [`docs/SPEC.md`](docs/SPEC.md) § Current Status.

### Immediate Next Steps

1. **T37 sword pickup trigger** — Link stalls at y=$8D. Likely merchant collision rect fires but pickup state transition doesn't consume. Parity infra already built in `compare_t37_sword_parity.py`.
2. **T12/T13 probe rewrite** — stale VRAM assumption invalidates boot signal.
3. **T16 HUD "UU" glyphs** — CHR upload cosmetic defect.
4. **Post-T37**: T38 enemy AI, T45 SRAM save, then Genesis-native enhancements (6-button pad, Window-plane HUD, flicker-free sprites).

---

## Development Priorities

When in doubt, prioritize in this order:

1. Translator correctness
2. Hardware behavior fidelity
3. Probe quality
4. Deterministic reproducibility
5. Visible polish

Accuracy comes from structure, not cosmetics.

---

## Final Target

**The Legend of Zelda running on real Sega Genesis hardware with the highest practical gameplay fidelity to the NES original.**

Not merely "it runs," but "it runs for the right reasons."

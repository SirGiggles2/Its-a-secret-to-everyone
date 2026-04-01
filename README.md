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

**Completed through T15 + T11b** (2026-04-01). T16/T17a (CHR tile upload) in progress — 5/7 passing.

| Milestone | Status |
|---|---|
| T1–T5 | ✓ Foundation complete (shell, forensics, transpiler, ROM assembly) |
| T6–T11 | ✓ Boot/timing/memory complete (reset trace, NMI cadence, RAM parity) |
| T11b | ✓ MMC1 state tracking — CTRL=$0F, PRG=$05 verified (8/8) |
| T12–T15 | ✓ PPU register semantics complete (latch, increment, ctrl, scroll) |
| T16/T17a | ⚠ In progress — CHR upload path implemented, 5/7 passing; sprite tile VRAM zero under investigation |
| T17b–T48 | Pending |

Full milestone matrix with pass/fail evidence: [`docs/SPEC.md`](docs/SPEC.md) § Current Status.

### Immediate Next Steps

1. Resolve T16 TILE0_NONEMPTY FAIL — run probe with `CHR_HIT_COUNT` debug counter to confirm whether CHR path is entered
2. T18 (nametable → Plane A) after T16 resolves
3. T17b (banked CHR decode) — unblocked now that T11b passes

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

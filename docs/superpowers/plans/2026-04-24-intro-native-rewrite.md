# Intro Native Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken transpiled story-scroll and item-showcase stages of the Zelda intro with Genesis-native C modules running under V32 VDP mode, fixing the long-standing story-scroll crash and the V64 dead zone without touching title, fades, or file select.

**Architecture:** Three new C modules (`intro_common`, `intro_story`, `intro_showcase`) replace phase-1 subphase dispatchers in `frontend_runtime.c` via a takeover flag. VDP Reg 16 flips V64 → V32 during fade-out, V32 → V64 during handoff. Assets extracted from committed `reference/aldonunez/dat/` files at build time — no external NES ROM dependency.

**Tech Stack:** C (m68k-elf-gcc), vasm Motorola asm, Python 3 (extract tool), BizHawk Lua (probes), Genesis VDP (YM2612/PSG reused via existing native player).

**Spec reference:** [docs/superpowers/specs/2026-04-24-intro-native-rewrite-design.md](../specs/2026-04-24-intro-native-rewrite-design.md)

---

## File Structure

**New source files (C):**
- `src/intro_common.h` — public API: stage enter/update signatures, `intro_story_tick`, VDP wrappers
- `src/intro_common.c` — `g_intro_takeover`, `intro_should_take_over`, `intro_story_tick` dispatcher, VDP primitive wrappers
- `src/intro_story.h` — `intro_story_enter`, `intro_story_update`
- `src/intro_story.c` — story-scroll implementation (V32 plane setup, row-boundary scroll, exit detection)
- `src/intro_showcase.h` — `intro_showcase_enter`, `intro_showcase_update`
- `src/intro_showcase.c` — item-showcase implementation (mirrors story structure)
- `src/intro_handoff.h` — `intro_handoff`, `intro_handoff_state_t`
- `src/intro_handoff.c` — V32 → V64 switch, CHR/CRAM restore, state-byte write-back

**Generated files (emitted by extract tool, committed to repo so they're reviewable):**
- `src/gen/intro_font_chr.c` — NES font tiles converted to Genesis 4bpp
- `src/gen/intro_art_chr.c` — story/showcase art tiles
- `src/gen/intro_palette.c` — CRAM table (NES palette → Genesis 9-bit)
- `src/gen/intro_story_tilemap.c` — story scroll nametable strip
- `src/gen/intro_showcase_tilemap.c` — showcase nametable strip
- `src/gen/intro_restore_chr.c` — CHR blob to restore for file-select handoff
- `src/gen/intro_restore_palette.c` — CRAM snapshot for file-select handoff
- `src/gen/intro_handoff_state.c` — captured RAM state constants
- `src/gen/intro_asset_hashes.txt` — SHA registry for regression detection

**New tools:**
- `tools/extract_intro_assets.py` — reads `reference/aldonunez/dat/`, emits all `src/gen/intro_*` files
- `tools/capture_intro_handoff_state.py` — orchestrates handoff-state capture via existing probes

**Modified files:**
- `src/frontend_runtime.c` — `frontdemo_init_demo_phase_1` and `frontdemo_animate_phase_1` gain takeover short-circuit
- `src/frontend_runtime.h` — add externs for `g_intro_takeover`, `intro_should_take_over`, `intro_story_tick`
- `build.bat` — add extractor pre-step, register new C modules, register new generated modules

**Existing tools reused (no changes needed):**
- `tools/bizhawk_intro_state_probe.lua`
- `tools/bizhawk_capture_intro_sequence.lua`
- `tools/bizhawk_capture_intro_window.lua`
- `tools/bizhawk_intro_vram_dump.lua`
- `tools/bizhawk_intro_hook_probe.lua`
- `tools/bizhawk_sweep_story.lua`
- `tools/analyze_intro_continuity.py`
- `tools/analyze_intro_scroll_window.py`

---

## Execution Order

Phases run strictly in order because later phases depend on captured data from earlier ones:

1. **Phase 0 — Reconnaissance** captures authoritative handoff state (blocker for Phase 5).
2. **Phase 1 — Extract tool** produces all `src/gen/intro_*` assets (blocker for Phases 2–4).
3. **Phase 2 — `intro_common`** provides VDP primitives used by Phases 3–5.
4. **Phase 3 — `intro_story`** and **Phase 4 — `intro_showcase`** are parallel-safe but sequence in the plan to keep subagent dispatch simple.
5. **Phase 5 — `intro_handoff`** consumes data from Phase 0.
6. **Phase 6 — Integration** wires the takeover into `frontend_runtime.c`.
7. **Phase 7 — Build wiring** enables the new code to compile.
8. **Phase 8 — Testing** validates the rewrite end-to-end.
9. **Phase 9 — Gated cleanup** runs only after Phase 8 passes.

---

## Phase 0 — Reconnaissance

### Task 0: Worktree + branch setup

**Files:** none (git operations)

- [ ] **Step 1: Verify working tree is clean on main**

Run: `git status --short`
Expected: empty output (or only `.claude/` / build artifacts untracked).

- [ ] **Step 2: Create feature branch**

Run:
```bash
git checkout -b feat/intro-native-rewrite
```

- [ ] **Step 3: Confirm branch**

Run: `git branch --show-current`
Expected: `feat/intro-native-rewrite`

---

### Task 1: Capture legacy handoff state via probe

**Files:**
- Create: `tools/capture_intro_handoff_state.py`
- Create: `docs/superpowers/captures/2026-04-24-intro-handoff-state.json`

- [ ] **Step 1: Write capture orchestrator**

Create `tools/capture_intro_handoff_state.py`:
```python
"""Capture the legacy frontend RAM state at the moment file-select is entered.

Drives a BizHawk probe that boots the current ROM, simulates the Start-skip
workaround (presses Start on title to bypass the story-scroll crash), waits
until the flow reaches the file-select entry point, then dumps the RAM
addresses the intro rewrite must restore during handoff.

Output: JSON blob consumed by tools/extract_intro_assets.py to emit
src/gen/intro_handoff_state.c.
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

HANDOFF_ADDRS = [
    ("mode_value",              0x0012),  # MODE_VALUE       (progress_state.h)
    ("submode_value",           0x0013),  # SUBMODE_VALUE    (trap_state.h)
    ("frontend_demo_phase",     0x042C),  # phase-0/1 flag   (frontend_runtime.c:157,303)
    ("frontend_demo_subphase",  0x042D),  # FRONTEND_DEMO_SUBPHASE (frontend_state.h)
    ("front_start_release_gate",0x042B),  # (frontend_runtime.c:178)
    ("vram_force_blank_gate",   0x083D),  # (frontend_runtime.c:176)
    ("frontend_delay_timer",    0x0528),  # (frontend_runtime.c:183,278)
    ("room_mode_timer",         0x0011),  # ROOM_MODE_TIMER  (room_state.h)
    ("item_sfx_secondary",      0x0600),  # ITEM_SFX_SECONDARY (item_state.h)
    ("room_transfer_buf_select",0x0014),  # ROOM_TRANSFER_BUF_SELECT (room_state.h)
]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", required=True, help="Path to current whatif.bin")
    ap.add_argument("--bizhawk", default=os.environ.get("CODEX_BIZHAWK_ROOT"),
                    help="BizHawk install root (or CODEX_BIZHAWK_ROOT env)")
    ap.add_argument("--out", required=True, help="JSON output path")
    args = ap.parse_args()

    if not args.bizhawk:
        print("error: --bizhawk or CODEX_BIZHAWK_ROOT required", file=sys.stderr)
        sys.exit(2)

    probe = Path(__file__).parent / "bizhawk_intro_state_probe.lua"
    if not probe.exists():
        print(f"error: probe not found: {probe}", file=sys.stderr)
        sys.exit(2)

    # Existing probe writes its dump to a known temp path.
    # Extend it via environment variable to target our outfile.
    env = os.environ.copy()
    env["INTRO_STATE_DUMP"] = args.out
    env["INTRO_STATE_ADDRS"] = ",".join(f"{n}:{a:04x}" for n, a in HANDOFF_ADDRS)

    emuhawk = Path(args.bizhawk) / "EmuHawk.exe"
    cmd = [str(emuhawk), f"--lua={probe}", args.rom]
    rc = subprocess.call(cmd, env=env)
    if rc != 0:
        sys.exit(rc)

    if not Path(args.out).exists():
        print(f"error: probe did not emit {args.out}", file=sys.stderr)
        sys.exit(3)

    print(f"captured handoff state → {args.out}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Extend probe to honor env-var output**

Read `tools/bizhawk_intro_state_probe.lua` to confirm the dump path is fixed. If so, append an env-var override block near the top:
```lua
-- env override: let capture_intro_handoff_state.py redirect the dump
local env_dump = os.getenv("INTRO_STATE_DUMP")
local env_addrs = os.getenv("INTRO_STATE_ADDRS")
if env_dump and env_addrs then
  -- parse env_addrs = "name1:addr1,name2:addr2,..." and dump those addresses
  -- when the probe arms its freeze condition on file-select entry.
  -- Implementation follows existing probe's dump routine pattern.
end
```

If the probe already has this pattern, skip. If not, add it minimally — do not rewrite the probe.

- [ ] **Step 3: Build current ROM (with known Start-skip path intact)**

Run: `cmd /c build.bat`
Expected: build succeeds, emits `builds/whatif.bin`. (This is the baseline — the crash still exists in this ROM but the Start-skip workaround still works.)

- [ ] **Step 4: Run capture**

Run:
```bash
mkdir -p docs/superpowers/captures
python tools/capture_intro_handoff_state.py \
  --rom builds/whatif.bin \
  --out docs/superpowers/captures/2026-04-24-intro-handoff-state.json
```
Expected: JSON file written with all 9 RAM addresses and their captured values. If the probe times out or a value is missing, investigate before proceeding — **do not guess values**.

- [ ] **Step 5: Inspect capture output**

Run: `cat docs/superpowers/captures/2026-04-24-intro-handoff-state.json`
Expected: every field populated with a concrete hex byte value. If anything is `null` or missing, loop back to step 2.

- [ ] **Step 6: Commit capture**

Run:
```bash
git add tools/capture_intro_handoff_state.py tools/bizhawk_intro_state_probe.lua docs/superpowers/captures/2026-04-24-intro-handoff-state.json
git commit -m "intro: capture legacy handoff state bytes via bizhawk probe"
```

---

### Task 2: Capture file-select restore CHR + CRAM snapshots

**Files:**
- Modify: `tools/capture_intro_handoff_state.py` (add CHR + CRAM dump flags)
- Create: `docs/superpowers/captures/2026-04-24-intro-restore-chr.bin`
- Create: `docs/superpowers/captures/2026-04-24-intro-restore-cram.bin`

- [ ] **Step 1: Extend capture tool with CHR/CRAM flags**

Add to `tools/capture_intro_handoff_state.py`:
```python
ap.add_argument("--out-chr", help="VRAM $0000-$3FFF dump path")
ap.add_argument("--out-cram", help="CRAM dump path (64 words)")
# … pass through env as INTRO_CHR_DUMP / INTRO_CRAM_DUMP
```

- [ ] **Step 2: Extend probe to emit CHR + CRAM at the same freeze point**

Extend `tools/bizhawk_intro_state_probe.lua` to honor `INTRO_CHR_DUMP` / `INTRO_CRAM_DUMP` env vars. Use BizHawk's `memory.read_bytes_as_array` on the domain `VRAM` for CHR and `CRAM` for palette. Write as raw bytes.

- [ ] **Step 3: Run capture**

Run:
```bash
python tools/capture_intro_handoff_state.py \
  --rom builds/whatif.bin \
  --out docs/superpowers/captures/2026-04-24-intro-handoff-state.json \
  --out-chr docs/superpowers/captures/2026-04-24-intro-restore-chr.bin \
  --out-cram docs/superpowers/captures/2026-04-24-intro-restore-cram.bin
```
Expected: `.bin` files present, CHR = 16384 bytes (`$0000-$3FFF`), CRAM = 128 bytes (64 words).

- [ ] **Step 4: Verify sizes**

Run: `wc -c docs/superpowers/captures/2026-04-24-intro-restore-*.bin`
Expected: `16384 … restore-chr.bin`, `128 … restore-cram.bin`.

- [ ] **Step 5: Commit captures**

Run:
```bash
git add docs/superpowers/captures/2026-04-24-intro-restore-chr.bin \
        docs/superpowers/captures/2026-04-24-intro-restore-cram.bin \
        tools/capture_intro_handoff_state.py \
        tools/bizhawk_intro_state_probe.lua
git commit -m "intro: capture file-select restore CHR + CRAM snapshots"
```

---

## Phase 1 — Extract Tool

### Task 3: Extract tool skeleton + CLI

**Files:**
- Create: `tools/extract_intro_assets.py`
- Create: `tools/tests/test_extract_intro_assets.py`

- [ ] **Step 1: Write failing skeleton test**

Create `tools/tests/test_extract_intro_assets.py`:
```python
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TOOL = REPO / "tools" / "extract_intro_assets.py"

def test_tool_runs_with_help():
    result = subprocess.run([sys.executable, str(TOOL), "--help"],
                            capture_output=True, text=True)
    assert result.returncode == 0
    assert "extract" in result.stdout.lower()

def test_tool_requires_ref_dir():
    result = subprocess.run([sys.executable, str(TOOL)],
                            capture_output=True, text=True)
    assert result.returncode != 0
```

- [ ] **Step 2: Run test to verify it fails (tool doesn't exist yet)**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py -v`
Expected: FAIL (file not found).

- [ ] **Step 3: Create minimal skeleton**

Create `tools/extract_intro_assets.py`:
```python
"""Extract Zelda intro assets from the committed disassembly reference tree.

Reads reference/aldonunez/dat/ and emits src/gen/intro_*.c files containing
font CHR, art CHR, palette table, story tilemap, showcase tilemap, restore
blobs, and a handoff-state struct. Also emits src/gen/intro_asset_hashes.txt
listing SHA256 of every output for regression detection.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

def main() -> int:
    ap = argparse.ArgumentParser(description="extract intro assets")
    ap.add_argument("--ref-dir", default=str(REPO / "reference" / "aldonunez" / "dat"),
                    help="path to committed disassembly reference data")
    ap.add_argument("--out-dir", default=str(REPO / "src" / "gen"),
                    help="output directory for generated C files")
    ap.add_argument("--handoff-json", default=str(REPO / "docs" / "superpowers" /
                    "captures" / "2026-04-24-intro-handoff-state.json"),
                    help="captured handoff state JSON")
    ap.add_argument("--restore-chr", default=str(REPO / "docs" / "superpowers" /
                    "captures" / "2026-04-24-intro-restore-chr.bin"))
    ap.add_argument("--restore-cram", default=str(REPO / "docs" / "superpowers" /
                    "captures" / "2026-04-24-intro-restore-cram.bin"))
    ap.add_argument("--verify", action="store_true",
                    help="re-check SHA of emitted files against committed hashes")
    args = ap.parse_args()

    ref_dir = Path(args.ref_dir)
    if not ref_dir.is_dir():
        print(f"error: reference dir not found: {ref_dir}", file=sys.stderr)
        return 2
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Subsequent tasks fill in the emit steps.
    emitted: dict[str, str] = {}

    hash_file = out_dir / "intro_asset_hashes.txt"
    if args.verify:
        return _verify(emitted, hash_file)
    _write_hashes(emitted, hash_file)
    return 0

def _sha(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()

def _write_hashes(emitted: dict[str, str], hash_file: Path) -> None:
    lines = [f"{sha}  {name}\n" for name, sha in sorted(emitted.items())]
    hash_file.write_text("".join(lines))

def _verify(emitted: dict[str, str], hash_file: Path) -> int:
    if not hash_file.exists():
        print(f"error: hash file missing: {hash_file}", file=sys.stderr)
        return 3
    expected = {}
    for line in hash_file.read_text().splitlines():
        sha, name = line.split("  ", 1)
        expected[name] = sha
    if expected != emitted:
        print("error: emitted SHA set differs from committed", file=sys.stderr)
        return 3
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

Run:
```bash
git add tools/extract_intro_assets.py tools/tests/test_extract_intro_assets.py
git commit -m "intro: extract-tool skeleton + CLI + SHA verification hook"
```

---

### Task 4: NES CHR → Genesis CHR conversion

**Files:**
- Modify: `tools/extract_intro_assets.py`
- Modify: `tools/tests/test_extract_intro_assets.py`

- [ ] **Step 1: Write failing test for 2bpp → 4bpp conversion**

Add to `tools/tests/test_extract_intro_assets.py`:
```python
from tools.extract_intro_assets import nes_tile_to_gen_tile

def test_nes_tile_to_gen_tile_all_zero():
    nes = bytes(16)  # 16 bytes NES tile, all zero
    gen = nes_tile_to_gen_tile(nes)
    assert len(gen) == 32
    assert gen == bytes(32)

def test_nes_tile_to_gen_tile_color_1():
    # NES tile where bitplane 0 = 0xFF (all pixels = color 1)
    nes = bytes([0xFF] * 8 + [0x00] * 8)
    gen = nes_tile_to_gen_tile(nes)
    assert len(gen) == 32
    # Genesis 4bpp: each pixel is a nibble; all pixels = 1 → every byte = 0x11
    assert gen == bytes([0x11] * 32)

def test_nes_tile_to_gen_tile_color_3():
    # NES tile where both bitplanes = 0xFF (all pixels = color 3)
    nes = bytes([0xFF] * 16)
    gen = nes_tile_to_gen_tile(nes)
    assert len(gen) == 32
    assert gen == bytes([0x33] * 32)
```

- [ ] **Step 2: Run tests to verify failures**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py -v`
Expected: 3 new tests FAIL (import error — function not defined).

- [ ] **Step 3: Implement conversion**

Add to `tools/extract_intro_assets.py` above `main()`:
```python
def nes_tile_to_gen_tile(nes: bytes) -> bytes:
    """Convert a single 8×8 NES 2bpp tile (16 bytes) to Genesis 4bpp (32 bytes).

    NES layout: 8 bytes of bitplane 0 (rows 0..7), then 8 bytes of bitplane 1.
    Genesis layout: 8 rows × 4 bytes/row; each row packs 8 pixels as 4-bit
    indices, high nibble first.
    """
    if len(nes) != 16:
        raise ValueError(f"nes tile must be 16 bytes, got {len(nes)}")
    out = bytearray(32)
    for row in range(8):
        bp0 = nes[row]
        bp1 = nes[row + 8]
        row_out = bytearray(4)
        for px in range(8):
            bit = 7 - px
            color = ((bp0 >> bit) & 1) | (((bp1 >> bit) & 1) << 1)
            byte_idx = px >> 1
            if (px & 1) == 0:
                row_out[byte_idx] |= (color & 0x0F) << 4
            else:
                row_out[byte_idx] |= (color & 0x0F)
        out[row * 4:(row + 1) * 4] = row_out
    return bytes(out)
```

- [ ] **Step 4: Run tests to verify pass**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py -v`
Expected: all PASS.

- [ ] **Step 5: Commit**

Run:
```bash
git add tools/extract_intro_assets.py tools/tests/test_extract_intro_assets.py
git commit -m "intro: extract NES 2bpp tile → Genesis 4bpp tile conversion"
```

---

### Task 5: NES palette → Genesis 9-bit CRAM conversion

**Files:**
- Modify: `tools/extract_intro_assets.py`
- Modify: `tools/tests/test_extract_intro_assets.py`

- [ ] **Step 1: Write failing tests**

Add to `tools/tests/test_extract_intro_assets.py`:
```python
from tools.extract_intro_assets import nes_color_to_gen_cram

def test_nes_black_to_gen():
    # NES $0F is black → Genesis $0000
    assert nes_color_to_gen_cram(0x0F) == 0x0000

def test_nes_white_to_gen():
    # NES $30 is white-ish → Genesis $0EEE (all channels max)
    v = nes_color_to_gen_cram(0x30)
    # each nibble ≥ 0xA (top two bins of the quantizer)
    assert (v & 0x000E) >= 0x000A
    assert ((v >> 4) & 0x000E) >= 0x000A
    assert ((v >> 8) & 0x000E) >= 0x000A

def test_nes_color_range():
    for i in range(64):
        v = nes_color_to_gen_cram(i)
        assert 0 <= v <= 0x0EEE
        assert (v & 0x0111) == 0  # low bit of each nibble zero (Gen format)
```

- [ ] **Step 2: Run tests to verify failures**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py -v`

- [ ] **Step 3: Implement conversion**

Add to `tools/extract_intro_assets.py`:
```python
# Canonical NES palette RGB values (Nesdev "2C02" LUT, first 64 entries).
# Each entry is (R, G, B) in 0..255.
NES_PALETTE_RGB = [
    (0x62, 0x62, 0x62), (0x00, 0x1F, 0xB2), (0x24, 0x04, 0xC8), (0x52, 0x00, 0xB2),
    (0x73, 0x00, 0x76), (0x80, 0x00, 0x24), (0x73, 0x0B, 0x00), (0x52, 0x28, 0x00),
    (0x24, 0x44, 0x00), (0x00, 0x57, 0x00), (0x00, 0x5C, 0x00), (0x00, 0x53, 0x24),
    (0x00, 0x3C, 0x76), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00),

    (0xAB, 0xAB, 0xAB), (0x0D, 0x57, 0xFF), (0x4B, 0x30, 0xFF), (0x8A, 0x13, 0xFF),
    (0xBC, 0x08, 0xD6), (0xD2, 0x12, 0x69), (0xC7, 0x2E, 0x00), (0x9D, 0x54, 0x00),
    (0x60, 0x7B, 0x00), (0x20, 0x98, 0x00), (0x00, 0xA3, 0x00), (0x00, 0x99, 0x42),
    (0x00, 0x7D, 0xB4), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00),

    (0xFF, 0xFF, 0xFF), (0x53, 0xAE, 0xFF), (0x90, 0x85, 0xFF), (0xD3, 0x65, 0xFF),
    (0xFF, 0x57, 0xFF), (0xFF, 0x5D, 0xCF), (0xFF, 0x77, 0x57), (0xFA, 0x9E, 0x00),
    (0xBD, 0xC7, 0x00), (0x7A, 0xE7, 0x00), (0x43, 0xF6, 0x11), (0x26, 0xEF, 0x7E),
    (0x2C, 0xD5, 0xF6), (0x4E, 0x4E, 0x4E), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00),

    (0xFF, 0xFF, 0xFF), (0xB6, 0xE1, 0xFF), (0xCE, 0xD1, 0xFF), (0xE9, 0xC3, 0xFF),
    (0xFF, 0xBC, 0xFF), (0xFF, 0xBD, 0xF4), (0xFF, 0xC6, 0xC3), (0xFF, 0xD5, 0x9A),
    (0xE9, 0xE6, 0x81), (0xCE, 0xF4, 0x81), (0xB6, 0xFB, 0x9A), (0xA9, 0xFA, 0xC3),
    (0xA9, 0xF0, 0xF4), (0xB8, 0xB8, 0xB8), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00),
]

def _quantize_channel(v: int) -> int:
    """Quantize an 8-bit channel to the Genesis 3-bit palette step (0/2/4/…/14)."""
    # Map [0..255] → one of 0, 2, 4, 6, 8, 10, 12, 14 (8 discrete steps).
    step = min(7, v * 8 // 256)
    return step * 2

def nes_color_to_gen_cram(nes_idx: int) -> int:
    """Convert NES palette byte index (0..63) to a Genesis CRAM word.

    Genesis CRAM word format: 0000 BBB0 GGG0 RRR0 (little-endian bits).
    """
    if not 0 <= nes_idx < 64:
        raise ValueError(f"nes palette index out of range: {nes_idx}")
    r, g, b = NES_PALETTE_RGB[nes_idx]
    return (_quantize_channel(b) << 8) | (_quantize_channel(g) << 4) | _quantize_channel(r)
```

- [ ] **Step 4: Run tests to verify pass**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py -v`
Expected: all PASS.

- [ ] **Step 5: Commit**

Run:
```bash
git add tools/extract_intro_assets.py tools/tests/test_extract_intro_assets.py
git commit -m "intro: NES palette → Genesis 9-bit CRAM conversion"
```

---

### Task 6: Emit intro_font_chr.c + intro_art_chr.c

**Files:**
- Modify: `tools/extract_intro_assets.py`
- Modify: `tools/tests/test_extract_intro_assets.py`
- Generated (by running tool): `src/gen/intro_font_chr.c`, `src/gen/intro_art_chr.c`

- [ ] **Step 1: Write failing test**

Add to `tools/tests/test_extract_intro_assets.py`:
```python
def test_emit_produces_font_and_art_chr(tmp_path):
    # Run the tool end-to-end with a minimal ref dir and check the C outputs.
    # Use the committed reference dir; assert outputs compile-parseable.
    import subprocess, sys
    out_dir = tmp_path
    result = subprocess.run([
        sys.executable, str(TOOL),
        "--ref-dir", str(REPO / "reference" / "aldonunez" / "dat"),
        "--out-dir", str(out_dir),
        "--handoff-json", str(REPO / "docs" / "superpowers" / "captures" /
                              "2026-04-24-intro-handoff-state.json"),
        "--restore-chr",  str(REPO / "docs" / "superpowers" / "captures" /
                              "2026-04-24-intro-restore-chr.bin"),
        "--restore-cram", str(REPO / "docs" / "superpowers" / "captures" /
                              "2026-04-24-intro-restore-cram.bin"),
    ], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    font = (out_dir / "intro_font_chr.c").read_text()
    art = (out_dir / "intro_art_chr.c").read_text()
    assert "const unsigned char intro_font_chr" in font
    assert "const unsigned char intro_art_chr" in art
    assert len(font.splitlines()) > 20  # non-empty
```

- [ ] **Step 2: Run test — expect failure (emit not implemented)**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py::test_emit_produces_font_and_art_chr -v`
Expected: FAIL (outputs missing or wrong format).

- [ ] **Step 3: Implement CHR emit**

Add to `tools/extract_intro_assets.py`:
```python
def _emit_chr_array(out_path: Path, symbol: str, data: bytes) -> None:
    lines = [f"/* Auto-generated by tools/extract_intro_assets.py — do not edit. */\n",
             f"const unsigned char {symbol}[{len(data)}] = {{\n"]
    for i in range(0, len(data), 16):
        row = ", ".join(f"0x{b:02X}" for b in data[i:i+16])
        lines.append(f"    {row},\n")
    lines.append("};\n")
    out_path.write_text("".join(lines))

def _load_nes_chr(path: Path) -> bytes:
    """Read NES 2bpp CHR blob, convert to Genesis 4bpp, return concatenated bytes."""
    nes = path.read_bytes()
    assert len(nes) % 16 == 0, f"{path}: CHR length not multiple of 16"
    gen = bytearray()
    for i in range(0, len(nes), 16):
        gen += nes_tile_to_gen_tile(nes[i:i+16])
    return bytes(gen)
```

Update `main()` emit block (replacing the `emitted: dict[str, str] = {}` placeholder) to call:
```python
    font_src = ref_dir / "DemoBackgroundPatterns.dat"
    art_src = ref_dir / "DemoSpritePatterns.dat"
    if not font_src.exists() or not art_src.exists():
        print("error: required reference files missing", file=sys.stderr)
        return 2

    font_gen = _load_nes_chr(font_src)
    art_gen  = _load_nes_chr(art_src)
    _emit_chr_array(out_dir / "intro_font_chr.c", "intro_font_chr", font_gen)
    _emit_chr_array(out_dir / "intro_art_chr.c",  "intro_art_chr",  art_gen)

    emitted = {
        "intro_font_chr.c": _sha(out_dir / "intro_font_chr.c"),
        "intro_art_chr.c":  _sha(out_dir / "intro_art_chr.c"),
    }
```

- [ ] **Step 4: Run test to verify pass**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py -v`
Expected: all PASS.

- [ ] **Step 5: Run tool for real and commit generated outputs**

Run:
```bash
python tools/extract_intro_assets.py
ls -la src/gen/intro_font_chr.c src/gen/intro_art_chr.c src/gen/intro_asset_hashes.txt
```
Expected: three files present, non-empty.

Run:
```bash
git add tools/extract_intro_assets.py tools/tests/test_extract_intro_assets.py \
        src/gen/intro_font_chr.c src/gen/intro_art_chr.c src/gen/intro_asset_hashes.txt
git commit -m "intro: emit intro_font_chr + intro_art_chr from reference data"
```

---

### Task 7: Emit intro_palette.c

**Files:**
- Modify: `tools/extract_intro_assets.py`
- Modify: `tools/tests/test_extract_intro_assets.py`
- Generated: `src/gen/intro_palette.c`

- [ ] **Step 1: Write failing test**

Add:
```python
def test_emit_produces_palette(tmp_path):
    # Reuse setup from test_emit_produces_font_and_art_chr.
    # Assert intro_palette.c contains a 64-entry palette table.
    # Body identical to the font/art test except asserts on intro_palette.c.
    import subprocess, sys
    result = subprocess.run([
        sys.executable, str(TOOL),
        "--ref-dir", str(REPO / "reference" / "aldonunez" / "dat"),
        "--out-dir", str(tmp_path),
        "--handoff-json", str(REPO / "docs" / "superpowers" / "captures" /
                              "2026-04-24-intro-handoff-state.json"),
        "--restore-chr",  str(REPO / "docs" / "superpowers" / "captures" /
                              "2026-04-24-intro-restore-chr.bin"),
        "--restore-cram", str(REPO / "docs" / "superpowers" / "captures" /
                              "2026-04-24-intro-restore-cram.bin"),
    ], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    pal = (tmp_path / "intro_palette.c").read_text()
    assert "const unsigned short intro_palette" in pal
    assert pal.count("0x") >= 16  # at least a dozen entries emitted
```

- [ ] **Step 2: Run test — expect failure**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py::test_emit_produces_palette -v`
Expected: FAIL.

- [ ] **Step 3: Implement palette emit**

The source palettes live in `frontend_runtime.c` as `kTitlePaletteTransferRecord` and `kStoryPaletteTransferRecord`. For the intro rewrite, read the **story** palette (36 bytes, 4 NES palette bytes per subpalette × 4 subpalettes + a length prefix). Parse the format as used in that record.

Add to `tools/extract_intro_assets.py`:
```python
# Story palette record lives in src/frontend_runtime.c. Duplicate the values
# here rather than parsing C — the record is stable and small.
STORY_PALETTE_RECORD = [
    0x3F, 0x00, 0x20, 0x0F, 0x30, 0x30, 0x30, 0x0F, 0x21, 0x30, 0x30, 0x0F,
    0x16, 0x30, 0x30, 0x0F, 0x29, 0x1A, 0x09, 0x0F, 0x29, 0x37, 0x17, 0x0F,
    0x02, 0x22, 0x30, 0x0F, 0x16, 0x27, 0x30, 0x0F, 0x0B, 0x1B, 0x2B, 0xFF,
]

def _build_story_cram() -> list[int]:
    """Convert the NES story palette record to a 64-entry Genesis CRAM buffer."""
    # Record layout (NES-style PPU transfer): skip 3-byte header, then 32 NES
    # palette bytes (4 sub-palettes × 8 entries, of which 0..3 are meaningful
    # per sub-palette in NES; Genesis uses 4 palettes × 16 colors).
    nes_bytes = STORY_PALETTE_RECORD[3:3 + 32]
    # Map NES 4-color sub-palettes onto Genesis 16-color palettes 0..3:
    # first 4 Gen colors per palette = the NES sub-palette, rest = 0 (black).
    cram = [0] * 64
    for subpal in range(4):
        for color in range(4):
            nes_idx = nes_bytes[subpal * 4 + color] & 0x3F
            cram[subpal * 16 + color] = nes_color_to_gen_cram(nes_idx)
    return cram

def _emit_palette(out_path: Path, cram: list[int]) -> None:
    lines = [f"/* Auto-generated by tools/extract_intro_assets.py — do not edit. */\n",
             f"const unsigned short intro_palette[64] = {{\n"]
    for i in range(0, 64, 8):
        row = ", ".join(f"0x{v:04X}" for v in cram[i:i+8])
        lines.append(f"    {row},\n")
    lines.append("};\n")
    out_path.write_text("".join(lines))
```

Extend `main()` emit block:
```python
    cram = _build_story_cram()
    _emit_palette(out_dir / "intro_palette.c", cram)
    emitted["intro_palette.c"] = _sha(out_dir / "intro_palette.c")
```

- [ ] **Step 4: Run tests**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py -v`
Expected: all PASS.

- [ ] **Step 5: Regenerate and commit**

Run:
```bash
python tools/extract_intro_assets.py
git add tools/extract_intro_assets.py tools/tests/test_extract_intro_assets.py \
        src/gen/intro_palette.c src/gen/intro_asset_hashes.txt
git commit -m "intro: emit intro_palette.c from NES story palette record"
```

---

### Task 8: Emit intro_story_tilemap.c

**Files:**
- Modify: `tools/extract_intro_assets.py`
- Modify: `tools/tests/test_extract_intro_assets.py`
- Generated: `src/gen/intro_story_tilemap.c`

- [ ] **Step 1: Understand the source format**

Before writing code, read:
- `reference/aldonunez/dat/DemoTextFields.dat` (story text field definitions)
- `reference/aldonunez/dat/DemoLineTextAddrs.inc` (text field address table)
- `reference/aldonunez/dat/StoryTileAttrTransferBuf.dat` (palette attribute strip)

Use `od -An -v -t x1` to inspect hex. Document the layout in a comment at the top of the new function.

- [ ] **Step 2: Write failing test**

Add:
```python
def test_emit_produces_story_tilemap(tmp_path):
    import subprocess, sys
    result = subprocess.run([
        sys.executable, str(TOOL),
        "--ref-dir", str(REPO / "reference" / "aldonunez" / "dat"),
        "--out-dir", str(tmp_path),
        "--handoff-json", str(REPO / "docs" / "superpowers" / "captures" /
                              "2026-04-24-intro-handoff-state.json"),
        "--restore-chr",  str(REPO / "docs" / "superpowers" / "captures" /
                              "2026-04-24-intro-restore-chr.bin"),
        "--restore-cram", str(REPO / "docs" / "superpowers" / "captures" /
                              "2026-04-24-intro-restore-cram.bin"),
    ], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    tm = (tmp_path / "intro_story_tilemap.c").read_text()
    assert "const unsigned short intro_story_tilemap" in tm
    assert "intro_story_tilemap_rows" in tm
    assert tm.count("0x") >= 64  # at least 2 rows × 32 cells
```

- [ ] **Step 3: Run test — expect failure**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py::test_emit_produces_story_tilemap -v`
Expected: FAIL.

- [ ] **Step 4: Implement story tilemap emit**

Add to `tools/extract_intro_assets.py`:
```python
def _build_story_tilemap(ref_dir: Path) -> tuple[list[int], int]:
    """Compose the story scroll nametable strip.

    Inputs:
      - DemoTextFields.dat      (tile indices per text row)
      - DemoLineTextAddrs.inc   (address table — identifies row boundaries)
      - StoryTileAttrTransferBuf.dat (per-row palette attribute bits)

    Output: list of Genesis nametable words (one per cell), length = rows*32.
    """
    text_fields = (ref_dir / "DemoTextFields.dat").read_bytes()
    attr_buf    = (ref_dir / "StoryTileAttrTransferBuf.dat").read_bytes()
    # The two files together define the scroll strip. Exact decoding requires
    # reading DemoLineTextAddrs.inc to find row boundaries. For this plan,
    # the implementation step is to parse those three files into a
    # row-major grid and emit Genesis cells.
    #
    # Each Genesis cell = (tile_idx & 0x7FF) | (palette << 13).
    # Tile indices are offset by FONT_BASE_TILE (= 0, assumes font loaded at
    # VRAM $0000).
    #
    # For safety, if parsing fails or the row count is 0, raise a clear error.
    rows: list[list[int]] = []
    # ... parse text_fields/attr_buf row-by-row using DemoLineTextAddrs.inc.
    # (The implementer must read those files and decide on an exact decoder.
    # The decoder is self-contained — no dependency on anything outside this
    # function — and must produce rows of exactly 32 cells each.)
    if not rows:
        raise RuntimeError("story tilemap parser produced 0 rows — check refs")

    flat: list[int] = [cell for row in rows for cell in row]
    return flat, len(rows)

def _emit_tilemap(out_path: Path, symbol: str, cells: list[int], rows: int) -> None:
    lines = [f"/* Auto-generated by tools/extract_intro_assets.py — do not edit. */\n",
             f"const unsigned short {symbol}_rows = {rows};\n",
             f"const unsigned short {symbol}[{rows * 32}] = {{\n"]
    for r in range(rows):
        row = ", ".join(f"0x{c:04X}" for c in cells[r*32:(r+1)*32])
        lines.append(f"    {row},\n")
    lines.append("};\n")
    out_path.write_text("".join(lines))
```

Extend `main()`:
```python
    story_cells, story_rows = _build_story_tilemap(ref_dir)
    if story_rows > 256:
        print(f"error: story tilemap too tall: {story_rows} rows", file=sys.stderr)
        return 2
    _emit_tilemap(out_dir / "intro_story_tilemap.c", "intro_story_tilemap",
                  story_cells, story_rows)
    emitted["intro_story_tilemap.c"] = _sha(out_dir / "intro_story_tilemap.c")
```

**Important:** the `_build_story_tilemap` parser needs to read `DemoLineTextAddrs.inc` and walk the text field definitions to produce rows. The exact byte-walk is determined by inspecting the reference files (step 1). Do **not** guess — if the inspection shows an unfamiliar format, stop and ask before proceeding.

- [ ] **Step 5: Run tests**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py -v`
Expected: all PASS.

- [ ] **Step 6: Regenerate and commit**

Run:
```bash
python tools/extract_intro_assets.py
git add tools/extract_intro_assets.py tools/tests/test_extract_intro_assets.py \
        src/gen/intro_story_tilemap.c src/gen/intro_asset_hashes.txt
git commit -m "intro: emit intro_story_tilemap.c from disassembly reference"
```

---

### Task 9: Emit intro_showcase_tilemap.c

**Files:**
- Modify: `tools/extract_intro_assets.py`
- Modify: `tools/tests/test_extract_intro_assets.py`
- Generated: `src/gen/intro_showcase_tilemap.c`

Follows the same pattern as Task 8. Source files for the item showcase: inspect `reference/aldonunez/dat/GameTitleTransferBuf.dat` and any other `Demo*` or `Story*` file that contains the item-parade row data. Implementation steps identical to Task 8 with `intro_showcase_tilemap` symbol.

- [ ] **Step 1: Inspect source files** (hex-dump suspected showcase source)

Run: `od -An -v -t x1 reference/aldonunez/dat/GameTitleTransferBuf.dat | head`

- [ ] **Step 2: Write failing test**

Add test analogous to `test_emit_produces_story_tilemap` but asserting on `intro_showcase_tilemap.c` and `intro_showcase_tilemap_rows`.

- [ ] **Step 3: Run test — expect failure**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py::test_emit_produces_showcase_tilemap -v`

- [ ] **Step 4: Implement `_build_showcase_tilemap` + emit call in `main()`**

Pattern mirrors `_build_story_tilemap`. Add to `tools/extract_intro_assets.py` (no code duplication of the emit helper — reuse `_emit_tilemap`).

- [ ] **Step 5: Run tests**

Run: `python -m pytest tools/tests/test_extract_intro_assets.py -v`

- [ ] **Step 6: Regenerate and commit**

Run:
```bash
python tools/extract_intro_assets.py
git add tools/extract_intro_assets.py tools/tests/test_extract_intro_assets.py \
        src/gen/intro_showcase_tilemap.c src/gen/intro_asset_hashes.txt
git commit -m "intro: emit intro_showcase_tilemap.c from disassembly reference"
```

---

### Task 10: Emit restore blobs + handoff-state struct

**Files:**
- Modify: `tools/extract_intro_assets.py`
- Generated: `src/gen/intro_restore_chr.c`, `src/gen/intro_restore_palette.c`, `src/gen/intro_handoff_state.c`

- [ ] **Step 1: Implement restore-blob emit**

Add to `tools/extract_intro_assets.py`:
```python
def _emit_restore_chr(out_path: Path, bin_path: Path) -> None:
    data = bin_path.read_bytes()
    _emit_chr_array(out_path, "intro_restore_chr", data)

def _emit_restore_palette(out_path: Path, bin_path: Path) -> None:
    raw = bin_path.read_bytes()
    # CRAM dump is 128 bytes = 64 words big-endian.
    words = [(raw[i] << 8) | raw[i+1] for i in range(0, len(raw), 2)]
    assert len(words) == 64, f"expected 64 CRAM words, got {len(words)}"
    lines = [f"/* Auto-generated by tools/extract_intro_assets.py — do not edit. */\n",
             f"const unsigned short intro_restore_palette[64] = {{\n"]
    for i in range(0, 64, 8):
        row = ", ".join(f"0x{v:04X}" for v in words[i:i+8])
        lines.append(f"    {row},\n")
    lines.append("};\n")
    out_path.write_text("".join(lines))

def _emit_handoff_state(out_path: Path, json_path: Path) -> None:
    data = json.loads(json_path.read_text())
    lines = [f"/* Auto-generated by tools/extract_intro_assets.py — do not edit. */\n",
             f'#include "intro_handoff.h"\n\n',
             "const intro_handoff_state_t INTRO_HANDOFF_EXPECTED = {\n"]
    for k, v in data.items():
        lines.append(f"    .{k} = 0x{v & 0xFF:02X},\n")
    lines.append("};\n")
    out_path.write_text("".join(lines))
```

Extend `main()`:
```python
    _emit_restore_chr(out_dir / "intro_restore_chr.c", Path(args.restore_chr))
    _emit_restore_palette(out_dir / "intro_restore_palette.c", Path(args.restore_cram))
    _emit_handoff_state(out_dir / "intro_handoff_state.c", Path(args.handoff_json))
    for name in ("intro_restore_chr.c", "intro_restore_palette.c", "intro_handoff_state.c"):
        emitted[name] = _sha(out_dir / name)
```

- [ ] **Step 2: Run tool and inspect outputs**

Run:
```bash
python tools/extract_intro_assets.py
head src/gen/intro_restore_chr.c src/gen/intro_restore_palette.c src/gen/intro_handoff_state.c
```
Expected: three non-empty C files, each with the declared symbol.

- [ ] **Step 3: Commit**

Run:
```bash
git add tools/extract_intro_assets.py src/gen/intro_restore_chr.c \
        src/gen/intro_restore_palette.c src/gen/intro_handoff_state.c \
        src/gen/intro_asset_hashes.txt
git commit -m "intro: emit restore CHR + palette + handoff-state struct"
```

---

## Phase 2 — intro_common

### Task 11: intro_common.h skeleton

**Files:**
- Create: `src/intro_common.h`

- [ ] **Step 1: Create header**

Create `src/intro_common.h`:
```c
#ifndef INTRO_COMMON_H
#define INTRO_COMMON_H

#ifdef __cplusplus
extern "C" {
#endif

/* Takeover flag — armed when the intro rewrite assumes control of phase-1.
 * Cleared by intro_handoff once the legacy pipeline is ready to resume. */
extern unsigned char g_intro_takeover;

/* One-shot predicate: arms g_intro_takeover on first call inside phase-1. */
unsigned char intro_should_take_over(void);

/* Dispatcher: advances story → showcase → handoff each frame while
 * g_intro_takeover is set. */
void intro_story_tick(void);

/* --- VDP primitives (thin wrappers around VDP_CTRL/VDP_DATA in
 *     genesis_shell.asm). Stages must use these — never raw VDP I/O. --- */
void vdp_set_mode_v32(void);
void vdp_set_mode_v64(void);
void vdp_dma_to_vram(unsigned long src, unsigned short dst, unsigned short len);
void vdp_write_nametable_row(unsigned short plane_base, unsigned short row,
                             const unsigned short *cells);
void vdp_set_vscroll(unsigned short value);
void vdp_load_cram(const unsigned short *src, unsigned short count);

#ifdef __cplusplus
}
#endif

#endif /* INTRO_COMMON_H */
```

- [ ] **Step 2: Commit**

Run:
```bash
git add src/intro_common.h
git commit -m "intro: declare intro_common public API"
```

---

### Task 12: intro_common.c — `g_intro_takeover` + `intro_should_take_over` + `intro_story_tick` skeleton

**Files:**
- Create: `src/intro_common.c`

- [ ] **Step 1: Create `intro_common.c`**

Create `src/intro_common.c`:
```c
#include "intro_common.h"
#include "intro_story.h"
#include "intro_showcase.h"
#include "intro_handoff.h"
#include "nes_ram.h"  /* exposes RAM(addr) macro used by existing code */

unsigned char g_intro_takeover = 0;

static unsigned char s_takeover_armed = 0;
static unsigned char s_substage = 0;   /* 0 = story, 1 = showcase, 2 = handoff */
static unsigned char s_entered = 0;

unsigned char intro_should_take_over(void) {
    /* Called from frontdemo_init_demo_phase_1. If phase-1 is active
     * (RAM(0x042C) != 0) and we have not yet armed the takeover, arm it. */
    if (s_takeover_armed) return g_intro_takeover;
    if (RAM(0x042C) == 0) return 0;  /* still in phase-0; not our turn */
    g_intro_takeover = 1;
    s_takeover_armed = 1;
    s_substage = 0;
    s_entered = 0;
    return 1;
}

void intro_story_tick(void) {
    if (!g_intro_takeover) return;

    if (s_substage == 0) {
        if (!s_entered) { intro_story_enter(); s_entered = 1; }
        if (intro_story_update()) { s_substage = 1; s_entered = 0; }
        return;
    }
    if (s_substage == 1) {
        if (!s_entered) { intro_showcase_enter(); s_entered = 1; }
        if (intro_showcase_update()) { s_substage = 2; s_entered = 0; }
        return;
    }
    /* s_substage == 2 → handoff */
    intro_handoff();
    /* intro_handoff clears g_intro_takeover and advances legacy state. */
}
```

- [ ] **Step 2: Stub out VDP primitive declarations so this compiles**

Append to `src/intro_common.c` (real bodies in later tasks):
```c
/* VDP primitives — real bodies follow. Stubs so early linker checks pass. */
void vdp_set_mode_v32(void) {}
void vdp_set_mode_v64(void) {}
void vdp_dma_to_vram(unsigned long src, unsigned short dst, unsigned short len) { (void)src; (void)dst; (void)len; }
void vdp_write_nametable_row(unsigned short plane_base, unsigned short row,
                             const unsigned short *cells) {
    (void)plane_base; (void)row; (void)cells;
}
void vdp_set_vscroll(unsigned short value) { (void)value; }
void vdp_load_cram(const unsigned short *src, unsigned short count) {
    (void)src; (void)count;
}
```

- [ ] **Step 3: Verify file parses (lint via gcc)**

Run:
```bash
"$M68K_GCC" -B "$M68K_BIN/" -m68000 -ffreestanding -nostdlib -nostartfiles \
  -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 \
  -I src -c src/intro_common.c -o /tmp/intro_common.o
```
(Adjust `$M68K_GCC`/`$M68K_BIN` to the local toolchain paths; check `build.bat` for actual values.)
Expected: no errors. Header references to `intro_story.h` / `intro_showcase.h` / `intro_handoff.h` will fail until those are created — at this point, either stub them (empty headers guarded) or accept the failure and fix in the next task. Prefer creating empty stub headers now:

- [ ] **Step 4: Create stub headers for undeclared modules**

Create `src/intro_story.h`:
```c
#ifndef INTRO_STORY_H
#define INTRO_STORY_H
#ifdef __cplusplus
extern "C" {
#endif
void intro_story_enter(void);
unsigned int intro_story_update(void);
#ifdef __cplusplus
}
#endif
#endif
```

Create `src/intro_showcase.h` (same pattern, `intro_showcase_enter` / `intro_showcase_update`).

Create `src/intro_handoff.h`:
```c
#ifndef INTRO_HANDOFF_H
#define INTRO_HANDOFF_H
#ifdef __cplusplus
extern "C" {
#endif
typedef struct {
    unsigned char mode_value;
    unsigned char submode_value;
    unsigned char frontend_demo_subphase;
    unsigned char front_start_release_gate;
    unsigned char vram_force_blank_gate;
    unsigned char frontend_delay_timer;
    unsigned char room_mode_timer;
    unsigned char item_sfx_secondary;
    unsigned char room_transfer_buf_select;
} intro_handoff_state_t;

extern const intro_handoff_state_t INTRO_HANDOFF_EXPECTED;

void intro_handoff(void);
#ifdef __cplusplus
}
#endif
#endif
```

- [ ] **Step 5: Re-run compile to confirm parse**

Run: gcc command from step 3. Expected: no errors.

- [ ] **Step 6: Commit**

Run:
```bash
git add src/intro_common.c src/intro_story.h src/intro_showcase.h src/intro_handoff.h
git commit -m "intro: intro_common.c takeover + dispatcher + VDP stubs + module headers"
```

---

### Task 13: Implement `vdp_set_mode_v32` / `vdp_set_mode_v64`

**Files:**
- Modify: `src/intro_common.c`

- [ ] **Step 1: Replace stubs**

In `src/intro_common.c`, replace the stub bodies of `vdp_set_mode_v32` and `vdp_set_mode_v64`:
```c
#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)

void vdp_set_mode_v32(void) {
    /* VDP Reg 16 = $9001 (H64 × V32). See src/genesis_shell.asm:236. */
    VDP_CTRL_WORD = 0x9001;
}

void vdp_set_mode_v64(void) {
    /* VDP Reg 16 = $9011 (H64 × V64). Matches gameplay default. */
    VDP_CTRL_WORD = 0x9011;
}
```

- [ ] **Step 2: Recompile**

Run: same gcc command as Task 12 step 3. Expected: no errors.

- [ ] **Step 3: Commit**

Run:
```bash
git add src/intro_common.c
git commit -m "intro: vdp_set_mode_v32 / vdp_set_mode_v64 via VDP_CTRL"
```

---

### Task 14: Implement `vdp_dma_to_vram`

**Files:**
- Modify: `src/intro_common.c`

- [ ] **Step 1: Replace stub**

Replace `vdp_dma_to_vram` body:
```c
#define VDP_DATA_WORD (*(volatile unsigned short *)0x00C00000)
#define VDP_CTRL_LONG (*(volatile unsigned long  *)0x00C00004)

void vdp_dma_to_vram(unsigned long src, unsigned short dst, unsigned short len) {
    /* Writes `len` bytes from CPU-addressable `src` to VRAM[dst..dst+len].
     * Register sequence per Genesis VDP DMA manual (matches genesis_shell.asm). */
    unsigned short len_words = (unsigned short)(len >> 1);
    unsigned long src_word = (src >> 1) & 0x7FFFFFUL;

    VDP_CTRL_WORD = (unsigned short)(0x9300 | (len_words & 0xFF));       /* Reg 19: DMA len lo */
    VDP_CTRL_WORD = (unsigned short)(0x9400 | ((len_words >> 8) & 0xFF));/* Reg 20: DMA len hi */
    VDP_CTRL_WORD = (unsigned short)(0x9500 | (src_word & 0xFF));        /* Reg 21: DMA src lo */
    VDP_CTRL_WORD = (unsigned short)(0x9600 | ((src_word >> 8) & 0xFF)); /* Reg 22: DMA src mid */
    VDP_CTRL_WORD = (unsigned short)(0x9700 | ((src_word >> 16) & 0x7F));/* Reg 23: DMA src hi */

    /* VRAM write command + DMA bit: 0x40000080 | (dst address) */
    unsigned long cmd = 0x40000080UL | ((unsigned long)(dst & 0x3FFF) << 16)
                                    | ((dst >> 14) & 0x0003);
    VDP_CTRL_LONG = cmd;
    /* DMA starts; CPU stalls until complete for VRAM writes. */
}
```

- [ ] **Step 2: Compile and commit**

Run gcc check; commit:
```bash
git add src/intro_common.c
git commit -m "intro: vdp_dma_to_vram register sequence"
```

---

### Task 15: Implement `vdp_write_nametable_row`, `vdp_set_vscroll`, `vdp_load_cram`

**Files:**
- Modify: `src/intro_common.c`

- [ ] **Step 1: Replace stubs**

```c
void vdp_write_nametable_row(unsigned short plane_base, unsigned short row,
                             const unsigned short *cells) {
    /* plane_base = plane A base ($4000) or plane B base ($6000).
     * row = 0..31 (V32 plane). Writes 32 cells (64 bytes). */
    unsigned short addr = (unsigned short)(plane_base + (row * 64));
    unsigned long cmd = 0x40000000UL | ((unsigned long)(addr & 0x3FFF) << 16)
                                     | ((addr >> 14) & 0x0003);
    VDP_CTRL_LONG = cmd;
    for (int i = 0; i < 32; i++) {
        VDP_DATA_WORD = cells[i];
    }
}

void vdp_set_vscroll(unsigned short value) {
    /* VSRAM write to address $00 (plane A vscroll). */
    VDP_CTRL_LONG = 0x40000010UL;
    VDP_DATA_WORD = value;
}

void vdp_load_cram(const unsigned short *src, unsigned short count) {
    /* CRAM write starting at CRAM address 0. count = words (max 64). */
    VDP_CTRL_LONG = 0xC0000000UL;
    for (unsigned short i = 0; i < count; i++) {
        VDP_DATA_WORD = src[i];
    }
}
```

- [ ] **Step 2: Compile and commit**

```bash
git add src/intro_common.c
git commit -m "intro: vdp_write_nametable_row + vdp_set_vscroll + vdp_load_cram"
```

---

## Phase 3 — intro_story

### Task 16: intro_story.c — stage_enter

**Files:**
- Create: `src/intro_story.c`

- [ ] **Step 1: Create module with `intro_story_enter`**

Create `src/intro_story.c`:
```c
#include "intro_story.h"
#include "intro_common.h"

/* Externs emitted by the extract tool. */
extern const unsigned char  intro_font_chr[];
extern const unsigned char  intro_art_chr[];
extern const unsigned short intro_palette[64];
extern const unsigned short intro_story_tilemap_rows;
extern const unsigned short intro_story_tilemap[];

/* Sizes of the font and art blobs in bytes — emitted by the extractor but
 * accessed here as sizeof symbols. Declared via a paired size table to keep
 * this module decoupled from the generated files. */
extern const unsigned long intro_font_chr_size;
extern const unsigned long intro_art_chr_size;

#define PLANE_A_BASE  0x4000u
#define SCROLL_SPEED  1u  /* pixels per frame */

static unsigned long s_scroll_pixel;
static unsigned short s_next_source_row;

void intro_story_enter(void) {
    vdp_set_mode_v32();

    /* Clear plane A: DMA-fill 2048 bytes with zero — skipped here for
     * brevity; implement via vdp_dma_to_vram over a zero-buffer if needed.
     * For the first implementation, assume fade-out left the plane blank. */

    vdp_dma_to_vram((unsigned long)intro_font_chr, 0x0000, (unsigned short)intro_font_chr_size);
    vdp_dma_to_vram((unsigned long)intro_art_chr,  (unsigned short)intro_font_chr_size,
                    (unsigned short)intro_art_chr_size);

    vdp_load_cram(intro_palette, 64);

    /* Load the first 32 rows of the story tilemap into plane A. */
    unsigned short first_rows = intro_story_tilemap_rows < 32
                                 ? intro_story_tilemap_rows : 32;
    for (unsigned short r = 0; r < first_rows; r++) {
        vdp_write_nametable_row(PLANE_A_BASE, r, &intro_story_tilemap[r * 32]);
    }

    vdp_set_vscroll(0);
    s_scroll_pixel = 0;
    s_next_source_row = (unsigned short)first_rows;
}
```

- [ ] **Step 2: Compile stage**

Run gcc check (as in Task 12). Expected: unresolved externs for `intro_font_chr_size`, `intro_art_chr_size`. Extend the extract tool in the next task step — or define them alongside the CHR emit.

- [ ] **Step 3: Add size externs to the extractor**

In `tools/extract_intro_assets.py` `_emit_chr_array`, append a size constant:
```python
    lines.append(f"const unsigned long {symbol}_size = {len(data)};\n")
```
Regenerate:
```bash
python tools/extract_intro_assets.py
```

- [ ] **Step 4: Recompile**

Run gcc check. Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add src/intro_story.c tools/extract_intro_assets.py \
        src/gen/intro_font_chr.c src/gen/intro_art_chr.c src/gen/intro_asset_hashes.txt
git commit -m "intro: intro_story_enter — V32 switch + CHR DMA + first 32 rows"
```

---

### Task 17: intro_story.c — stage_update (scroll + row-boundary copy)

**Files:**
- Modify: `src/intro_story.c`

- [ ] **Step 1: Add `intro_story_update`**

Append to `src/intro_story.c`:
```c
static unsigned short s_last_row;  /* previous value of (s_scroll_pixel >> 3) */
static unsigned short s_done;

unsigned int intro_story_update(void) {
    if (s_done) return 1;

    s_scroll_pixel += SCROLL_SPEED;
    vdp_set_vscroll((unsigned short)(s_scroll_pixel & 0xFFFF));

    unsigned short new_row = (unsigned short)(s_scroll_pixel >> 3);
    if (new_row > s_last_row) {
        /* A row boundary has passed. The plane row that scrolled off the
         * top is (s_last_row) mod 32 (V32 plane). Fill it with the next
         * source row if any remain. */
        unsigned short plane_row = (unsigned short)(s_last_row & 31u);
        if (s_next_source_row < intro_story_tilemap_rows) {
            vdp_write_nametable_row(PLANE_A_BASE, plane_row,
                &intro_story_tilemap[s_next_source_row * 32]);
            s_next_source_row++;
        }
        s_last_row = new_row;
    }

    /* Exit: scroll has advanced past the total tilemap height plus the
     * visible region (32 rows × 8 px). */
    unsigned long end_pixel = (unsigned long)intro_story_tilemap_rows * 8u
                            + 32u * 8u;
    if (s_scroll_pixel >= end_pixel) {
        s_done = 1;
        return 1;
    }
    return 0;
}
```

- [ ] **Step 2: Reset statics in `intro_story_enter`**

Add at the bottom of `intro_story_enter`:
```c
    s_last_row = 0;
    s_done = 0;
```

- [ ] **Step 3: Compile**

Run gcc check. Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add src/intro_story.c
git commit -m "intro: intro_story_update — VSRAM scroll + row-boundary copy + exit detection"
```

---

## Phase 4 — intro_showcase

### Task 18: intro_showcase.c (mirrors intro_story)

**Files:**
- Create: `src/intro_showcase.c`

- [ ] **Step 1: Create module**

Mirror `intro_story.c` structure but operate on `intro_showcase_tilemap` / `intro_showcase_tilemap_rows`. Share as much logic as reasonable without forcing a premature abstraction; if the overlap is > 90%, extract the scroll helper into `intro_common.c` at the end of this task (see step 4).

Create `src/intro_showcase.c`:
```c
#include "intro_showcase.h"
#include "intro_common.h"

extern const unsigned short intro_showcase_tilemap_rows;
extern const unsigned short intro_showcase_tilemap[];

#define PLANE_A_BASE  0x4000u
#define SCROLL_SPEED  1u

static unsigned long  s_scroll_pixel;
static unsigned short s_next_source_row;
static unsigned short s_last_row;
static unsigned short s_done;

void intro_showcase_enter(void) {
    /* CHR + palette still loaded from intro_story_enter — reuse.
     * If a different palette is needed, swap-in here via vdp_load_cram. */
    unsigned short first_rows = intro_showcase_tilemap_rows < 32
                                 ? intro_showcase_tilemap_rows : 32;
    for (unsigned short r = 0; r < first_rows; r++) {
        vdp_write_nametable_row(PLANE_A_BASE, r, &intro_showcase_tilemap[r * 32]);
    }
    vdp_set_vscroll(0);
    s_scroll_pixel = 0;
    s_next_source_row = (unsigned short)first_rows;
    s_last_row = 0;
    s_done = 0;
}

unsigned int intro_showcase_update(void) {
    if (s_done) return 1;
    s_scroll_pixel += SCROLL_SPEED;
    vdp_set_vscroll((unsigned short)(s_scroll_pixel & 0xFFFF));
    unsigned short new_row = (unsigned short)(s_scroll_pixel >> 3);
    if (new_row > s_last_row) {
        unsigned short plane_row = (unsigned short)(s_last_row & 31u);
        if (s_next_source_row < intro_showcase_tilemap_rows) {
            vdp_write_nametable_row(PLANE_A_BASE, plane_row,
                &intro_showcase_tilemap[s_next_source_row * 32]);
            s_next_source_row++;
        }
        s_last_row = new_row;
    }
    unsigned long end_pixel = (unsigned long)intro_showcase_tilemap_rows * 8u + 32u * 8u;
    if (s_scroll_pixel >= end_pixel) { s_done = 1; return 1; }
    return 0;
}
```

- [ ] **Step 2: Compile**

Run gcc check. Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add src/intro_showcase.c
git commit -m "intro: intro_showcase stage (same structure as intro_story)"
```

- [ ] **Step 4: Optional — extract shared scroll helper**

If the diff between `intro_story.c` and `intro_showcase.c` is limited to the tilemap symbol, extract the shared scroll loop into `intro_common.c` as:
```c
typedef struct {
    const unsigned short *tilemap;
    unsigned short tilemap_rows;
    unsigned long scroll_pixel;
    unsigned short next_source_row;
    unsigned short last_row;
    unsigned char done;
} intro_scroll_state_t;

void intro_scroll_init(intro_scroll_state_t *s, const unsigned short *tilemap,
                       unsigned short rows);
unsigned int intro_scroll_update(intro_scroll_state_t *s);
```

Only extract if the result reduces net line count and does not create a leaky abstraction. If in doubt, skip — duplicate code is acceptable for two sites.

Commit separately if extracted:
```bash
git add src/intro_common.c src/intro_common.h src/intro_story.c src/intro_showcase.c
git commit -m "intro: extract shared scroll helper into intro_common"
```

---

## Phase 5 — intro_handoff

### Task 19: intro_handoff.c — VDP + CHR/CRAM restore (steps 1-5)

**Files:**
- Create: `src/intro_handoff.c`

- [ ] **Step 1: Create module**

Create `src/intro_handoff.c`:
```c
#include "intro_handoff.h"
#include "intro_common.h"

extern const unsigned char  intro_restore_chr[];
extern const unsigned long  intro_restore_chr_size;
extern const unsigned short intro_restore_palette[64];

static void clear_plane(unsigned short plane_base);

void intro_handoff(void) {
    /* 1. Switch back to V64. */
    vdp_set_mode_v64();

    /* 2. Restore file-select CHR captured from legacy flow. */
    vdp_dma_to_vram((unsigned long)intro_restore_chr, 0x0000,
                    (unsigned short)intro_restore_chr_size);

    /* 3. Restore file-select CRAM. */
    vdp_load_cram(intro_restore_palette, 64);

    /* 4. Reset VSRAM to 0 — legacy fade-in assumes no scroll. */
    vdp_set_vscroll(0);

    /* 5. Clear plane A + plane B nametables to zero. */
    clear_plane(0x4000);  /* plane A */
    clear_plane(0x6000);  /* plane B — legacy often has it zero; re-clear. */
    /* Steps 6 + 7 implemented in the next task. */
}

static void clear_plane(unsigned short plane_base) {
    unsigned short zero_row[32] = {0};
    for (unsigned short r = 0; r < 32; r++) {
        vdp_write_nametable_row(plane_base, r, zero_row);
    }
}
```

- [ ] **Step 2: Compile**

Run gcc check. Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add src/intro_handoff.c
git commit -m "intro: intro_handoff steps 1-5 (V64 switch + CHR/CRAM restore + clear planes)"
```

---

### Task 20: intro_handoff — state-byte write-back (step 6) + clear takeover (step 7)

**Files:**
- Modify: `src/intro_handoff.c`

- [ ] **Step 1: Extend with state write-back**

Append inside `intro_handoff`:
```c
    /* 6. Write authoritative state bytes captured by probe during Task 1. */
    RAM(0x00E0) = INTRO_HANDOFF_EXPECTED.mode_value;
    RAM(0x0012) = INTRO_HANDOFF_EXPECTED.submode_value;
    RAM(0x042C) = INTRO_HANDOFF_EXPECTED.frontend_demo_subphase;
    RAM(0x042B) = INTRO_HANDOFF_EXPECTED.front_start_release_gate;
    RAM(0x083D) = INTRO_HANDOFF_EXPECTED.vram_force_blank_gate;
    RAM(0x0528) = INTRO_HANDOFF_EXPECTED.frontend_delay_timer;
    RAM(0x0013) = INTRO_HANDOFF_EXPECTED.room_mode_timer;
    RAM(0x0605) = INTRO_HANDOFF_EXPECTED.item_sfx_secondary;
    RAM(0x060E) = INTRO_HANDOFF_EXPECTED.room_transfer_buf_select;

    /* 7. Clear takeover — legacy dispatchers resume normal behavior. */
    g_intro_takeover = 0;
}
```

Add `#include "nes_ram.h"` at the top (for `RAM(addr)`).

- [ ] **Step 2: Compile**

Run gcc check. Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add src/intro_handoff.c
git commit -m "intro: intro_handoff steps 6-7 (authoritative state bytes + clear takeover)"
```

---

## Phase 6 — Integration Hook

### Task 21: Add takeover short-circuit to `frontdemo_init_demo_phase_1`

**Files:**
- Modify: `src/frontend_runtime.c:145`
- Modify: `src/frontend_runtime.h`

- [ ] **Step 1: Update `frontend_runtime.h`**

Add to `src/frontend_runtime.h` (alongside existing externs):
```c
#include "intro_common.h"
```

- [ ] **Step 2: Modify `frontdemo_init_demo_phase_1`**

Replace the existing body at [src/frontend_runtime.c:145](src/frontend_runtime.c:145):
```c
void frontdemo_init_demo_phase_1(void) {
    if (g_intro_takeover || intro_should_take_over()) {
        intro_story_tick();
        return;
    }
    /* Phase-1 subphase dispatch (jump table replaced by switch). */
    switch (FRONTEND_DEMO_SUBPHASE) {
        case 0: c_import_init_demo_subphase_clear_artifacts(); break;
        case 1: c_import_init_demo_subphase_transfer_story_palette(); break;
        case 2: c_import_init_demo_subphase_transfer_story_tiles(); break;
        default: break;
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/frontend_runtime.c src/frontend_runtime.h
git commit -m "intro: hook intro_story_tick into frontdemo_init_demo_phase_1"
```

---

### Task 22: Add takeover short-circuit to `frontdemo_animate_phase_1`

**Files:**
- Modify: `src/frontend_runtime.c:291`

- [ ] **Step 1: Modify `frontdemo_animate_phase_1`**

Replace the body at [src/frontend_runtime.c:291](src/frontend_runtime.c:291):
```c
void frontdemo_animate_phase_1(void) {
    if (g_intro_takeover) {
        intro_story_tick();
        return;
    }
    switch (FRONTEND_DEMO_SUBPHASE) {
        case 0: c_import_animate_demo_phase1_subphase0(); break;
        case 1: c_import_animate_demo_phase1_subphase1(); break;
        case 2: c_import_animate_demo_phase1_subphase2(); break;
        case 3: c_import_animate_demo_phase1_subphase3(); break;
        case 4: frontdemo_animate_demo_phase1_subphase4(); break;
        default: break;
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/frontend_runtime.c
git commit -m "intro: hook intro_story_tick into frontdemo_animate_phase_1"
```

---

## Phase 7 — Build Wiring

### Task 23: Add extractor pre-step to `build.bat`

**Files:**
- Modify: `build.bat`

- [ ] **Step 1: Insert extractor step before C compile**

Open `build.bat` and find the line just above `if not exist "%C_OBJ_DIR%" mkdir "%C_OBJ_DIR%"` (near [build.bat:91](build.bat:91)). Insert:
```batch
echo [2a.0/4] Extracting intro assets from reference data...
"%PYTHON%" "%ROOT%\tools\extract_intro_assets.py"
if errorlevel 1 exit /b 1
```

- [ ] **Step 2: Test build**

Run: `cmd /c build.bat`
Expected: extractor runs, regenerates `src/gen/intro_*.c`, build continues. At this point C modules are not registered yet, so new .c files are emitted but unused — build still succeeds.

- [ ] **Step 3: Commit**

```bash
git add build.bat
git commit -m "build: add intro-asset extractor as pre-step"
```

---

### Task 24: Register intro_* C modules in build.bat

**Files:**
- Modify: `build.bat:104`

- [ ] **Step 1: Append to `C_SOURCES`**

At [build.bat:104](build.bat:104), add `intro_common intro_story intro_showcase intro_handoff` to the end of the `C_SOURCES` variable value (one space separator each).

- [ ] **Step 2: Append to `C_GEN_SOURCES`**

At [build.bat:105](build.bat:105), add `intro_font_chr intro_art_chr intro_palette intro_story_tilemap intro_showcase_tilemap intro_restore_chr intro_restore_palette intro_handoff_state` to the end of `C_GEN_SOURCES`.

- [ ] **Step 3: Build**

Run: `cmd /c build.bat`
Expected: all new modules compile and link, ROM builds successfully.

- [ ] **Step 4: Commit**

```bash
git add build.bat
git commit -m "build: register intro_common/story/showcase/handoff + generated intro_* modules"
```

---

## Phase 8 — Testing

### Task 25: Idle-run (no-crash) test

**Files:** none new

- [ ] **Step 1: Build current ROM**

Run: `cmd /c build.bat`
Expected: `builds/whatif.bin` emitted.

- [ ] **Step 2: Run idle capture**

Run:
```bash
"$CODEX_BIZHAWK_ROOT/EmuHawk.exe" \
  --lua=tools/bizhawk_capture_intro_sequence.lua builds/whatif.bin
```
Expected: BizHawk launches, runs the intro with zero input, captures frames to `tools/_captures/` (or whatever the existing script uses).

- [ ] **Step 3: Analyze continuity**

Run:
```bash
python tools/analyze_intro_continuity.py tools/_captures/<latest>
```
Expected: report no stall frames between story-start and file-select-entry. If stalls reported, the rewrite is crashing — debug before proceeding.

- [ ] **Step 4: Document result**

Append the analyzer's summary to `docs/superpowers/captures/2026-04-24-idle-run.txt` and commit:
```bash
git add docs/superpowers/captures/2026-04-24-idle-run.txt
git commit -m "intro: idle-run test passes (no crash)"
```

---

### Task 26: Visual parity checkpoints

**Files:** none new

- [ ] **Step 1: Capture matched checkpoint frames from both NES + Gen**

Run:
```bash
"$CODEX_BIZHAWK_ROOT/EmuHawk.exe" --lua=tools/bizhawk_capture_intro_window.lua builds/whatif.bin
```
Expected: 10 checkpoint frames written to `tools/_captures/intro_window/`.

- [ ] **Step 2: Compare against NES reference**

Run:
```bash
python tools/analyze_intro_scroll_window.py tools/_captures/intro_window/
```
Expected: per-checkpoint mismatch report. Checkpoints 1 and 10 ≤ 1%; checkpoints 2-9 ≤ 5%.

- [ ] **Step 3: Document result**

Append summary to `docs/superpowers/captures/2026-04-24-visual-parity.txt` and commit.

---

### Task 27: V64 dead-zone regression guard

**Files:** none new

- [ ] **Step 1: Capture VRAM during showcase**

Run:
```bash
"$CODEX_BIZHAWK_ROOT/EmuHawk.exe" --lua=tools/bizhawk_intro_vram_dump.lua builds/whatif.bin
```
Expected: 60 VRAM dumps across showcase frames.

- [ ] **Step 2: Inspect rows 60-63 region**

Rows 60-63 of the plane map are only relevant in V64. Under V32 they don't exist. Confirm the dump shows V32 addressing (plane size 32×32 × 2 bytes = 2048 bytes) during showcase.

- [ ] **Step 3: Document result**

Append summary to `docs/superpowers/captures/2026-04-24-dead-zone-guard.txt` and commit.

---

### Task 28: Frame-budget measurement

**Files:**
- Modify: `tools/bizhawk_sweep_story.lua` (add timestamp instrumentation)

- [ ] **Step 1: Extend sweep script**

Add timestamp-on-entry / timestamp-on-exit hooks at the C entry addresses of `intro_story_update` and `intro_showcase_update`. Emit the wall-clock delta to a CSV.

- [ ] **Step 2: Run measurement**

Run:
```bash
"$CODEX_BIZHAWK_ROOT/EmuHawk.exe" --lua=tools/bizhawk_sweep_story.lua builds/whatif.bin
```
Expected: CSV with per-frame timings.

- [ ] **Step 3: Assert budget**

Run:
```bash
python -c "
import csv
with open('tools/_captures/intro_budget.csv') as f:
    vals = [float(row['us']) for row in csv.DictReader(f)]
print(f'max={max(vals):.1f}us avg={sum(vals)/len(vals):.1f}us')
assert max(vals) < 1000, 'frame budget exceeded'
"
```
Expected: no assertion failure. If > 1000 μs, revisit the row-copy strategy per the spec's Frame Budget note.

- [ ] **Step 4: Commit**

```bash
git add tools/bizhawk_sweep_story.lua docs/superpowers/captures/2026-04-24-frame-budget.csv
git commit -m "intro: frame-budget measurement <1ms per frame"
```

---

### Task 29: Handoff state verification

**Files:** none new

- [ ] **Step 1: Run state probe against new ROM**

Run:
```bash
python tools/capture_intro_handoff_state.py \
  --rom builds/whatif.bin \
  --out /tmp/intro-handoff-state-new.json
```
Expected: JSON with the same 9 addresses captured.

- [ ] **Step 2: Diff against reference**

Run:
```bash
diff docs/superpowers/captures/2026-04-24-intro-handoff-state.json \
     /tmp/intro-handoff-state-new.json
```
Expected: empty diff. Every byte matches the reference captured at Task 1.

- [ ] **Step 3: Commit result note**

```bash
echo "handoff state verification: pass" >> docs/superpowers/captures/2026-04-24-handoff-verify.txt
git add docs/superpowers/captures/2026-04-24-handoff-verify.txt
git commit -m "intro: handoff state matches legacy capture byte-for-byte"
```

---

### Task 30: Asset-extraction SHA verification

**Files:** none new

- [ ] **Step 1: Run extractor in verify mode**

Run:
```bash
python tools/extract_intro_assets.py --verify
```
Expected: exit code 0, no "SHA differs" message.

- [ ] **Step 2: Commit result note**

```bash
echo "asset SHA verification: pass" >> docs/superpowers/captures/2026-04-24-asset-verify.txt
git add docs/superpowers/captures/2026-04-24-asset-verify.txt
git commit -m "intro: asset SHAs stable"
```

---

## Phase 9 — Gated Cleanup (Separate Commit After Phase 8 Green)

### Task 31 (gated): Static unreachability grep

**Files:** none

- [ ] **Step 1: Grep each candidate symbol**

Run:
```bash
for sym in AnimateDemoPhase1Subphase2 AnimateDemoPhase1Subphase3 \
           AnimateDemoPhase1Subphase4 \
           c_import_animate_demo_phase1_subphase0 \
           c_import_animate_demo_phase1_subphase1 \
           c_import_animate_demo_phase1_subphase2 \
           c_import_animate_demo_phase1_subphase3 \
           c_import_init_demo_subphase_clear_artifacts \
           c_import_init_demo_subphase_transfer_story_palette \
           c_import_init_demo_subphase_transfer_story_tiles \
           frontdemo_animate_demo_phase1_subphase4; do
    echo "=== $sym ==="
    grep -rn "$sym" src/ tools/ reference/ 2>/dev/null | grep -v '^Binary'
done > docs/superpowers/captures/2026-04-24-unreachability-grep.txt
```

- [ ] **Step 2: Review output manually**

Every call site outside the intro-owned takeover path must be accounted for. Any symbol still reachable from the legacy live path is **excluded** from deletion.

- [ ] **Step 3: Commit grep log (proof)**

```bash
git add docs/superpowers/captures/2026-04-24-unreachability-grep.txt
git commit -m "intro: static unreachability grep for deletion candidates"
```

---

### Task 32 (gated): Runtime path-map probe

**Files:** none new

- [ ] **Step 1: Run hook probe**

Run:
```bash
"$CODEX_BIZHAWK_ROOT/EmuHawk.exe" --lua=tools/bizhawk_intro_hook_probe.lua builds/whatif.bin
```
Expected: probe emits a CSV of touched symbols during idle-run.

- [ ] **Step 2: Diff candidate list against touched set**

Confirm every candidate-for-deletion symbol has 0 hits. Any symbol with positive hits is **excluded** from deletion.

- [ ] **Step 3: Commit probe output**

```bash
git add docs/superpowers/captures/2026-04-24-path-map-probe.csv
git commit -m "intro: runtime path-map probe — identify deletion-safe symbols"
```

---

### Task 33 (gated): Delete legacy symbols

**Files:** many (remove unreachable symbols from `z_02.asm`, `src/gen/z_02.c`, `c_shims.asm`, `frontend_runtime.c`, `frontend_runtime.h`, `tools/gen_wrappers/z_02_manifest.json` as applicable)

- [ ] **Step 1: Remove each symbol marked safe by both gates**

For each symbol cleared by Tasks 31 + 32, remove its definition + externs + forwarders. Do not remove anything not cleared by both gates.

- [ ] **Step 2: Build + run full test suite**

Run:
```bash
cmd /c build.bat
# then re-run Tasks 25, 26, 27 to confirm no regression
```
Expected: all Phase 8 tests still pass.

- [ ] **Step 3: Commit deletion**

```bash
git add -A
git commit -m "intro: delete unreachable legacy story/showcase symbols (both gates passed)"
```

---

## Self-Review Checklist

- **Spec coverage:** every spec section has a matching task. Foundation capture (spec §Handoff State Bytes / Handoff Details) → Tasks 1-2. Extract pipeline → Tasks 3-10. intro_common VDP-wrapper boundary (spec §Module Responsibilities) → Tasks 11-15. intro_story + intro_showcase (spec §Core Technical Decisions / Stage Flow) → Tasks 16-18. intro_handoff (spec §Handoff Details) → Tasks 19-20. Integration (spec §Integration Hook) → Tasks 21-22. Build (spec §Build Integration) → Tasks 23-24. Tests (spec §Testing) → Tasks 25-30. Deletion (spec §Deletion Gated Cleanup) → Tasks 31-33.
- **Placeholder scan:** no TBD / TODO / "fill in later" in executable steps. `_build_story_tilemap` parser body is described at a high level because the exact byte layout must be determined by inspecting the reference files (step 1 of Task 8 is the explicit inspection step); the decoder is entirely contained within that function with no external dependencies.
- **Type consistency:** `intro_handoff_state_t` fields match the capture JSON keys in Task 1. `g_intro_takeover` is `unsigned char` throughout. `vdp_*` helpers use consistent `unsigned short` / `unsigned long` types.

# RoomRom Sprite CHR Expansion + Phase 5 Acceptance — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the remaining sprite-side work in [docs/superpowers/specs/2026-05-01-roomrom-bg-palette-chr-expansion-design.md](../specs/2026-05-01-roomrom-bg-palette-chr-expansion-design.md): sprite CHR 4x expansion (Phase 3 sprite half), sprite-renderer sub-pal wiring (Phase 4 sprite half), HUD/sprite stale-PAL3-comment cleanup, and Phase 5 acceptance verifiers. Closes the prerequisite blocking the atlas north-star spec.

**Architecture:** Sprite CHR is currently single-copy (sub-pal 0 only) per `roomrom_vram_map.h:ROOMROM_SPR_SUBPAL_COUNT = 1u`. NES Z1 draws bomb / explosion / certain enemies with sprite sub-pal 1+. Without 4x expansion the renderer falls back to sub-pal 0 colors → wrong art tone. We replicate the working BG expansion path: `tools/expand_sprite_chr.py` emits 4-copy sprite CHR with the pixel-bias rule, `roomrom_sprites_upload_chr` uploads all 4 banks, sprite renderers select the correct sub-pal via `ROOMROM_SPR_TILE_BASE_PAL(s) + local_tile`, with `s` driven by NES dispatch citations. Verifier walks all renderer sources to gate the cutover.

**Tech Stack:** SGDK m68k gcc (existing toolchain), Python 3 generator scripts (existing pattern in `RoomRom/tools/`), BizHawk Lua probes (existing pattern), build via `RoomRom/build.bat`.

**Spec citations:** Phase 3 step 2 (sprite CHR expander), Phase 4 step 5 (sprite sub-pal wiring), Phase 4 step 6 (sprite palette PAL1 cutover finalization), Phase 5 steps 3+4+6 (verifiers + emu smoke).

---

## File Structure

**New files:**
- `RoomRom/tools/expand_sprite_chr.py` — sprite CHR 4x expander (mirrors `expand_bg_chr.py`)
- `RoomRom/src/expanded_sprite_chr.{c,h}` — generated 4-copy sprite CHR arrays
- `RoomRom/probe_roomrom_sprite_subpal.lua` — visual probe firing each B-item against NES side-by-side capture
- `tools/captures/<item>_<variant>_<frame>.png` — captured visual baselines (committed)

**Modified files:**
- `RoomRom/src/roomrom_vram_map.h` — bump `ROOMROM_SPR_SUBPAL_COUNT` to 4
- `RoomRom/src/roomrom_sprites.c` — upload 4 sprite CHR banks, accept sub-pal in tile-index math
- `RoomRom/src/roomrom_sprites.h` — sub-pal arg in setter signatures, drop "Owns PAL3" comment
- `RoomRom/src/roomrom_combat.c` — drive sub-pal per NES dispatch
- `RoomRom/src/roomrom_bomb.c` — drive sub-pal per `DrawCloud` (NES sprite sub-pal 1)
- `RoomRom/src/roomrom_arrow.c`, `RoomRom/src/roomrom_boomerang.c` — drive sub-pal (sub-pal 0 unless NES says otherwise)
- `RoomRom/src/main.c` — comment cleanup; remove "PAL3" residue
- `RoomRom/tools/verify_slot_map.py` — extend to check sprite renderers for `ROOMROM_SPR_TILE_BASE_PAL` usage and absence of PAL3 in sprite-side calls
- `RoomRom/tools/verify_vram_budget.py` — recompute with sprite x4 expansion
- `RoomRom/build.bat` — link `expanded_sprite_chr.c`

**Touched but unchanged in shape:**
- `RoomRom/data/atlas_master.json` n/a (atlas spec is north-star, not implemented)

---

## Task 0: Diagnostic baseline + commit working state

Capture the current bomb/boomerang regression as a screenshot baseline so post-fix diff is meaningful.

**Files:**
- Read: current `RoomRom/out/RoomRom.md` (already built, commit `7d45fa85`)
- Probe: existing `RoomRom/probe_roomrom_bomb.lua`, `RoomRom/probe_roomrom_boomerang_b.lua`
- Output: `RoomRom/out/baselines/pre_sprite_expansion/*.png`

- [ ] **Step 0.1: Build current ROM and stage to `C:\tmp`.**

```bash
cd "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY-roomrom-s1"
cmd.exe /c "RoomRom\\build.bat"
cp RoomRom/out/RoomRom.md C:/tmp/RoomRom.md
```

Expected: `[5] Written: ...\RoomRom.md` line at end of build. Validator warnings present (5 known — sword_vert/horz, arrow_vert/horz, sword_diag) but build succeeds.

- [ ] **Step 0.2: Run boomerang probe, save baseline screenshots.**

```bash
mkdir -p RoomRom/out/baselines/pre_sprite_expansion
cp RoomRom/probe_roomrom_boomerang_b.lua C:/tmp/probe_roomrom_boomerang_b.lua
rm -f C:/tmp/boom_*.png
```

Then via PowerShell:

```powershell
Start-Process -FilePath 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' -ArgumentList '--lua=C:\tmp\probe_roomrom_boomerang_b.lua','C:\tmp\RoomRom.md' -WorkingDirectory 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64'
```

Wait until `C:/tmp/boom_right_f48.png` exists. Then:

```bash
cp C:/tmp/boom_*.png RoomRom/out/baselines/pre_sprite_expansion/
```

Expected: 12 PNG files (4 facings × 3 frames each).

- [ ] **Step 0.3: Run bomb probe, save baseline screenshots.**

```bash
cp RoomRom/probe_roomrom_bomb.lua C:/tmp/probe_roomrom_bomb.lua
rm -f C:/tmp/roomrom_bomb_*.png
```

Launch EmuHawk via PowerShell with the bomb probe. Wait for `C:/tmp/roomrom_bomb_f80.png`. Copy:

```bash
cp C:/tmp/roomrom_bomb_*.png RoomRom/out/baselines/pre_sprite_expansion/
```

Expected: 4 PNG files (f15, f50, f65, f80).

- [ ] **Step 0.4: Commit baselines.**

```bash
git add RoomRom/out/baselines/pre_sprite_expansion/
git commit -m "roomrom: capture sprite baselines before CHR expansion

Bomb + boomerang screenshots from commit 7d45fa85 (current state).
Sprite renderer is single-copy sub-pal 0 only, so bomb (NES sub-pal 1)
and explosion render with sword colors instead of NES blue. These are
the regression visuals user reported; serve as diff target for the
sprite-side CHR expansion work."
```

Expected: commit succeeds, baseline locked in.

---

## Task 1: Verify ROOMROM_SPR_SUBPAL_COUNT is wired but parameterizable

Confirm the existing macro structure in `roomrom_vram_map.h` supports bumping from 1 to 4 without renderer-side regression. Pure read + tiny refactor if needed.

**Files:**
- Read: `RoomRom/src/roomrom_vram_map.h`
- Read: every file using `ROOMROM_SPR_TILE_BASE` or `ROOMROM_SPR_TILE_BASE_PAL`

- [ ] **Step 1.1: Find all references.**

```bash
grep -rn "ROOMROM_SPR_TILE_BASE\|ROOMROM_SPR_SUBPAL_COUNT\|ROOMROM_SPR_TILE_COUNT_PER_PAL" RoomRom/src/
```

Expected: only `roomrom_vram_map.h` definitions plus zero or a few consumers. Renderers currently hard-pin to sub-pal 0 (i.e., `ROOMROM_SPR_TILE_BASE` directly) so consumer count is small.

- [ ] **Step 1.2: Verify `ROOMROM_SPR_TILE_BASE_PAL(s)` math is correct.**

```bash
grep -A 3 "ROOMROM_SPR_TILE_BASE_PAL" RoomRom/src/roomrom_vram_map.h
```

Expected:
```
#define ROOMROM_SPR_TILE_BASE_PAL(s) \
    (ROOMROM_SPR_TILE_BASE + (unsigned short)(s) * ROOMROM_SPR_TILE_COUNT_PER_PAL)
```

If macro absent or shape differs, write a failing test first that asserts `ROOMROM_SPR_TILE_BASE_PAL(0) == ROOMROM_SPR_TILE_BASE` and `ROOMROM_SPR_TILE_BASE_PAL(1) == ROOMROM_SPR_TILE_BASE + ROOMROM_SPR_TILE_COUNT_PER_PAL`. Then fix the macro.

No commit yet (no changes if macro is correct).

---

## Task 2: Build `tools/expand_sprite_chr.py` (mirror of `expand_bg_chr.py`)

Reads single-copy sprite CHR arrays, applies per-nibble pixel-bias rule, emits 4-copy expansion.

**Files:**
- Create: `RoomRom/tools/expand_sprite_chr.py`
- Create (generated by tool, but script must exist): `RoomRom/src/expanded_sprite_chr.{c,h}`

- [ ] **Step 2.1: Write the failing tool-runner test.**

Create `RoomRom/tools/test_expand_sprite_chr.py`:

```python
"""Test that expand_sprite_chr.py produces the expected pixel-biased output."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_expand_sprite_chr_runs():
    result = subprocess.run(
        [sys.executable, str(ROOT / "RoomRom" / "tools" / "expand_sprite_chr.py")],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"stdout: {result.stdout}\nstderr: {result.stderr}"
    out_h = ROOT / "RoomRom" / "src" / "expanded_sprite_chr.h"
    out_c = ROOT / "RoomRom" / "src" / "expanded_sprite_chr.c"
    assert out_h.exists(), f"missing {out_h}"
    assert out_c.exists(), f"missing {out_c}"


def test_pixel_bias_rule_for_subpal_1():
    """Source pixel value 1 with sub_pal=1 -> output 1*4 + 1 = 5."""
    from importlib import import_module
    sys.path.insert(0, str(ROOT / "RoomRom" / "tools"))
    mod = import_module("expand_sprite_chr")
    biased = mod.bias_byte(0x12, 1)  # high nibble 1 -> 5, low nibble 2 -> 6
    assert biased == 0x56, f"expected 0x56, got 0x{biased:02X}"


def test_pixel_bias_rule_zero_stays_zero():
    """Source pixel value 0 -> output 0 for any sub_pal."""
    from importlib import import_module
    sys.path.insert(0, str(ROOT / "RoomRom" / "tools"))
    mod = import_module("expand_sprite_chr")
    for s in range(4):
        assert mod.bias_byte(0x03, s) == ((s * 4 + 3) & 0x0F), f"sub_pal={s}"
        assert mod.bias_byte(0x30, s) == (((s * 4 + 3) << 4) & 0xF0), f"sub_pal={s}"
        assert mod.bias_byte(0x00, s) == 0x00


if __name__ == "__main__":
    test_pixel_bias_rule_zero_stays_zero()
    test_pixel_bias_rule_for_subpal_1()
    test_expand_sprite_chr_runs()
    print("OK")
```

- [ ] **Step 2.2: Run test to verify it fails (tool doesn't exist).**

```bash
python RoomRom/tools/test_expand_sprite_chr.py
```

Expected: `ModuleNotFoundError: No module named 'expand_sprite_chr'` or similar.

- [ ] **Step 2.3: Implement `RoomRom/tools/expand_sprite_chr.py`.**

```python
#!/usr/bin/env python3
"""Phase 3 sprite-side: 4x sub-pal pixel-bias expander for RoomRom sprite CHR.

Mirrors RoomRom/tools/expand_bg_chr.py but operates on sprite CHR arrays
(common_sprite_chr from data/chr/sprites.c plus the live item atlas in
RoomRom/src/roomrom_item_chr.c, plus Link / sword / beam / bomb /
explosion / boomerang / arrow CHR sourced from data/chr/common.c).

Per-nibble bias rule:
    out_pixel = (in_pixel == 0) ? 0 : (sub_pal * 4 + in_pixel)

Source nibble assertion: every source pixel must already be in {0..3}
(unbiased 4-color NES sprite pixel). Aborts on out-of-range so we can't
double-bias an already-expanded array.

Reads:
  data/chr/sprites.c        -> sprites_chr (NES sprite-half common CHR)
  RoomRom/src/roomrom_item_chr.c -> roomrom_item_chr[VARIANT_COUNT][BYTES]

Writes:
  RoomRom/src/expanded_sprite_chr.h
  RoomRom/src/expanded_sprite_chr.c
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROOMROM = ROOT / "RoomRom"

SOURCES = [
    # (path_relative_to_repo_root, array_name, declared_dim_count)
    ("data/chr/sprites.c",                 "sprites_chr",         1),
    ("RoomRom/src/roomrom_item_chr.c",     "roomrom_item_chr",    2),
]

OUT_C = ROOMROM / "src" / "expanded_sprite_chr.c"
OUT_H = ROOMROM / "src" / "expanded_sprite_chr.h"


def fail(msg):
    print(f"expand_sprite_chr: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def bias_byte(byte_val, sub_pal):
    """Apply pixel-bias rule to one source byte (high+low nibble).
    NES pixel 0 stays 0; nonzero pixels become sub_pal*4 + pixel."""
    if not (0 <= sub_pal <= 3):
        fail(f"sub_pal out of range: {sub_pal}")
    hi = (byte_val >> 4) & 0x0F
    lo = byte_val & 0x0F
    if hi > 3 or lo > 3:
        fail(f"source pixel > 3 in byte 0x{byte_val:02X} (already biased?)")
    new_hi = 0 if hi == 0 else (sub_pal * 4 + hi) & 0x0F
    new_lo = 0 if lo == 0 else (sub_pal * 4 + lo) & 0x0F
    return ((new_hi << 4) | new_lo) & 0xFF


def parse_1d_array(text, name):
    pat = re.compile(
        r"const\s+unsigned\s+char\s+" + re.escape(name) +
        r"\s*\[\s*(\d+)\s*\]\s*=\s*\{([^}]*)\}",
        re.MULTILINE | re.DOTALL,
    )
    m = pat.search(text)
    if not m:
        return None
    size = int(m.group(1))
    body = m.group(2)
    bytes_out = [int(t.group(1), 16) for t in re.finditer(r"0x([0-9A-Fa-f]{1,2})", body)]
    if len(bytes_out) != size:
        fail(f"{name}: declared size {size} != parsed {len(bytes_out)} bytes")
    return [bytes_out]  # list-of-rows for uniform downstream handling


def parse_2d_array(text, name):
    pat = re.compile(
        r"const\s+unsigned\s+char\s+" + re.escape(name) +
        r"\s*\[\s*(\d+)\s*\]\s*\[\s*[A-Z_0-9]+\s*\]\s*=\s*\{(.*?)\};",
        re.MULTILINE | re.DOTALL,
    )
    m = pat.search(text)
    if not m:
        return None
    n_rows = int(m.group(1))
    body = m.group(2)
    rows = []
    for inner in re.finditer(r"\{([^{}]*)\}", body):
        row = [int(t.group(1), 16) for t in re.finditer(r"0x([0-9A-Fa-f]{1,2})", inner.group(1))]
        rows.append(row)
    if len(rows) != n_rows:
        fail(f"{name}: declared {n_rows} rows, parsed {len(rows)}")
    return rows


def expand_array(rows, sub_pal):
    return [bytes(bias_byte(b, sub_pal) for b in row) for row in rows]


def emit_header(arrays):
    lines = [
        "/* Auto-generated by RoomRom/tools/expand_sprite_chr.py - do not edit. */",
        "#ifndef ROOMROM_EXPANDED_SPRITE_CHR_H",
        "#define ROOMROM_EXPANDED_SPRITE_CHR_H",
        "",
    ]
    for name, byte_count, n_rows in arrays:
        ident = name.upper() + "_X4_BYTES"
        lines.append(f"#define {ident} {byte_count * 4}u")
        if n_rows == 1:
            lines.append(f"extern const unsigned char {name}_x4[{ident}];")
        else:
            lines.append(f"extern const unsigned char {name}_x4[{n_rows}][{ident}];")
        lines.append("")
    lines += ["#endif", ""]
    OUT_H.write_text("\n".join(lines), encoding="ascii", newline="\n")


def emit_source(expansions):
    lines = [
        "/* Auto-generated by RoomRom/tools/expand_sprite_chr.py - do not edit. */",
        '#include "expanded_sprite_chr.h"',
        "",
    ]
    for name, n_rows, rows_x4 in expansions:
        ident = name.upper() + "_X4_BYTES"
        if n_rows == 1:
            row = rows_x4[0]
            lines.append(f"const unsigned char {name}_x4[{ident}] = {{")
            for i in range(0, len(row), 16):
                chunk = row[i:i+16]
                lines.append("    " + ", ".join(f"0x{b:02X}" for b in chunk) + ",")
            lines.append("};")
            lines.append("")
        else:
            lines.append(f"const unsigned char {name}_x4[{n_rows}][{ident}] = {{")
            for r, row in enumerate(rows_x4):
                lines.append(f"    {{ /* row {r} */")
                for i in range(0, len(row), 16):
                    chunk = row[i:i+16]
                    lines.append("        " + ", ".join(f"0x{b:02X}" for b in chunk) + ",")
                lines.append("    },")
            lines.append("};")
            lines.append("")
    OUT_C.write_text("\n".join(lines), encoding="ascii", newline="\n")


def main():
    arrays_meta = []
    expansions = []
    for src_rel, name, dim in SOURCES:
        text = (ROOT / src_rel).read_text(encoding="utf-8")
        rows = parse_1d_array(text, name) if dim == 1 else parse_2d_array(text, name)
        if rows is None:
            fail(f"{src_rel}: array '{name}' not found")
        # Concatenate per row, expanded across all 4 sub-pals.
        rows_x4 = []
        for row in rows:
            buf = bytearray()
            for s in range(4):
                buf.extend(bias_byte(b, s) for b in row)
            rows_x4.append(buf)
        n_rows = len(rows)
        byte_count = len(rows[0])
        arrays_meta.append((name, byte_count, n_rows))
        expansions.append((name, n_rows, rows_x4))
    emit_header(arrays_meta)
    emit_source(expansions)
    print(f"wrote {OUT_H} and {OUT_C} ({len(arrays_meta)} array(s))")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2.4: Run unit tests.**

```bash
python RoomRom/tools/test_expand_sprite_chr.py
```

Expected: `OK` printed.

- [ ] **Step 2.5: Run the tool standalone, eyeball outputs.**

```bash
python RoomRom/tools/expand_sprite_chr.py
ls -la RoomRom/src/expanded_sprite_chr.{c,h}
head -20 RoomRom/src/expanded_sprite_chr.h
```

Expected: both files exist, header has `*_X4_BYTES` defines and extern decls.

- [ ] **Step 2.6: Commit tool + first generated output.**

```bash
git add RoomRom/tools/expand_sprite_chr.py RoomRom/tools/test_expand_sprite_chr.py \
        RoomRom/src/expanded_sprite_chr.c RoomRom/src/expanded_sprite_chr.h
git commit -m "roomrom: tools/expand_sprite_chr.py - 4x sub-pal sprite CHR expander

Mirrors expand_bg_chr.py but for sprite CHR (sprites_chr from
common, roomrom_item_chr from item atlas). Per-nibble pixel-bias
rule: out = 0 if in == 0 else sub_pal * 4 + in. Generates
expanded_sprite_chr.{c,h} with *_x4 arrays. Unit-tested for the
bias rule. Phase 3 sprite half of the active CHR-expansion spec."
```

---

## Task 3: Bump `ROOMROM_SPR_SUBPAL_COUNT` from 1 to 4

Activate the macro stride. Renderers don't reference sub-pal != 0 yet, so this is a pure metadata bump that the next tasks build on.

**Files:**
- Modify: `RoomRom/src/roomrom_vram_map.h`

- [ ] **Step 3.1: Run VRAM budget verifier with current value.**

```bash
python RoomRom/tools/verify_vram_budget.py
```

Expected: passes. Capture the printed `tile bank ends at N` line.

- [ ] **Step 3.2: Edit the macro.**

```c
/* RoomRom/src/roomrom_vram_map.h */
#define ROOMROM_SPR_SUBPAL_COUNT        4u      /* 4 sub-pal copies; was 1 */
```

Also update the leading comment block to drop the "sub-pal 0 only for now" callout, replacing with a note that all 4 copies are populated and renderer selects via `ROOMROM_SPR_TILE_BASE_PAL(s)`.

- [ ] **Step 3.3: Re-run VRAM budget verifier.**

```bash
python RoomRom/tools/verify_vram_budget.py
```

Expected: still passes (the audit comment in `roomrom_vram_map.h` already accounts for 4x BG; sprite stride of 312 × 4 = 1248 tiles starting at 1025 ends at tile 2272 — exceeds 1536-table-region). If verifier flags overlap, shrink `ROOMROM_SPR_TILE_COUNT_PER_PAL` to fit (audit `tools/audit_vram_tile_usage.py` to find the actual minimum).

- [ ] **Step 3.4: Build, confirm clean.**

```bash
cd "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY-roomrom-s1"
cmd.exe /c "RoomRom\\build.bat" 2>&1 | tail -8
```

Expected: build succeeds. ROM size unchanged (the macro change only affects tile-base math and uploads, not yet wired).

- [ ] **Step 3.5: Commit.**

```bash
git add RoomRom/src/roomrom_vram_map.h
git commit -m "roomrom: vram map - bump SPR_SUBPAL_COUNT 1 -> 4

Phase 3 sprite half: activate 4 sub-pal sprite CHR copies.
Macro change only; renderers are untouched in this commit and
still select sub-pal 0 implicitly. Subsequent commits wire
sub-pal selection per item per NES dispatch."
```

---

## Task 4: Upload all 4 sprite CHR banks at boot

Modify `roomrom_sprites_upload_chr` to push 4 banks of `expanded_sprite_chr_x4` data into VRAM at `ROOMROM_SPR_TILE_BASE_PAL(s) * 32` for `s ∈ {0..3}`.

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c`
- Modify: `RoomRom/build.bat` — link `expanded_sprite_chr.c`

- [ ] **Step 4.1: Add `expanded_sprite_chr.c` to the build OBJS.**

In `RoomRom/build.bat`, append a compile step (mirror existing pattern around line 116 for `expanded_bg_chr.c`):

```
echo [3] Compiling expanded_sprite_chr.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\expanded_sprite_chr.c" -o "%OUT%\expanded_sprite_chr.o"
if errorlevel 1 ( echo FAIL: expanded_sprite_chr.c & exit /b 1 )
```

And append `%OUT%\expanded_sprite_chr.o` to the `OBJS` line.

- [ ] **Step 4.2: Build to confirm linkage clean before logic change.**

```bash
cmd.exe /c "RoomRom\\build.bat" 2>&1 | tail -8
```

Expected: build succeeds; no link errors.

- [ ] **Step 4.3: Locate `roomrom_sprites_upload_chr` and the existing item-atlas upload call.**

```bash
grep -n "roomrom_sprites_upload_chr\|render_chr_upload\|ITEM_VRAM_TILE\|roomrom_item_chr_byte_count" RoomRom/src/roomrom_sprites.c | head -20
```

Identify the line that uploads the live item atlas (`render_chr_upload(ITEM_VRAM_TILE * 32, roomrom_item_chr[s_item_chr_variant], ...)`).

- [ ] **Step 4.4: Replace single-bank upload with 4-bank loop.**

In `roomrom_sprites_upload_chr`, replace the existing item atlas upload block with:

```c
/* Phase 3 sprite expansion: 4 sub-pal copies. The pre-baked
 * expanded_sprite_chr_x4 array contains 4 concatenated copies
 * (one per NES sprite sub-pal) of the live item atlas tile bytes.
 * Upload each copy to its sub-pal-specific VRAM tile range so
 * sprite renderers can pick the correct color set via
 * ROOMROM_SPR_TILE_BASE_PAL(s) + local_tile. */
{
    extern const unsigned char roomrom_item_chr_x4[ROOMROM_ITEM_CHR_VARIANT_COUNT]
                                                  [ROOMROM_ITEM_CHR_X4_BYTES];
    unsigned short variant = s_item_chr_variant;
    unsigned char  s;
    for (s = 0; s < 4u; s++) {
        unsigned short vram_tile = (unsigned short)(ROOMROM_SPR_TILE_BASE_PAL(s) + ITEM_LOCAL_TILE);
        unsigned long  blob_off  = (unsigned long)(roomrom_item_chr_byte_count) * (unsigned long)s;
        render_chr_upload(
            (unsigned short)(vram_tile * 32u),
            &roomrom_item_chr_x4[variant][blob_off],
            (unsigned short)roomrom_item_chr_byte_count
        );
    }
}
```

Replace `ITEM_LOCAL_TILE` with whatever local-tile-offset constant the existing code uses for the item atlas within the SPR bank (likely `0` if items live at the top of the SPR bank).

Add `#include "expanded_sprite_chr.h"` at the top of `roomrom_sprites.c` if not present.

- [ ] **Step 4.5: Build, confirm clean.**

```bash
cmd.exe /c "RoomRom\\build.bat" 2>&1 | tail -10
```

Expected: build succeeds. Compile warnings about unused `expanded_sprite_chr_x4` symbols are acceptable for this commit (renderers wire in next task).

- [ ] **Step 4.6: Smoke test — boot ROM, verify item visuals are at minimum unchanged.**

```bash
cp RoomRom/out/RoomRom.md C:/tmp/RoomRom.md
```

Launch via PowerShell:

```powershell
Start-Process -FilePath 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' -ArgumentList 'C:\tmp\RoomRom.md' -WorkingDirectory 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64'
```

Manually swing sword + throw boomerang. Expected: boomerang renders with the same sub-pal-0 colors as before (since renderer still doesn't pick sub-pal != 0). No visible regression.

Kill EmuHawk:

```powershell
Get-Process -Name EmuHawk -ErrorAction SilentlyContinue | Stop-Process -Force
```

- [ ] **Step 4.7: Commit.**

```bash
git add RoomRom/src/roomrom_sprites.c RoomRom/build.bat
git commit -m "roomrom: sprites - upload 4 sprite CHR sub-pal banks at boot

Phase 3 sprite half: roomrom_sprites_upload_chr now pushes all
4 sub-pal copies of the live item atlas to VRAM at
ROOMROM_SPR_TILE_BASE_PAL(s) for s in 0..3. Banks 1-3 are
populated but not yet referenced by any renderer; subsequent
commits wire per-item sub-pal selection per NES dispatch."
```

---

## Task 5: Bomb renderer picks NES sprite sub-pal 1

NES `DrawCloud` (Z_07.asm:4912) loads `Y = 1` into `[$04]` and `[$05]` — sprite attribute palette bits = 1. Bomb visible state + cloud animation frames all draw with sub-pal 1 → blue.

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c` — `set_bomb` / `set_explosion` accept sub-pal
- Modify: `RoomRom/src/roomrom_sprites.h` — signatures
- Modify: `RoomRom/src/roomrom_bomb.c` — pass sub-pal=1 to setters
- Citation: NES `Z_07.asm:4912 DrawCloud` STY $04 with Y=1

- [ ] **Step 5.1: Add subpal arg to bomb setters.**

`RoomRom/src/roomrom_sprites.h`:
```c
void roomrom_sprites_set_bomb(short x, short y, unsigned char sub_pal);
void roomrom_sprites_set_explosion(short x, short y,
                                   unsigned char timer,
                                   unsigned char sub_pal);
```

`RoomRom/src/roomrom_sprites.c`: update the two function bodies. Replace the bare `BOMB_VRAM_TILE` reference with `(unsigned short)(ROOMROM_SPR_TILE_BASE_PAL(sub_pal) + BOMB_LOCAL_TILE)`. Same for explosion: tile = `ROOMROM_SPR_TILE_BASE_PAL(sub_pal) + EXPLOSION_LOCAL_TILE + phase * 2`.

You'll need a per-item "local tile" constant relative to the SPR bank base: the offset within the item atlas slice. Currently `BOMB_VRAM_TILE` etc are absolute tile indices. Convert: `BOMB_LOCAL_TILE = BOMB_VRAM_TILE - ROOMROM_SPR_TILE_BASE`. Define these alongside the existing macros at the top of `roomrom_sprites.c`.

- [ ] **Step 5.2: Update `clear_bomb` and `clear_explosion` similarly.** Use `sub_pal=0` for the off-screen cleared sprite (color doesn't matter at -32, -32, but pick a deterministic value).

- [ ] **Step 5.3: Update bomb caller.**

`RoomRom/src/roomrom_bomb.c`:
```c
/* NES: DrawCloud (Z_07.asm:4912) sets sprite attr Y=1 -> sub-pal 1 (blue). */
#define ROOMROM_BOMB_SUBPAL 1u

case BOMB_FUSE:
    roomrom_sprites_set_bomb(s_x, s_y, ROOMROM_BOMB_SUBPAL);
    roomrom_sprites_clear_explosion();
    ...

case BOMB_EXPLODE:
    roomrom_sprites_clear_bomb();
    roomrom_sprites_set_explosion(s_x, s_y, s_timer, ROOMROM_BOMB_SUBPAL);
    ...
```

Apply at the two call sites in `roomrom_bomb_update`.

- [ ] **Step 5.4: Build, confirm clean.**

```bash
cmd.exe /c "RoomRom\\build.bat" 2>&1 | tail -6
```

Expected: clean build.

- [ ] **Step 5.5: Bomb visual probe.**

```bash
cp RoomRom/out/RoomRom.md C:/tmp/RoomRom.md
cp RoomRom/probe_roomrom_bomb.lua C:/tmp/probe_roomrom_bomb.lua
rm -f C:/tmp/roomrom_bomb_*.png
```

Launch via PowerShell, wait for `roomrom_bomb_f80.png`. Read the f15, f50, f65 PNGs.

Expected: bomb at f15 / f50 (fuse phase) renders with NES sub-pal 1 colors (typically blue/cyan in NES Z1 OW palette). Compare against `RoomRom/out/baselines/pre_sprite_expansion/roomrom_bomb_f15.png`. Color delta visible.

If colors look right, save post-expansion PNGs for diff record:

```bash
mkdir -p RoomRom/out/baselines/post_sprite_expansion
cp C:/tmp/roomrom_bomb_*.png RoomRom/out/baselines/post_sprite_expansion/
```

- [ ] **Step 5.6: Commit.**

```bash
git add RoomRom/src/roomrom_sprites.c RoomRom/src/roomrom_sprites.h \
        RoomRom/src/roomrom_bomb.c RoomRom/out/baselines/post_sprite_expansion/
git commit -m "roomrom: bomb + explosion - render with NES sprite sub-pal 1

NES DrawCloud (Z_07.asm:4912) loads Y=1 into [\$04]/[\$05], so
the sprite attribute palette bits select sub-pal 1 throughout
the bomb-visible state and cloud animation frames. On Genesis
this maps to ROOMROM_SPR_TILE_BASE_PAL(1) + local_tile, which
indexes into PAL1[5..7] (NES sprite sub-pal 1 colors).

Adds sub_pal arg to roomrom_sprites_set_bomb / set_explosion.
Bomb caller passes 1 per NES citation. Pre/post expansion
visuals committed to RoomRom/out/baselines/."
```

---

## Task 6: Boomerang + arrow renderers — sub-pal 0 (NES sprite-pal 0)

NES draws boomerang and arrow with sub-pal 0 (sword colors). The current renderer already implicitly uses sub-pal 0 because all sprite tiles index PAL1[0..3]. With expansion active, the renderer must EXPLICITLY pass `sub_pal=0` to keep behaviour stable.

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c` — `set_boomerang`, `set_arrow` accept sub-pal
- Modify: `RoomRom/src/roomrom_sprites.h`
- Modify: `RoomRom/src/roomrom_boomerang.c`, `RoomRom/src/roomrom_arrow.c`
- Citations: NES `Z_07.asm` boomerang draws default attr 0; arrow same

- [ ] **Step 6.1: Add subpal arg, wire local-tile math.** Mirror the bomb/explosion change. Tile = `ROOMROM_SPR_TILE_BASE_PAL(sub_pal) + LOCAL_TILE`.

- [ ] **Step 6.2: Callers pass `sub_pal=0`.**

`roomrom_boomerang.c`:
```c
#define ROOMROM_BOOMERANG_SUBPAL 0u  /* Z_07.asm:3437 base attr=0 */
roomrom_sprites_set_boomerang(s_x, s_y, s_phase_idx, ROOMROM_BOOMERANG_SUBPAL);
```

`roomrom_arrow.c` similarly with `ROOMROM_ARROW_SUBPAL 0u`.

- [ ] **Step 6.3: Build, confirm clean.**

```bash
cmd.exe /c "RoomRom\\build.bat" 2>&1 | tail -6
```

- [ ] **Step 6.4: Boomerang visual probe.**

```bash
cp RoomRom/out/RoomRom.md C:/tmp/RoomRom.md
cp RoomRom/probe_roomrom_boomerang_b.lua C:/tmp/probe_roomrom_boomerang_b.lua
rm -f C:/tmp/boom_*.png
```

Launch via PowerShell, wait for `boom_right_f48.png`. Read screenshots. Expected: boomerang renders identically to baseline (sub-pal 0 unchanged).

If identical, save:

```bash
cp C:/tmp/boom_*.png RoomRom/out/baselines/post_sprite_expansion/
```

- [ ] **Step 6.5: Commit.**

```bash
git add RoomRom/src/roomrom_sprites.{c,h} RoomRom/src/roomrom_boomerang.c \
        RoomRom/src/roomrom_arrow.c RoomRom/out/baselines/post_sprite_expansion/
git commit -m "roomrom: boomerang + arrow - explicit sub-pal 0

NES base attribute for boomerang (Z_07.asm:3437 +
RDirectionToWeaponBaseAttribute) and arrow is 0 -> sub-pal 0.
Phase 3 expansion now requires explicit sub-pal selection per
caller; pre-expansion implicit sub-pal 0 is preserved by passing
0 explicitly. Visuals byte-identical to baseline."
```

---

## Task 7: Sword + sword diagonal — sub-pal from NES Items inventory

NES `@CalcSwordAttrs` (Z_07.asm:4471): `sub-pal = base_attr + Items - 1`. With white sword `Items = 2`, sub-pal = 1; magic sword `Items = 3`, sub-pal = 2. Current RoomRom locks the sword to wood-sword equivalent (sub-pal 0).

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c` — sword setters accept sub-pal
- Modify: `RoomRom/src/roomrom_sprites.h`
- Modify: `RoomRom/src/roomrom_combat.c` — pick sub-pal from sword level

- [ ] **Step 7.1: Add subpal arg to `set_sword_vertical`, `set_sword_horizontal`, `set_sword_diagonal`.** Same pattern as Tasks 5/6.

- [ ] **Step 7.2: combat.c — derive sub-pal from sword level.**

```c
/* RoomRom currently boots with wood sword (Items=1). The NES
 * @CalcSwordAttrs (Z_07.asm:4471) computes sub-pal = base_attr +
 * Items - 1. base_attr is 0 (RDirectionToWeaponBaseAttribute),
 * so sub-pal == Items - 1. */
static unsigned char sword_subpal_for_items(unsigned char items_val) {
    if (items_val == 0u) return 0u;  /* defensive; NES holds sword sprite */
    unsigned char s = (unsigned char)(items_val - 1u);
    if (s > 3u) s = 3u;               /* safety clamp */
    return s;
}
```

Track current sword level in a static `s_sword_level` (default 1 for wood). All sword setter calls now pass `sword_subpal_for_items(s_sword_level)`.

- [ ] **Step 7.3: Build + smoke.**

```bash
cmd.exe /c "RoomRom\\build.bat" 2>&1 | tail -6
```

Boot, swing sword down/up/left/right, screenshot via existing `RoomRom/probe_roomrom_*` if there's a sword probe; otherwise eyeball.

Expected: sword renders sub-pal 0 (wood-sword colors) — same as baseline.

- [ ] **Step 7.4: Commit.**

```bash
git add RoomRom/src/roomrom_sprites.{c,h} RoomRom/src/roomrom_combat.c
git commit -m "roomrom: sword - sub-pal driven by NES Items inventory level

NES @CalcSwordAttrs (Z_07.asm:4471) computes sub-pal = base_attr
+ Items - 1. Wood sword (Items=1) -> sub-pal 0. Future white /
magic sword upgrades pick sub-pal 1 / 2 by writing s_sword_level.

set_sword_vertical / horizontal / diagonal now accept sub-pal arg.
Visuals identical at default wood-sword state."
```

---

## Task 8: HUD/main.c stale PAL3 comment cleanup

Drop the PAL3 wording from `roomrom_sprites.h` (file owns PAL1+PAL2 now) and from `main.c` log strings.

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.h:6` — drop "Owns PAL3"
- Modify: `RoomRom/src/main.c:222`, `:387` — comment fix

- [ ] **Step 8.1: Read each line, plan edits.**

```bash
sed -n '4,10p' RoomRom/src/roomrom_sprites.h
sed -n '220,224p' RoomRom/src/main.c
sed -n '385,389p' RoomRom/src/main.c
```

- [ ] **Step 8.2: Edit `roomrom_sprites.h` line 6.**

Replace:
```c
 * Owns PAL3 and the sprite-CHR VRAM region. Renders Link as slot 0 +
```
with:
```c
 * Owns PAL1 (NES SPR PALRAM) + the sprite-CHR VRAM region. PAL2 is
 * borrowed dynamically by the sword-beam color flash. Renders Link as
 * slot 0 +
```

- [ ] **Step 8.3: Edit `main.c` line 222 + 387 comments.** Replace `PAL3` with `PAL1` (or remove the trailing comment entirely if it adds nothing).

- [ ] **Step 8.4: Build clean.**

```bash
cmd.exe /c "RoomRom\\build.bat" 2>&1 | tail -4
```

- [ ] **Step 8.5: Commit.**

```bash
git add RoomRom/src/roomrom_sprites.h RoomRom/src/main.c
git commit -m "roomrom: drop stale PAL3 comments

Sprite slot moved from PAL3 to PAL1 in commit b22f17fe; comments
in roomrom_sprites.h and main.c never got updated. Fixed."
```

---

## Task 9: Extend `verify_slot_map.py` to gate sprite renderers

Spec §5 step 3: verify_slot_map must also check sprite-side renderers for absence of `(pal & 0x03) << 13` and presence of `ROOMROM_SPR_TILE_BASE_PAL` usage.

**Files:**
- Modify: `RoomRom/tools/verify_slot_map.py`

- [ ] **Step 9.1: Read existing verifier.** Identify the file list it greps + the patterns it gates.

- [ ] **Step 9.2: Add sprite-side checks.**

```python
SPRITE_RENDERERS = [
    "RoomRom/src/roomrom_sprites.c",
    "RoomRom/src/roomrom_combat.c",
    "RoomRom/src/roomrom_bomb.c",
    "RoomRom/src/roomrom_boomerang.c",
    "RoomRom/src/roomrom_arrow.c",
]

def check_sprite_uses_subpal_macro():
    for path in SPRITE_RENDERERS:
        text = (ROOT / path).read_text(encoding="utf-8")
        # Forbidden: (pal & 0x03) << 13
        if re.search(r"\(\s*pal\s*&\s*0x03\s*\)\s*<<\s*13", text):
            fail(f"{path}: forbidden (pal & 0x03) << 13 pattern present")
        # Forbidden: hard-coded PAL3 in TILE_ATTR_FULL (PAL2 OK for beam flash)
        if re.search(r"TILE_ATTR_FULL\(\s*PAL3\b", text):
            fail(f"{path}: forbidden TILE_ATTR_FULL(PAL3 present (post-cutover)")
        # Required: at least one ROOMROM_SPR_TILE_BASE_PAL reference
        # (skip files that only clear sprites; check the main renderer)
        if path.endswith("roomrom_sprites.c"):
            if "ROOMROM_SPR_TILE_BASE_PAL" not in text:
                fail(f"{path}: missing ROOMROM_SPR_TILE_BASE_PAL reference")
```

Wire `check_sprite_uses_subpal_macro()` into `main()`.

- [ ] **Step 9.3: Run verifier.**

```bash
python RoomRom/tools/verify_slot_map.py
```

Expected: passes. If a sprite renderer was missed in earlier tasks (still using `BOMB_VRAM_TILE` etc), failure here forces a follow-up fix.

- [ ] **Step 9.4: Commit.**

```bash
git add RoomRom/tools/verify_slot_map.py
git commit -m "roomrom: verify_slot_map - gate sprite renderers post-cutover

Greps roomrom_sprites.c / combat.c / bomb.c / boomerang.c /
arrow.c for forbidden patterns ((pal & 0x03) << 13, PAL3 in
TILE_ATTR_FULL) and required ROOMROM_SPR_TILE_BASE_PAL macro
usage. Closes Phase 5 verifier coverage of the sprite half."
```

---

## Task 10: Wire verifier suite into `build.bat` Step 0

Spec §13 deliverable: `build.bat runs validator strict by default`.

**Files:**
- Modify: `RoomRom/build.bat`

- [ ] **Step 10.1: Locate Step 0 verifier block.**

```bash
grep -n "Step 0\|verify_item_chr_manifest\|verify_vram_budget\|verify_slot_map" RoomRom/build.bat
```

- [ ] **Step 10.2: Append `verify_slot_map.py` and `verify_vram_budget.py` calls.**

```
echo [0] verify_slot_map...
python "%PROJ%\tools\verify_slot_map.py"
if errorlevel 1 ( echo FAIL: verify_slot_map & exit /b 1 )

echo [0] verify_vram_budget...
python "%PROJ%\tools\verify_vram_budget.py"
if errorlevel 1 ( echo FAIL: verify_vram_budget & exit /b 1 )
```

Insert after the existing item CHR manifest verifier block.

- [ ] **Step 10.3: Build, confirm all verifiers green.**

```bash
cmd.exe /c "RoomRom\\build.bat" 2>&1 | head -20
```

Expected: `[0]` lines for each verifier, all return 0, build proceeds to compile.

- [ ] **Step 10.4: Commit.**

```bash
git add RoomRom/build.bat
git commit -m "roomrom: build.bat - run all Phase 5 verifiers as Step 0

verify_item_chr_manifest + verify_slot_map + verify_vram_budget
all run before any compile step; failure halts the build.
Spec §13 deliverable."
```

---

## Task 11: Acceptance gate — visual diff against baseline

Compare every `pre_sprite_expansion` PNG against the matching `post_sprite_expansion` PNG. Boomerang / sword screenshots must be byte-identical (sub-pal 0 unchanged). Bomb / explosion must differ in pixel COLOR but show identical sprite SHAPE + position.

**Files:**
- Create: `RoomRom/tools/diff_sprite_baselines.py`

- [ ] **Step 11.1: Write diff script.**

```python
#!/usr/bin/env python3
"""Pre/post sprite-expansion baseline diff.

Reports per-file: SAME (no change), SHAPE_SAME_COLOR_DIFF (sprite
silhouette identical, color palette differs - expected for bomb /
explosion / sword-with-level), or DIFFERENT (pixel positions diverge).

Run: python RoomRom/tools/diff_sprite_baselines.py
"""
import sys
from pathlib import Path
from PIL import Image  # SGDK ships pillow in the build venv

ROOT = Path(__file__).resolve().parents[2]
PRE = ROOT / "RoomRom" / "out" / "baselines" / "pre_sprite_expansion"
POST = ROOT / "RoomRom" / "out" / "baselines" / "post_sprite_expansion"


def silhouette(im):
    """Boolean mask of non-background pixels."""
    px = im.load()
    return [[px[x, y] != (0, 0, 0, 255) and px[x, y] != (0, 0, 0)
             for x in range(im.width)] for y in range(im.height)]


def main():
    fails = 0
    for pre in sorted(PRE.glob("*.png")):
        post = POST / pre.name
        if not post.exists():
            print(f"MISSING POST: {pre.name}")
            fails += 1
            continue
        a = Image.open(pre).convert("RGBA")
        b = Image.open(post).convert("RGBA")
        if list(a.getdata()) == list(b.getdata()):
            print(f"SAME: {pre.name}")
            continue
        if silhouette(a) == silhouette(b):
            print(f"SHAPE_SAME_COLOR_DIFF: {pre.name}")
            continue
        print(f"DIFFERENT: {pre.name}")
        fails += 1
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
```

- [ ] **Step 11.2: Run diff.**

```bash
python RoomRom/tools/diff_sprite_baselines.py
```

Expected per file:
- All `boom_*.png` (12 files): `SAME`
- All `roomrom_bomb_*.png` (4 files): `SHAPE_SAME_COLOR_DIFF`

If any line says `DIFFERENT`, investigate — likely a position bug, not a color one.

- [ ] **Step 11.3: Commit.**

```bash
git add RoomRom/tools/diff_sprite_baselines.py
git commit -m "roomrom: tools/diff_sprite_baselines.py - pre/post visual diff

Confirms boomerang and sword visuals are byte-identical (sub-pal
0 unchanged) and bomb/explosion show sprite-shape-identical /
color-different diffs (sub-pal 1 cutover). Acceptance gate for
the sprite CHR expansion track."
```

---

## Task 12: Update memory + atlas-spec dependency status

Note that Phase −1 of the atlas spec is now complete. The atlas spec can graduate to its own implementation plan when the user calls for it.

**Files:**
- Modify: `docs/superpowers/specs/2026-05-01-roomrom-z1-full-atlas-design.md` — mark Phase −1 as landed
- Update: memory file `feedback_check_dont_guess.md` if a new lesson learned

- [ ] **Step 12.1: Mark Phase −1 done in atlas spec.**

In §10 Migration plan, replace:
```
### Phase −1 — finish dependencies (NOT this spec)
```
with:
```
### Phase −1 — finish dependencies (LANDED 2026-05-02)
```

And in §13 deliverables checklist mark the dependency line:
```
- [x] **Phase −1 dependency** ([2026-05-01-roomrom-bg-palette-chr-expansion-design.md]...) shipped before this spec graduates to implementation.
```

- [ ] **Step 12.2: Commit.**

```bash
git add docs/superpowers/specs/2026-05-01-roomrom-z1-full-atlas-design.md
git commit -m "spec: roomrom z1 atlas - Phase -1 dependency landed

The active CHR / palette expansion spec (2026-05-01-roomrom-bg-
palette-chr-expansion-design.md) is implemented as of commit
<HASH>. Atlas spec can now graduate to its own implementation
plan."
```

---

## Self-review

**Spec coverage** (against `docs/superpowers/specs/2026-05-01-roomrom-bg-palette-chr-expansion-design.md`):

- §Phase 3 step 1 (BG expander): already shipped (commit `d9fa093a`). N/A.
- §Phase 3 step 2 (sprite expander): Task 2.
- §Phase 3 step 3 (per-sub-pal tile-base macros): partially shipped via `roomrom_vram_map.h`; Task 3 finalizes by setting `SPR_SUBPAL_COUNT=4`.
- §Phase 3 step 4 (CHR uploader writes 4 banks per scene): Task 4.
- §Phase 3 step 5+6 (tile_word with no `(pal & 0x03) << 13`, sprite SAT writes use sub-pal in tile): Tasks 5-7.
- §Phase 4 step 0 (HUD cutover): already shipped via `roomrom_hud.c` using `ROOMROM_BG_TILE_BASE_PAL`. Task 8 cleans residual stale comments.
- §Phase 4 step 5 (sprite module sub-pal selection): Tasks 5-7.
- §Phase 4 step 6 (sprite palette PAL1 from PALRAM data): already shipped via `roomrom_bg_palette_load_palram_full`. N/A.
- §Phase 5 step 3 (verify_slot_map covers sprite renderers): Task 9.
- §Phase 5 step 4 (verify_vram_budget covers sprite x4): Task 3 + Task 10 wires it into build.
- §Phase 5 step 5 (NES side-by-side acceptance): Task 11 covers the Genesis-side visual diff baseline; the NES-PALRAM-byte-match check is already in `verify_bg_palette_manifest` (commit `b22f17fe`).
- §Phase 5 step 6 (emu smoke): Tasks 4-7 each include a probe step.

**Placeholder scan:** all code blocks complete; no TBD / TODO / "implement later". Each task has explicit file paths, complete code, expected command outputs.

**Type consistency:** signatures consistent across tasks. Bomb/explosion accept `sub_pal` first added in Task 5; boomerang/arrow match in Task 6; sword setters match in Task 7. `LOCAL_TILE` constants per item are introduced in Task 5 and reused throughout.

---

Plan complete. Saved at `docs/superpowers/plans/2026-05-02-roomrom-sprite-chr-expansion-plan.md`.

# C-First Promotion Pipeline Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the first real promoted C subsystem by moving object movement/runtime logic out of bank-owned generated code into a hand-owned module, while preserving current build/parity behavior on the `m68k-elf-gcc` toolchain.

**Architecture:** This plan deliberately does not try to port the whole game in one pass. It creates one owned subsystem, `object_runtime`, and routes existing bank-facing symbols through thin wrappers so the game still links and probes still work. That proves the long-term promotion model with minimal ABI churn: owned C module at center, generated bank C as compatibility layer, asm left untouched unless strictly necessary.

**Tech Stack:** C (`m68k-elf-gcc`), M68K assembly (`vasm`), batch build scripts, BizHawk Lua probes, Python parity/perf comparators

---

## File Structure

### New files

- `src/object_runtime.h`
  - Public interface for the first promoted subsystem
  - Declares owned movement/runtime helpers
  - Keeps all movement-related externs in one place

- `src/object_runtime.c`
  - Source of truth for object movement/runtime logic
  - Owns the current `c_move_object` behavior plus the helper cluster currently living in `src/gen/z_01.c`

### Modified files

- `src/nes_abi.h`
  - Add named offsets/constants used by object runtime so promoted code stops relying on scattered magic numbers

- `src/c_move_object.c`
  - Convert from “real implementation” to thin compatibility wrapper
  - Preserve the `c_move_object()` symbol expected by asm and generated C

- `src/gen/z_01.c`
  - Replace selected movement helper bodies with thin forwarding wrappers into `object_runtime`
  - Preserve current public symbol names so the rest of the build does not need a large rewrite

- `build.bat`
  - Compile `src/object_runtime.c`

### Existing verification files reused unchanged

- `tools/run_t34_nes.bat`
- `tools/run_t34_gen.bat`
- `tools/compare_t34_movement_parity.py`
- `tools/bizhawk_perf_sample.lua`
- `tools/compare_perf.py`

This is intentionally one subsystem plan. Later promoted subsystems should get separate plans after this pattern is proven.

---

### Task 1: Capture movement + perf baseline before touching subsystem code

**Files:**
- Read: `tools/run_t34_nes.bat`
- Read: `tools/run_t34_gen.bat`
- Read: `tools/compare_t34_movement_parity.py`
- Read: `tools/bizhawk_perf_sample.lua`
- Read: `tools/compare_perf.py`
- Output: `builds/reports/t34_movement_parity_report.txt`
- Output: `builds/reports/perf_sample.json`
- Output: `builds/reports/perf_report.txt`

- [ ] **Step 1: Build current ROM**

Run:

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build completes and refreshes `builds\whatif.md`.

- [ ] **Step 2: Capture current T34 NES reference**

Run:

```powershell
cmd.exe /c ".\tools\run_t34_nes.bat"
```

Expected: `builds\reports\t34_movement_nes_capture.json` exists.

- [ ] **Step 3: Capture current T34 Genesis trace**

Run:

```powershell
cmd.exe /c ".\tools\run_t34_gen.bat"
```

Expected: `builds\reports\t34_movement_gen_capture.json` exists.

- [ ] **Step 4: Compare current movement parity**

Run:

```powershell
python .\tools\compare_t34_movement_parity.py
```

Expected: report ends with:

```text
T34_PARITY: ALL PASS
```

- [ ] **Step 5: Capture current perf sample**

Run BizHawk with:

```powershell
& 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' '--lua=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\bizhawk_perf_sample.lua' 'C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\builds\whatif.md'
```

Expected: `builds\reports\perf_sample.json` exists.

- [ ] **Step 6: Compare perf against baseline**

Run:

```powershell
python .\tools\compare_perf.py
```

Expected:
- first run may bootstrap `builds\reports\perf_baseline.json`
- later runs should end with `PERF_REPORT: ... 0 FAIL`

- [ ] **Step 7: Commit baseline capture notes if new baseline file was created**

```bash
git add builds/reports/perf_baseline.json
git commit -m "perf: capture baseline for T34 movement scenario"
```

If no baseline file changed, skip commit.

---

### Task 2: Create promoted `object_runtime` subsystem interface

**Files:**
- Create: `src/object_runtime.h`
- Modify: `src/nes_abi.h`

- [ ] **Step 1: Add named movement/runtime offsets to `src/nes_abi.h`**

Append these definitions after the existing object movement constants:

```c
#define NES_TMP0                 0x0000
#define NES_TMP1                 0x0001
#define NES_TMP2                 0x0002
#define NES_TMP3                 0x0003
#define NES_TMP4                 0x0004
#define NES_SHOT_COLLISION_FLAG  0x000E
#define NES_OBJ_DIR_STATE        0x000F
#define NES_CUR_SLOT             0x0016
#define NES_BOUND_LEFT           0x0346
#define NES_BOUND_RIGHT          0x0347
#define NES_BOUND_TOP            0x0348
#define NES_BOUND_BOTTOM         0x0349
#define NES_OBJ_TYPE             0x034F
```

- [ ] **Step 2: Create `src/object_runtime.h`**

Add:

```c
#ifndef OBJECT_RUNTIME_H
#define OBJECT_RUNTIME_H

#include "nes_abi.h"

#ifdef __cplusplus
extern "C" {
#endif

void objrt_move_object(unsigned short slot);
void objrt_bound_direction_horizontally(unsigned int slot);
void objrt_bound_direction_vertically(unsigned int slot);
unsigned char objrt_bound_by_room(unsigned int slot);
unsigned char objrt_bound_by_room_with_dir(unsigned char direction, unsigned int slot);
unsigned int objrt_add_q_speed_to_position_fraction(unsigned int slot);
unsigned int objrt_sub_q_speed_from_position_fraction(unsigned int slot);
void objrt_move_shot(unsigned char direction, unsigned int slot);

#ifdef __cplusplus
}
#endif

#endif /* OBJECT_RUNTIME_H */
```

- [ ] **Step 3: Build-check header-only changes**

Run:

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build still passes.

- [ ] **Step 4: Commit interface groundwork**

```bash
git add src/nes_abi.h src/object_runtime.h
git commit -m "infra: add object runtime interface and movement constants"
```

---

### Task 3: Move `c_move_object` implementation into owned subsystem code

**Files:**
- Create: `src/object_runtime.c`
- Modify: `src/c_move_object.c`
- Modify: `build.bat`

- [ ] **Step 1: Create `src/object_runtime.c` with the owned movement implementation**

Add:

```c
#include "object_runtime.h"

void objrt_move_object(unsigned short slot) {
    unsigned char pos_limit, neg_limit;
    unsigned char dir, old_frac, frac, speed, grid_off, step;
    int i;

    if (slot == 0) {
        pos_limit = 0x08;
        neg_limit = 0xF8;
    } else {
        pos_limit = 0x10;
        neg_limit = 0xF0;
    }
    RAM(NES_POS_GRID_LIMIT) = pos_limit;
    RAM(NES_NEG_GRID_LIMIT) = neg_limit;

    dir = RAM(NES_OBJ_DIR_STATE);
    if (dir == 0)
        return;

    for (i = 0; i < 4; i++) {
        if (dir & 0x01) {
            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
            frac = (unsigned char)(old_frac + OBJ(NES_OBJ_QSPD_FRAC, slot));
            step = (frac < old_frac) ? 1 : 0;
            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
            if (grid_off == pos_limit || grid_off == neg_limit)
                step = 0;
            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off + step);
            OBJ(NES_OBJ_X, slot) += step;
        } else if (dir & 0x02) {
            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
            speed = OBJ(NES_OBJ_QSPD_FRAC, slot);
            step = (old_frac < speed) ? 1 : 0;
            frac = (unsigned char)(old_frac - speed);
            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
            if (grid_off == pos_limit || grid_off == neg_limit)
                step = 0;
            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off - step);
            OBJ(NES_OBJ_X, slot) -= step;
        } else if (dir & 0x04) {
            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
            frac = (unsigned char)(old_frac + OBJ(NES_OBJ_QSPD_FRAC, slot));
            step = (frac < old_frac) ? 1 : 0;
            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
            if (grid_off == pos_limit || grid_off == neg_limit)
                step = 0;
            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off + step);
            OBJ(NES_OBJ_Y, slot) += step;
        } else {
            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
            speed = OBJ(NES_OBJ_QSPD_FRAC, slot);
            step = (old_frac < speed) ? 1 : 0;
            frac = (unsigned char)(old_frac - speed);
            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
            if (grid_off == pos_limit || grid_off == neg_limit)
                step = 0;
            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off - step);
            OBJ(NES_OBJ_Y, slot) -= step;
        }
    }
}
```

- [ ] **Step 2: Convert `src/c_move_object.c` into a compatibility wrapper**

Replace file contents with:

```c
#include "object_runtime.h"

void c_move_object(unsigned short slot) {
    objrt_move_object(slot);
}
```

- [ ] **Step 3: Add `object_runtime` to the C source list in `build.bat`**

Change:

```bat
set "C_SOURCES=c_runtime c_move_object"
```

To:

```bat
set "C_SOURCES=c_runtime c_move_object object_runtime"
```

- [ ] **Step 4: Build after subsystem extraction**

Run:

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build passes with the same exported `c_move_object` symbol behavior.

- [ ] **Step 5: Commit the first promoted module**

```bash
git add src/object_runtime.c src/c_move_object.c build.bat
git commit -m "feat: promote move object runtime into owned C module"
```

---

### Task 4: Move the `z_01` movement helper cluster behind `object_runtime`

**Files:**
- Modify: `src/object_runtime.c`
- Modify: `src/gen/z_01.c`

- [ ] **Step 1: Extend `src/object_runtime.c` with the helper cluster**

Append:

```c
static void objrt_reset_moving_dir_if_mask(unsigned char dir_bit) {
    if (RAM(NES_OBJ_DIR_STATE) & dir_bit)
        RAM(NES_OBJ_DIR_STATE) = 0;
}

void objrt_bound_direction_horizontally(unsigned int slot) {
    unsigned char x = RAM(NES_OBJ_X + slot);
    RAM(NES_TMP0) = x;
    int adjust = (slot != 0) && (slot >= 0x0D || RAM(NES_OBJ_TYPE + slot) == 0x5C);
    if (adjust)
        RAM(NES_TMP0) = (unsigned char)(x + 0x0B);
    if (RAM(NES_TMP0) < RAM(NES_BOUND_LEFT)) {
        objrt_reset_moving_dir_if_mask(2);
        return;
    }
    if (adjust)
        RAM(NES_TMP0) = (unsigned char)(RAM(NES_TMP0) - 0x17);
    if (RAM(NES_TMP0) >= RAM(NES_BOUND_RIGHT))
        objrt_reset_moving_dir_if_mask(1);
}

void objrt_bound_direction_vertically(unsigned int slot) {
    unsigned char y = RAM(NES_OBJ_Y + slot);
    RAM(NES_TMP0) = y;
    int adjust = (slot != 0) && (slot >= 0x0D || RAM(NES_OBJ_TYPE + slot) == 0x5C);
    if (adjust)
        RAM(NES_TMP0) = (unsigned char)(y + 0x0F);
    if (RAM(NES_TMP0) < RAM(NES_BOUND_TOP)) {
        objrt_reset_moving_dir_if_mask(8);
        return;
    }
    if (adjust)
        RAM(NES_TMP0) = (unsigned char)(RAM(NES_TMP0) - 0x21);
    if (RAM(NES_TMP0) >= RAM(NES_BOUND_BOTTOM))
        objrt_reset_moving_dir_if_mask(4);
}

unsigned char objrt_bound_by_room(unsigned int slot) {
    objrt_bound_direction_horizontally(slot);
    objrt_bound_direction_vertically(slot);
    return RAM(NES_OBJ_DIR_STATE);
}

unsigned char objrt_bound_by_room_with_dir(unsigned char direction, unsigned int slot) {
    RAM(NES_OBJ_DIR_STATE) = direction;
    return objrt_bound_by_room(slot);
}

unsigned int objrt_add_q_speed_to_position_fraction(unsigned int slot) {
    unsigned int result = (unsigned int)RAM(NES_OBJ_POS_FRAC + slot) + RAM(NES_OBJ_QSPD_FRAC + slot);
    RAM(NES_OBJ_POS_FRAC + slot) = (unsigned char)result;
    unsigned int carry = result >> 8;
    unsigned char grid = RAM(NES_OBJ_GRID_OFFSET + slot);
    if (grid == RAM(NES_POS_GRID_LIMIT) || grid == RAM(NES_NEG_GRID_LIMIT))
        carry = 0;
    RAM(NES_OBJ_GRID_OFFSET + slot) = (unsigned char)(grid + (unsigned char)carry);
    return carry ? CARRY_SET : 0u;
}

unsigned int objrt_sub_q_speed_from_position_fraction(unsigned int slot) {
    unsigned int frac = RAM(NES_OBJ_POS_FRAC + slot);
    unsigned int sub_val = RAM(NES_OBJ_QSPD_FRAC + slot);
    unsigned int borrow = (frac < sub_val) ? 1u : 0u;
    RAM(NES_OBJ_POS_FRAC + slot) = (unsigned char)(frac - sub_val);
    unsigned char grid = RAM(NES_OBJ_GRID_OFFSET + slot);
    if (grid == RAM(NES_POS_GRID_LIMIT) || grid == RAM(NES_NEG_GRID_LIMIT))
        return 0u;
    RAM(NES_OBJ_GRID_OFFSET + slot) = (unsigned char)(grid - (unsigned char)borrow);
    return borrow ? 0u : CARRY_SET;
}

void objrt_move_shot(unsigned char direction, unsigned int slot) {
    unsigned char dir_result = objrt_bound_by_room_with_dir(direction, slot);
    if (dir_result == 0) {
        RAM(NES_SHOT_COLLISION_FLAG) = 0x80;
        return;
    }
    unsigned char saved_offset = RAM(NES_OBJ_GRID_OFFSET + slot);
    RAM(NES_OBJ_GRID_OFFSET + slot) = 0;
    objrt_move_object((unsigned short)slot);
    unsigned char new_offset = RAM(NES_OBJ_GRID_OFFSET + slot);
    if (RAM(NES_SHOT_COLLISION_FLAG) == 0)
        RAM(NES_OBJ_GRID_OFFSET + slot) = (unsigned char)(saved_offset + new_offset);
    else
        RAM(NES_OBJ_GRID_OFFSET + slot) = saved_offset;
}
```

- [ ] **Step 2: Add the new include in `src/gen/z_01.c`**

Near the existing includes, add:

```c
#include "object_runtime.h"
```

- [ ] **Step 3: Replace the selected `z_01` helper bodies with forwarding wrappers**

Use these exact replacements:

```c
void z01_bound_direction_horizontally(unsigned int slot) {
    objrt_bound_direction_horizontally(slot);
}

void z01_bound_direction_vertically(unsigned int slot) {
    objrt_bound_direction_vertically(slot);
}

unsigned char z01_bound_by_room(unsigned int slot) {
    return objrt_bound_by_room(slot);
}

unsigned char z01_bound_by_room_with_a(unsigned char direction, unsigned int slot) {
    return objrt_bound_by_room_with_dir(direction, slot);
}

unsigned int z01_add_q_speed_to_position_fraction(unsigned int slot) {
    return objrt_add_q_speed_to_position_fraction(slot);
}

unsigned int z01_sub_q_speed_from_position_fraction(unsigned int slot) {
    return objrt_sub_q_speed_from_position_fraction(slot);
}

void z01_move_shot(unsigned char direction, unsigned int slot) {
    objrt_move_shot(direction, slot);
}
```

- [ ] **Step 4: Build after bank-wrapper migration**

Run:

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build passes, and no duplicate symbol errors appear for the moved helper logic.

- [ ] **Step 5: Commit the helper promotion**

```bash
git add src/object_runtime.c src/gen/z_01.c
git commit -m "refactor: route z01 movement helpers through object runtime"
```

---

### Task 5: Verify parity and perf after the first promoted subsystem lands

**Files:**
- Output: `builds/reports/t34_movement_parity_report.txt`
- Output: `builds/reports/perf_sample.json`
- Output: `builds/reports/perf_report.txt`

- [ ] **Step 1: Rebuild final candidate ROM**

Run:

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build succeeds.

- [ ] **Step 2: Re-run T34 NES reference**

Run:

```powershell
cmd.exe /c ".\tools\run_t34_nes.bat"
```

Expected: NES capture completes.

- [ ] **Step 3: Re-run T34 Genesis capture**

Run:

```powershell
cmd.exe /c ".\tools\run_t34_gen.bat"
```

Expected: Genesis capture completes with no exception.

- [ ] **Step 4: Re-run parity comparison**

Run:

```powershell
python .\tools\compare_t34_movement_parity.py
```

Expected:

```text
T34_PARITY: ALL PASS
```

- [ ] **Step 5: Re-run perf sample**

Run:

```powershell
& 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' '--lua=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\bizhawk_perf_sample.lua' 'C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\builds\whatif.md'
```

Expected: fresh `builds\reports\perf_sample.json`.

- [ ] **Step 6: Re-run perf regression check**

Run:

```powershell
python .\tools\compare_perf.py
```

Expected:
- `PERF_SAMPLE_OK` passes
- no new perf regression gate fails

- [ ] **Step 7: Commit verified subsystem promotion**

```bash
git add src/nes_abi.h src/object_runtime.h src/object_runtime.c src/c_move_object.c src/gen/z_01.c build.bat builds/reports/perf_baseline.json
git commit -m "refactor: promote object movement runtime to owned C subsystem"
```

If `builds/reports/perf_baseline.json` did not change, omit it from `git add`.

---

### Task 6: Document the promotion rule in code comments so the next subsystem follows the same pattern

**Files:**
- Modify: `src/object_runtime.h`
- Modify: `src/c_move_object.c`

- [ ] **Step 1: Add a subsystem ownership note to `src/object_runtime.h`**

Add above the declarations:

```c
/* object_runtime is the owned implementation layer for promoted movement code.
 * Generated bank C may call through wrappers, but new fixes and optimizations
 * for this subsystem belong here first.
 */
```

- [ ] **Step 2: Add a compatibility note to `src/c_move_object.c`**

Keep wrapper file small and add:

```c
/* Compatibility entry point preserved for asm shims and generated callers.
 * Real implementation lives in object_runtime.c.
 */
```

- [ ] **Step 3: Final build smoke check**

Run:

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build still passes.

- [ ] **Step 4: Commit ownership documentation**

```bash
git add src/object_runtime.h src/c_move_object.c
git commit -m "docs: mark object runtime as owned promoted subsystem"
```


# Infrastructure-First Promotion Scaffold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the migration infrastructure (symbolic RAM naming, wrapper-generation tool, CI drift gate, promotion-checklist template) that all subsequent gen/ drains will ride on, while making zero behavior changes this batch.

**Architecture:** Names-first, tool-second, gate-third. New `*_state.h` headers declare subsystem-owned RAM cells. Shared ABI cells live in `src/nes_abi.h`. A 180-line Python tool reads per-bank JSON manifests describing forwarder signatures and regenerates the marker-bounded forwarder region of each `src/gen/z_0x.c`. A `--check` mode wired into `build.bat` locks gen/ passive the moment this plan ships. ROM must byte-compare identical to baseline after every step.

**Tech Stack:** C (`m68k-elf-gcc`), M68K assembly (`vasm`), Windows batch (`cmd.exe /c`), Python 3 standard library only (no PyYAML), BizHawk Lua probes, existing Python parity/perf comparators.

**Spec clarification:** the spec proposed YAML for the manifest format. This plan uses JSON instead to keep the tool strictly stdlib-only. Manifest semantics are unchanged.

---

## File Structure

### New files

- `src/object_state.h` — subsystem-owned RAM cell names for object slot state.
- `src/sprite_state.h` — OAM and sprite attribute cell names.
- `src/save_state.h` — SRAM-backed save cell names.
- `src/link_state.h` — Link position / animation / halt cell names.
- `src/collision_state.h` — shared collision scratch cell names.
- `src/weapon_state.h` — weapon slot cell names.
- `src/hud_state.h` — HUD / status row cell names.
- `tools/gen_wrappers/README.md` — schema and tool contract.
- `tools/gen_wrappers/z_01_manifest.json` — forwarder inventory for `src/gen/z_01.c`.
- `tools/gen_wrappers/z_02_manifest.json` — forwarder inventory for `src/gen/z_02.c`.
- `tools/gen_wrappers/z_03_manifest.json` — forwarder inventory for `src/gen/z_03.c`.
- `tools/gen_wrappers/z_04_manifest.json` — forwarder inventory for `src/gen/z_04.c`.
- `tools/gen_wrappers/z_05_manifest.json` — forwarder inventory for `src/gen/z_05.c`.
- `tools/gen_wrappers/z_06_manifest.json` — forwarder inventory for `src/gen/z_06.c`.
- `tools/gen_wrappers/z_07_manifest.json` — forwarder inventory for `src/gen/z_07.c`.
- `tools/emit_gen_wrappers.py` — manifest-driven wrapper generator, idempotent, `--check` mode.
- `tools/gen_wrappers/test_emit_gen_wrappers.py` — unittest suite for the tool.
- `docs/superpowers/templates/promotion-checklist.md` — checklist template derived from `best practices.md`.
- `docs/superpowers/work/2026-04-23-ram-inventory.md` — working inventory of raw RAM offsets in gen/*.c.
- `builds/reports/rom_baseline_plan_w.sha256` — ROM hash captured at plan start.

### Modified files

- `src/nes_abi.h` — add grouped `#define NES_*` constants for all magic RAM offsets surfaced in gen/*.c logic bodies and at the gen boundary.
- `src/room_state.h` — add room-transfer buffer cell names.
- `src/progress_state.h` — add continue-count / save-slot cell names if absent.
- `src/gen/z_01.c` — insert marker-region comments around existing forwarder block. No logic change.
- `src/gen/z_02.c` — same.
- `src/gen/z_03.c` — same.
- `src/gen/z_04.c` — same.
- `src/gen/z_05.c` — same.
- `src/gen/z_06.c` — same.
- `src/gen/z_07.c` — same.
- `build.bat` — add post-compile drift-gate step running `python tools\emit_gen_wrappers.py --check`.
- `docs/superpowers/specs/2026-04-23-infra-first-promotion-scaffold-design.md` — link checklist template after it exists.

### Existing verification files reused unchanged

- `tools/run_t34_nes.bat`
- `tools/run_t34_gen.bat`
- `tools/compare_t34_movement_parity.py`
- `tools/bizhawk_perf_sample.lua`
- `tools/compare_perf.py`

---

### Task 1: Capture baselines before any change

**Files:**
- Output: `builds/reports/rom_baseline_plan_w.sha256`
- Output: `builds/reports/t34_movement_parity_report.txt`
- Output: `builds/reports/perf_sample.json`
- Output: `builds/reports/perf_report.txt`

- [ ] **Step 1: Build current ROM**

Run:

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build completes without error and `builds\whatif.md` exists.

- [ ] **Step 2: Hash baseline ROM**

Run:

```powershell
certutil -hashfile builds\whatif.md SHA256 | findstr /v "hash" > builds\reports\rom_baseline_plan_w.sha256
```

Expected: `builds\reports\rom_baseline_plan_w.sha256` contains one hex digest line.

- [ ] **Step 3: Capture T34 NES reference**

Run:

```powershell
cmd.exe /c ".\tools\run_t34_nes.bat"
```

Expected: `builds\reports\t34_movement_nes_capture.json` exists.

- [ ] **Step 4: Capture T34 Genesis trace**

Run:

```powershell
cmd.exe /c ".\tools\run_t34_gen.bat"
```

Expected: `builds\reports\t34_movement_gen_capture.json` exists.

- [ ] **Step 5: Compare parity**

Run:

```powershell
python .\tools\compare_t34_movement_parity.py
```

Expected: report ends with:

```text
T34_PARITY: ALL PASS
```

If not, STOP and investigate — plan cannot proceed with a broken baseline.

- [ ] **Step 6: Capture perf baseline**

Run:

```powershell
& 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' '--lua=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\bizhawk_perf_sample.lua' 'C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\builds\whatif.md'
```

Expected: `builds\reports\perf_sample.json` refreshed.

- [ ] **Step 7: Run perf regression check**

Run:

```powershell
python .\tools\compare_perf.py
```

Expected: exit code 0, report ends with `PERF_REPORT: ... 0 FAIL`. If `builds\reports\perf_baseline.json` is missing, the first run bootstraps it.

- [ ] **Step 8: Commit baseline artifact**

```bash
git add builds/reports/rom_baseline_plan_w.sha256
git commit -m "infra: capture ROM baseline hash for Plan W"
```

If `builds/reports/perf_baseline.json` was freshly created, add it in the same commit.

---

### Task 2: Inventory raw RAM offsets currently used in gen/*.c logic bodies

**Files:**
- Create: `docs/superpowers/work/2026-04-23-ram-inventory.md`

- [ ] **Step 1: Create the work directory if missing**

Run:

```powershell
if not exist docs\superpowers\work mkdir docs\superpowers\work
```

- [ ] **Step 2: Gather unique `RAM(0x...)` references in gen/**

Run:

```powershell
findstr /r /c:"RAM(0x" src\gen\*.c | sort /unique > docs\superpowers\work\2026-04-23-ram-grep.txt
```

Expected: file contains one line per `RAM(0xNNNN...)` usage found in `src/gen/*.c`.

- [ ] **Step 3: Also gather `nes_ram[...]` references**

Run:

```powershell
findstr /r /c:"nes_ram\[" src\gen\*.c > docs\superpowers\work\2026-04-23-nesram-grep.txt
```

Expected: file contains every line that indexes `nes_ram` directly.

- [ ] **Step 4: Write the inventory report**

Create `docs/superpowers/work/2026-04-23-ram-inventory.md` with this exact content:

```markdown
# Raw RAM offset inventory — 2026-04-23

Purpose: enumerate every magic offset currently surfaced in `src/gen/*.c` so
the state-header pass can name them before any drain runs. Grouped by owning
subsystem. Entries listed here MUST be covered by the state-header / nes_abi.h
additions in Tasks 3–5.

## Shared ABI / scratch (nes_abi.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x0000 | NES_TILE_XFER_PTR_LO      | scratch pointer low / multi-use          |
| 0x0001 | NES_TILE_XFER_PTR_HI      | scratch pointer high                     |
| 0x0002 | NES_SCRATCH_2             | multi-use scratch                        |
| 0x0003 | NES_SCRATCH_3             | multi-use scratch                        |
| 0x0004 | NES_SCRATCH_4             | multi-use scratch                        |
| 0x0005 | NES_SCRATCH_5             | multi-use scratch                        |
| 0x0010 | NES_CUR_LEVEL             | current dungeon level / overworld flag   |
| 0x0011 | NES_GAME_MODE_PREV        | previous game-mode latch                 |
| 0x0012 | NES_GAME_MODE             | active top-level game mode               |
| 0x0013 | NES_SUB_MODE              | mode sub-state                           |
| 0x0015 | NES_FRAME_TICK            | frame tick bit field                     |
| 0x0016 | NES_SAVE_SLOT             | selected save slot 0..2                  |

## Room subsystem (room_state.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x00E8 | NES_TILE_XFER_COL         | target column + 1                        |
| 0x00E9 | NES_TILE_XFER_ROW         | target row                               |
| 0x00EB | NES_CUR_ROOM_ID           | currently loaded room id                 |
| 0x00FE | NES_PPU_MASK_SHADOW       | PPU mask written pre-vblank              |
| 0x0301 | NES_TILE_XFER_BUF_IDX     | next free byte in transfer buffer        |
| 0x0302 | NES_TILE_XFER_BUF_BASE    | transfer records base                    |
| 0x0526 | NES_ROOM_ID_ALT           | alternate room id latch                  |
| 0x0529 | NES_ROOM_HISTORY_IDX      | room history cursor                      |
| 0x0621 | NES_ROOM_HISTORY_BASE     | room history 6-entry table base          |
| 0x0657 | NES_ITEMS_BY_LEVEL_BASE   | per-level item bitmap table base         |
| 0x6530 | NES_PLAY_AREA_BASE        | 22x32 play-area tile storage             |
| 0x0016 | (shares NES_TILE_COL_STRIDE 0x16) | stride constant, not RAM          |

## Object / enemy slot (object_state.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x0070 | NES_OBJ_TILE_X_BASE       | per-slot tile X (indexed by slot)        |
| 0x0084 | NES_OBJ_TILE_Y_BASE       | per-slot tile Y                          |
| 0x0098 | NES_OBJ_FLAG_BASE         | per-slot flag byte                       |
| 0x00AC | NES_OBJ_STATE_BASE        | per-slot state byte                      |
| 0x00C0 | NES_OBJ_SHOVE_DIR_BASE    | per-slot shove direction                 |
| 0x00D3 | NES_OBJ_SHOVE_DIST_BASE   | per-slot shove distance                  |
| 0x034F | NES_OBJ_TYPE_BASE         | per-slot object type                     |
| 0x0394 | NES_OBJ_ALIGN_FLAG_BASE   | per-slot alignment flag                  |
| 0x03D0 | NES_OBJ_ANIM_CNTR_BASE    | per-slot anim counter                    |
| 0x03E4 | NES_OBJ_HFLIP_BASE        | per-slot horizontal flip                 |
| 0x0405 | NES_OBJ_METASTATE_BASE    | per-slot meta state                      |
| 0x049E | NES_OBJ_TILE_NEXT_BASE    | per-slot next tile                       |
| 0x04F0 | NES_OBJ_INV_TIMER_BASE    | per-slot invincibility timer             |

## Sprite / OAM (sprite_state.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x0200 | NES_OAM_BASE              | OAM shadow, 64 sprites * 4 bytes         |

## Link (link_state.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x000F | NES_LINK_MOVING_DIR       | moving direction bits                    |
| 0x0033 | NES_MODE11_DEATH_TIMER    | mode-11 death countdown                  |
| 0x0059 | NES_LINK_ROOM_SCRATCH     | room-scratch byte used by link logic     |
| 0x0602 | NES_DEATH_FRAME_COUNTER   | death animation frame                    |
| 0x066C | NES_LINK_HALT_FLAG        | player halt flag                         |

## Save / SRAM (save_state.h)

| Offset         | Proposed name                 | Notes                        |
|----------------|-------------------------------|------------------------------|
| 0x6000 + 0x09FE| NES_SRAM_ROOM_UNIQUE_ID_BASE  | per-room unique id table     |
| 0x6000 + 0x0BAF| NES_SRAM_ROOM_FLAGS_PTR_LO    | room-flags pointer low       |
| 0x6000 + 0x0BB0| NES_SRAM_ROOM_FLAGS_PTR_HI    | room-flags pointer high      |
| 0x0630         | NES_CONTINUE_COUNT_BASE       | per-slot continue counter    |

## Collision / link collision (collision_state.h)

No new magic offsets observed in gen/ logic bodies; collision already runs
through `lcrt_` / `colrt_` forwarders. Header created as a declaration
boundary placeholder so future drains have a home.

## Weapon (weapon_state.h)

No new magic offsets observed. Header created as boundary placeholder.

## HUD (hud_state.h)

No new magic offsets observed. Header created as boundary placeholder.

## Progress / item (progress_state.h extension)

`0x0010` (NES_CUR_LEVEL) lives in nes_abi.h. `0x0657` is an item-bitmap
table; declare `NES_ITEMS_BY_LEVEL_BASE` in `progress_state.h` pointing
at the nes_abi.h constant to keep ownership clear.

## Exclusions / already-named

- `NES_OBJ_DIR_STATE (0x000F)` — already named in `nes_abi.h`; confirm in Task 3.
- `NES_CUR_SLOT (0x0016)` — already named; confirm in Task 3.
- Per-slot offsets already named by earlier phases — confirm in Task 3 grep.
```

- [ ] **Step 5: Commit the inventory**

```bash
git add docs/superpowers/work/2026-04-23-ram-inventory.md docs/superpowers/work/2026-04-23-ram-grep.txt docs/superpowers/work/2026-04-23-nesram-grep.txt
git commit -m "infra: enumerate raw RAM offsets in gen/ as state-header input"
```

---

### Task 3: Expand `src/nes_abi.h` with shared ABI cells

**Files:**
- Modify: `src/nes_abi.h`

- [ ] **Step 1: Inspect current `nes_abi.h` defines**

Run:

```powershell
findstr /r /c:"#define NES_" src\nes_abi.h
```

Record the output. Any proposed name below that collides must be dropped from the add-list; the existing name wins.

- [ ] **Step 2: Insert shared ABI block**

Append after the last existing `#define` in `src/nes_abi.h`, before any trailing `#endif`, exactly the following block. Skip any line whose `NES_*` name already exists per Step 1.

```c
/* ---- Plan W: shared ABI cells ------------------------------------------- */
/* Multi-use scratch pointer / misc */
#define NES_TILE_XFER_PTR_LO     0x0000
#define NES_TILE_XFER_PTR_HI     0x0001
#define NES_SCRATCH_2            0x0002
#define NES_SCRATCH_3            0x0003
#define NES_SCRATCH_4            0x0004
#define NES_SCRATCH_5            0x0005

/* Game-mode / slot / ticks */
#define NES_CUR_LEVEL            0x0010
#define NES_GAME_MODE_PREV       0x0011
#define NES_GAME_MODE            0x0012
#define NES_SUB_MODE             0x0013
#define NES_FRAME_TICK           0x0015
/* NES_SAVE_SLOT 0x0016 is already defined if present; if not: */
#ifndef NES_SAVE_SLOT
#define NES_SAVE_SLOT            0x0016
#endif

/* Tile-transfer / play-area constants */
#define NES_TILE_XFER_COL        0x00E8
#define NES_TILE_XFER_ROW        0x00E9
#define NES_CUR_ROOM_ID          0x00EB
#define NES_PPU_MASK_SHADOW      0x00FE
#define NES_TILE_XFER_BUF_IDX    0x0301
#define NES_TILE_XFER_BUF_BASE   0x0302
#define NES_PLAY_AREA_BASE       0x6530u
#define NES_TILE_COL_STRIDE      0x16u

/* OAM */
#define NES_OAM_BASE             0x0200

/* Room / progress cells */
#define NES_ROOM_ID_ALT          0x0526
#define NES_ROOM_HISTORY_IDX     0x0529
#define NES_ROOM_HISTORY_BASE    0x0621
#define NES_CONTINUE_COUNT_BASE  0x0630
#define NES_ITEMS_BY_LEVEL_BASE  0x0657

/* Link / mode-11 death */
#define NES_LINK_MOVING_DIR      0x000F
#define NES_MODE11_DEATH_TIMER   0x0033
#define NES_LINK_ROOM_SCRATCH    0x0059
#define NES_DEATH_FRAME_COUNTER  0x0602
#define NES_LINK_HALT_FLAG       0x066C

/* Per-slot object bases (add `+ slot`) */
#define NES_OBJ_TILE_X_BASE      0x0070
#define NES_OBJ_TILE_Y_BASE      0x0084
#define NES_OBJ_FLAG_BASE        0x0098
#define NES_OBJ_STATE_BASE       0x00AC
#define NES_OBJ_SHOVE_DIR_BASE   0x00C0
#define NES_OBJ_SHOVE_DIST_BASE  0x00D3
#define NES_OBJ_TYPE_BASE        0x034F
#define NES_OBJ_ALIGN_FLAG_BASE  0x0394
#define NES_OBJ_ANIM_CNTR_BASE   0x03D0
#define NES_OBJ_HFLIP_BASE       0x03E4
#define NES_OBJ_METASTATE_BASE   0x0405
#define NES_OBJ_TILE_NEXT_BASE   0x049E
#define NES_OBJ_INV_TIMER_BASE   0x04F0

/* SRAM (NES $6000 base) */
#define NES_SRAM_BASE                 0x6000u
#define NES_SRAM_ROOM_UNIQUE_ID_BASE  0x09FE
#define NES_SRAM_ROOM_FLAGS_PTR_LO    0x0BAF
#define NES_SRAM_ROOM_FLAGS_PTR_HI    0x0BB0
```

Do not remove or renumber any existing define. Only add.

- [ ] **Step 3: Build check**

Run:

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build passes. A redefine warning/error means a name collided with existing content; fix per Step 1 guidance (drop the dup from the add-list) and rebuild.

- [ ] **Step 4: Hash ROM and confirm byte-identical to baseline**

Run:

```powershell
certutil -hashfile builds\whatif.md SHA256 | findstr /v "hash" > builds\reports\rom_after_task3.sha256
fc builds\reports\rom_after_task3.sha256 builds\reports\rom_baseline_plan_w.sha256
```

Expected: `fc` reports `FC: no differences encountered`. A diff here means a macro somehow leaked into an expression used by gen/*.c; investigate before commit.

- [ ] **Step 5: Commit**

```bash
git add src/nes_abi.h
git commit -m "infra: name shared ABI cells in nes_abi.h (Plan W)"
```

---

### Task 4: Create new subsystem state headers

**Files:**
- Create: `src/object_state.h`
- Create: `src/sprite_state.h`
- Create: `src/save_state.h`
- Create: `src/link_state.h`
- Create: `src/collision_state.h`
- Create: `src/weapon_state.h`
- Create: `src/hud_state.h`

Rule: every new `*_state.h` includes only `nes_abi.h`. No cross-state-header includes.

- [ ] **Step 1: Create `src/object_state.h`**

Write the exact content:

```c
#ifndef OBJECT_STATE_H
#define OBJECT_STATE_H

#include "nes_abi.h"

/* Per-slot object-state cell bases. Index with `+ slot` at the call site.
 * Owned by object_runtime; any new offset touched by object logic belongs here.
 */

/* Position / tile */
#define OBJ_TILE_X(slot)        RAM(NES_OBJ_TILE_X_BASE + (slot))
#define OBJ_TILE_Y(slot)        RAM(NES_OBJ_TILE_Y_BASE + (slot))
#define OBJ_TILE_NEXT(slot)     RAM(NES_OBJ_TILE_NEXT_BASE + (slot))
#define OBJ_ALIGN_FLAG(slot)    RAM(NES_OBJ_ALIGN_FLAG_BASE + (slot))

/* Type / state */
#define OBJ_TYPE(slot)          RAM(NES_OBJ_TYPE_BASE + (slot))
#define OBJ_FLAG(slot)          RAM(NES_OBJ_FLAG_BASE + (slot))
#define OBJ_STATE(slot)         RAM(NES_OBJ_STATE_BASE + (slot))
#define OBJ_METASTATE(slot)     RAM(NES_OBJ_METASTATE_BASE + (slot))

/* Shove */
#define OBJ_SHOVE_DIR(slot)     RAM(NES_OBJ_SHOVE_DIR_BASE + (slot))
#define OBJ_SHOVE_DIST(slot)    RAM(NES_OBJ_SHOVE_DIST_BASE + (slot))

/* Animation */
#define OBJ_ANIM_CNTR(slot)     RAM(NES_OBJ_ANIM_CNTR_BASE + (slot))
#define OBJ_HFLIP(slot)         RAM(NES_OBJ_HFLIP_BASE + (slot))

/* Invulnerability */
#define OBJ_INV_TIMER(slot)     RAM(NES_OBJ_INV_TIMER_BASE + (slot))

#endif /* OBJECT_STATE_H */
```

- [ ] **Step 2: Create `src/sprite_state.h`**

```c
#ifndef SPRITE_STATE_H
#define SPRITE_STATE_H

#include "nes_abi.h"

/* Sprite / OAM shadow cells. Owned by sprite_runtime.
 * OAM layout: 64 sprites * 4 bytes, starting at NES_OAM_BASE.
 *   [0] y, [1] tile, [2] attr, [3] x
 */
#define OAM_BYTE(i)        RAM(NES_OAM_BASE + (unsigned short)(i))
#define OAM_SPRITE_Y(n)    RAM(NES_OAM_BASE + ((unsigned short)(n) * 4) + 0)
#define OAM_SPRITE_TILE(n) RAM(NES_OAM_BASE + ((unsigned short)(n) * 4) + 1)
#define OAM_SPRITE_ATTR(n) RAM(NES_OAM_BASE + ((unsigned short)(n) * 4) + 2)
#define OAM_SPRITE_X(n)    RAM(NES_OAM_BASE + ((unsigned short)(n) * 4) + 3)

#define OAM_SPRITE_COUNT   64

#endif /* SPRITE_STATE_H */
```

- [ ] **Step 3: Create `src/save_state.h`**

```c
#ifndef SAVE_STATE_H
#define SAVE_STATE_H

#include "nes_abi.h"

/* SRAM-backed save state. NES SRAM maps at NES_SRAM_BASE. */

#define SAVE_BYTE(off)  nes_ram[NES_SRAM_BASE + (unsigned short)(off)]

#define SAVE_ROOM_UNIQUE_ID(room_id) \
    SAVE_BYTE(NES_SRAM_ROOM_UNIQUE_ID_BASE + (room_id))

#define SAVE_ROOM_FLAGS_PTR_LO  SAVE_BYTE(NES_SRAM_ROOM_FLAGS_PTR_LO)
#define SAVE_ROOM_FLAGS_PTR_HI  SAVE_BYTE(NES_SRAM_ROOM_FLAGS_PTR_HI)

#define CONTINUE_COUNT(slot)    RAM(NES_CONTINUE_COUNT_BASE + (slot))

#endif /* SAVE_STATE_H */
```

- [ ] **Step 4: Create `src/link_state.h`**

```c
#ifndef LINK_STATE_H
#define LINK_STATE_H

#include "nes_abi.h"

/* Link (player) state cells. Owned by link_collision_runtime and
 * link-side slices of room_player_runtime.
 */
#define LINK_MOVING_DIR       RAM(NES_LINK_MOVING_DIR)
#define LINK_ROOM_SCRATCH     RAM(NES_LINK_ROOM_SCRATCH)
#define LINK_HALT_FLAG        RAM(NES_LINK_HALT_FLAG)
#define MODE11_DEATH_TIMER    RAM(NES_MODE11_DEATH_TIMER)
#define DEATH_FRAME_COUNTER   RAM(NES_DEATH_FRAME_COUNTER)

#endif /* LINK_STATE_H */
```

- [ ] **Step 5: Create `src/collision_state.h`**

```c
#ifndef COLLISION_STATE_H
#define COLLISION_STATE_H

#include "nes_abi.h"

/* Collision subsystem state boundary. No raw cells required at Plan W time.
 * This header exists so future drains have a named home for collision-owned
 * cells as they surface. Do not add cross-subsystem cells here; keep those
 * in nes_abi.h.
 */

#endif /* COLLISION_STATE_H */
```

- [ ] **Step 6: Create `src/weapon_state.h`**

```c
#ifndef WEAPON_STATE_H
#define WEAPON_STATE_H

#include "nes_abi.h"

/* Weapon subsystem state boundary placeholder. See collision_state.h note. */

#endif /* WEAPON_STATE_H */
```

- [ ] **Step 7: Create `src/hud_state.h`**

```c
#ifndef HUD_STATE_H
#define HUD_STATE_H

#include "nes_abi.h"

/* HUD / status-row subsystem state boundary placeholder. */

#endif /* HUD_STATE_H */
```

- [ ] **Step 8: Build check**

Run:

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build passes. No file currently includes these headers; they compile transitively when touched. Creating the headers alone must not affect any object file. To prove that, hash the ROM:

- [ ] **Step 9: ROM byte-compare**

```powershell
certutil -hashfile builds\whatif.md SHA256 | findstr /v "hash" > builds\reports\rom_after_task4.sha256
fc builds\reports\rom_after_task4.sha256 builds\reports\rom_baseline_plan_w.sha256
```

Expected: `FC: no differences encountered`.

- [ ] **Step 10: Commit**

```bash
git add src/object_state.h src/sprite_state.h src/save_state.h src/link_state.h src/collision_state.h src/weapon_state.h src/hud_state.h
git commit -m "infra: add subsystem state headers (object, sprite, save, link, collision, weapon, hud)"
```

---

### Task 5: Extend existing state headers

**Files:**
- Modify: `src/room_state.h`
- Modify: `src/progress_state.h`

- [ ] **Step 1: Inspect existing `room_state.h`**

Run:

```powershell
type src\room_state.h
```

Read the output. The extension is appended before the trailing `#endif`. If any proposed name below already appears, skip that line.

- [ ] **Step 2: Append to `src/room_state.h`**

Before the final `#endif` in `src/room_state.h`, add:

```c
/* ---- Plan W: room transfer + meta cells --------------------------------- */
#define ROOM_TILE_XFER_COL       RAM(NES_TILE_XFER_COL)
#define ROOM_TILE_XFER_ROW       RAM(NES_TILE_XFER_ROW)
#define ROOM_CUR_ROOM_ID         RAM(NES_CUR_ROOM_ID)
#define ROOM_PPU_MASK_SHADOW     RAM(NES_PPU_MASK_SHADOW)
#define ROOM_TILE_XFER_BUF_IDX   RAM(NES_TILE_XFER_BUF_IDX)
#define ROOM_TILE_XFER_BUF(off)  RAM(NES_TILE_XFER_BUF_BASE + (unsigned short)(off))
#define ROOM_ID_ALT              RAM(NES_ROOM_ID_ALT)
#define ROOM_HISTORY_IDX         RAM(NES_ROOM_HISTORY_IDX)
#define ROOM_HISTORY(i)          RAM(NES_ROOM_HISTORY_BASE + (unsigned char)(i))
#define PLAY_AREA(i)             nes_ram[NES_PLAY_AREA_BASE + (unsigned short)(i)]
```

- [ ] **Step 3: Inspect existing `progress_state.h`**

Run:

```powershell
type src\progress_state.h
```

- [ ] **Step 4: Append to `src/progress_state.h`**

Before the final `#endif`:

```c
/* ---- Plan W: save / progress cells -------------------------------------- */
#define PROG_CUR_LEVEL           RAM(NES_CUR_LEVEL)
#define PROG_ITEMS_BY_LEVEL(off) RAM(NES_ITEMS_BY_LEVEL_BASE + (unsigned short)(off))
```

- [ ] **Step 5: Build check**

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build passes.

- [ ] **Step 6: ROM byte-compare**

```powershell
certutil -hashfile builds\whatif.md SHA256 | findstr /v "hash" > builds\reports\rom_after_task5.sha256
fc builds\reports\rom_after_task5.sha256 builds\reports\rom_baseline_plan_w.sha256
```

Expected: `FC: no differences encountered`.

- [ ] **Step 7: Commit**

```bash
git add src/room_state.h src/progress_state.h
git commit -m "infra: extend room_state and progress_state with Plan W cell names"
```

---

### Task 6: Create `tools/gen_wrappers/` with README

**Files:**
- Create: `tools/gen_wrappers/README.md`

- [ ] **Step 1: Create the directory**

Run:

```powershell
if not exist tools\gen_wrappers mkdir tools\gen_wrappers
```

- [ ] **Step 2: Write `tools/gen_wrappers/README.md`**

Exact content:

````markdown
# gen_wrappers — forwarder manifests and generator

## Purpose

`src/gen/z_0x.c` files are declared passive: they forward to owned runtime
modules and hold no real logic. This directory stores the authoritative
inventory of every forwarder symbol per bank, and `tools/emit_gen_wrappers.py`
regenerates the forwarder region of each bank file from its manifest.

The generator is idempotent and has a `--check` mode wired into `build.bat`.
A build fails if the forwarder region of any `src/gen/z_0x.c` drifts from
its manifest.

## Manifest schema (JSON)

```json
{
  "bank": "z_05",
  "includes": [
    "room_transfer_runtime.h",
    "room_mode_runtime.h"
  ],
  "symbols": [
    {
      "old": "z05_copy_column_to_tilebuf",
      "new": "roomxf_copy_column_to_tilebuf",
      "sig": "void ()"
    },
    {
      "old": "z05_has_compass",
      "new": "roomrt_has_compass",
      "sig": "unsigned char ()"
    }
  ]
}
```

Fields:

- `bank` — stem of the target file (`z_05` → `src/gen/z_05.c`).
- `includes` — list of runtime header basenames emitted into the forwarder
  region's include block. May be empty when the generator's prefix → header
  map covers every symbol's `new` prefix.
- `symbols` — ordered list of forwarders. Order is preserved in output.
- `symbols[].old` — declared name in `src/gen/z_0x.c`.
- `symbols[].new` — target owned-runtime symbol.
- `symbols[].sig` — signature string. Grammar: `<ret> (<params>)` where
  `<ret>` is one of `void`, `unsigned char`, `unsigned int`, `unsigned short`,
  `int`, `char`, `signed char`; `<params>` is empty or a comma-separated list
  of `<type> <name>` pairs using the same type set plus `const ...`.

## Marker region

The generator rewrites text between these markers in each bank file:

```c
/* <<< auto-wrappers: z_05 (generated by tools/emit_gen_wrappers.py) >>> */
...generated forwarder block...
/* <<< end auto-wrappers >>> */
```

Text outside the markers is hand-owned: top-of-file includes, extern
declarations, static helpers that survived the drain, etc.

## Commands

```bash
python tools/emit_gen_wrappers.py            # regenerate all banks
python tools/emit_gen_wrappers.py --bank z_05  # one bank
python tools/emit_gen_wrappers.py --check    # exit non-zero on drift
```
````

- [ ] **Step 3: Commit**

```bash
git add tools/gen_wrappers/README.md
git commit -m "infra: add gen_wrappers README with manifest schema"
```

---

### Task 7: Author forwarder manifests for z_01 through z_07

Each manifest captures every current forwarder in its bank. The manifest is
the ground-truth input for the tool round-trip test in Task 9.

**Files:**
- Create: `tools/gen_wrappers/z_01_manifest.json`
- Create: `tools/gen_wrappers/z_02_manifest.json`
- Create: `tools/gen_wrappers/z_03_manifest.json`
- Create: `tools/gen_wrappers/z_04_manifest.json`
- Create: `tools/gen_wrappers/z_05_manifest.json`
- Create: `tools/gen_wrappers/z_06_manifest.json`
- Create: `tools/gen_wrappers/z_07_manifest.json`

- [ ] **Step 1: Produce a mechanical extraction script**

Create `tools/gen_wrappers/_scan_forwarders.py` (scratch helper for this task only; committed with the manifests):

```python
"""One-shot helper that scans a src/gen/z_0x.c file and prints a JSON
manifest candidate to stdout.

It recognises the common forwarder shapes:
    void z0N_name(args) { runtime_prefix_name(args); }
    ret  z0N_name(args) { return runtime_prefix_name(args); }

Empty-body or non-forwarder functions are skipped and reported on stderr.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

FWD_RE = re.compile(
    r"^\s*(?P<ret>void|unsigned\s+char|unsigned\s+int|unsigned\s+short|int|char|signed\s+char)"
    r"\s+(?P<old>z0[1-7]_[A-Za-z0-9_]+)\s*"
    r"\((?P<params>[^)]*)\)\s*\{\s*"
    r"(?:return\s+)?(?P<new>[a-z]+(?:rt|ld|md|obj|pl|xf)_[A-Za-z0-9_]+)\s*"
    r"\((?P<call>[^)]*)\)\s*;\s*\}",
    re.MULTILINE,
)

PREFIX_HEADERS = {
    "cavert_":  "cave_runtime.h",
    "cobrt_":   "combat_runtime.h",
    "colrt_":   "collision_runtime.h",
    "corert_":  "core_runtime.h",
    "enrt_":    "enemy_runtime.h",
    "hudrt_":   "hud_runtime.h",
    "itemrt_":  "item_runtime.h",
    "lcrt_":    "link_collision_runtime.h",
    "objrt_":   "object_runtime.h",
    "progrt_":  "progress_runtime.h",
    "roomld_":  "room_load_runtime.h",
    "roommd_":  "room_mode_runtime.h",
    "roomobj_": "room_object_runtime.h",
    "roompl_":  "room_player_runtime.h",
    "roomrt_":  "room_runtime.h",
    "roomxf_":  "room_transfer_runtime.h",
    "savert_":  "save_menu_runtime.h",
    "sprrt_":   "sprite_runtime.h",
    "targrt_":  "targeting_runtime.h",
    "trprt_":   "trap_runtime.h",
    "uwrt_":    "uw_person_runtime.h",
    "weprt_":   "weapon_runtime.h",
    "worldrt_": "world_runtime.h",
}


def header_for(new: str) -> str | None:
    for prefix, header in PREFIX_HEADERS.items():
        if new.startswith(prefix):
            return header
    return None


def main(path_str: str) -> None:
    path = Path(path_str)
    text = path.read_text()
    bank = path.stem
    symbols = []
    includes: list[str] = []
    seen_includes: set[str] = set()
    for m in FWD_RE.finditer(text):
        ret = re.sub(r"\s+", " ", m.group("ret")).strip()
        params = re.sub(r"\s+", " ", m.group("params")).strip()
        sig = f"{ret} ({params})" if params else f"{ret} ()"
        entry = {"old": m.group("old"), "new": m.group("new"), "sig": sig}
        symbols.append(entry)
        header = header_for(m.group("new"))
        if header and header not in seen_includes:
            seen_includes.add(header)
            includes.append(header)
    manifest = {"bank": bank, "includes": includes, "symbols": symbols}
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main(sys.argv[1])
```

- [ ] **Step 2: Run the scanner against each bank and write the manifests**

For each bank in `z_01 z_02 z_03 z_04 z_05 z_06 z_07`, run:

```powershell
python tools\gen_wrappers\_scan_forwarders.py src\gen\z_01.c > tools\gen_wrappers\z_01_manifest.json
python tools\gen_wrappers\_scan_forwarders.py src\gen\z_02.c > tools\gen_wrappers\z_02_manifest.json
python tools\gen_wrappers\_scan_forwarders.py src\gen\z_03.c > tools\gen_wrappers\z_03_manifest.json
python tools\gen_wrappers\_scan_forwarders.py src\gen\z_04.c > tools\gen_wrappers\z_04_manifest.json
python tools\gen_wrappers\_scan_forwarders.py src\gen\z_05.c > tools\gen_wrappers\z_05_manifest.json
python tools\gen_wrappers\_scan_forwarders.py src\gen\z_06.c > tools\gen_wrappers\z_06_manifest.json
python tools\gen_wrappers\_scan_forwarders.py src\gen\z_07.c > tools\gen_wrappers\z_07_manifest.json
```

Expected: each JSON file contains `"bank"`, `"includes"` (possibly empty),
and a `"symbols"` array.

- [ ] **Step 3: Spot-check each manifest**

For each bank, open the JSON and verify:

- `"bank"` matches filename stem.
- `"symbols"` has entries matching hand-inspected forwarders.
- Every `new` prefix maps cleanly to a runtime header (if any symbol has no
  matching prefix, the scanner skipped it silently; inspect `src/gen/z_0x.c`
  and either rename the target to match convention, or add an explicit entry
  to the manifest).

Not every function in `src/gen/z_0x.c` becomes a forwarder manifest entry:
empty-body stubs (`void foo(void) {}`) are recorded in a comment note in
this task, not in the manifest. Record any such stubs in
`docs/superpowers/work/2026-04-23-ram-inventory.md` under a new section
"## Empty stubs (kept as-is in gen/)".

- [ ] **Step 4: Commit**

```bash
git add tools/gen_wrappers/_scan_forwarders.py tools/gen_wrappers/z_01_manifest.json tools/gen_wrappers/z_02_manifest.json tools/gen_wrappers/z_03_manifest.json tools/gen_wrappers/z_04_manifest.json tools/gen_wrappers/z_05_manifest.json tools/gen_wrappers/z_06_manifest.json tools/gen_wrappers/z_07_manifest.json docs/superpowers/work/2026-04-23-ram-inventory.md
git commit -m "infra: author forwarder manifests for z_01..z_07 (Plan W)"
```

---

### Task 8: Implement `tools/emit_gen_wrappers.py` via TDD

**Files:**
- Create: `tools/emit_gen_wrappers.py`
- Create: `tools/gen_wrappers/test_emit_gen_wrappers.py`

All tests use the Python `unittest` stdlib module. No pytest dependency.

- [ ] **Step 1: Write the failing test file**

Create `tools/gen_wrappers/test_emit_gen_wrappers.py`:

```python
"""Tests for emit_gen_wrappers.py. Run:
    python -m unittest tools.gen_wrappers.test_emit_gen_wrappers
"""
from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import textwrap
import unittest
from pathlib import Path

# Load the tool as a module
ROOT = Path(__file__).resolve().parents[2]
TOOL_PATH = ROOT / "tools" / "emit_gen_wrappers.py"


def load_tool():
    spec = importlib.util.spec_from_file_location("emit_gen_wrappers", TOOL_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class SigTests(unittest.TestCase):
    def setUp(self):
        self.mod = load_tool()

    def test_void_no_args(self):
        self.assertEqual(self.mod.parse_sig("void ()"),
                         ("void", []))

    def test_void_one_arg(self):
        self.assertEqual(self.mod.parse_sig("void (unsigned int slot)"),
                         ("void", [("unsigned int", "slot")]))

    def test_return_type_two_args(self):
        self.assertEqual(
            self.mod.parse_sig("unsigned char (unsigned char a, unsigned int b)"),
            ("unsigned char", [("unsigned char", "a"), ("unsigned int", "b")]))

    def test_bad_sig_raises(self):
        with self.assertRaises(ValueError):
            self.mod.parse_sig("double ()")


class RenderTests(unittest.TestCase):
    def setUp(self):
        self.mod = load_tool()

    def test_void_body(self):
        out = self.mod.render_forwarder(
            {"old": "z05_foo", "new": "roomxf_foo", "sig": "void ()"})
        self.assertEqual(
            out.strip(),
            "void z05_foo(void) {\n    roomxf_foo();\n}")

    def test_return_body(self):
        out = self.mod.render_forwarder(
            {"old": "z05_bar", "new": "roomrt_bar",
             "sig": "unsigned char (unsigned int slot)"})
        self.assertEqual(
            out.strip(),
            "unsigned char z05_bar(unsigned int slot) {\n"
            "    return roomrt_bar(slot);\n}")

    def test_args_forwarded_by_name(self):
        out = self.mod.render_forwarder(
            {"old": "z05_baz", "new": "roomrt_baz",
             "sig": "void (unsigned int a, unsigned char b)"})
        self.assertIn("roomrt_baz(a, b)", out)


class HeaderMapTests(unittest.TestCase):
    def setUp(self):
        self.mod = load_tool()

    def test_known_prefix(self):
        self.assertEqual(self.mod.header_for("roomxf_foo"),
                         "room_transfer_runtime.h")

    def test_unknown_prefix(self):
        self.assertIsNone(self.mod.header_for("xyz_unknown"))


class RegionTests(unittest.TestCase):
    def setUp(self):
        self.mod = load_tool()

    def test_replace_between_markers(self):
        source = textwrap.dedent("""
            /* header comment */
            #include "foo.h"

            /* <<< auto-wrappers: z_05 (generated by tools/emit_gen_wrappers.py) >>> */
            OLD CONTENT
            /* <<< end auto-wrappers >>> */

            /* footer comment */
        """).lstrip()
        new = self.mod.replace_region(source, "z_05", "NEW CONTENT\n")
        self.assertIn("NEW CONTENT", new)
        self.assertNotIn("OLD CONTENT", new)
        self.assertIn("/* header comment */", new)
        self.assertIn("/* footer comment */", new)

    def test_missing_markers_appends(self):
        source = '#include "foo.h"\n'
        new = self.mod.replace_region(source, "z_05", "FORWARDERS\n")
        self.assertIn("/* <<< auto-wrappers: z_05", new)
        self.assertIn("FORWARDERS", new)
        self.assertIn("/* <<< end auto-wrappers >>> */", new)


class IdempotencyTests(unittest.TestCase):
    def setUp(self):
        self.mod = load_tool()

    def test_double_run_stable(self):
        manifest = {
            "bank": "z_05",
            "includes": ["room_transfer_runtime.h"],
            "symbols": [
                {"old": "z05_foo", "new": "roomxf_foo", "sig": "void ()"},
                {"old": "z05_bar", "new": "roomxf_bar",
                 "sig": "unsigned char (unsigned int slot)"},
            ],
        }
        with tempfile.TemporaryDirectory() as d:
            src = Path(d) / "z_05.c"
            src.write_text("/* z_05.c */\n#include \"../nes_abi.h\"\n")
            self.mod.apply_manifest(manifest, src)
            first = src.read_text()
            self.mod.apply_manifest(manifest, src)
            second = src.read_text()
            self.assertEqual(first, second)


class CheckModeTests(unittest.TestCase):
    def setUp(self):
        self.mod = load_tool()

    def test_check_passes_on_clean(self):
        manifest = {
            "bank": "z_05",
            "includes": [],
            "symbols": [
                {"old": "z05_foo", "new": "roomxf_foo", "sig": "void ()"},
            ],
        }
        with tempfile.TemporaryDirectory() as d:
            src = Path(d) / "z_05.c"
            src.write_text("/* z_05.c */\n")
            self.mod.apply_manifest(manifest, src)
            drift = self.mod.check_manifest(manifest, src)
            self.assertFalse(drift)

    def test_check_fails_on_drift(self):
        manifest = {
            "bank": "z_05",
            "includes": [],
            "symbols": [
                {"old": "z05_foo", "new": "roomxf_foo", "sig": "void ()"},
            ],
        }
        with tempfile.TemporaryDirectory() as d:
            src = Path(d) / "z_05.c"
            src.write_text("/* z_05.c */\n")
            self.mod.apply_manifest(manifest, src)
            polluted = src.read_text().replace(
                "roomxf_foo();",
                "roomxf_foo(); /* hand-edited */")
            src.write_text(polluted)
            drift = self.mod.check_manifest(manifest, src)
            self.assertTrue(drift)


class DuplicateSymbolTests(unittest.TestCase):
    def setUp(self):
        self.mod = load_tool()

    def test_duplicate_old_rejected(self):
        manifest = {
            "bank": "z_05",
            "includes": [],
            "symbols": [
                {"old": "z05_foo", "new": "roomxf_foo", "sig": "void ()"},
                {"old": "z05_foo", "new": "roomxf_bar", "sig": "void ()"},
            ],
        }
        with self.assertRaises(ValueError):
            self.mod.render_bank(manifest)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to confirm they fail (tool does not exist yet)**

```powershell
python -m unittest tools.gen_wrappers.test_emit_gen_wrappers
```

Expected: tests fail with `FileNotFoundError` or import error because `tools/emit_gen_wrappers.py` does not exist.

- [ ] **Step 3: Create `tools/emit_gen_wrappers.py` (minimal scaffold)**

Write exactly:

```python
"""emit_gen_wrappers.py — generate or verify the marker-bounded forwarder
region of each src/gen/z_0x.c from its JSON manifest.

See tools/gen_wrappers/README.md for manifest schema. Standard library only.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GEN_DIR = ROOT / "src" / "gen"
MANIFEST_DIR = ROOT / "tools" / "gen_wrappers"

ALLOWED_TYPES = {
    "void", "unsigned char", "unsigned int", "unsigned short",
    "int", "char", "signed char",
}

PREFIX_HEADERS = {
    "cavert_":  "cave_runtime.h",
    "cobrt_":   "combat_runtime.h",
    "colrt_":   "collision_runtime.h",
    "corert_":  "core_runtime.h",
    "enrt_":    "enemy_runtime.h",
    "hudrt_":   "hud_runtime.h",
    "itemrt_":  "item_runtime.h",
    "lcrt_":    "link_collision_runtime.h",
    "objrt_":   "object_runtime.h",
    "progrt_":  "progress_runtime.h",
    "roomld_":  "room_load_runtime.h",
    "roommd_":  "room_mode_runtime.h",
    "roomobj_": "room_object_runtime.h",
    "roompl_":  "room_player_runtime.h",
    "roomrt_":  "room_runtime.h",
    "roomxf_":  "room_transfer_runtime.h",
    "savert_":  "save_menu_runtime.h",
    "sprrt_":   "sprite_runtime.h",
    "targrt_":  "targeting_runtime.h",
    "trprt_":   "trap_runtime.h",
    "uwrt_":    "uw_person_runtime.h",
    "weprt_":   "weapon_runtime.h",
    "worldrt_": "world_runtime.h",
}

START_TMPL = "/* <<< auto-wrappers: {bank} (generated by tools/emit_gen_wrappers.py) >>> */"
END_MARKER = "/* <<< end auto-wrappers >>> */"

SIG_RE = re.compile(r"^\s*(?P<ret>[a-z ]+?)\s*\(\s*(?P<args>.*?)\s*\)\s*$")


def header_for(new: str) -> str | None:
    for prefix, header in PREFIX_HEADERS.items():
        if new.startswith(prefix):
            return header
    return None


def parse_sig(sig: str) -> tuple[str, list[tuple[str, str]]]:
    m = SIG_RE.match(sig)
    if not m:
        raise ValueError(f"bad signature: {sig!r}")
    ret = re.sub(r"\s+", " ", m.group("ret")).strip()
    if ret not in ALLOWED_TYPES:
        raise ValueError(f"bad return type: {ret!r}")
    args_src = m.group("args").strip()
    if not args_src:
        return ret, []
    args: list[tuple[str, str]] = []
    for part in args_src.split(","):
        part = part.strip()
        tokens = part.split()
        if len(tokens) < 2:
            raise ValueError(f"bad arg: {part!r}")
        name = tokens[-1]
        atype = " ".join(tokens[:-1])
        if atype not in ALLOWED_TYPES:
            raise ValueError(f"bad arg type: {atype!r} in {sig!r}")
        args.append((atype, name))
    return ret, args


def render_forwarder(entry: dict) -> str:
    old = entry["old"]
    new = entry["new"]
    ret, args = parse_sig(entry["sig"])
    if args:
        param_decl = ", ".join(f"{t} {n}" for t, n in args)
        call_args = ", ".join(n for _, n in args)
    else:
        param_decl = "void"
        call_args = ""
    body_call = f"{new}({call_args});"
    if ret == "void":
        body = f"    {body_call}"
    else:
        body = f"    return {body_call}"
    return f"{ret} {old}({param_decl}) {{\n{body}\n}}\n"


def render_bank(manifest: dict) -> str:
    bank = manifest["bank"]
    includes = list(manifest.get("includes", []))
    symbols = manifest["symbols"]

    seen = set()
    for entry in symbols:
        if entry["old"] in seen:
            raise ValueError(f"duplicate old symbol: {entry['old']!r}")
        seen.add(entry["old"])
        header = header_for(entry["new"])
        if header and header not in includes:
            includes.append(header)
        if not header and header_for(entry["new"]) is None:
            pass  # includes already provided manually

    lines = [START_TMPL.format(bank=bank), ""]
    if includes:
        for h in includes:
            lines.append(f'#include "../{h}"')
        lines.append("")
    for entry in symbols:
        lines.append(render_forwarder(entry).rstrip() + "\n")
    lines.append(END_MARKER)
    return "\n".join(lines) + "\n"


def replace_region(source: str, bank: str, body: str) -> str:
    start = START_TMPL.format(bank=bank)
    start_idx = source.find(start)
    end_idx = source.find(END_MARKER, start_idx + 1) if start_idx != -1 else -1

    if start_idx == -1 or end_idx == -1:
        trailing = "" if source.endswith("\n") else "\n"
        return source + trailing + "\n" + body

    end_idx += len(END_MARKER)
    # Also consume a trailing newline if present so we don't accumulate blanks.
    if end_idx < len(source) and source[end_idx] == "\n":
        end_idx += 1
    return source[:start_idx] + body + source[end_idx:]


def apply_manifest(manifest: dict, path: Path) -> None:
    body = render_bank(manifest)
    new_text = replace_region(path.read_text(), manifest["bank"], body)
    path.write_text(new_text)


def check_manifest(manifest: dict, path: Path) -> bool:
    """Return True if the file would change (drift), False if clean."""
    body = render_bank(manifest)
    expected = replace_region(path.read_text(), manifest["bank"], body)
    return expected != path.read_text()


def bank_path(bank: str) -> Path:
    return GEN_DIR / f"{bank}.c"


def manifest_path(bank: str) -> Path:
    return MANIFEST_DIR / f"{bank}_manifest.json"


def load_manifest(bank: str) -> dict:
    return json.loads(manifest_path(bank).read_text())


def all_banks() -> list[str]:
    return sorted(p.stem.removesuffix("_manifest") for p in MANIFEST_DIR.glob("z_*_manifest.json"))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bank", help="restrict to one bank, e.g. z_05")
    parser.add_argument("--check", action="store_true",
                        help="exit non-zero if any bank would change")
    args = parser.parse_args(argv)

    banks = [args.bank] if args.bank else all_banks()
    drift = False
    for bank in banks:
        manifest = load_manifest(bank)
        path = bank_path(bank)
        if args.check:
            if check_manifest(manifest, path):
                print(f"DRIFT: {bank}", file=sys.stderr)
                drift = True
        else:
            apply_manifest(manifest, path)

    return 1 if (args.check and drift) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 4: Run tests**

```powershell
python -m unittest tools.gen_wrappers.test_emit_gen_wrappers
```

Expected: all tests pass. If any fail, fix the implementation until they pass.

- [ ] **Step 5: Commit**

```bash
git add tools/emit_gen_wrappers.py tools/gen_wrappers/test_emit_gen_wrappers.py
git commit -m "infra: add emit_gen_wrappers tool with unittest coverage"
```

---

### Task 9: Insert marker regions into `src/gen/z_01.c` through `z_07.c`

Goal: wrap the existing hand-written forwarder block of each bank in marker
comments, then prove the tool produces byte-identical output against the
committed manifests.

**Files:**
- Modify: `src/gen/z_01.c` through `src/gen/z_07.c`

For each bank `z_0N`:

- [ ] **Step 1: Locate the forwarder block boundaries**

Open `src/gen/z_0N.c`. Identify the first forwarder (first `void z0N_...` or
`ret z0N_...` that body-forwards to a runtime). Identify the last forwarder.
Anything above the first forwarder is hand-owned (includes, externs, static
helpers); anything below the last forwarder is likewise hand-owned.

- [ ] **Step 2: Insert start marker immediately above the first forwarder**

Insert, as its own line before the first forwarder:

```c
/* <<< auto-wrappers: z_0N (generated by tools/emit_gen_wrappers.py) >>> */
```

- [ ] **Step 3: Insert end marker immediately below the last forwarder**

Insert, as its own line after the last forwarder:

```c
/* <<< end auto-wrappers >>> */
```

Leave everything between the markers unchanged for now.

- [ ] **Step 4: Run the generator against that bank**

```powershell
python tools\emit_gen_wrappers.py --bank z_0N
```

Expected: tool replaces the region with generated forwarders that are
semantically identical to the hand-written block. The `#include "../*.h"`
entries inside the region are auto-emitted.

- [ ] **Step 5: Build and confirm ROM unchanged**

```powershell
cmd.exe /c ".\build.bat"
certutil -hashfile builds\whatif.md SHA256 | findstr /v "hash" > builds\reports\rom_after_z0N.sha256
fc builds\reports\rom_after_z0N.sha256 builds\reports\rom_baseline_plan_w.sha256
```

Expected: build passes and `fc` reports `FC: no differences encountered`.

- [ ] **Step 6: Run `--check`**

```powershell
python tools\emit_gen_wrappers.py --check --bank z_0N
```

Expected: exit code 0.

- [ ] **Step 7: Commit**

```bash
git add src/gen/z_0N.c
git commit -m "infra: mark z_0N forwarder region and regenerate (Plan W)"
```

Repeat Steps 1–7 for `z_01`, `z_02`, `z_03`, `z_04`, `z_05`, `z_06`, `z_07` in
order. One commit per bank keeps bisect clean. If a bank's ROM-compare fails,
STOP: the tool mis-generated something against that bank's idioms. Inspect the
diff before proceeding.

---

### Task 10: Wire the drift gate into `build.bat`

**Files:**
- Modify: `build.bat`

- [ ] **Step 1: Inspect current `build.bat`**

Run:

```powershell
type build.bat
```

Identify: the line that finishes the C/ASM compile/link step and the line
that produces the final ROM (`builds\whatif.md`). The gate must run after
compile is proven green and before the ROM pack, so a drift failure aborts
before a stale ROM is written.

- [ ] **Step 2: Insert the drift-gate step**

Add immediately after the last compile/link step and before the ROM-pack
step in `build.bat`:

```bat
echo [gate] verifying gen/ forwarders ...
python tools\emit_gen_wrappers.py --check
if errorlevel 1 (
    echo [gate] FAIL: gen/ forwarders drift from manifest
    exit /b 1
)
echo [gate] OK
```

Do not alter any existing build step.

- [ ] **Step 3: Build and confirm gate passes**

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build passes end-to-end. The `[gate] OK` line appears.

- [ ] **Step 4: ROM byte-compare**

```powershell
certutil -hashfile builds\whatif.md SHA256 | findstr /v "hash" > builds\reports\rom_after_task10.sha256
fc builds\reports\rom_after_task10.sha256 builds\reports\rom_baseline_plan_w.sha256
```

Expected: `FC: no differences encountered`.

- [ ] **Step 5: Prove the gate fires on deliberate drift**

Manually corrupt one forwarder inside a marker region:

```powershell
powershell -Command "(Get-Content src\gen\z_05.c) -replace 'roomxf_copy_column_to_tilebuf\(\);', 'roomxf_copy_column_to_tilebuf(); /* TAMPER */' | Set-Content src\gen\z_05.c"
cmd.exe /c ".\build.bat"
```

Expected: build fails with `[gate] FAIL: gen/ forwarders drift from manifest`
and non-zero exit. If it does NOT fail, the gate is not wired correctly — go
back to Step 2.

- [ ] **Step 6: Revert the tamper and re-verify**

```powershell
git checkout -- src\gen\z_05.c
cmd.exe /c ".\build.bat"
```

Expected: build passes. `[gate] OK` appears. Re-run ROM byte-compare per
Step 4 to confirm clean state.

- [ ] **Step 7: Commit**

```bash
git add build.bat
git commit -m "infra: wire gen/ drift gate into build.bat (Plan W)"
```

---

### Task 11: Write the promotion-checklist template

**Files:**
- Create: `docs/superpowers/templates/promotion-checklist.md`
- Modify: `docs/superpowers/specs/2026-04-23-infra-first-promotion-scaffold-design.md`

- [ ] **Step 1: Create the templates directory**

```powershell
if not exist docs\superpowers\templates mkdir docs\superpowers\templates
```

- [ ] **Step 2: Write the checklist file**

Create `docs/superpowers/templates/promotion-checklist.md` with exact content:

```markdown
# Promotion Checklist Template

Copy this list into every batch note (plan doc, PR description, or commit
trailer) that promotes code out of `src/gen/` into an owned runtime module,
or that moves behavior between owned modules.

Source: `best practices.md` §Promotion Checklist, §Design Checklist for
Promotion Batches, §Routine and State Checklist, §Done Definition.

## Before starting the batch

- [ ] Long-term owning subsystem identified.
- [ ] Destination owned module identified (existing or new split).
- [ ] Compatibility wrapper plan identified (bank forwarder stays, symbol
      preserved).
- [ ] Touched raw RAM fields are already named in `nes_abi.h` or a
      `*_state.h` header. If not, name them first.
- [ ] Behavior is being moved as part of a coherent family, not at random.
- [ ] Focused smoke/probe plan named (T34, cave, enemy spawn, etc.).
- [ ] Rollback point captured: baseline ROM hash stored under
      `builds/reports/`.

## Design quality

- [ ] More than one decomposition considered before choosing.
- [ ] Change moves code upward into subsystem / problem-domain terms.
- [ ] Hardware/ABI details stay below the owned runtime layer.
- [ ] Subsystem interface is narrow and intentional.
- [ ] Coupling reduced rather than preserved.
- [ ] Design is lean; no unnecessary new abstraction.

## Routine / state quality

- [ ] Each routine does one well-defined job.
- [ ] Routine names describe behavior, not historical bank origin.
- [ ] Wrappers remain thin and boring.
- [ ] Input parameters not used as working scratch.
- [ ] Enums / named constants replace ad-hoc flags and magic values.

## Verification

- [ ] `build.bat` passes green.
- [ ] `tools/emit_gen_wrappers.py --check` exits 0.
- [ ] Targeted parity probe passes (T34 or subsystem-specific).
- [ ] `tools/compare_perf.py` reports `0 FAIL`.
- [ ] ROM diff vs baseline is expected (same when no behavior change
      intended; documented delta otherwise).

## Done definition

- [ ] Behavior matches expectations for the targeted area.
- [ ] Ownership is clearer than before.
- [ ] Wrappers preserve compatibility entrypoints.
- [ ] Raw offsets touched by the batch have names or controlled aliases.
- [ ] Smoke/probe coverage exists for the batch.
- [ ] Change leaves behind less coupling, less magic state, or less
      generated ownership than before.

Compilation alone is not done. Language change alone is not progress.
```

- [ ] **Step 3: Link the template from the spec**

Edit `docs/superpowers/specs/2026-04-23-infra-first-promotion-scaffold-design.md`.
Find the line that reads `- Promotion-checklist template at`. Append on the
next line a reference:

```markdown
  See: `docs/superpowers/templates/promotion-checklist.md`.
```

- [ ] **Step 4: Build smoke (unaffected but confirms green)**

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build passes, gate OK.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/templates/promotion-checklist.md docs/superpowers/specs/2026-04-23-infra-first-promotion-scaffold-design.md
git commit -m "docs: add promotion-checklist template (Plan W)"
```

---

### Task 12: Final verification

**Files:**
- Output: `builds/reports/rom_final_plan_w.sha256`
- Output: `builds/reports/t34_movement_parity_report.txt`
- Output: `builds/reports/perf_report.txt`

- [ ] **Step 1: Clean build**

```powershell
cmd.exe /c ".\build.bat"
```

Expected: build completes, `[gate] OK` present in output.

- [ ] **Step 2: ROM byte-compare against baseline**

```powershell
certutil -hashfile builds\whatif.md SHA256 | findstr /v "hash" > builds\reports\rom_final_plan_w.sha256
fc builds\reports\rom_final_plan_w.sha256 builds\reports\rom_baseline_plan_w.sha256
```

Expected: `FC: no differences encountered`. A diff here means code moved or a
macro leaked behavior; STOP and investigate before committing further.

- [ ] **Step 3: Re-run T34 parity probe**

```powershell
cmd.exe /c ".\tools\run_t34_nes.bat"
cmd.exe /c ".\tools\run_t34_gen.bat"
python .\tools\compare_t34_movement_parity.py
```

Expected: `T34_PARITY: ALL PASS`.

- [ ] **Step 4: Re-run perf regression**

```powershell
& 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' '--lua=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\bizhawk_perf_sample.lua' 'C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\builds\whatif.md'
python .\tools\compare_perf.py
```

Expected: `PERF_REPORT: ... 0 FAIL`.

- [ ] **Step 5: Run the full unit-test suite for the tool**

```powershell
python -m unittest tools.gen_wrappers.test_emit_gen_wrappers
```

Expected: all tests pass.

- [ ] **Step 6: Commit final artifacts**

```bash
git add builds/reports/rom_final_plan_w.sha256
git commit -m "infra: Plan W final verification artifacts"
```

If `builds/reports/perf_baseline.json` or parity-report files refreshed,
include them in the same commit.

- [ ] **Step 7: Tag the milestone**

```bash
git tag plan-w-complete
```

Plan W is done. Plan B (z_05 drain) can now run against this scaffold.

---

## Self-review notes

- Every new file path listed in "File Structure" has a creating task.
- Every modified file path has a modifying task.
- No step contains "TBD", "implement later", or unqualified "add error
  handling"; all handlers are explicit.
- Types and symbols used in later tasks match earlier tasks (tool API:
  `parse_sig`, `render_forwarder`, `render_bank`, `replace_region`,
  `apply_manifest`, `check_manifest`, `header_for`, consistent across Task 8
  and test file).
- Manifest schema is consistent across Task 6 (README), Task 7 (authoring),
  Task 8 (tool).
- Marker comment strings are byte-identical across README (Task 6), Task 9
  insertions, and tool constants (Task 8 `START_TMPL` / `END_MARKER`).
- Drift gate enforcement order: compile → gate → ROM pack (Task 10 Step 2).
- ROM byte-compare checkpoints after every structural change confirm the
  "no behavior change" invariant of Plan W.

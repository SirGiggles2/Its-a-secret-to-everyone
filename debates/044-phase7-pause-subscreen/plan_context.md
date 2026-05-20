# Visual Regression Sweep + Fix Pass — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. Discipline adapted: byte-diff via probe replaces unit test in red-green-refactor — probe captures are the test artifacts.

**Goal:** Find and fix all visual graphical regressions on `builds/Debug.md` across scenes left UNVERIFIED by the 34-commit cleanup pass (5ffa9d28..063259d9), using byte-diff against the reference NES ROM as the ground truth.

**Architecture:** Single bundled "scene-walk" Lua probe drives BizHawk through every unverified scene, dumping CRAM + plane A + SAT + VRAM tile + OAM + PALRAM + nametable per scene. Same probe shape runs against the reference NES Z1 ROM. Hex-diff classifies each break into 6 known classes (A-F). Fixes apply at labeled catalog sites (bg_sparse_tile_lut / sprite_slots.h / items_chr_x4.h / SCENE_CONTRACTS / subpal_routing / render_cram_subrange_upload). Catalog drives one commit per fix with byte-diff in commit message.

**Tech Stack:** SGDK m68k + drained C runtime, BizHawk Lua (one-big-probe), Python probe tooling, vasm Motorola syntax. ROM target = `builds/Debug.md` via `Debug.bat`.

**Hard rules** (enforced — see CLAUDE.md):
- RULE ZERO: probe NES + probe Genesis + byte-diff BEFORE writing any code
- WT-5: NEVER add files under `RoomRom/src/`, `RoomRom/data/`, `RoomRom/tools/`. Existing files may be edited only when absolutely required, with justification in commit message
- BT-1: sole build target = `Debug.bat` -> `builds/Debug.md`
- New probes -> `build/probes/` (preferred) or `tools/probes/`
- New docs -> `docs/atlas/` or `docs/`
- New gameplay code -> `src/game/<subsystem>/`
- BizHawk launch via `/bizhawkScript` skill (never raw `--lua=`)
- `$env:CODEX_BIZHAWK_ROOT` set before launch (memory `feedback_bizhawk_lua_env`)
- ONE probe per BizHawk launch — bundle all state dumps in single Lua (memory `feedback_one_big_probe`)
- Commit working state before each next task (memory `feedback_commit_first`)
- Worktree check before build (memory `feedback_check_worktree_first`)

**Do not touch:**
- Story scroll crash (pre-existing per memory `project_title_story_crash`) — skip scene, document in scene_breaks.md as BLOCKED
- G-v2 plane reloc (deferred — 618 tile headroom)
- Refactor for cleanliness — only fix visual breaks

---

## File Structure — what gets created vs modified

**Created:**
- `build/probes/scene_walk_full.lua` — bundled multi-scene probe (Genesis side)
- `build/probes/scene_walk_nes_reference.lua` — same probe shape, NES reference ROM
- `tools/probes/scene_walk_diff.py` — byte-diff classifier, emits scene_breaks.md ticket fragments
- `docs/atlas/scene_breaks.md` — per-scene break ticket tracker (sole authoritative break log)
- `build/captures/scene_walk_gen/` — Genesis capture artifacts (one subdir per scene)
- `build/captures/scene_walk_nes/` — NES capture artifacts (one subdir per scene)

**Modified per fix (data-driven; only edit when ticket points here):**
- `tools/probes/audit_per_tile_subpal.py` — Class A: add force-include + regen sparse LUT
- `RoomRom/src/bg_sparse_chr.c` (regenerated) — Class A: LUT slot fix
- `RoomRom/data/item_chr_manifest.json` — Class B: provenance update (existing file, edit-in-place justified per WT-5)
- `src/game/world/render/sprite_render.c` lines 611-684 — Class C: add dispatch case
- `RoomRom/tools/gen_atlas.py` SCENE_CONTRACTS — Class D: tile_count fix
- `RoomRom/src/atlas/roomrom_scene_vram_contracts.c` (regenerated)
- `src/sgdk_adapter/render_adapter.c` `render_cram_subrange_upload` callsites — Class E/F: transient CRAM swap

---

## Task 0: Pre-flight (worktree check + baseline commit)

**Why:** Per CLAUDE.md, commit working state before next task; verify single-worktree assumption; freeze baseline so per-fix commits are clean atomic units.

**Files:** none modified — git operations only.

- [ ] **Step 0.1: Confirm worktree topology**

Run:
```powershell
git worktree list
```
Expected: only main worktree present (or document any parallel worktrees and rebase before proceeding).

- [ ] **Step 0.2: Check git status — note untracked probes**

Run:
```powershell
git status --short
```
Expected: ~40 untracked `build/probes/*.lua` from prior sessions (per gitstatus header) plus DMC sample artifacts. None are blockers — these are session detritus.

- [ ] **Step 0.3: Confirm Debug.md baseline builds clean**

Run:
```powershell
.\Debug.bat
```
Expected: emits `builds/Debug.md` with no errors. If build fails, STOP — fix build before regression sweep.

- [ ] **Step 0.4: Locate reference NES ROM**

Run:
```powershell
python tools/probes/locate_reference_rom.py
```
Expected: prints absolute path to NES Zelda 1 ROM and SHA256 confirming USA rev 1. If missing, STOP — sweep needs NES reference for byte-diff.

- [ ] **Step 0.5: Commit untracked-but-keep probes (optional cleanup)**

This is judgment-call. The 40 untracked probes are prior-session artifacts. Per CLAUDE.md "commit first" — but only commit probes you intend to keep. Leave intact if unsure; sweep does not modify them.

---

## Task 1: Build scene-walk probe (Genesis side)

**Why:** Need ONE Lua probe (per memory `feedback_one_big_probe`) that drives BizHawk through all unverified scenes and dumps the full state shape per scene. Re-launching BizHawk per scene is forbidden.

**Files:**
- Create: `build/probes/scene_walk_full.lua`
- Test: probe runs to completion, writes per-scene logs to `build/captures/scene_walk_gen/`

- [ ] **Step 1.1: Read existing boot-skip pattern**

Read `build/probes/skip_to_gameplay.lua` (77 lines). Note the ABC+Start chord at title and the joypad button-name fallback (`P1 A` / `P1 Start` / etc — BizHawk Genesis has multiple naming styles).

- [ ] **Step 1.2: Read existing capture helpers**

Read `build/probes/baseline_full_state.lua` (if exists in untracked list) or any `*_full_state*.lua` — these likely already define the CRAM/plane/SAT/VRAM dump shape we want. Reuse, do not rewrite. If none exist, define a `capture_state(label)` helper inline that writes 6 files per call:
  - `{label}.png` — screenshot via `client.screenshot()`
  - `{label}_cram.bin` — VDP CRAM ($C00000 read sequence)
  - `{label}_plane_a.bin` — plane A nametable (VRAM read from plane A base)
  - `{label}_sat.bin` — sprite attribute table (VRAM read from SAT base, 640 bytes)
  - `{label}_vram_tile.bin` — VRAM tile data ($0000-$80FF gives all banks; trim by scene to keep size sane)
  - `{label}_regs.txt` — vdp regs ($00-$1F) + relevant 68K RAM ($FF0000-$FF1FFF excerpt)

- [ ] **Step 1.3: Define scene-walk sequence**

Scene list (in order — designed so each scene transition is reachable from the prior via scripted joypad bursts):

| seq | label | how to reach | unverified reason |
|---|---|---|---|
| 1 | `title_post_boot` | wait 240 frames after reset | baseline (already verified — sanity check) |
| 2 | `fileselect_cursor` | Start at title, wait 90 frames | UNVERIFIED |
| 3 | `fileselect_register_name` | A at fileselect, type "Z" (Right + A), Start, wait | UNVERIFIED |
| 4 | `gameplay_ow_spawn` | A at "Save name" entry, wait 240 | baseline check |
| 5 | `gameplay_ow_walk_4dirs` | hold Right 60, Down 60, Left 60, Up 60 | UNVERIFIED scroll-stage transitions |
| 6 | `cave_entry_first` | navigate to known cave-bearing room (use `RoomRom/data/uw_manifest.json` for coords), Down to enter | UNVERIFIED cave palette overlay |
| 7 | `cave_shop_interior` | inside cave that contains shop (find via uw_manifest); wait for text | UNVERIFIED |
| 8 | `cave_fairy_pond` | navigate to fairy-pond cave | UNVERIFIED |
| 9 | `uw1_entry` | exit cave, walk to L1 entrance, enter | baseline check |
| 10 | `uw1_first_combat` | inside L1, enter room with enemies, wait 120 | UNVERIFIED sub-pal 3 sprites |
| 11 | `uw1_boss_room` | navigate to L1 boss room (Aquamentus) | UNVERIFIED boss SCENE_OBJ bank |
| 12 | `inventory_open` | press Start mid-gameplay | UNVERIFIED full inventory (B-item, magic meter, key/bomb count) |
| 13 | `inventory_select_b_item` | within inventory, cycle B-item slot | UNVERIFIED |
| 14 | `inventory_close` | Start again | UNVERIFIED close-side render |
| 15 | `link_death` | take 4 hits in a row (script enemy contact) OR pause+poke `$FF0098=0` | UNVERIFIED death sequence + game-over |
| 16 | `game_over_screen` | wait for death animation | UNVERIFIED |

Optional / skip-with-note:
- `story_scroll` — BLOCKED per memory `project_title_story_crash`. Skip; mark BLOCKED in scene_breaks.md.
- `boss_per_level` — L2-L9 bosses each have own SCENE_OBJ. Defer to follow-up sweep; capture L1 boss only in this pass.
- `redux_variant` — Z1 Redux toggle (separate ROM mode). Defer.

- [ ] **Step 1.4: Write joypad helper**

Inline helper:
```lua
local function press_for(button, frames)
  for i = 1, frames do
    joypad.set({[button] = true}, 1)
    emu.frameadvance()
  end
  -- release frame to avoid sticky-button artifacts
  joypad.set({[button] = false}, 1)
  emu.frameadvance()
end

local function wait_frames(n)
  for i = 1, n do emu.frameadvance() end
end
```

- [ ] **Step 1.5: Implement scene transitions**

For each entry in Step 1.3 table, sequence the joypad calls then `capture_state(label)`. Wait long enough after each transition for any scroll-stage / palette fade to complete (60-120 frames typical).

- [ ] **Step 1.6: Test probe end-to-end (Genesis)**

Run via `/bizhawkScript` skill:
- Set `$env:CODEX_BIZHAWK_ROOT` to `C:\tmp\bizhawk_root` (or wherever skill expects) BEFORE launch
- Copy `builds/Debug.md` to the BizHawk-relative location the skill uses
- Invoke `/bizhawkScript build/probes/scene_walk_full.lua`

Expected: BizHawk runs to completion in headless or visible mode; `build/captures/scene_walk_gen/` contains 16 subdirs (one per scene) each with 6 files. PNG screenshots show the labeled scene at correct frame.

If any scene's transition fails (button names wrong, navigation lands wrong room, scene never reaches expected state): debug the transition before proceeding. Do not capture noise.

- [ ] **Step 1.7: Commit**

```powershell
git add build/probes/scene_walk_full.lua
git commit -m "probe: scene_walk_full — bundled 16-scene capture for visual regression sweep"
```

---

## Task 2: Adapt probe for NES reference ROM

**Why:** RULE ZERO — Genesis state alone proves nothing. Need byte-identical capture shape against NES Z1 to compute diff. NES VRAM/OAM/PALRAM differ in mechanics from Genesis VDP, so probe shape changes but per-scene semantics stay aligned.

**Files:**
- Create: `build/probes/scene_walk_nes_reference.lua`

- [ ] **Step 2.1: Read existing NES-side probes**

Find via:
```powershell
ls build/probes/nes_*.lua
```
Pick the most recent comprehensive NES-side state dumper. Mirror its capture shape (PPU OAM 256 B, PALRAM 32 B, nametables $2000-$2FFF, CHR $0000-$1FFF via PPU read).

- [ ] **Step 2.2: Mirror scene-walk sequence — NES side**

Same 16 scenes from Task 1 Step 1.3. NES Z1 button mapping is simpler (no SGDK middleware) — direct `Up`/`Down`/`Left`/`Right`/`A`/`B`/`Start`/`Select`. Cave/dungeon/inventory navigation differs slightly (NES has Select-cycle for B-item; Genesis port may differ — capture both honestly).

- [ ] **Step 2.3: Write capture helper for NES PPU state**

```lua
local function capture_nes(label)
  local dir = "build/captures/scene_walk_nes/" .. label .. "/"
  os.execute("mkdir " .. dir:gsub("/","\\"))
  client.screenshot(dir .. label .. ".png")
  -- OAM
  local oam = {}
  for i = 0, 255 do oam[#oam+1] = string.char(memory.readbyte(i, "OAM")) end
  io.open(dir..label.."_oam.bin","wb"):write(table.concat(oam)):close()
  -- PALRAM
  local pal = {}
  for i = 0, 31 do pal[#pal+1] = string.char(memory.readbyte(i, "PALRAM")) end
  io.open(dir..label.."_palram.bin","wb"):write(table.concat(pal)):close()
  -- Nametables
  local nt = {}
  for i = 0, 0xFFF do nt[#nt+1] = string.char(memory.readbyte(0x2000 + i, "PPU Bus")) end
  io.open(dir..label.."_nt.bin","wb"):write(table.concat(nt)):close()
  -- CHR
  local chr = {}
  for i = 0, 0x1FFF do chr[#chr+1] = string.char(memory.readbyte(i, "PPU Bus")) end
  io.open(dir..label.."_chr.bin","wb"):write(table.concat(chr)):close()
  -- 2KB RAM (relevant Z1 state lives in $0000-$07FF)
  local ram = {}
  for i = 0, 0x7FF do ram[#ram+1] = string.char(memory.readbyte(i, "RAM")) end
  io.open(dir..label.."_ram.bin","wb"):write(table.concat(ram)):close()
end
```

- [ ] **Step 2.4: Test probe end-to-end (NES)**

Locate reference NES Z1 ROM via Step 0.4 path. Launch via skill against the NES ROM (NES domain BizHawk core). Expected: `build/captures/scene_walk_nes/` populated with 16 subdirs.

- [ ] **Step 2.5: Commit**

```powershell
git add build/probes/scene_walk_nes_reference.lua
git commit -m "probe: scene_walk_nes_reference — NES Z1 baseline for diff"
```

---

## Task 3: Byte-diff classifier + scene_breaks.md emitter

**Why:** Manual diff across 16 scenes * 6 capture files is 96 file pairs. Needs scripted classification per the 6 known break classes (A-F). Output = `docs/atlas/scene_breaks.md` with per-scene tickets.

**Files:**
- Create: `tools/probes/scene_walk_diff.py`
- Create: `docs/atlas/scene_breaks.md`

- [ ] **Step 3.1: Stub the classifier**

```python
"""scene_walk_diff.py — per-scene NES vs Genesis byte-diff with class A-F tagging.

Maps NES PPU concepts to Genesis VDP concepts per scene, computes diffs,
and emits a markdown ticket fragment per break.

Reads:
  build/captures/scene_walk_nes/<label>/   — NES side (OAM, PALRAM, NT, CHR, RAM)
  build/captures/scene_walk_gen/<label>/   — Genesis side (CRAM, plane A, SAT, VRAM tile, regs)

Writes:
  docs/atlas/scene_breaks.md               — markdown ticket per break
"""
import pathlib, json, sys

SCENE_LABELS = [
    "title_post_boot", "fileselect_cursor", "fileselect_register_name",
    "gameplay_ow_spawn", "gameplay_ow_walk_4dirs",
    "cave_entry_first", "cave_shop_interior", "cave_fairy_pond",
    "uw1_entry", "uw1_first_combat", "uw1_boss_room",
    "inventory_open", "inventory_select_b_item", "inventory_close",
    "link_death", "game_over_screen",
]

CLASSES = {
    "A": "sparse LUT miss — bg combo not in audit, sentinel 0xFFFF -> blank tile",
    "B": "extracted CHR from wrong NES bank — manifest stored wrong bank's bytes",
    "C": "item dispatch placeholder — item_id not in switch, falls to boomerang glyph",
    "D": "stale SCENE_OBJ contract — tile_count drifted from atlas reality",
    "E": "sub-pal 3 sprite clamped to sub-pal 2 — needs transient CRAM swap or document divergence",
    "F": "CRAM conflict — scene needs BG sub-pal X + SPR sub-pal Y at same CRAM slot (4-PAL collapse)",
}

def diff_palettes(nes_palram, gen_cram):
    """Map NES PALRAM (32 B) to Genesis CRAM (128 B, 4 PALs x 16 entries x 2 B).
    Z1 uses 4 BG sub-pals (PALRAM[0..15]) and 4 SPR sub-pals (PALRAM[16..31]).
    Genesis port collapses to 4 PALs total per Phase B/F.
    Return list of (slot, nes_rgb, gen_rgb, class_tag) tuples for mismatches.
    """
    ...

def diff_sat_vs_oam(nes_oam, gen_sat, gen_vram_tile):
    """Per-sprite check: NES OAM tile_id -> Genesis SAT tile_id via item dispatch.
    If NES item_id has no Genesis dispatch case, classify C.
    If tile in VRAM differs from extracted manifest sha256, classify B.
    """
    ...

def diff_bg(nes_nt, nes_chr, gen_plane_a, gen_vram_tile):
    """For each NES BG tile in nametable, look up the sparse LUT slot for
    (nes_tile_id, sub_pal). If slot == 0xFFFF -> classify A.
    If slot tile bytes differ from NES CHR -> classify D (atlas drift).
    """
    ...

def emit_ticket(scene_label, breaks):
    """Write one markdown section per scene to docs/atlas/scene_breaks.md."""
    ...

if __name__ == "__main__":
    out = pathlib.Path("docs/atlas/scene_breaks.md")
    tickets = []
    for label in SCENE_LABELS:
        nes_dir = pathlib.Path("build/captures/scene_walk_nes") / label
        gen_dir = pathlib.Path("build/captures/scene_walk_gen") / label
        if not nes_dir.exists() or not gen_dir.exists():
            tickets.append((label, [{"class": "MISSING_CAPTURE", "detail": "probe did not produce capture"}]))
            continue
        breaks = []
        breaks += diff_palettes(...)
        breaks += diff_sat_vs_oam(...)
        breaks += diff_bg(...)
        tickets.append((label, breaks))
    # write markdown
    ...
```

- [ ] **Step 3.2: Implement diff_palettes**

Map NES PALRAM bytes (NES master palette 64-color indices) to Genesis CRAM (9-bit RGB per entry). Use the NES master palette as conversion table (file likely already exists at `tools/probes/nes_master_palette.py` or similar — search first, reuse).

Logic:
- NES BG sub-pal N (PALRAM[N*4..N*4+3]) ↔ Genesis BG PAL slot per `subpal_routing.h` mapping
- NES SPR sub-pal N (PALRAM[16+N*4..16+N*4+3]) ↔ Genesis SPR PAL slot
- If sub-pal 3 SPR is in use on NES side but Genesis PAL slot shows sub-pal 2 colors -> class E
- If two sub-pals collide in Genesis (post-collapse) but NES has them distinct -> class F

- [ ] **Step 3.3: Implement diff_sat_vs_oam**

For each NES OAM sprite (64 sprites * 4 bytes):
1. Decode item_id by reverse-lookup of tile_id range
2. Check `sprite_render.c:611-684` dispatch — does this item_id have a case?
3. If no case AND Genesis SAT shows boomerang tile (820) at the same OAM slot -> class C
4. If case exists, fetch the Genesis tile_id from SAT, hash the bytes from gen_vram_tile, compare to manifest sha256 -> class B if mismatch

- [ ] **Step 3.4: Implement diff_bg**

For each BG tile in NES nametable, attribute table gives the sub-pal. Look up `bg_sparse_tile_lut[nes_tile][sub_pal]`:
- 0xFFFF -> class A (sentinel, never extracted)
- Valid slot -> compare bytes against NES CHR for that tile_id (post-bank-swap; consult `feedback_nes_chr_bank_swap` — UW/boss tiles need PRG dat lookup, not OW capture)
- Mismatch -> class D (or B if extraction provenance is wrong)

- [ ] **Step 3.5: Implement emit_ticket**

Per-scene markdown section. Format:

```markdown
## scene_label

**State at capture:** brief description
**Captures:** [gen](../build/captures/scene_walk_gen/{label}/), [nes](../build/captures/scene_walk_nes/{label}/)

### Break 1 — Class C — item dispatch missing
- NES OAM slot 7: tile $50 (heart container)
- Genesis SAT slot 7: tile 820 (boomerang fallback)
- Diff: item_id 0x14 in NES → no case in sprite_render.c switch → default sentinel → boomerang
- Fix site: src/game/world/render/sprite_render.c lines 611-684, add case 0x14
- Estimated cost: 30 min
- Priority: P0 (visual severity high, parity high — heart container is post-boss reward)

### Break 2 — Class A — sparse LUT miss
- NES BG tile $C2 sub_pal 2 → bg_sparse_tile_lut[0xC2][2] = 0xFFFF
- Genesis plane A: tile $0000 (blank) at row/col
- Fix site: tools/probes/audit_per_tile_subpal.py force-include list, regen
- Estimated cost: 30 min
- Priority: P1
```

- [ ] **Step 3.6: Run the classifier**

```powershell
python tools/probes/scene_walk_diff.py
```
Expected: `docs/atlas/scene_breaks.md` populated with 0-N tickets per scene. Per handoff estimate: 5-15 total breaks expected.

- [ ] **Step 3.7: Read scene_breaks.md end-to-end**

Validate ticket quality: each break has class tag, fix site, byte-diff evidence, priority. Reject any "looks wrong" tickets without byte-diff. Reject Class-D tickets that lack tile_count comparison.

If catalog quality is bad, fix classifier and re-run. Do NOT proceed to Task 5 with a noisy catalog.

- [ ] **Step 3.8: Commit**

```powershell
git add tools/probes/scene_walk_diff.py docs/atlas/scene_breaks.md
git add build/captures/scene_walk_gen/ build/captures/scene_walk_nes/
git commit -m "sweep: scene_breaks.md catalog from byte-diff of 16 unverified scenes"
```

Note: capture artifacts are large (PNGs + binaries). If `build/captures/` is .gitignored, skip those `git add` lines. Otherwise commit them — they're the evidence backing every fix.

---

## Task 4: Sort breaks by priority and define fix order

**Why:** Fix order = visual severity * NES-parity-importance. Some breaks are cosmetic (1-pixel mis-color); some are correctness-critical (wrong item dispatched). Plan does not pre-prioritize because catalog is data-driven.

**Files:** modifies `docs/atlas/scene_breaks.md` (add priority ordering preamble).

- [ ] **Step 4.1: Add priority preamble to scene_breaks.md**

Sort tickets into P0/P1/P2 buckets and write a "Fix order" section at the top:
- **P0** (must fix): incorrect item dispatched (Class C), boss not rendered (any class), Link/sword core gameplay tile wrong
- **P1** (should fix): wrong color on visible sprite, BG tile blank when should be art, sub-pal 3 clamp on a sprite the user can see
- **P2** (nice-to-have): cosmetic edge cases, single-pixel color drift, off-screen tiles wrong

- [ ] **Step 4.2: Commit ordering**

```powershell
git add docs/atlas/scene_breaks.md
git commit -m "sweep: priority order P0/P1/P2 across scene_breaks tickets"
```

---

## Task 5 (TEMPLATE — repeats per ticket): Fix one break

**Why:** Each break is fixed at its labeled site per class. This task is a template; the executor repeats it per ticket from scene_breaks.md in P0→P1→P2 order. One ticket = one commit. Class-specific recipes below.

**Files vary per class — see recipes.**

- [ ] **Step 5.1: Read the ticket from scene_breaks.md**

Identify class (A-F), scene, byte-diff, fix site. Do not start a fix without a ticket — RULE ZERO violation.

- [ ] **Step 5.2: Re-probe to confirm break is still present**

The cleanup pass landed 34 commits. Some breaks may already be repaired by a later commit. Re-run the single-scene probe before fixing:
```powershell
# trim scene_walk_full.lua to only the affected scene OR write a one-shot probe
# capture only the scene of interest
```
If break gone -> close ticket as "resolved upstream", commit catalog update.

- [ ] **Step 5.3: Apply fix per class recipe** (see Class Recipes below)

- [ ] **Step 5.4: Rebuild**

```powershell
.\Debug.bat
```
Expected: clean build, no warnings escalated to errors, ROM size delta sensible (sparse LUT add = +N bytes, dispatch case = ~50 bytes, etc).

- [ ] **Step 5.5: Re-probe the scene; verify fix**

Run trimmed scene-walk probe again. Byte-diff the affected pixels/tiles/sprites. Expected: diff = 0 against NES at the labeled location. If still mismatched, do NOT commit — diagnose with `/chuckle` skill before continuing.

- [ ] **Step 5.6: Commit with byte-diff in message**

```powershell
git add <fix files>
git commit -m "fix(<scene>): <one-line>

Class <X> — <break description>
Before: <NES bytes> vs <Genesis bytes>
After: <new Genesis bytes>
Probe: build/captures/scene_walk_gen/<label>/ (post-fix)
Fix site: <file:line>"
```

- [ ] **Step 5.7: Mark ticket closed in scene_breaks.md, commit catalog update separately or amend prior commit**

---

## Class Recipes

### Class A — sparse LUT miss

Fix site: `tools/probes/audit_per_tile_subpal.py` force-include list, then regen.

1. Add the missing `(nes_tile_id, sub_pal)` combo to the audit's force-include set
2. Run: `python tools/probes/audit_per_tile_subpal.py` (writes updated audit)
3. Run: `python RoomRom/tools/gen_atlas.py` (regenerates `bg_sparse_chr.c`)
4. Verify `bg_sparse_tile_lut[N][P]` now != 0xFFFF
5. Rebuild + re-probe per Task 5

Estimated cost: 30 min.

### Class B — wrong NES bank

Fix site: `RoomRom/data/item_chr_manifest.json` (existing file, edit-in-place per WT-5 with justification).

1. Probe `reference/aldonunez/dat/*.dat` for the correct bank — use `tools/probes/probe_nes_chr_bank.py` if exists, else write one-shot
2. Update manifest entry: `source` (bank label), `sha256` (recomputed), `bytes` (re-extracted)
3. Run: `python RoomRom/tools/gen_atlas.py` to re-emit C surfaces
4. Rebuild + re-probe

Note: `item_chr_manifest.json` is under `RoomRom/data/` — WT-5 says NEVER ADD files there but allows EDITS to existing files with justification. Commit message must justify: "Class B fix per scene_breaks.md ticket X — wrong bank captured in original extraction".

Estimated cost: 45 min.

### Class C — dispatch placeholder

Fix site: `src/game/world/render/sprite_render.c` lines 611-684.

1. Identify item_id and the `ROOMROM_ITEM_TILE_*` constant for it (defined in `RoomRom/src/atlas/items_chr_x4.h`)
2. If constant doesn't exist, extract the item CHR first (Class B-style flow): add manifest entry, regen, then constant appears
3. Add case to the switch:
   ```c
   case 0xNN: tile_offset = ROOMROM_ITEM_TILE_<NAME>; break;
   ```
4. Rebuild + re-probe

Estimated cost: 30 min (extraction adds 45 min if needed).

### Class D — stale SCENE_OBJ contract

Fix site: `RoomRom/tools/gen_atlas.py` SCENE_CONTRACTS dict.

1. Identify the scene + its declared `tile_count`
2. Probe the actual atlas: how many tiles does the SCENE_OBJ for this scene contain?
3. Update SCENE_CONTRACTS entry to match reality
4. Run: `python RoomRom/tools/gen_atlas.py` (regenerates `roomrom_scene_vram_contracts.c`)
5. Verify the DMA upload no longer reads past end (consult `docs/atlas/dma_pipeline.md` for byte-count math)
6. Rebuild + re-probe

Pattern recall: Phase F bug was UWSP declared 136 vs actual 34 → 3264 B over-read.

Estimated cost: 20 min.

### Class E — sub-pal 3 clamp

Fix site: `src/sgdk_adapter/render_adapter.c` `render_cram_subrange_upload` callsites, OR document divergence in scene_breaks.md.

**Decision point:** restore vs document. Default per `feedback_full_native_rewrite`: restore via transient CRAM swap. But cost is 1-2 hr per scene.

Restore recipe:
1. Identify the SPR sub-pal needed and the CRAM slot it should write
2. Add a callsite to `render_cram_subrange_upload` at scene entry that loads the sub-pal 3 colors into the chosen CRAM slot
3. Add reverse-swap at scene exit if sub-pal 3 is scene-scoped
4. Re-probe — sprite should now show correct NES colors

Document recipe (faster):
1. In scene_breaks.md ticket, add "Decision: accept divergence. Sub-pal 3 sprites in this scene will render with sub-pal 2 colors. Tradeoff: <colors diff'd> vs <cost-to-restore>"
2. Close ticket without code change

Estimated cost: 1-2 hr (restore) or 10 min (document).

### Class F — CRAM conflict

Fix site: scene-entry hook in `src/game/<subsystem>/<scene>_runtime.c`, calling `render_cram_subrange_upload`.

1. Identify the BG sub-pal X and SPR sub-pal Y colliding at the same CRAM slot
2. Add a transient swap at scene entry: upload BG palette to CRAM slot, swap to SPR palette before SAT upload, swap back per-frame as needed
3. Verify HBlank/VBlank timing — CRAM swaps mid-frame need exact DMA window per `docs/atlas/dma_pipeline.md` worst-case scenarios A-D
4. Re-probe

Estimated cost: 1-2 hr.

---

## Verification (end-to-end after all tickets closed)

**Why:** After all P0+P1 fixes land, re-run the full 16-scene probe and confirm catalog is empty or only P2 remains. This is the gate for closing the sweep phase.

- [ ] **Step V.1: Rebuild final ROM**

```powershell
.\Debug.bat
```

- [ ] **Step V.2: Re-run full scene-walk probe**

```powershell
# /bizhawkScript build/probes/scene_walk_full.lua
# /bizhawkScript build/probes/scene_walk_nes_reference.lua  (only if NES side changed)
```

- [ ] **Step V.3: Re-run classifier**

```powershell
python tools/probes/scene_walk_diff.py
```

- [ ] **Step V.4: Diff scene_breaks.md against original catalog**

Expected: P0+P1 tickets all marked closed/resolved. New tickets only if fixes introduced regressions elsewhere. Any new P0 ticket = STOP, fix before declaring sweep done.

- [ ] **Step V.5: Close sweep — final commit**

Write summary section at top of scene_breaks.md: "Sweep closed YYYY-MM-DD. N tickets resolved (X P0, Y P1, Z P2). M tickets accepted as divergence (sub-pal 3 documents)."

```powershell
git add docs/atlas/scene_breaks.md
git commit -m "sweep: close visual regression sweep — N tickets resolved"
```

---

## Self-review checklist (run before declaring plan ready)

- [x] Spec coverage: each of the 6 break classes A-F has a recipe; each unverified scene has a probe step
- [x] No placeholders: every `<...>` is data-driven by the catalog (Task 3), not hand-waved
- [x] Type consistency: `bg_sparse_tile_lut`, `ROOMROM_ITEM_TILE_*`, `ROOMROM_SPRITE_SLOT_*`, `SCENE_CONTRACTS`, `render_cram_subrange_upload` all referenced consistently
- [x] WT-5 compliance: only existing RoomRom files edited (item_chr_manifest.json, gen_atlas.py, bg_sparse_chr.c — all pre-existing per Explore agent verification)
- [x] BT-1 compliance: sole build = Debug.bat
- [x] One-big-probe: 16 scenes in single Lua per launch
- [x] CODEX_BIZHAWK_ROOT env var set before launch
- [x] commit-first discipline: every task ends in a commit
- [x] RULE ZERO: probe before code at every step

---

## Cost summary

| Phase | Estimated cost |
|---|---|
| Task 0 (pre-flight) | 15 min |
| Task 1 (Genesis probe) | 2-3 hr |
| Task 2 (NES probe) | 1-2 hr |
| Task 3 (classifier + catalog) | 3-4 hr |
| Task 4 (priority sort) | 30 min |
| Task 5 (fixes, 5-15 breaks @ 30 min - 2 hr) | 5-15 hr |
| Verification | 30 min |
| **Total** | **12-25 hr** (vs handoff estimate of 5-15 hr — handoff did not account for probe-build time) |

---

## Open questions to resolve before fix-phase

These do NOT block Task 0-4 (catalog phase) but need answers before Class E/F fixes start:

1. **Sub-pal 3 stance:** restore via CRAM swap (1-2 hr each, expensive but NES-accurate) OR document divergence (10 min, accept palette drift)? Plan default = restore unless catalog reveals 5+ class E tickets, at which point document is reasonable.
2. **Class F priority:** CRAM conflicts are intentional per Phase B/F (4-PAL collapse). Restoring full 8-sub-pal fidelity = many transient swaps + DMA window pressure. Fix only when scene becomes unreadable, document otherwise.
3. **Boss-room coverage:** plan captures L1 boss only. Defer L2-L9 to follow-up sweep? Or extend probe sequence in Task 1?

---

# Phase 2: Post-Sweep Roadmap (2026-05-19 follow-up)

**Context.** Sweep v2 closed clean (commits 624c3bc7 / b383a53e / 848c2e31). Headline: the 34-commit VRAM cleanup pass introduced NO byte-level main-path regressions across title + OW gameplay. Probes + classifier remain as persistent infrastructure under `build/probes/scene_walk_*.lua` + `tools/probes/scene_walk_diff.py`.

Phase 1 explore revealed three follow-up corrections + extensions worth landing before declaring the sweep work-stream done:

1. **Probe SAT base wrong.** `scene_walk_full.lua:28` hardcodes `SAT_BASE = 0xF800` but live `RoomRom/src/main.c:489` calls `VDP_setSpriteListAddress(0xF400u)`. Sweep's SAT-side detection (Class C boomerang fallback dispatch) ran against a wrong VRAM window — main-path BG findings stand, but SAT findings are unverified. One-line fix, then re-run.
2. **PR-2 already deployed.** Memory `project_pr2_vram_relocation` said "spec next session, drop point 9a3c587c". Reality (per `RoomRom/src/main.c:485-489` + `docs/superpowers/specs/2026-05-08-pr2-vram-relocation-design.md`): the chosen design was Option F (64×32 + BG_B vertical staging), NOT the original Option B. All VDP_set* calls already deploy the target layout (planes $C000 shared, Window $E000, HScroll $F000, SAT $F400). Memory entry is stale and should be retired.
3. **Probe coverage limited to room $77.** Sweep never reached cave / UW1 / L1 boss / inventory because (a) RAM-mirror room pokes are no-ops (renderer reads `s_room_id` C static), and (b) probe used a single ABC chord which triggered the debug stress harness. The port DOES expose `MODE_TELEPORT` (RoomRom/src/main.c:93,112,2004) — X button enters teleport mode, D-pad mutates `s_room_id` directly (line 2304-2315). Probe should adopt this pattern.

The inventory/pause subscreen (sweep finding M2) is a Phase 6 + Phase 9 native rewrite per `debates/001-prime-directive-plan-improvement/rounds/r001_codex.md:1684-1694` — large enough to be its own work-stream, not folded into this roadmap.

---

## Task R1: Fix probe SAT_BASE address

**Why:** Sweep's SAT-side detection ran against $F800; live SAT is $F400 (PR-2 deployed). Fix invalidates any future Class C / E / F sprite-side ticket triage until corrected. Typo-class fix.

**Files:**
- Modify: `build/probes/scene_walk_full.lua:28`

- [ ] **Step R1.1: Patch SAT_BASE constant**

Edit `build/probes/scene_walk_full.lua` line 28. Change `local SAT_BASE = 0xF800` to `local SAT_BASE = 0xF400` and update the comment block (lines 25-27) to cite `RoomRom/src/main.c:489` as the source of truth instead of `src/debug/probes/sat_dma_lag_verify.lua:42` (which is itself stale — also update if pursued).

- [ ] **Step R1.2: Re-stage + re-launch Genesis probe**

NES probe captures unaffected. Genesis side only.

```powershell
Copy-Item "build\probes\scene_walk_full.lua" "C:\tmp\scene_walk_full.lua" -Force
Remove-Item "C:\tmp\scene_walk_gen" -Recurse -Force -ErrorAction SilentlyContinue
$env:CODEX_BIZHAWK_ROOT = "C:\tmp"
# Launch via skill: /bizhawkScript build/probes/scene_walk_full.lua
```

- [ ] **Step R1.3: Verify SAT dump is non-zero**

```powershell
$gen = [System.IO.File]::ReadAllBytes("C:\tmp\scene_walk_gen\02_post_chord\02_post_chord_sat.bin")
$nz = ($gen | Where-Object { $_ -ne 0 }).Count
Write-Output "$nz / 640 non-zero"
```

Expected: >0 non-zero bytes. Sweep's earlier dump from $F800 was empty; if $F400 also reads empty, SAT is at yet a third address — investigate VDP reg 5 via `memory.read_u16_be(0x84, "System Bus")` or similar.

- [ ] **Step R1.4: Re-run classifier**

```powershell
python tools/probes/scene_walk_diff.py
```

Expected: any new Class C tickets surface where Genesis SAT shows the boomerang fallback tile (826) against NES OAM real sprites. Likely none for scenes 01-12 (no items in start cave / OW spawn), but adds verification rigor.

- [ ] **Step R1.5: Commit**

```powershell
git add build/probes/scene_walk_full.lua docs/atlas/scene_breaks.md
git commit -m "sweep: probe SAT_BASE 0xF800 -> 0xF400 (PR-2 deployed live)"
```

---

## Task R2: Extend probe via MODE_TELEPORT for cave / UW1 / boss / inventory

**Why:** Sweep covered title + OW spawn ($77) only. Original handoff flagged cave palette overlay, boss SCENE_OBJ banks, sub-pal 3 sprites as primary risk targets — all unreached. RoomRom's `MODE_TELEPORT` (joypad X button + D-pad → `s_room_id` mutation per main.c:2304-2315) is the supported teleport mechanism; RAM pokes don't reach the renderer.

**Files:**
- Modify: `build/probes/scene_walk_full.lua` (add MODE_TELEPORT scene burst section)
- Read: `RoomRom/src/main.c:93,112,2004,2304-2315` for teleport API contract
- Read: `src/game/cave/cave_entrance.c:20-34` + `src/game/cave/cave_dispatch.c:88-137` for cave-entry tile IDs ($24, $88, $70-$73)

- [ ] **Step R2.1: Read teleport mechanism**

```powershell
# Read RoomRom/src/main.c around lines 93, 112, 2004, 2300-2320
# Confirm: which button enters MODE_TELEPORT, what D-pad does, what exits.
```

- [ ] **Step R2.2: Add teleport helper to probe**

Append to `scene_walk_full.lua` after current scene 13. Pattern (drafted; refine after reading teleport code):

```lua
local function teleport_to(row, col)
  -- Enter teleport mode (X button — confirm via main.c:93)
  press({X=true}, 4); idle(30)
  -- Navigate grid (16x8: 16 cols, 8 rows). Each D-pad press steps one cell.
  -- Reset to known origin via Up+Left bursts first.
  press({Up=true}, 16); press({Left=true}, 16); idle(30)
  if row > 0 then press({Down=true}, row); end
  if col > 0 then press({Right=true}, col); end
  -- Exit teleport mode (X again, or Start — confirm via main.c)
  press({X=true}, 4); idle(120)
end

local function read_room_state_mirror()
  -- $FF7204 scene, $FF7205 room, $FF7207 x, $FF7209 y, $FF720A face
  return {
    scene = memory.read_u8(0x7204, "68K RAM"),
    room  = memory.read_u8(0x7205, "68K RAM"),
    x     = memory.read_u8(0x7207, "68K RAM"),
    y     = memory.read_u8(0x7209, "68K RAM"),
  }
end
```

- [ ] **Step R2.3: Add 5 new scenes via teleport**

After scene 13, insert:
```
16: ow_shop_cave        -- room $5F or whichever overworld col contains a shop
17: ow_fairy_cave       -- room with fairy_pond cave entry
18: uw1_entry           -- L1 first room ($73 per memory feedback_check_dont_guess)
19: uw1_combat_room     -- adjacent L1 room with enemies
20: uw1_boss_aquamentus -- L1 boss room ($35)
```

Per scene: teleport via grid coords, idle 180 frames for palette + CHR settle, then `capture(label)`.

Use `read_room_state_mirror()` to log the achieved room id in `state.txt`. If achieved-room != target-room, the teleport failed (e.g. teleport mode doesn't cross scene boundaries OW↔UW); record as MISSING_CAPTURE in catalog.

- [ ] **Step R2.4: Validate cave entry separately**

Cave entry from OW does NOT use teleport; it triggers when Link walks Up onto a cave-entry tile ($24/$88/$70-$73 per cave_entrance.c:20-34). For shop / fairy / level-1 entry, the probe must:
1. Teleport to OW room containing the entrance (e.g. L1 entrance at $73)
2. Position Link via D-pad nav to the entrance tile
3. Press Up to trigger `cave_init()` (cave_dispatch.c:88-137)

Detail: cave_init is hard-coded to $6A in slice-1 per main.c:~1950. If teleport-to-$73 then up-press lands in cave $6A regardless of source OW room, that confirms slice-1 behavior; catalog as known limitation.

- [ ] **Step R2.5: Update classifier SCENE_LABELS**

Edit `tools/probes/scene_walk_diff.py:SCENE_LABELS` to add the 5 new labels. Diff functions need no change — same byte-diff applies.

- [ ] **Step R2.6: Re-stage NES probe with matching scene labels**

NES Z1 navigates cave/UW differently (no MODE_TELEPORT). For each new label, mirror semantics:
- `16_ow_shop_cave`: navigate to known NES shop room (e.g. OW room with mer-old-man), enter
- `17_ow_fairy_cave`: navigate to fairy pond, enter
- `18_uw1_entry`: walk into L1 (NES OW screen $37)
- `19_uw1_combat_room`: walk Up from L1 entry
- `20_uw1_boss_aquamentus`: navigate through L1 to boss

Each NES navigation may take 200-400 frames per transition. Tolerable.

- [ ] **Step R2.7: Re-run both probes**

```powershell
# Genesis side
.\Debug.bat
# /bizhawkScript build/probes/scene_walk_full.lua
# NES side
# /bizhawkScript build/probes/scene_walk_nes_reference.lua
```

- [ ] **Step R2.8: Re-run classifier + read catalog**

```powershell
python tools/probes/scene_walk_diff.py
```

Expected: scenes 16-20 each surface new Class A/C/D/E/F tickets (or document as clean if no breaks). This is the HIGH-VALUE coverage extension the original handoff requested.

- [ ] **Step R2.9: Commit**

```powershell
git add build/probes/scene_walk_full.lua build/probes/scene_walk_nes_reference.lua tools/probes/scene_walk_diff.py docs/atlas/scene_breaks.md
git commit -m "sweep: extend coverage to cave/UW1/boss via MODE_TELEPORT"
```

---

## Task R3: Triage new tickets from Task R2

**Why:** Coverage extension WILL surface real tickets (handoff explicitly flagged these scenes as high-risk). Each ticket gets the Task 5 template treatment from Phase 1 plan (re-probe → fix at labeled site → rebuild → re-probe verify → commit per fix).

**Files:** data-driven from R2 catalog output.

- [ ] **Step R3.1: Sort R2-produced tickets P0/P1/P2** as in original Task 4.

- [ ] **Step R3.2: Apply class recipes from original Task 5** (Class A-F sections above in this plan file).

- [ ] **Step R3.3: Per-fix commits with byte-diff in messages.**

- [ ] **Step R3.4: Final re-run + close sweep + retire stale memory entries**

Retire `project_pr2_vram_relocation` (PR-2 deployed; addresses live in main.c:485-489 match spec). Update or remove.

---

## Task R4: Inventory subscreen MVP (DEFERRED — separate work-stream)

**Why:** Per Phase 1 explore, `src/game/inventory/` does NOT exist. Debate 001 lines 1684-1694 list 5 unimplemented subscreen tasks: pause render, cursor movement, map view, manual save, parity verify. Prerequisite chain (debate 001 Phase 6 Tasks 6.10.4-6.10.8) is partially complete. Pause-menu frame/cursor CHR glyphs are NOT extracted (item_chr_manifest.json has only gameplay items).

**Scope estimate:** 12-30 hr (full Phase 6 task 6.10.9 + Phase 9 prerequisites if not done).

**Do NOT roll into this roadmap.** Spec separately under `docs/superpowers/plans/2026-XX-XX-inventory-subscreen-plan.md` when ready. Sweep finding M2 stays open as the placeholder ticket.

---

## Cost summary (Phase 2)

| Task | Estimated cost |
|---|---|
| R1 (probe SAT base fix) | 15 min |
| R2 (MODE_TELEPORT coverage extension) | 3-5 hr |
| R3 (triage new tickets) | 2-10 hr depending on count |
| R4 (inventory MVP — deferred) | — |
| **Total Phase 2** | **5-15 hr** |

---

## Verification (Phase 2)

After R3 closes:
1. Re-run `python tools/probes/scene_walk_diff.py` → catalog shows expected new scenes captured + tickets resolved.
2. `git log --oneline -10` shows per-fix commits with byte-diff evidence.
3. Memory entry `project_pr2_vram_relocation` retired / updated.
4. `docs/atlas/scene_breaks.md` headline section updated to reflect extended-coverage finding.

---

## Adversarial review — risks + corrections folded back into plan

After self-review of the Phase 2 draft, the following risks surfaced. Each is addressed by an inline correction in the relevant Task above. Lower-section items NOT yet folded back are tracked here for resolution before execution.

### G1 — PR-2 closure status unverified

**Claim:** Phase 1 explore said "PR-2 is deployed" because main.c:485-489 calls the VDP_set* APIs at target addresses. **Risk:** sub-step PR-2c (update `verify_vram_budget.py` + `roomrom_vram_map.h` tile_limit to $C000=1536) may NOT be done. If those audit/doc surfaces still reflect pre-PR-2 layout, declaring PR-2 retired in R3.4 is premature.

**Correction:** Add explicit step R0 (pre-roadmap) to verify PR-2 closure: run `python RoomRom/tools/verify_vram_budget.py` and confirm it asserts the post-PR-2c tile_limit. If it doesn't, PR-2c is the first sub-task to land, not the last.

### G2 — SAT base contradiction needs runtime resolution

**Claim:** Explore says live SAT is $F400; sweep used $F800 (got zeros). **Risk:** $F400 may also read empty if (a) BizHawk's SGDK port has SAT in CPU-side cache only and VRAM SAT is DMA-uploaded each VBlank, or (b) the address is set per-frame by a different code path. Empty captures both at $F800 AND $F400 = wrong domain or wrong frame timing.

**Correction:** R1 must include a VDP-reg-5 readback step. BizHawk Genesis core exposes the last-written VDP reg state via the "VDP" memory domain at offset 5. Compute SAT base = `(reg5 & 0x7E) << 9` and dump from that address. Don't hardcode $F400 — derive at runtime per scene.

### G3 — Cave coverage limited to room $6A

**Claim:** Plan adds `16_ow_shop_cave`, `17_ow_fairy_cave`, etc. **Risk:** per Phase 1 (main.c:~1950), `cave_init(0x6A)` is hard-coded in slice-1. Every "OW → Up onto cave-entry tile" routes to room $6A. So `shop_cave` and `fairy_cave` and any other cave label all capture the SAME Genesis state. Labels suggest coverage that doesn't exist.

**Correction:** Drop multi-cave labels. Replace with ONE label `16_cave_6A` and note in plan + catalog that current build limits cave coverage to a single test cave until per-room lookup lands. Save `shop_cave` / `fairy_cave` for post-cave-table sweep.

### G4 — Save-states beat navigation for NES side

**Claim:** NES probe will navigate fresh to L1 boss room $35 each run. **Risk:** Z1 L1 traversal requires sword pickup + key + bomb navigation + enemy kills. Each step has frame-timing brittleness. Probe will fail intermittently.

**Correction:** Pre-record BizHawk save states for each target NES scene as a one-time setup (`build/probes/states/nes_uw1_entry.State`, `nes_uw1_boss.State`, etc). NES probe `loadstate(path)` instead of navigating. Genesis side keeps MODE_TELEPORT navigation since teleport is deterministic. Add Step R2.0 to record save states before scripting.

### G5 — Classifier B/D/E not implemented

**Claim:** R3 says "Apply class recipes from original Task 5". **Risk:** classifier only detects A + C + F (gated). B (wrong NES bank), D (stale SCENE_CONTRACT), E (sub-pal 3 clamp) have no detection code. Tickets in those classes won't surface; sweep will miss real regressions if any.

**Correction:** Add Step R2.5b: stub detectors for B/D/E even if heuristic. B = compare tile byte hash in vram_tile.bin vs item_chr_manifest.json sha256. D = compare VRAM tile_count consumed at scene-obj base vs SCENE_CONTRACTS declaration. E = look for sprite tiles in PALRAM with sub-pal 3 NES route, check if Genesis PAL3 reflects expected NES SPR sub-pal 2 (clamp) colors.

### G6 — Worktree drift

**Claim:** Phase 1 task 0 noted 6 worktrees. **Risk:** during Phase 2 elapsed time, parallel worktrees may have advanced. R1/R2 builds could trample.

**Correction:** Re-run `git worktree list` + `git log main..` on each worktree branch before R1. Add Step R0.5.

### G7 — MODE_TELEPORT details unverified by direct read

**Claim:** Plan cites main.c:2304-2315 for teleport input handling based on Explore summary. **Risk:** explorer summarized; I have not read those lines myself. The line numbers may have drifted, or the API may exit teleport mode differently than the X-press described.

**Correction:** Step R2.1 must `Read RoomRom/src/main.c offset=2300 limit=20` BEFORE writing the helper. Plan does say "Read teleport mechanism" but should specify exact line range + what to extract (which input enters, which mutates, which exits).

### G8 — Cost estimate optimistic

**Claim:** R2 = 3-5 hr. **Risk:** writing teleport helper + 5 scene transitions + NES side navigation + save-state recording + classifier extensions + debugging realistic = 8-12 hr.

**Correction:** Revise cost summary: R1 = 30 min, R2 = 6-10 hr, R3 = 3-10 hr. Total Phase 2 = 10-21 hr. Acceptable scope — flag during execution if it grows past 25 hr.

---

## Revised cost summary

| Task | Estimated cost |
|---|---|
| R0 (PR-2 closure verify) | 15 min |
| R0.5 (worktree topology re-check) | 5 min |
| R1 (probe SAT fix + VDP reg5 derivation) | 30 min |
| R2 (MODE_TELEPORT + save-state coverage extension) | 6-10 hr |
| R2.5b (B/D/E classifier stubs) | 1-2 hr |
| R3 (triage + per-fix commits) | 3-10 hr |
| R4 (inventory MVP — deferred) | — |
| **Total Phase 2** | **10-21 hr** |

---

# Phase 3: Tile/Sprite Atlas Audit via Custom NES Test ROM + Genesis Debug Scene

**Context.** Scene-walk sweep (Phase 1 + 2) found no byte-level main-path regressions, but the byte-diff only checked WHAT THE SCENE HAPPENED TO RENDER — not the COMPLETE tile/sprite atlas. Many tiles in the port's VRAM (e.g. UW boss tiles, dungeon enemy variants, cave-only tiles, demo-only tiles) are never reached by OW gameplay alone. To audit completeness — when NES shows a sword, Genesis shows a sword; when NES nametable cell $C2 with sub-pal 1 expects ORANGE-TAN, Genesis renders the same pixel bytes — we need an EXHAUSTIVE tile-grid comparison.

Approach: build a custom NES test ROM that loads each Z1 CHR bank and renders it as a deterministic tile grid. Build a matching Genesis debug scene that reads `bg_sparse_tile_lut[][]` + atlas data and renders the same grid. Probe both, byte-diff, surface tickets where the maps disagree.

**Coverage targets** (per Phase 1 explore):
- ~530 unique NES BG + SPR tiles across 9 banks
- 4 NES sub-palettes per tile = 2120 (tile_id, sub_pal) combos
- Genesis side: 1535 VRAM tile slots (atlas + headroom)
- 9 banks × 4 sub-pals = 36 combo rooms (BG only); double if including SPR coverage

**Key infrastructure findings:**
- NES toolchain MISSING (no ca65/cc65). Generate `.nes` directly via Python — iNES header + minimal PRG + CHR banks. Use mapper 3 (CNROM) for trivial CHR bank-switching by writing bank# to $8000-$FFFF. ~150 lines Python.
- CHR banks live at `reference/aldonunez/dat/`: `CommonBackgroundPatterns.dat`, `CommonSpritePatterns.dat`, `CommonMiscPatterns.dat`, `DemoBackground/SpritePatterns.dat`, `PatternBlockOWBG/SP.dat`, `PatternBlockUWBG/SP.dat`, `PatternBlockUWSP127/358/469.dat`, `PatternBlockUWSPBoss1257/3468/9.dat`.
- Bank layout: tile_id $00-$6F = Common (static), $70-$EF = scene-swapped PatternBlock, $F0-$FF = CommonMisc.
- Genesis scene-dispatch hook at `RoomRom/src/main.c` after SCENE_CAVE return block (line ~2002). Add `SCENE_DEBUG_TILEGRID` enum value.
- Genesis render primitives: `render_plane_fill()` at `src/sgdk_adapter/render_adapter.c:425`, `render_set_sprite_full()` at line 360, `bg_sparse_tile_lut[256][4]` at `RoomRom/src/bg_sparse_chr.h:22`.

---

## Task T1: Python NES test-ROM generator

**Why:** No 6502 toolchain available. Python emits the `.nes` file directly. The PRG only needs ~256 bytes of 6502 (init + NMI handler + tile-grid render); we hand-assemble these as a byte array. CHR banks pack from existing `.dat` files.

**Files:**
- Create: `tools/gen_chr_viewer_rom.py` (~150 lines)
- Create: `build/probes/chr_viewer_rom.nes` (build output)

**Design:**
- iNES header: mapper 3 (CNROM), 1 PRG bank (32 KB), N CHR banks (8 KB each = 16384 tiles × 16 B / 8192 = 2 tiles per page... wait, 8 KB = 512 tiles × 16 B each; we use this for 1 BG-page (256 tiles at $1000-$1FFF) + 1 SPR-page (256 tiles at $0000-$0FFF) per bank)
- For each Z1 CHR bank (9 banks identified above), pack the bank's BG-side into CHR page upper half + Common into lower half, OR simpler: 18 CHR pages = 9 banks × (BG-page + SPR-page) selected via mapper write.
- PRG layout:
  - Reset vector: clear PPU, set CHR bank 0 via STA $8000, init nametable to tile grid $00..$FF (16-wide × 16-tall), attribute table = sub-pal 0
  - NMI handler: read CurrentBank from $0010, write to $8000 (CNROM bank select); read CurrentSubPal from $0011, fill attribute table accordingly
  - Input handler: A button cycles bank, B button cycles sub-pal, Start outputs frame counter for sync
- The probe captures CIRAM + PALRAM + OAM + CHR + RAM at known frame after probe sets ($0010, $0011) = (bank, sub_pal) and presses Start to advance.

**Steps:**
- [ ] **T1.1: Verify CHR bank `.dat` integrity**

```powershell
foreach ($f in @("CommonBackgroundPatterns.dat","CommonSpritePatterns.dat","CommonMiscPatterns.dat","PatternBlockOWBG.dat","PatternBlockOWSP.dat","PatternBlockUWBG.dat","PatternBlockUWSP.dat","PatternBlockUWSP127.dat","PatternBlockUWSP358.dat","PatternBlockUWSP469.dat","PatternBlockUWSPBoss1257.dat","PatternBlockUWSPBoss3468.dat","PatternBlockUWSPBoss9.dat","DemoBackgroundPatterns.dat","DemoSpritePatterns.dat")) {
  $size = (Get-Item "reference\aldonunez\dat\$f").Length
  Write-Output "$f : $size B = $($size/16) tiles"
}
```

Expected: sizes match Phase 1 explore inventory (sum = ~530 tiles).

- [ ] **T1.2: Hand-assemble PRG byte array**

In `gen_chr_viewer_rom.py`:
```python
PRG = bytearray(0x8000)  # 32 KB

# Reset vector at $FFFC = $C000 (PRG start)
PRG[0x7FFC] = 0x00; PRG[0x7FFD] = 0xC0
# NMI vector at $FFFA = $C100
PRG[0x7FFA] = 0x00; PRG[0x7FFB] = 0xC1
# IRQ vector unused
PRG[0x7FFE] = 0x00; PRG[0x7FFF] = 0xC0

# Reset code at $C000 (PRG offset 0x4000)
# ... hand-write 6502 opcodes ...
```

Reset sequence:
1. SEI; CLD; LDX #$FF; TXS
2. Wait 2 VBlanks for PPU warmup
3. Clear $0000-$07FF RAM
4. Initialize CurrentBank = 0, CurrentSubPal = 0 at $0010/$0011
5. Set nametable: fill $2000-$23BF with tiles $00..$FF in 16x16 grid (256 tiles fill 16 rows × 16 cols)
6. Set attribute table $23C0-$23FF to all-zeros (sub-pal 0); NMI handler updates per CurrentSubPal
7. Set PALRAM from a hardcoded reference (use Z1 OW palette as default: $0F $30 $00 $12 $0F $16 $27 $36 ...)
8. Enable PPU rendering ($2001 = $1E), enable NMI ($2000 = $80)
9. Infinite loop with input polling at $C200 (joypad strobe + read)

NMI handler at $C100:
1. PHA; TXA; PHA
2. Read $4016/$4017 for joypad state
3. If A pressed (edge): CurrentBank = (CurrentBank + 1) % NUM_BANKS; STA $8000 (CNROM bank select)
4. If B pressed: CurrentSubPal = (CurrentSubPal + 1) % 4; rewrite attribute table $23C0-$23FF with all-quads = CurrentSubPal
5. Increment frame counter at $0012 (probe reads for sync)
6. PLA; TAX; PLA; RTI

- [ ] **T1.3: Assemble CHR pages from `.dat` files**

```python
def pack_chr_page(bg_dat: bytes, spr_dat: bytes) -> bytes:
    """One 8 KB CHR page: $0000-$0FFF SPR, $1000-$1FFF BG.
    Pad each to 4 KB with zeros if smaller."""
    spr = (spr_dat + b'\x00' * 4096)[:4096]
    bg = (bg_dat + b'\x00' * 4096)[:4096]
    return spr + bg

CHR_PAGES = []
# Page 0: Common BG + Common SPR
CHR_PAGES.append(pack_chr_page(
    bg_dat=read("CommonBackgroundPatterns.dat") + read("CommonMiscPatterns.dat"),
    spr_dat=read("CommonSpritePatterns.dat")))
# Page 1: OW BG + OW SPR
CHR_PAGES.append(pack_chr_page(
    bg_dat=read("PatternBlockOWBG.dat"),
    spr_dat=read("PatternBlockOWSP.dat")))
# Page 2: UW BG + UW SPR (level 1 default)
CHR_PAGES.append(pack_chr_page(
    bg_dat=read("PatternBlockUWBG.dat"),
    spr_dat=read("PatternBlockUWSP.dat") + read("PatternBlockUWSP127.dat")))
# Page 3: UW BG + UW SP358
# Page 4: UW BG + UW SP469
# Pages 5-7: UW BG + Boss variants 1257 / 3468 / 9
# Page 8: Demo BG + Demo SPR
```

- [ ] **T1.4: Write iNES header + PRG + CHR**

```python
def write_ines(prg: bytes, chr_pages: list[bytes]) -> bytes:
    header = bytearray(16)
    header[0:4] = b'NES\x1a'      # iNES magic
    header[4] = len(prg) // 16384  # PRG banks (16 KB each); 32 KB = 2
    header[5] = len(chr_pages)     # CHR banks (8 KB each)
    header[6] = 0x30               # mapper 3 (CNROM) low nibble
    header[7] = 0x00               # mapper 3 high nibble = 0, NES 1.0
    # remaining bytes zero
    chr = b''.join(chr_pages)
    return bytes(header) + prg + chr
```

- [ ] **T1.5: Verify ROM boots in BizHawk**

```powershell
python tools/gen_chr_viewer_rom.py
Copy-Item build/probes/chr_viewer_rom.nes C:\tmp\chr_viewer.nes -Force
# Launch via /bizhawkScript with chr_viewer.nes
```

Expected: BizHawk loads ROM, displays 16×16 tile grid of NES tile_id $00..$FF rendered from CHR page 0 (Common). Press A to cycle to page 1 (OW). Etc.

- [ ] **T1.6: Commit**

```powershell
git add tools/gen_chr_viewer_rom.py
git commit -m "audit T1: NES CHR viewer ROM generator (mapper 3 CNROM)"
```

ROM artifact (`build/probes/chr_viewer_rom.nes`) is build output — `.gitignore` or commit per project convention.

---

## Task T2: Genesis SCENE_DEBUG_TILEGRID

**Why:** Mirror the NES test ROM's tile-grid layout on Genesis. Each (bank, sub_pal) combo on NES corresponds to a Genesis room that fills plane A with the same tile sequence routed through `bg_sparse_tile_lut`.

**Files:**
- Modify: `RoomRom/src/main.c` (existing — add SCENE_DEBUG_TILEGRID enum + dispatcher branch). Edit-in-place per WT-5 with justification.
- Create: `src/game/debug/scene_debug_tilegrid.c` + `.h` (new subsystem under src/game/, not under RoomRom/)
- Modify: `tools/debug/build_debug.py` to link the new TU

**Design:**
- New enum value `SCENE_DEBUG_TILEGRID = 3` in `scene_t`
- New static `s_debug_bank` (0..8), `s_debug_subpal` (0..3)
- Dispatcher branch in main loop (insert after SCENE_CAVE handler around line 2002):
  ```c
  if (s_scene == SCENE_DEBUG_TILEGRID) {
      scene_debug_tilegrid_render(s_debug_bank, s_debug_subpal);
      return;
  }
  ```
- `scene_debug_tilegrid_render()` body:
  ```c
  void scene_debug_tilegrid_render(unsigned char bank, unsigned char sub_pal) {
      /* Plane A 32x32 cells. Fill first 16x16 region with tile_id grid.
       * For each NES tile_id 0..255, look up Genesis slot via sparse LUT
       * and write to plane A cell (row*32 + col)*2. */
      for (unsigned short tile_id = 0; tile_id < 256; tile_id++) {
          unsigned short slot = bg_sparse_tile_lut[tile_id][sub_pal];
          unsigned short row = tile_id / 16;
          unsigned short col = tile_id % 16;
          unsigned short cell = row * 32 + col;
          unsigned short attr = (sub_pal << 13) | (slot & 0x7FF);
          // open VRAM write at plane_a + cell * 2
          render_plane_a_write_cell(cell, attr);
      }
  }
  ```
- New button binding: Y already toggles walk-style. C+START enters cave. Choose new chord (e.g. Z+C) to enter SCENE_DEBUG_TILEGRID. Inside, X cycles bank, Y cycles sub_pal.

**Steps:**
- [ ] **T2.1: Read existing scene dispatcher**

```powershell
# Re-read RoomRom/src/main.c around lines 1975-2200 to map every scene transition path.
```

- [ ] **T2.2: Add enum + statics**

Edit `RoomRom/src/main.c:92`:
```c
typedef enum { SCENE_OW = 0, SCENE_UW = 1, SCENE_CAVE = 2, SCENE_DEBUG_TILEGRID = 3 } scene_t;
```

After `s_room_id`:
```c
static u8 s_debug_bank   = 0;  /* 0..8 = NES CHR bank index */
static u8 s_debug_subpal = 0;  /* 0..3 = NES sub-pal */
```

- [ ] **T2.3: Add dispatcher branch**

Insert after SCENE_CAVE return block (~line 2002). Call `scene_debug_tilegrid_render(s_debug_bank, s_debug_subpal)`.

- [ ] **T2.4: Implement scene_debug_tilegrid_render**

Create `src/game/debug/scene_debug_tilegrid.c` with the function body above. Add `.h`.

- [ ] **T2.5: Wire into build**

Edit `tools/debug/build_debug.py` to include the new TU in compile list.

- [ ] **T2.6: Add button bindings**

In main.c input handler:
- Z+C chord (or some unbound combo) toggles SCENE_DEBUG_TILEGRID
- Inside SCENE_DEBUG_TILEGRID: X cycles `s_debug_bank`, Y cycles `s_debug_subpal`

- [ ] **T2.7: Build + smoke test**

```powershell
.\Debug.bat
# Launch BizHawk with Debug.md
# Press Z+C in OW; expect tile-grid render
# Press X, Y to cycle
```

- [ ] **T2.8: Commit**

```powershell
git add RoomRom/src/main.c src/game/debug/scene_debug_tilegrid.c src/game/debug/scene_debug_tilegrid.h tools/debug/build_debug.py
git commit -m "audit T2: SCENE_DEBUG_TILEGRID for atlas byte-diff comparison"
```

---

## Task T3: Cross-side probe + byte-diff classifier

**Why:** Now that both sides can render the same (bank, sub_pal) tile grid deterministically, capture all 36 (bank × sub_pal) combos on both sides and byte-diff per tile.

**Files:**
- Create: `build/probes/chr_grid_walk.lua` (Genesis side — drives SCENE_DEBUG_TILEGRID through all 9 banks × 4 sub-pals)
- Create: `build/probes/chr_grid_walk_nes.lua` (NES side — drives chr_viewer_rom.nes through same 9 × 4 combo)
- Create: `tools/probes/chr_grid_diff.py` (per-tile byte-diff classifier)
- Create: `docs/atlas/tilegrid_audit.md` (per-tile audit report)

**Steps:**
- [ ] **T3.1: Write Genesis probe**

Boot Debug.md, enter SCENE_DEBUG_TILEGRID. For bank = 0..8, sub_pal = 0..3:
- Set s_debug_bank, s_debug_subpal via X/Y taps (or direct memory poke if address known)
- idle 60 frames
- capture(`bank{bank}_subpal{sub_pal}`) — dump CRAM + plane_a + VRAM tile

- [ ] **T3.2: Write NES probe**

Boot chr_viewer_rom.nes. For each (bank, sub_pal):
- Poke $0010 = bank, $0011 = sub_pal
- Idle 60 frames
- capture(`bank{bank}_subpal{sub_pal}`) — dump PALRAM + nametable + CHR + OAM

- [ ] **T3.3: Write classifier**

For each (bank, sub_pal) combo:
- For tile_id 0..255:
  - NES side: read 16 bytes from CHR at offset tile_id*16 (BG range $1000+tile_id*16)
  - Expand NES 2bpp → Genesis 4bpp with pixel-bias per sub_pal route
  - Genesis side: read Genesis tile slot via plane_a[cell] tile_id
  - Compare 32 bytes
- Surface mismatches as tickets: tile_id, expected slot, actual slot, byte diff

- [ ] **T3.4: Run + catalog**

```powershell
python tools/probes/chr_grid_diff.py
```

Expected output: `docs/atlas/tilegrid_audit.md` with per-tile per-subpal status. Clean = both sides byte-identical for that combo. Mismatch = real Class A/B ticket.

- [ ] **T3.5: Commit**

```powershell
git add build/probes/chr_grid_walk.lua build/probes/chr_grid_walk_nes.lua tools/probes/chr_grid_diff.py docs/atlas/tilegrid_audit.md
git commit -m "audit T3: exhaustive tile-grid byte-diff (9 banks × 4 sub-pals × 256 tiles)"
```

---

## Task T4: Triage mismatches

**Why:** T3 will surface every real Class A (sparse LUT miss), Class B (wrong CHR bank captured), Class D (tile bytes drift). Each gets the Task 5 template recipe.

**Files:** data-driven from T3 audit output.

- [ ] **T4.1: Sort tickets by class + severity**
- [ ] **T4.2: Apply class A/B/D recipes from Task 5 template above**
- [ ] **T4.3: Per-fix commit with byte-diff in message**
- [ ] **T4.4: Final re-run + close**

---

## Cost summary (Phase 3)

| Task | Estimated cost |
|---|---|
| T1 (NES ROM generator) | 4-6 hr (6502 hand-assembly is tricky) |
| T2 (Genesis SCENE_DEBUG_TILEGRID) | 2-4 hr |
| T3 (probes + classifier) | 3-5 hr |
| T4 (triage + fix per ticket) | 5-20 hr depending on ticket count |
| **Total Phase 3** | **14-35 hr** |

---

## Open questions resolved (defaults chosen — user can redirect)

1. **Sprite coverage:** include 8x16 sprite mode pairs in same rooms? **Default: yes** — SPR side rendered as separate room cycle after BG. Catches Class C dispatch holes + Class B bank provenance.
2. **All sub-pals per tile:** all 4 NES sub-pals each tile rendered as 4 separate rooms. **Default: yes** — sub-pal 3 clamp (Class E) only surfaces with this coverage.
3. **PAL banks for boss variants:** include UW Boss1257/3468/9 + per-level SP127/358/469 as separate banks. **Default: yes** — adds 6 banks × 4 sub-pal = 24 combos on top of base 9 × 4 = 36.

---

## Risks (G-series)

### G9 — NES ROM hand-assembly bugs

**Risk:** Hand-coded 6502 opcodes have no compiler to catch typos. A bad opcode causes BizHawk to crash on load or render garbage.

**Mitigation:** Reference Nesdev wiki 6502 opcode table. Test PRG with a single-tile-grid first, then expand. If hand-assembly is too error-prone, fall back to bundling a tiny 6502 assembler (e.g. `asm6` 200-line Python rewrite) as part of `gen_chr_viewer_rom.py`.

### G10 — bg_sparse_tile_lut may not cover every NES tile_id

**Risk:** Genesis port only extracts (tile_id, sub_pal) combos that are actually USED by Z1 OW/UW gameplay. Tiles like UW Boss-9 sprite or demo-only title text may have sentinel 0xFFFF for every sub_pal. T3 will flag these as massive Class A — but they're EXPECTED (the port doesn't need them) not REGRESSIONS.

**Mitigation:** Pre-classify each (tile_id, sub_pal) as IN_SCOPE (used by gameplay scenes the port renders) or OUT_OF_SCOPE (demo/intro-only). Skip OUT_OF_SCOPE from T4 triage. The pre-classifier reads NES Z1 game-mode dispatch to determine which tile/sub-pal combos any active scene actually uses.

### G11 — Genesis port may render tile_id correctly but via DIFFERENT VRAM slot

**Risk:** If Genesis port routed tile $C2 sub_pal 1 to slot 850 (instead of expected slot from manifest), the rendered pixels are still correct but my classifier flags it as a slot-mismatch.

**Mitigation:** T3 classifier compares PIXEL BYTES at the resolved slot, not slot indices. As long as final pixels match, the route is correct regardless of which slot index holds them.

### G12 — 8x16 sprite mode pairs require tile-id alignment

**Risk:** NES Z1 sprites use 8x16 mode. Tile_id X and X+1 form a pair. If my test ROM lays out single 8x8 tiles in a 16x16 grid, NES PPU interprets tile_id X as "show tile X (top) and X+1 (bottom)" pair, distorting the grid.

**Mitigation:** Test ROM uses 8x8 sprite mode (PPUCTRL bit 5 = 0) for tile-grid display. This differs from Z1 runtime (8x16) but reveals raw tile pixels. Separate room cycle for 8x16 pair verification covers the runtime case.

### G13 — Hand-assembled 6502 is fragile

**Risk:** T1 step T1.2 hand-encodes ~200-300 6502 opcodes in a Python bytearray. No compiler validates correctness. One typo (wrong opcode byte, wrong branch offset) bricks the ROM with no error message — BizHawk just renders garbage or hangs. Debug cycle is "edit Python, regen .nes, boot, eyeball" which is slow.

**Mitigation:** Bundle a 50-100 line minimal 6502 assembler inside `gen_chr_viewer_rom.py`. Source code becomes readable asm with labels:
```python
ASM = """
.org $C000
reset:
  sei
  cld
  ldx #$FF
  txs
  ; ... wait 2 vblanks ...
"""
ROM = assemble(ASM)
```
Reference: existing repos like `py65` or `asmotor-py` provide ~200-line 6502 assemblers. Cost: +2 hr writing the assembler vs +10 hr debugging hand-assembled bytes.

### G14 — Atlas extracted from REDUX ROM, not original

**Risk:** `RoomRom/data/item_chr_manifest.json` may have provenance pointing to Zelda Redux ROM tiles (per `feedback_redux_automap_room_reset` memory + `src/game/world/ow_palette.c` which carries both `orig` and `redux` palette arrays). If T1 test ROM packs ORIGINAL Z1 tile bytes but Genesis atlas was extracted from REDUX, T3 will flag EVERY tile as mismatch — pure noise.

**Mitigation:** Add pre-T1 step: grep `item_chr_manifest.json` and `RoomRom/data/*.json` for `source` / `nes_rom` fields. Confirm which ROM (orig or redux) the atlas was extracted from. T1 ROM generator reads from the SAME ROM source. If both orig + redux are present (per ow_palette.c structure), generate two test ROMs and run T3 twice with the corresponding manifest variant.

### G15 — Noise floor from out-of-scope tile_ids

**Risk:** Genesis atlas only contains tiles for scenes the port renders (OW + UW1-9 + caves). Tiles for unused scenes (Demo-only intro, GameOver-only) have sentinel 0xFFFF for every sub_pal. T3 will flag hundreds of these as "Class A" but they're NOT regressions — they're intentional exclusions. Catalog becomes unreadable.

**Mitigation:** Phase 1 pre-classify step. Before T3 runs, build `tools/probes/in_scope_tile_table.json` from:
- Read `RoomRom/src/atlas/roomrom_scene_vram_contracts.c` for every scene's tile bundle
- Read `bg_sparse_tile_lut[256][4]` from `RoomRom/src/bg_sparse_chr.c` — every non-0xFFFF entry IS in-scope
- Optionally extend: any tile_id used in ANY NES Z1 nametable across all OW/UW/cave rooms (extract from LevelBlock + RoomCols dat files)
- T3 classifier skips out-of-scope (tile_id, sub_pal) combos (or surfaces them under a separate "Demo/intro tile not extracted" section with priority P3 — informational).

### G16 — T2 has no verification before T3

**Risk:** Plan jumps from T2 (Genesis SCENE_DEBUG_TILEGRID code lands) directly to T3 (probe captures from both sides). If SCENE_DEBUG_TILEGRID renders garbage (or doesn't render at all), T3 captures garbage and surfaces 1000+ false-positive tickets.

**Mitigation:** Add Step T2.7 (already present) requires manual eye-check: launch Debug.md, trigger SCENE_DEBUG_TILEGRID, screenshot, confirm SOME tile content is visible. If blank, debug T2 before T3 starts. Add explicit pass-criteria.

### G17 — Button binding conflict (no free chord)

**Risk:** Current Genesis button map (main.c:73-80) uses ALL buttons: X (teleport), Y (walk style), A (sword), B (item), Z (cycle item), C (map variant), START (scene toggle). No unbound chord exists. Z+START already toggles quest in UW. Adding a SCENE_DEBUG_TILEGRID entry needs a 3-button chord that doesn't conflict.

**Mitigation:** Use `MODE` button (Genesis 6-button only) per main.c:83 — currently "intentionally unbound". For 3-button controllers, fall back to A+B+C+Z chord (4-key combo) which the existing dispatcher does NOT use. Verify by reading the input handler in main.c around line 2000.

### G18 — PPUCTRL state for tile_id-to-pattern-table mapping

**Risk:** Plan assumes BG tiles render from $1000 (PPUCTRL bit 4 = 1) — but Z1 runtime sets bit 5 (8x16 sprite mode) and the BG pattern table base depends on bit 4. If test ROM doesn't match Z1's actual PPUCTRL state, tile_id-to-CHR-offset math diverges from reality.

**Mitigation:** T1 step T1.2 explicitly sets PPUCTRL to a documented value at boot: `$00 | $80 = $80` (NMI on, no 8x16, BG at $0000, sprites at $0000). Document this state in T1 design block + cross-reference Z1 runtime PPUCTRL value via NES probe of normal Z1 boot.

---

## Plan revisions folded back

- T1.2 → use embedded 6502 assembler (200-line Python) instead of raw hand-assembled bytes (G13)
- T0 → add ROM-provenance verification: which ROM did atlas come from (G14)
- T0 → build `in_scope_tile_table.json` from atlas + nametable union (G15)
- T2.7 already covers manual eye-check (G16) — make pass-criteria explicit
- T2.6 → use unbound `MODE` button or 4-key chord A+B+C+Z (G17)
- T1.2 → document PPUCTRL state explicitly at boot (G18)

## Revised cost summary (Phase 3 with G-fixes)

| Task | Estimated cost |
|---|---|
| T0 (ROM provenance + in-scope table) | 1-2 hr |
| T1 (NES ROM gen + embedded 6502 assembler) | 6-10 hr |
| T2 (Genesis SCENE_DEBUG_TILEGRID + eye-check) | 3-5 hr |
| T3 (probes + classifier) | 3-5 hr |
| T4 (triage + fix per ticket) | 5-20 hr |
| **Total Phase 3 (revised)** | **18-42 hr** |

---

## 5× Adversarial Review

### Round 2 — YAGNI / scope creep

**Critique:** Custom NES ROM (T1) is over-engineered. ~530 unique tiles already exist in authentic Z1 game-states the port supports. Real Z1 reaches every CHR bank during normal play (boot → title → file-select → OW → cave → UW1..9 → bosses). A simpler approach: BizHawk save-state capture at each authentic scene.

**Alternative T1-ALT — Save-state authentic capture:**
- One-time setup: launch real NES Z1 in BizHawk, navigate to each target scene (cave, fairy, shop, UW1 entry, UW1 boss, UW9 Ganon, file-select, title-demo), `savestate.save()` to `build/probes/states/nes_<scene>.State`.
- Save-state count: ~10-15 states cover all CHR banks (Common + OW BG/SPR + each UW level's BG/SPR + each boss bank + demo + title).
- NES probe: `savestate.load(path)`, idle 60 frames, capture CIRAM + PALRAM + CHR + OAM.
- Coverage: authentic — every tile_id rendered is one Z1 actually uses in that state.
- Cost: 1 hr save-state recording (manual) + 30 min probe writing vs 6-10 hr T1 hand-assembly route.

**Trade-off:**
- T1 (custom ROM): exhaustive coverage of EVERY tile in EVERY bank with EVERY sub-pal — including tiles Z1 never displays. Pure data-driven.
- T1-ALT (save-state): only tiles Z1 actually renders in its supported scenes — but that's IDENTICAL to the in-scope set Phase 3 already targets via G15.

**Decision:** T1-ALT is sufficient. Drop T1, replace with T1-ALT. Saves 5-9 hr. Custom ROM only needed if a tile is suspected wrong AND it never renders in authentic gameplay (rare).

### Round 3 — completion criteria

**Critique:** Phase 3 doesn't define "done". Risk: T3 surfaces 30 mismatches, half get fixed, project drifts open indefinitely.

**Pass conditions (explicit):**
1. T3 classifier produces `docs/atlas/tilegrid_audit.md` with per-tile per-subpal byte-diff status.
2. Every in-scope (tile_id, sub_pal) row is either MATCH or has a P0/P1/P2 ticket with named class (A/B/C/D/E).
3. Every P0 ticket is closed (commit landed, re-probe shows MATCH).
4. P1 tickets MAY remain open if user decides cost-not-worth-it (document the decision per-ticket).
5. P2 tickets are informational; no closure required.

**Phase 3 closes when:** all P0 closed + all P1 either closed or documented-as-accepted + summary commit lands at `docs/atlas/tilegrid_audit.md` with "Phase 3 CLOSED YYYY-MM-DD" header.

### Round 4 — failure modes

**Critique:** Plan ignores three concrete failure modes:

**F1 — SGDK DMA queue lag.** SCENE_DEBUG_TILEGRID writes to plane A via `render_plane_fill()`. SGDK queues these for next VBlank. If the probe captures before VBlank, plane A is still showing stale tiles.

**Mitigation:** Add `frameadvance` 4× after entering SCENE_DEBUG_TILEGRID to drain DMA queue. Equivalent on NES side after `savestate.load()`.

**F2 — BizHawk poke survival across frame.** Probe pokes `$0010 = bank` on NES side. If next frame's CPU code overwrites $0010, poke is lost. Need to verify the test ROM's NMI handler READS $0010 to drive bank-select (it does per T1 design); for T1-ALT (save-state), this doesn't apply.

**Mitigation (T1-ALT only):** No poke needed — save-state IS the bank. Eliminates F2 entirely.

**F3 — Probe cycle timing.** T3 wants 36 combos × 60 frames + capture overhead = ~30 sec per side. If Genesis dispatcher takes 90 frames to settle a bank change (CHR DMA upload), captures are stale and falsely flag mismatches.

**Mitigation:** Idle 120 frames between bank change and capture. Verify via probe state-mirror that `s_debug_bank` matches expected value before capturing.

### Round 5 — integration

**Critique 1 — Does SCENE_DEBUG_TILEGRID ship?** Per BT-1 sole build = Debug.md. Adding ~2KB debug-only code is acceptable (current ROM 2.0 MB; +0.1% size). But: should it be gated behind a compile flag for release? Per memory `project_title_screen_goal` "title + FS customized, NOT NES parity" — there's no current "release" concept, so this is moot. Ship it.

**Critique 2 — Does this duplicate `RoomRom/tools/walk_z1_disasm.py`?** That tool walks Z1 disasm statically, doesn't render. Different purpose. No conflict.

**Critique 3 — `tools/audit/active_scope.py` update?** Per CLAUDE.md, active_scope tracks current phase's edit zone. Phase 3 adds `src/game/debug/scene_debug_tilegrid.c` + edits `RoomRom/src/main.c` + new probes + docs/atlas. active_scope should reflect this. Add Step T0.5 to update `docs/audit/active_scope.md` before T2 lands.

**Critique 4 — Tile_grid catalog overlaps scene_breaks.md?** scene_breaks.md tracks scene-walk findings. tilegrid_audit.md tracks atlas audit. Different scopes. Cross-reference but keep separate.

**Critique 5 — `data/chr/` already has extracted CHR.** Per Phase 1 explore, `tools/extract_chr.py` already outputs C arrays under `data/chr/` (per `data/chr/common.c`, etc). Genesis port consumes those. T3 should diff against `data/chr/*.c` content not just `bg_sparse_chr.c` — wider audit. Add to T3.3 step.

### Round 6 — final consolidation

All 5 rounds folded back. **Net plan revisions:**
- T0 adds T0.5 (active_scope update).
- T2 adds DMA-drain frameadvance after SCENE_DEBUG_TILEGRID enter.
- T3.3 widens diff target to include `data/chr/*.c` content not just sparse LUT.
- T4 closure criteria made explicit.

### Round 7 — user pushback: save-state route NOT reliable for this executor

**Critique:** Round 2 recommended T1-ALT (save-state authentic capture) as simpler than custom NES ROM. User correctly flagged: this executor struggles with save-states. Real cost of T1-ALT:
- Recording save-states requires manual NES Z1 playthrough through cave / fairy / shop / UW1 entry / UW1 boss / UW9 Ganon / file-select / title — hours of skilled play OR a deterministic TAS script.
- TAS script suffers the SAME brittleness as the failed MODE_TELEPORT navigation in R2 (limitation 7): edge-detect timing, sword-state strips D-pad, etc.
- This executor has no reliable way to produce save-states without user assistance.

**Revised decision:** REVERT to T1 (custom NES ROM via Python generator). The G13 hand-assembly risk is real but mitigated by embedding a 100-200 line minimal 6502 assembler in `gen_chr_viewer_rom.py`. Python is what this executor does well; deterministic ROM generation has no nav-brittleness, no manual playthrough, no save-state dependency.

**T1 stays. T1-ALT dropped.**

### Final consolidation (after Round 7)

- T1 KEPT (custom NES ROM with embedded 6502 assembler per G13 mitigation).
- T1-ALT REJECTED (executor cannot reliably produce save-states).
- T0 adds T0.5 (active_scope update).
- T2 adds DMA-drain frameadvance after SCENE_DEBUG_TILEGRID enter.
- T3.3 widens diff target to include `data/chr/*.c` content not just sparse LUT.
- T4 closure criteria made explicit (Round 3).

## Final cost summary (Phase 3 — post-7×-review)

| Task | Estimated cost |
|---|---|
| T0 (provenance + in-scope table + active_scope) | 1-2 hr |
| T1 (NES ROM gen + embedded 6502 assembler) | 6-10 hr |
| T2 (Genesis SCENE_DEBUG_TILEGRID + DMA-drain + eye-check) | 3-5 hr |
| T3 (probes + classifier diffing sparse LUT + data/chr/) | 3-5 hr |
| T4 (triage + fix per ticket; closure criteria explicit) | 5-20 hr |
| **Total Phase 3 (final)** | **18-42 hr** |

---

# Phase 4: Visual-Aligned Atlas Audit (2026-05-19)

**Context.** Phase 3 byte audit (`tools/probes/full_atlas_audit_v2.py`) found 0 real BG/Common-SPR/SCENE_OBJ/CRAM mismatches after fixing 3 upstream bugs:
1. `gen_bg_sparse.py` Common BG section offset (read SPR section bytes by accident)
2. `nes_chr_cycle.lua` memory domain (read raw "CHR" page 0 only, ignoring CNROM bank-switch)
3. `vram_dma_upload` NMI preemption mid-stream (clobbered VDP auto-increment, scattered 2 KB to wrong VRAM)

But that audit only covered BG sparse + Common SPR first 44 tiles + per-bank SCENE_OBJ + CRAM. **NOT** audited: ITEM atlas (`items_chr_x4`), Link/sword pose blobs, sprite-page 1-3 mapping, plane A nametable cell routing, animation states. User flagged uncovered surfaces twice — visual side-by-side comparison is the most direct way to catch routing/palette/animation bugs missed by byte audit.

**Goal:** Build aligned debug scenes (Genesis + NES) that expose EVERY drawable atlas (BG + SPR + ITEM + SCENE_OBJ + Link + sword + HUD + Misc) in identical positions, drive both ROMs through every bank/sub_pal/page/mode state, and run a 3-mode PNG diff tool (pixel-exact + tile-bounded + side-by-side mosaic) to confirm byte AND visual parity. AI-friendly per-cell JSON manifest lets me scan diffs without re-running probes.

**Constraints (per user 2026-05-19):**
- EVERY visual must be exposed (no atlas left out)
- Both ROMs must align IDENTICAL layouts at identical pixel coordinates
- Output must be AI-readable (PNG diff + machine JSON, not just hex dump)
- Redux stays untouched — orig variants only
- Items audit currently broken (compares vs wrong source) — fix first to confirm or refute hidden item bugs

**File structure:**
- Modify: `src/game/debug/debug_tilegrid.c` (rewrite as universal-graphics scene)
- Modify: `tools/gen_chr_viewer_rom.py` (mirror Genesis layout in NES test ROM)
- Modify: `tools/probes/item_atlas_audit.py` (use manifest as truth)
- Create: `tools/probes/png_diff_atlas.py` (3-mode diff toolkit)
- Output to: `docs/atlas/visual_diff/` (mosaics + per-state JSON manifests + divergences.md)

---

## Task V0: Items audit fix (gate to V1)

**Why.** Current `tools/probes/item_atlas_audit.py` compares items_chr_x4.c bytes to `common_chr` and `sprites_chr` offsets — but items_chr_x4 is generated from `item_chr_manifest.json` which has per-tile NES 2bpp `bytes` field as the source of truth. Audit using manifest = the ONLY way to detect items_chr_x4 generation drift.

**Files:**
- Modify `tools/probes/item_atlas_audit.py`
- Read `RoomRom/data/item_chr_manifest.json` for tile bytes (each variant's `tiles[tile_id].bytes` = 32 hex chars = 16 NES 2bpp bytes)
- Read `RoomRom/tools/gen_atlas.py:build_legacy_variant_blob` (lines 1127-1181) to mirror its draw-rule dispatch (mirrored / wide_16x16_mirrored_8x16 / plain) and hflip behavior

**Steps:**
- [ ] V0.1: Replace expected-source logic in item_atlas_audit.py:
  ```python
  # For each item def + variant 'orig':
  for item_def in defs:
      tile_ids = item_def["tile_ids"]
      rule = item_def["draw_rule"]
      bake_mirror = rule.startswith("mirrored_")
      is_8x16_mirrored = rule.startswith("wide_16x16_mirrored_8x16")
      tiles_dict = variant_orig["tiles"]
      atlas_offset = ITEM_TILE_INDEX[item_def["name"]] * 32
      cursor = atlas_offset
      def get_expected(tid):
          return nes_2bpp_to_gen_4bpp(bytes.fromhex(tiles_dict[tid]["bytes"]), sub_pal=0)
      if is_8x16_mirrored:
          for i in range(0, len(tile_ids), 2):
              top = get_expected(tile_ids[i])
              bot = get_expected(tile_ids[i+1])
              compare(cursor + 0, top)
              compare(cursor + 32, bot)
              compare(cursor + 64, hflip_gen_tile(top))
              compare(cursor + 96, hflip_gen_tile(bot))
              cursor += 128
      elif bake_mirror:
          for tid in tile_ids:
              gen = get_expected(tid)
              compare(cursor, gen)
              compare(cursor + 32, hflip_gen_tile(gen))
              cursor += 64
      else:
          for tid in tile_ids:
              compare(cursor, get_expected(tid))
              cursor += 32
  ```
- [ ] V0.2: Add `hflip_gen_tile()` helper (mirrors `gen_atlas.py:hflip_genesis_tile`)
- [ ] V0.3: Run audit. Three outcomes:
  - 0 mismatches → items_chr_x4 generation is correct, skip to V1
  - N mismatches → real items bug. Triage: which tiles, which items, byte-pattern. Fix at root (likely a bad manifest tile entry or gen_atlas bug)
- [ ] V0.4: Commit fix (audit script + any root-cause fixes)

**Verification.** Audit report: 0 mismatches OR all flagged tiles have root-cause fix landed + commit message documenting before/after.

**Cost: 30 min** (audit fix); +1-3 hr if real items bugs surface.

---

## Task V1: Genesis universal-graphics scene

**Why.** Current SCENE_DEBUG_TILEGRID exposes only BG 16×16 grid + sprite 8×8 grid. Need every atlas in fixed-position grid layout so PNG diff comparable to NES side cell-by-cell.

**Files:**
- Major edit `src/game/debug/debug_tilegrid.c`
- Read `src/game/world/render/sprite_render.c` (Link pose tile constants `LINK_VRAM_TILE`, `ATTACK_VRAM_TILE`, `ITEM_VRAM_TILE` lines 63-95)
- Read `RoomRom/src/roomrom_vram_map.h` (tile base constants lines 85-130)
- Read `RoomRom/src/atlas/items_chr_x4.h` for ROOMROM_ITEM_TILE_* tile-index constants

**Layout (Genesis Plane A, 32 cols × 28 visible rows = 256×224):**

```
Row 0-15  cols 0-15 : BG sparse grid (NES tile_id $00..$FF)
Row 0-15  cols 16-31: SPR atlas grid (256 slots from SPR_TILE_BASE=533)
Row 16-21 cols 0-15 : ITEM atlas (98 tiles in 16×6 layout, labeled w/ ROOMROM_ITEM_TILE_*)
Row 16-21 cols 16-31: SCENE_OBJ overlay (per-bank enemy/boss CHR — 96 tiles max)
Row 22-25 cols 0-15 : Link walk poses (8 poses × 4 tiles = 32 tiles, 8x4 layout)
Row 22-25 cols 16-31: Link attack poses (4 poses × 4 tiles = 16 tiles) + sword item tiles
Row 26-27           : Common Misc + HUD strip
```

**Cell labeling (AI-friendly):**
- Identical positional layout: tile at (row, col) ALWAYS represents the same NES origin in both ROMs
- 1-pixel border per tile (in PAL3 color $0AAA = neutral gray) to delimit cells visually
- Row/col headers in left+top margins using Common BG digit glyphs (tiles $00..$0F = '0'..'F')
- Cycle controls (X=bank, Y=sub_pal, Z=sprite page, C=8x16 mode) — show on screen at top-right corner

**Steps:**
- [ ] V1.1: Read existing debug_tilegrid.c end-to-end. Inventory functions: `redraw_bg`, `redraw_sat`, `upload_bank`, `joy_read6`, main loop. Note layout knobs to refactor.
- [ ] V1.2: Refactor `redraw_bg` to be `redraw_grid(grid_id)` with parameterized region (start_row, start_col, width, height, source). Five grid IDs: BG_GRID, SPR_GRID, ITEM_GRID, SCENE_OBJ_GRID, LINK_GRID.
- [ ] V1.3: Implement `redraw_item_grid()`. For each ROOMROM_ITEM_TILE_* tile_index (98 entries), write plane A cell at (row=16+(tile_idx/16), col=tile_idx%16) with attribute referencing VRAM tile (ITEM_VRAM_TILE + tile_idx).
- [ ] V1.4: Implement `redraw_link_pose_grid()`. Walk + attack poses laid out at known positions.
- [ ] V1.5: Add cell borders. Reserve VRAM tile slot for a 1-pixel-border glyph (8×8 with thin frame, transparent center). Plane A cell composites tile + border via PAL3 attr or layered Plane B.
- [ ] V1.6: Build + smoke test. Enter scene from title via C+START. Verify BG grid still works + new ITEM/Link grids render at expected positions.
- [ ] V1.7: Commit "debug: universal-graphics scene exposing all atlases in aligned grids"

**Verification.** Boot Debug.md, enter scene, screenshot. Read PNG via Read tool. Expected: 28 rows visible with all 6 grids laid out in fixed positions per Layout block above. Border around each cell delineates tile boundaries.

**Cost: 3-5 hr.**

---

## Task V2: NES test ROM universal-graphics layout

**Why.** NES side must render IDENTICAL layout — same tile at same cell position — so PNG diff is meaningful cell-by-cell. Current `chr_viewer_rom.nes` shows only BG 16×16 + SPR 8×8.

**Constraint.** NES PPU = 32×30 nametable, 64-sprite OAM limit per frame, BG pattern table $1000+ but SPR pattern table $0000+. Items/Link tiles in NES Z1 live in SPR pattern table — can't be rendered via nametable directly (BG fetches from $1000 region).

**Solution.** Use BG-only rendering. Pack SPR/ITEM/Link source tiles into the BG pattern table region of each CHR page (replacing scene-BG region). NES test ROM doesn't need to match Z1's runtime PPU layout — just needs to render the same SOURCE tiles in same positions as Genesis. The PNG diff cares about visual output, not PPU mechanism.

**Files:**
- Major edit `tools/gen_chr_viewer_rom.py`
- Read `RoomRom/data/item_chr_manifest.json` for item tile NES 2bpp bytes
- Read `src/game/world/render/sprite_render.c:link_poses + attack_poses` for Link pose tile_ids

**Steps:**
- [ ] V2.1: Extend CHR page packer to include SPR/ITEM tiles in BG pattern table region of each page. New layout per page:
  ```
  $0000-$0FFF SPR pattern table:   Common SPR (top 0..0FFF) — for OAM if needed
  $1000-$16FF BG pattern table:    Common BG ($00-$6F) — for BG cell display
  $1700-$1EFF BG pattern table:    Scene-specific BG ($70-$F1) per bank
  $1F00-$1FEF BG pattern table:    Common Misc ($F2..$FF)
  ```
  Same as today. Then ADD a separate "items strip" via dedicated tile_ids in pattern table $1F20-$1FFF? Limited space.

  Better: NES test ROM uses NMI to cycle "pages" (item view, link view, etc) via Select button. PRG code switches PPUCTRL bit 4 (BG pattern table source) OR loads different CHR page on Select press. Each "page" exposes one atlas.

  Even better: forget single-frame coverage. Cycle via `s_page` variable (Start button on NES, already wired). Page 0 = BG grid + Common SPR (current). Page 1 = ITEM grid. Page 2 = Link poses. Page 3 = Misc/HUD.

  Genesis side uses same page-cycle scheme. Probe drives `s_page` poke same way for both.

- [ ] V2.2: Pack item NES tiles into new CHR page (item_view_page) where tile_id $00..$5F = items_chr_x4 source tiles (98 tiles fit in 8KB CHR if 16B/tile = 1568B... fits easily).
- [ ] V2.3: Build matching nametable for item page = same 16×6 layout as Genesis row 16-21 cols 0-15.
- [ ] V2.4: Cell borders on NES side. Add a "border" tile in CHR ($FE? or unused tile_id) drawn around each cell. Genesis side mirrors.
- [ ] V2.5: Test ROM smoke: cycle through page 0..3, screenshot, eyeball layout matches Genesis side.

**Verification.** Run `nes_chr_cycle.lua` against new chr_viewer_rom.nes. Compare bank0_sub0_page1 NES screenshot vs Genesis bank0_sub0_page1 screenshot. Same layout.

**Cost: 4-6 hr** (NES 6502 hand-assembly is fiddly; embedded assembler helps).

---

## Task V3: Re-stage + re-capture

**Why.** After V1 + V2 land, both ROMs need fresh captures with new universal-graphics layout.

**Steps:**
- [ ] V3.1: Rebuild Debug.md (`.\Debug.bat`), copy to `C:\tmp\Debug.md`
- [ ] V3.2: Regenerate NES test ROM (`python tools/gen_chr_viewer_rom.py`), copy to `C:\tmp\chr_viewer.nes`
- [ ] V3.3: Re-run Genesis probe: bizhawkScript with `gen_tilegrid_cycle.lua`, captures land in `C:\tmp\chr_cycle_gen\`
- [ ] V3.4: Re-run NES probe: bizhawkScript with `nes_chr_cycle.lua`, captures land in `C:\tmp\chr_cycle_nes\`
- [ ] V3.5: Verify 256 states captured on each side; sanity-check 3-4 PNGs visually match expected layout

**Cost: 1 hr.**

---

## Task V4: PNG diff toolkit (3-mode)

**Why.** User requested all three: pixel-exact + tile-bounded + side-by-side mosaic. Each catches different bug classes:
- Pixel-exact: any RGB drift (palette quantization, color routing)
- Tile-bounded: 8×8 region-level diff aggregation — cell-level granularity for AI to grep
- Mosaic: human-reviewable PNG showing NES | Genesis | diff overlay

**Files:**
- Create `tools/probes/png_diff_atlas.py`
- Use PIL (Pillow) — already present per Python env
- Output dir: `docs/atlas/visual_diff/`

**Per-state outputs:**

1. **Pixel diff** (`pixel_diff_{state}.png`): 256x224 RGB image where pixel = (NES.R - Gen.R, NES.G - Gen.G, NES.B - Gen.B) with absolute value. Saturation = magnitude of diff. Black = match.

2. **Tile-bounded diff JSON** (`tile_diff_{state}.json`):
   ```json
   {
     "state": "bank1_sub0_page0_8x160",
     "total_cells": 1024,
     "diff_cells": 4,
     "cells": {
       "16,3": {"tile_id_nes": "$24", "tile_id_gen": 820, "diff_px": 12, "source": "ITEM"},
       "16,7": {"tile_id_nes": "$36", "tile_id_gen": 826, "diff_px": 3, "source": "ITEM"},
       ...
     }
   }
   ```

3. **Mosaic** (`mosaic_{state}.png`): 528x224 RGB image (256 NES + 16 gap + 256 Gen). Red 1-px box around any cell with diff_px > 0. Easy human review.

**Steps:**
- [ ] V4.1: Implement pixel_diff_image(nes_png, gen_png) -> PIL.Image
- [ ] V4.2: Implement tile_bounded_diff(nes_png, gen_png, cell_size=8) -> dict[cell_id, diff_count]
- [ ] V4.3: Implement mosaic(nes_png, gen_png, diff_cells) -> PIL.Image with red boxes
- [ ] V4.4: Per-cell source labeling: read tile_id from the universal-graphics scene layout — cell (r, c) is known to map to one of {BG, SPR, ITEM, SCENE_OBJ, Link, Misc}. Hardcode the layout map.
- [ ] V4.5: Top-level summary report (`docs/atlas/visual_diff/summary.md`):
  ```markdown
  # Visual Diff Summary
  Total states: 256
  Clean states: N (0 diff cells)
  States with diff: M
  Diff cells by source: BG=X, SPR=Y, ITEM=Z, ...
  ```

**Verification.** Run on existing captures (post V3). If V0+V1+V2 are all correct, total diff cells = 0. Else summary points to specific (state, cell, source) tuples for triage.

**Cost: 2-3 hr.**

---

## Task V5: Iterate per diff cell

**Why.** V4 surfaces real visual bugs. Each diff cell = one ticket. Fix at root, re-run, until clean OR divergence documented.

**Process per diff cell:**
1. Read tile_diff JSON, find cell with diff_px > 0
2. Look up cell source (BG/SPR/ITEM/etc) via layout map
3. Identify root cause:
   - Wrong atlas bytes → fix gen_atlas.py / gen_bg_sparse.py / source DAT
   - Wrong palette routing → fix bg_palette.c subpal_routing
   - Wrong VRAM slot → fix sprite_render.c upload path
   - Animation state difference (e.g. sword swing frame mismatch) → adjust scene capture timing
4. Apply minimal fix
5. Re-stage ROM + re-capture state + re-run V4
6. Confirm cell cleared OR divergence documented in `docs/atlas/visual_diff/divergences.md`

**End state:** Either zero diff cells across all 256 states, or every remaining diff has an entry in divergences.md with reason (e.g. "Genesis CRAM 3-bit quantization rounds NES $XX to nearest available color; visually indistinguishable").

**Cost: varies; estimate 2-10 hr depending on how many bugs surface.**

---

## Verification (Phase 4 closure)

End condition (ALL must hold):
1. `tools/probes/item_atlas_audit.py` reports 0 mismatches
2. `docs/atlas/visual_diff/summary.md` shows either 0 diff cells across 256 states OR all remaining diffs documented
3. Both ROMs render identical universal-graphics layout (visual eye-check on 3-4 representative state PNGs)
4. Per-state JSON manifests enable AI to grep specific cells by source/tile_id
5. Mosaic PNG samples human-reviewable

---

## Risks / open questions

**G19 — NES CHR space constraint.** ITEM tiles + Common SPR + Common BG + Scene BG + Misc + Link poses may not all fit in 8KB CHR per bank. Mitigation: cycle pages on both sides via existing `s_page` variable. NES PRG remains stable; CHR pages 9-15 added for item/Link views.

**G20 — Genesis VRAM space.** Universal-graphics scene uploads multiple atlases concurrently. Current VRAM budget: BG sparse 532 + SPR atlas 287 + ITEM 98 + SCENE_OBJ 96 + headroom = ~1100 slots. PR-2 Option F has $C000 plane base; VRAM atlas region = $0000-$BFFF / 32 = 1536 slots. Fits. But careful with SCENE_OBJ overlay collision.

**G21 — Cell border visual contamination.** 1-pixel border on each tile changes pixel-exact diff (border in NES vs Genesis must be byte-equal too). Mitigation: borders use same PAL3 entry on both sides; gen via shared rendering code path. Or: borders ONLY in mosaic output, not in actual rendered scene (PIL overlay).

**G22 — Items audit may surface large drift.** If items_chr_x4 generation has been wrong, V0 will surface many mismatches. Triage burden grows. Mitigation: fix biggest class first (likely a single manifest field or gen_atlas dispatch case).

**G23 — Animation state alignment.** Some NES tiles (sword swing, candle flame) are frame-dependent. Probe captures specific frame N. If Genesis renders frame M ≠ N, pixel diff non-zero even though both are correct in their phase. Mitigation: V5 ticket documents these as "animation phase mismatch — both engines correct, capture timing differs"; fix probe to sync frames if needed.

---

## Cost summary

| Task | Effort |
|---|---|
| V0 items audit fix | 30 min - 3 hr |
| V1 Genesis universal scene | 3-5 hr |
| V2 NES test ROM extension | 4-6 hr |
| V3 re-stage + capture | 1 hr |
| V4 PNG diff toolkit | 2-3 hr |
| V5 iterate per finding | 2-10 hr |
| **Total Phase 4** | **12-28 hr** |

---

## Recommended execution order

1. V0 first (cheap, gates V1 — confirms whether item bugs need fixing)
2. V1 + V2 in tandem (Genesis + NES layouts must mirror)
3. V3 + V4 after both layouts land
4. V5 iteration loop until verification gate passes

Defer redux variant audit to Phase 5 — orig is what user prioritized.

---

# Phase 5: Octorok NES-exact parity (2026-05-19)

**Context.** Phase 4 atlas correctness landed (byte-identical to NES). Phase E0 fixed enemy invisibility (stale SPR_TILE_BASE 1025→533). User now reports "Octorocks have some weird things — make sure spawn location, ai, and movement match NES exactly."

Three-agent investigation (Explore × 3) surfaced these specific divergences from NES reference (`reference/aldonunez/Z_04.asm` + `Z_05.asm`):

**Issue 1 — Fast octorok speed hardcoded.** `src/game/enemies/enemy_walker_bridge.c:689` uses qspeed `0x40` directly. NES `InitFastOctorock` (Z_04.asm:1869) sets `ObjQSpeedFrac = $30`, `UpdateOctorock` (Z_04.asm:2966) doubles via ASL → effective $60. Genesis $40 ≠ NES $60. Slow variants ($07/$09) use $20 which matches NES InitSlowOctorock.

**Issue 2 — Edge-spawn substrate gap.** `src/game/enemies/obj_lists.c:390-399` uses `spawn_pos_list_0` as fallback for `LBA_F bit 3` edge-spawn mode instead of per-direction `FindNextEdgeSpawnCell` (Z_05.asm:1885-1996). Source comment: "Visible parity approximate." Means octorok x/y on screen-edge entries diverges from NES.

**Issue 3 — c_shoot_if_wanted is stub returning 0.** `src/game/enemies/enemy_walker_bridge.c:742` calls `c_shoot_if_wanted(0x53u, slot)` but the implementation returns 0 always. Octoroks NEVER fire rocks. Per NES `_TryShooting` (Z_04.asm:1975-2019) red octoroks gate on `Random+slot >= $F8` + `ShootTimer != 0`; blue skip gate.

**Issue 4 — Spawn list parser may have data-set drift.** `obj_lists.c:226-291` reads `LevelBlockAttrsC/D` and dispatches to template_id. Need byte-verify per-room count + ObjType[1..N] matches NES at room enter.

**Issue 5 — Walker turn rate.** Blue ObjType $09+ uses `ENEMY_AIR_SPEED = 0xA0`; red = $70. NES values per `UpdateOctorock` need direct verify.

**Files to modify (per ticket):**
- `src/game/enemies/enemy_walker_bridge.c` — speed fix (Issue 1), shoot wiring (Issue 3)
- `src/oracle/enemies/c_wanderer.c` — turn rate verify (Issue 5)
- `src/game/enemies/obj_lists.c` — edge-spawn substrate (Issue 2), spawn list audit (Issue 4)
- `src/game/enemies/enemy_common_bridge.c` (or similar) — `c_shoot_if_wanted` real impl (Issue 3)

**Reuse:**
- `build/probes/octorok_shoot.lua` — force-spawn + shoot monitor
- `build/probes/octorok_audit.lua` — spawn placement + LBA cells dump
- `build/probes/octorok_visual.lua` — room $67 walk + screenshot
- `docs/audit/enemy_parity/spawn_graph.md` — type $07/$08/$09/$0A → $53/$54 spawn graph
- NES asm: `reference/aldonunez/Z_04.asm:1864` (InitSlow), `:1869` (InitFast), `:1975` (_TryShooting), `:2966` (UpdateOctorock)

---

## Task O1: Capture NES + Genesis baseline (RULE ZERO probe before code)

**Why.** Per CLAUDE.md RULE ZERO — never guess. Capture live NES Z1 + Genesis at the same room/state, byte-diff RAM + OAM + SAT, then code.

**Steps:**
- [ ] O1.1: Pick reference room. Room $67 (existing octorok_visual.lua) — overworld, 2 octorok spawns. Document selected room + frame # for capture.
- [ ] O1.2: Save NES BizHawk state at room-enter frame to `build/probes/states/nes_octorok_room67.State`. Manual play OR scripted nav.
- [ ] O1.3: Save Genesis BizHawk state similarly to `nes_octorok_room67_gen.State` (use MODE_TELEPORT to reach $67).
- [ ] O1.4: Write `build/probes/octorok_baseline_capture.lua` — load state, idle N frames, dump RAM [$0028+1..0028+11] (ObjY), [$0070+1..0070+11] (ObjX), [$034F+1..034F+11] (ObjType), [$0405+1..0405+11] (ObjDir), [$04A0+1..04A0+11] (ObjQSpeedFrac), [$04F0+1..04F0+11] (ObjInvTimer). Plus OAM 256 B + SAT region.
- [ ] O1.5: Run both ROMs through capture. Diff RAM byte-by-byte across 60 frames post-room-enter.

**Verification.** Byte-diff produces a "spawn-time RAM signature" + "frame-by-frame movement signature." Divergence locations point to specific fix sites.

**Cost: 1-2 hr.**

---

## Task O2: Fix Issue 1 — fast octorok speed $40 → $60

**Why.** NES `InitFastOctorock` (Z_04.asm:1869) sets ObjQSpeedFrac = $30. NES `UpdateOctorock` (Z_04.asm:2966 area) doubles ObjQSpeedFrac via ASL each frame → effective qspeed = $60 (per ASL of $30). Genesis hardcodes $40 at `enemy_walker_bridge.c:689` short-circuiting both the source $30 store and the doubling rule.

**Files:**
- Read `src/game/enemies/enemy_walker_bridge.c:680-720` to confirm exact line
- Read `src/oracle/enemies/enemy_walker_runtime.c:84-90` for init function

**Steps:**
- [ ] O2.1: Determine intended encoding. Either:
  - (a) Match NES exactly: store $30 in ObjQSpeedFrac, ASL in update path → $60 effective
  - (b) Pre-compute: store $60 directly, skip ASL
  - (a) is byte-NES-exact; (b) is functionally equivalent but loses ABI fidelity
- [ ] O2.2: Apply chosen fix. Prefer (a) — store $30, ensure ASL doubles per NES.
- [ ] O2.3: Build + capture Genesis frame-by-frame ObjQSpeedFrac. Byte-equal NES capture from O1.

**Cost: 30 min - 1 hr.**

---

## Task O3: Fix Issue 3 — implement c_shoot_if_wanted (rock projectile)

**Why.** Octoroks never shoot due to stub. NES `_TryShooting` (Z_04.asm:1975-2019) is well-defined:

1. Type check: $09/$0A blue → skip RNG gate; $07/$08 red → check `Random[$19] < $F8`
2. ShootTimer check: red gates on != 0
3. On pass: find empty enemy slot (FindEmptyMonsterSlot scan)
4. Init new slot with type $53 (FlyingRock)
5. Set ShootTimer cooldown

**Files:**
- Read `src/game/enemies/enemy_walker_bridge.c:692-751` for current stub call
- Read `src/game/enemies/enemy_common_bridge.c:88-115` for FindEmptyMonsterSlot ref
- Read `src/oracle/enemies/c_shoot_if_wanted.c` if exists (likely shell/stub)

**Steps:**
- [ ] O3.1: Read NES `_TryShooting` Z_04.asm:1975-2019 end-to-end. Record exact RNG offset (Random+slot? Random+$19?), exact cooldown frames, exact init-slot args.
- [ ] O3.2: Port full body into `c_shoot_if_wanted` impl. Match NES byte-for-byte for RNG comparisons.
- [ ] O3.3: Force-RNG seed via `build/probes/octorok_shoot.lua` — verify shoot fires at same frame on both ROMs given identical Random[$19] value.
- [ ] O3.4: Byte-verify ENEMY_SHOT_COUNT + new slot ObjType[$53] populates at exact same frame.

**Cost: 1-3 hr** (depends on RNG plumbing).

---

## Task O4: Fix Issue 2 — edge-spawn substrate gap (FindNextEdgeSpawnCell)

**Why.** `obj_lists.c:390-399` fallback to `spawn_pos_list_0` for LBA_F bit 3 edge-spawn diverges from NES `FindNextEdgeSpawnCell` (Z_05.asm:1885+). Source comment self-flags: "Visible parity approximate."

**Files:**
- `src/game/enemies/obj_lists.c:358-496`
- NES `reference/aldonunez/Z_05.asm:1885-1996`

**Steps:**
- [ ] O4.1: Read NES FindNextEdgeSpawnCell + AssignObjSpawnPositions end-to-end.
- [ ] O4.2: Port full per-direction logic into `enemy_assign_spawn_positions` — replacing the fallback.
- [ ] O4.3: Per-room byte-verify spawn x/y against NES at room enter (Task O1 baseline reused).

**Cost: 2-4 hr.**

---

## Task O5: Verify Issues 4 + 5 — spawn list parse + walker turn rate

**Why.** Issues surfaced by Explore agent but not yet root-traced. Need direct byte-diff.

**Files:**
- `src/game/enemies/obj_lists.c:226-291` (load_objects)
- `src/oracle/enemies/c_wanderer.c:7-20` (target_player + turn rate)
- NES `Z_05.asm:1700-1820` (InitMode_EnterRoom monster parse)

**Steps:**
- [ ] O5.1: For each octorok-bearing room (compile list from data/rooms/overworld.c), diff Genesis ObjType[1..N] vs NES at room enter.
- [ ] O5.2: Diff ENEMY_AIR_SPEED (turn rate) per-type ($07/$08 red = $70; $09/$0A blue = $A0). Confirm NES uses same values.
- [ ] O5.3: If any divergence, fix at root in either obj_lists or c_wanderer.

**Cost: 1-2 hr.**

---

## Task O6: Final verification — frame-by-frame parity

**Why.** Confirm octorok behavior matches NES exactly across N representative scenarios.

**Steps:**
- [ ] O6.1: Re-capture both ROMs at room $67 (and 2-3 other octorok rooms for variety: $63, $69, $7A).
- [ ] O6.2: 60-frame byte-diff: ObjX, ObjY, ObjType, ObjDir, ObjQSpeedFrac, ObjFrame for all 11 slots.
- [ ] O6.3: 60-frame OAM/SAT diff: octorok tile_ids + positions match.
- [ ] O6.4: Force-RNG identical seed; verify shoot timing matches.
- [ ] O6.5: Document any remaining divergences in `docs/atlas/octorok_parity.md`.

**End condition:** Either 0 byte mismatches across 60-frame window OR every mismatch documented as accepted divergence with reason.

**Cost: 2-3 hr.**

---

## Cost summary (Phase 5)

| Task | Effort |
|---|---|
| O1 NES + Genesis baseline capture | 1-2 hr |
| O2 Fast octorok speed fix | 30 min - 1 hr |
| O3 c_shoot_if_wanted impl | 1-3 hr |
| O4 Edge-spawn substrate port | 2-4 hr |
| O5 Spawn list + turn rate verify | 1-2 hr |
| O6 Final frame-by-frame parity | 2-3 hr |
| **Total Phase 5** | **8-15 hr** |

---

## Execution order

1. **O1 first** — baseline RAM/OAM signatures (RULE ZERO gate)
2. **O5 in parallel with O2** — spawn parse + turn rate verify is read-only audit; speed fix is small
3. **O3** — shoot impl (largest single task)
4. **O4** — edge-spawn port (depends on baseline understanding from O1)
5. **O6** — final gate

---

## Risks

- **G24 — Spawn list NES-asm complexity.** AssignObjSpawnPositions has branched logic per direction + room geometry. Full port may exceed 4 hr estimate.
- **G25 — RNG plumbing for shoot impl.** Random table read must match NES exactly; if Genesis uses different RNG advance order, shoot timing diverges even if RNG values match.
- **G26 — Wanderer behavior.** c_wanderer.c is a shared primitive — modifying for octorok may affect Lynel/Moblin/etc. Verify scope before edit.

---

# Phase 5b: Octorok parity revised plan (2026-05-19 post-baseline)

**Context revision.** Original Phase 5 hypothesized O4 (FindNextEdgeSpawnCell substrate gap) as primary cause. After O1 baseline capture with CORRECTED RAM addresses (prior probe used wrong ObjY/ObjDir offsets — ObjY = $0084, ObjDir = $0098 per Variables.inc, NOT $0028/$0008):

- LBA_F[$67] = $40 on BOTH ROMs (bit 3 CLEAR) — edge-spawn branch NOT taken.
- Real divergences = D1 (spawn position drift), D3 (over-init), D2/D4 (cascades).

**Real Phase 5b tasks** (replaces O2-O6 from Phase 5):

## Task O5b.1: Genesis defers init via Genesis-equivalent ObjUninitialized

**Why.** Genesis `enemy_room_load_objects()` (enemy_loop.c:1169-1199) fires `enemy_init_fns[type](slot)` synchronously for all N slots at room load. NES Z_07.asm:5240-5267 defers: each slot has `ObjUninitialized` flag, set $FF at room load; per-frame `UpdateObject` reads flag, calls `InitObject` once per slot when ready.

NES InitObject (Z_07.asm:5466+) further gates on `LevelBlockAttrsByteF bit 3 + MonstersFromEdgesLongTimer` — if non-zero, RESETS uninit flag → defers init another frame.

**Substrate problem.** NES `ObjUninitialized` at $0492 is REPURPOSED in Genesis as `ENEMY_ALIVE_FLAG` with OPPOSITE polarity (1=alive vs $FF=uninit). Per `src/game/enemies/enemy_walker_bridge.c:820-848` comment, this conflict is documented but unresolved.

**Approach options:**
- (a) Move ENEMY_ALIVE_FLAG to a NEW Genesis-private RAM cell (say $07XX in unused range). Reclaim $0492 for NES ObjUninitialized semantics.
- (b) Add a SEPARATE Genesis-private "init_done" cell. ALIVE_FLAG stays. Skip-init-if-done pattern.

Option (a) is byte-NES-exact. Option (b) less invasive.

**Files:**
- `src/state/enemy_state.h` — define new ENEMY_UNINIT_FLAG macro
- `src/abi/platform_abi.h` — reserve unused $07XX range
- `src/game/enemies/enemy_loop.c:1169-1199` — replace synchronous init with "mark uninit, defer to per-frame loop"
- `src/game/enemies/enemy_loop.c` (per-frame tick) — add UpdateObject equivalent that picks up uninit slots
- Reference NES `Z_07.asm:5240-5267` (UpdateObject preamble) + `:5466-5550` (InitObject gate)

**Cost: 3-5 hr.** Risk: cascade across all enemy types (Lynel/Moblin/Goriya/etc).

## Task O5b.2: DUNGEON_SPAWN_CYCLE persistence across rooms

**Why.** D1 (spawn X/Y drift) likely due to `SpawnCycle` cell ($524 NES) holding different values at room enter on NES vs Genesis. NES uses persistent SpawnCycle that affects spawn list cycle index.

**Files:**
- `src/game/enemies/obj_lists.c:380-462` (uses DUNGEON_SPAWN_CYCLE)
- NES `Z_05.asm:1900+` reads/writes SpawnCycle

**Steps:**
- [ ] O5b.2.1: Probe Genesis DUNGEON_SPAWN_CYCLE value at room enter for several rooms; compare to NES SpawnCycle.
- [ ] O5b.2.2: If divergence, trace WHEN NES writes SpawnCycle (room transition? boss kill? specific events).
- [ ] O5b.2.3: Match Genesis write-back logic.

**Cost: 2-3 hr.**

## Task O5b.3: IsSafeToSpawn byte-exact verify

**Why.** D1 may also be IsSafeToSpawn semantics drift. Genesis `obj_lists.c:332` returns 1=unsafe. NES `Z_05.asm:2006` does similar but exact tile threshold + Link-distance calc may differ.

**Files:**
- `src/game/enemies/obj_lists.c:332-345`
- NES `Z_05.asm:2006-2050` IsSafeToSpawn

**Cost: 1-2 hr.**

## Verification

End condition: re-capture O1 baseline; require:
- All 4 slots: NES type == GEN type ✓ (already)
- All 4 slots: |NES X - GEN X| < $04 and |NES Y - GEN Y| < $04
- All 4 slots: NES dir == GEN dir
- All 4 slots: NES qspd state == GEN qspd state at SAME frame (= same init timing)

## Cost summary (Phase 5b)

| Task | Effort |
|---|---|
| O5b.1 defer init via uninit flag | 3-5 hr |
| O5b.2 SpawnCycle persistence | 2-3 hr |
| O5b.3 IsSafeToSpawn verify | 1-2 hr |
| Re-baseline + verify | 1 hr |
| **Total Phase 5b** | **7-11 hr** |

## Recommended next step

O5b.1 (defer init) is the BIGGEST visible win (eliminates D3 over-init + cascading D4 explosion-sprite). Substrate work but well-scoped.

Start with O5b.1 if continuing octorok parity work.

---

# Phase 7: Pixel-EXACT NES pause inventory subscreen (2026-05-20)

**Context.** User: "Plan out how to get the EXACT EXACT pause screen from the NES. and get it exactly right".

Phase 6 (P6.1-P6.5+P6.7) shipped a WORKING pause subscreen but visibly diverges from NES:
- Text via ASCII→tile LUT vs NES inline tile_id bytes baked from PRG transfer buffers
- Item sprite positions approximated on a fixed grid vs NES exact `SubmenuItemXs` table coords
- Scroll = row-by-row tilemap replacement vs NES VScroll PPU register animation ($EF→$41 over 43 frames)
- No CRAM swap on pause enter (relies on gameplay palette bleed)
- SAT blanking on enter vs NES keeps gameplay sprites frozen
- No NES baseline capture exists — Phase 6 was hand-coded against asm reading, not byte-diffed

User explicitly wants byte-exact NES parity. Per CLAUDE.md RULE ZERO — must capture NES live first, then port, then byte-diff.

---

## Pre-flight: PX0 — clean enemy_render.c merge conflict markers

**Blocker.** `src/game/enemies/enemy_render.c` has `<<<<<<< Updated stashed` markers at lines 58-72, 85-96, 131-143 from prior session merge that never resolved. Build will fail until cleaned. Pick the "Updated stashed" sides (newer) and remove conflict markers.

**File:** `src/game/enemies/enemy_render.c`. ~30 min.

---

## Task PX1: Capture NES pause screen baseline

**Why.** RULE ZERO. Need NES Z1 nametable + OAM + PALRAM + screenshots DURING pause to know what we're porting to. Phase 6 hand-coded from asm reading; this byte-diffs against actual NES PPU state.

**Files (create):**
- `build/probes/nes_pause_capture.lua` — boot Z1, walk into OW room, press Start, freeze, dump VRAM/OAM/PALRAM/screenshot
- Output: `C:/tmp/nes_pause/`

**Steps:**
- [ ] PX1.1: Boot `roms/Legend of Zelda, The (USA).nes`. Skip title → FS → game (use existing nav from `nes_octorok_baseline.lua`).
- [ ] PX1.2: Press Start mid-gameplay to open subscreen.
- [ ] PX1.3: Capture each scroll-in frame (frames 0-43): screenshot + PALRAM (32 B) + nametable region (PPU $2000-$23FF NT0 + $2400-$27FF NT1) + OAM (256 B) + PPU $2002 VScroll readback.
- [ ] PX1.4: Capture SUBSCREEN ACTIVE state at frame 50+: same capture set.
- [ ] PX1.5: Capture scroll-out (Start again): frames 0-43 same shape.
- [ ] PX1.6: Repeat for UW pause (dungeon room) — different tilemap selector data.

Output artifacts: `C:/tmp/nes_pause/ow_scroll_frame_NN.{png,nt.bin,oam.bin,pal.bin,vscroll.txt}`, same for UW. Plus archived to `docs/atlas/nes_pause_capture/`.

**Cost: 1-2 hr.**

---

## Task PX2: Capture Genesis subscreen baseline (current state)

**Why.** Establish current divergence baseline so each subsequent fix can be byte-diffed against NES.

**Files:**
- `build/probes/gen_pause_capture.lua` — mirror NES probe shape on Genesis side
- Output: `C:/tmp/gen_pause/`

**Steps:**
- [ ] PX2.1: Boot `builds/Debug.md`, ABC chord, Start press, frame-by-frame screenshot + VRAM dump (Plane A region $C000-$E000 + SAT $F400-$F47F + CRAM 128 B).
- [ ] PX2.2: Same scroll-in/active/scroll-out coverage as PX1.

**Cost: 1 hr.**

---

## Task PX3: Diff classifier — NES vs Genesis pause states

**Why.** Identify exact divergences per (frame, region). Drive PX4-PX8 fixes data-driven.

**Files (create):**
- `tools/probes/pause_diff.py`
- Output: `docs/atlas/pause_diff.md`

**Steps:**
- [ ] PX3.1: Per scroll frame N:
  - Diff NES nametable cells vs Genesis Plane A cells (after mapping NES tile_id → Genesis VRAM tile via bg_sparse_tile_lut + roomrom_vram_map).
  - Diff NES OAM 64-sprite × 4-byte vs Genesis SAT.
  - Diff NES PALRAM 32 B vs Genesis CRAM 128 B (via misc_palettes lookup, like Phase 4 V4 logical-color diff).
- [ ] PX3.2: Classify divergences:
  - TM_TILE: Genesis cell uses wrong tile_id
  - TM_ATTR: wrong sub-pal in cell attribute
  - SPR_POS: sprite at wrong X/Y
  - SPR_TILE: sprite wrong tile_id
  - SPR_PAL: sprite wrong palette
  - CRAM: palette entry wrong color
  - SCROLL: VScroll value differs per frame
  - SAT_MISS: NES sprite present, Genesis missing
  - SAT_EXTRA: Genesis sprite present, NES missing
- [ ] PX3.3: Emit pause_diff.md catalog with per-frame divergence list + fix-site mapping.

**Cost: 2-3 hr.**

---

## Task PX4: Port SubmenuTransferBufSelectors + tilemap blob

**Why.** Replace hand-coded `write_text()` + ASCII LUT with NES-exact tile_id sequences baked from the Z_05.asm:6754+ transfer buffers.

**Files:**
- Read NES `reference/aldonunez/Z_05.asm:6754-6869` (Submenu_CueTransferRowUW + OW)
- Create `src/game/inventory/inventory_tilemap.{c,h}` — static const blob of (row, col, tile_id, sub_pal) entries
- Modify `src/game/inventory/inventory_render.c` `write_inventory_row()` to consume the blob

**Steps:**
- [ ] PX4.1: Extract transfer-buffer rows from NES PRG. Either:
  - (a) Dump live via PX1 capture (NES NT bytes show exact tile_ids)
  - (b) Author Python tool to walk Z_05.asm transfer-buffer pointers + dump bytes
- [ ] PX4.2: Generate `inventory_tilemap.c` with one C const array per row index (rows 0..20 for OW pause, 0..12 + map cells for UW pause).
- [ ] PX4.3: Modify write_inventory_row to look up row's tile array from blob + write via render_plane_a_write_row.
- [ ] PX4.4: Verify via PX3 diff — TM_TILE + TM_ATTR counts drop to 0.

**Cost: 3-4 hr.**

---

## Task PX5: Port SubmenuItemXs + DrawItemInInventory exact coordinates

**Why.** Replace approximated 16-px-stride grid with exact NES coord table.

**Files:**
- Read NES `reference/aldonunez/Z_05.asm:7803-7898` SubmenuItemXs / Ys + Z_07.asm:868 DrawItemInInventory + 7869+ palette/tile offset routines
- Modify `src/game/inventory/inventory_render.c` `draw_item_sprites()` to use exact tables

**Steps:**
- [ ] PX5.1: Extract SubmenuItemXs (16-entry table per Phase 1 agent: `$80,$98,$AC,$B4,$C8,$80,$98,$B0,$C8,$80,$94,$A0,$B0,$C0,$CC,$B0`). Hardcode as `const unsigned char k_submenu_item_xs[16]`.
- [ ] PX5.2: Extract Y coords per slot range (slot <5 → $36, 5-9 → $46, $1E for compass/map, $9E compass, $76 map).
- [ ] PX5.3: Each item = 2 sprites (left + right halves). Update draw_item_icon to emit pair.
- [ ] PX5.4: Port DrawItemBySlot palette routing (Z_07.asm:878-924) — slots with color-vary route to per-item palette offset; flashing slots cycle.
- [ ] PX5.5: Verify via PX3 — SPR_POS + SPR_TILE counts drop.

**Cost: 3-4 hr.**

---

## Task PX6: Port cursor exact behavior

**Why.** Phase 6 cursor uses placeholder COMPASS tile + arbitrary x stride. NES uses tile $1E with specific flash routine.

**Files:**
- Read `Z_05.asm:7909-8003` SubmenuCursorXs + cursor draw routine
- Modify `src/game/inventory/inventory_render.c` `draw_cursor()`

**Steps:**
- [ ] PX6.1: SubmenuCursorXs hardcode: `$80,$98,$B0,$B0,$C8,$80,$98,$B0,$C8`.
- [ ] PX6.2: Cursor uses NES tile $1E (small white square). Verify tile_id is in BG sparse atlas OR add force-include to gen_bg_sparse.py.
- [ ] PX6.3: Emit two cursor sprites: left at (X, Y), right at (X+8, Y) with hflip attribute.
- [ ] PX6.4: Flash palette: `(FrameCounter & 0x08) ? PAL6 : PAL5` per Z_05.asm:7942 (AND #$08, LSR x3, ADC #$01). PAL5/6 are NES sprite palettes 1/2; Genesis routes to PAL2/PAL3.
- [ ] PX6.5: Y position from slot range (matches item Y).

**Cost: 1-2 hr.**

---

## Task PX7: Port UpdateMenu VScroll state machine

**Why.** Real NES scroll via PPUSCROLL register, not row replacement. Genesis equivalent: VSRAM[0] animation on Plane A.

**Constraint.** Plane A in PR-2 Option F = 64x32 cells = 512x256 px. NES does scroll between 2 nametables ($2000 + $2400). On Genesis, the equivalent is Plane A scroll wrap OR write subscreen to BOTH halves of Plane A (rows 0..27 gameplay, rows 28..55 inventory) and use VSRAM to slide.

But 32-row plane has only 32-28=4 rows of headroom below gameplay. Won't fit 28 rows of inventory.

**Solutions:**
- (a) Switch Plane A to 64x64 mode (512x512 px). Allows 28 gameplay + 28 inventory + scroll between.
- (b) Use Plane B for subscreen. Plane B normally idle during gameplay; populate it with inventory tilemap; on pause, raise Plane B priority + lower Plane A. Scroll Plane B vertically.
- (c) Keep current row-replacement BUT animate via VScroll for cosmetic illusion (NES-style without nametable swap).

**Recommended:** (b) — Plane B for subscreen. Lowest risk to existing gameplay rendering.

**Files:**
- Modify `src/game/inventory/inventory_render.c` to write tilemap to Plane B ($E000) instead of Plane A
- Modify `src/sgdk_adapter/render_adapter.c` for plane priority swap helper
- Modify VSRAM write helpers to animate Plane B VSCROLL

**Steps:**
- [ ] PX7.1: Move all inventory tilemap writes from PLANE_A_BASE (0xC000) to 0xE000.
- [ ] PX7.2: At pause enter: raise Plane B priority (VDP reg 12 / per-cell priority bit).
- [ ] PX7.3: Animate VSRAM[2] (Plane B vscroll) from $EF down to $41 over 43 frames (3 px/frame matches NES decrement).
- [ ] PX7.4: At pause exit: animate VSRAM[2] back $41 → $EF, then lower priority, then load_room.
- [ ] PX7.5: Verify via PX3 — SCROLL count drops to 0.

**Cost: 3-5 hr.** (Plane priority + 2-plane coordination is fiddly.)

---

## Task PX8: CRAM swap on pause enter/exit

**Why.** NES loads subscreen-specific palette. Genesis currently bleeds gameplay palette.

**Files:**
- Capture NES PALRAM during pause via PX1
- Create `src/game/inventory/inventory_palette.{c,h}` — static const subscreen palette blob
- Modify `inventory_subscreen_enter` to swap CRAM PAL2/PAL3 (or whichever) to subscreen colors
- `inventory_subscreen_exit` to restore (via `load_room` reload of room palette)

**Steps:**
- [ ] PX8.1: Extract NES PALRAM bytes during pause from PX1 capture. Should be 32 B (16 BG + 16 SPR).
- [ ] PX8.2: Convert each NES color via port `misc_palettes` lookup → Genesis CRAM word.
- [ ] PX8.3: Author `inventory_subscreen_palette[16]` array (or 32 if multiple sub-pals).
- [ ] PX8.4: On enter: render_load_palette(0..3 as needed) with subscreen colors.
- [ ] PX8.5: On exit: gameplay palette restored by load_room.

**Cost: 1-2 hr.**

---

## Task PX9: Final pixel-exact verification

**Why.** Confirm byte-for-byte match across all captured frames.

**Steps:**
- [ ] PX9.1: Re-run PX1 + PX2 captures.
- [ ] PX9.2: Re-run PX3 classifier.
- [ ] PX9.3: End condition: TM_TILE = TM_ATTR = SPR_POS = SPR_TILE = SPR_PAL = CRAM = SCROLL = 0 across all 100+ captured frames.
- [ ] PX9.4: PNG mosaic comparison via existing `tools/probes/png_diff_atlas.py` adapted for pause states.
- [ ] PX9.5: Document any accepted divergence (e.g. Genesis CRAM quantization noise per Phase 4 V5 closure) in `docs/atlas/pause_parity.md`.

**Cost: 2-3 hr.**

---

## Critical files to modify

| File | Changes |
|---|---|
| `src/game/enemies/enemy_render.c` | PX0 — strip merge conflict markers (~3 hunks) |
| `src/game/inventory/inventory_render.c` | PX4 (tilemap blob lookup) + PX5 (exact item coords) + PX6 (cursor) + PX7 (Plane B + VScroll) + PX8 (palette load) |
| `src/game/inventory/inventory_render.h` | API additions for tilemap blob + plane swap |
| `src/game/inventory/inventory_tilemap.{c,h}` | NEW — NES PRG-extracted subscreen tilemap blob |
| `src/game/inventory/inventory_palette.{c,h}` | NEW — subscreen CRAM palette blob |
| `RoomRom/src/main.c` | Possibly PX7 plane priority swap on enter/exit |
| `tools/debug/build_debug.py` | Wire new TUs |
| `build/probes/nes_pause_capture.lua` | NEW — NES baseline |
| `build/probes/gen_pause_capture.lua` | NEW — Genesis baseline |
| `tools/probes/pause_diff.py` | NEW — classifier |

## Existing functions to reuse

- `src/state/inventory.h` — `inventory_t g_inventory` already populated by P6.1 debug_unlock_all_items
- `src/abi/render_abi.h` — `render_plane_a_write_row`, `render_plane_fill`, `render_load_palette`, `render_vram_open_write`, `render_set_sprite_full`, `RENDER_SPRITE_SIZE`, `RENDER_TILE_ATTR_FULL`
- `RoomRom/src/bg_sparse_chr.h` — `bg_sparse_tile_lut` for tile_id→VRAM slot
- `RoomRom/src/atlas/items_chr_x4.h` — `ROOMROM_ITEM_TILE_*` constants
- `src/game/world/bg_palette.h` — `roomrom_bg_palette_nes_to_cram` for NES→CRAM color conversion
- `data/misc/palettes.c` — `misc_palettes[]` lookup table
- `tools/probes/png_diff_atlas.py` — V4 3-mode diff toolkit (adapt for pause states)

## Verification

End condition (all must hold):
1. `tools/probes/pause_diff.py` reports 0 byte mismatches across ALL captured frames (scroll-in + active + scroll-out, OW + UW)
2. Visual mosaic PNG: NES side-by-side Genesis indistinguishable (modulo accepted CRAM quantization noise)
3. Frame timing: scroll completes in exactly 43 frames matching NES
4. Cursor flashes at 8-frame interval matching NES
5. B-item selection (A press) writes nes_ram[$0656] with same value at same frame

---

## Cost summary

| Task | Effort |
|---|---|
| PX0 enemy_render.c merge cleanup | 30 min |
| PX1 NES pause capture | 1-2 hr |
| PX2 Genesis pause capture | 1 hr |
| PX3 diff classifier | 2-3 hr |
| PX4 tilemap blob port | 3-4 hr |
| PX5 item exact coords | 3-4 hr |
| PX6 cursor exact behavior | 1-2 hr |
| PX7 VScroll Plane B | 3-5 hr |
| PX8 CRAM swap | 1-2 hr |
| PX9 verification | 2-3 hr |
| **Total Phase 7** | **17-26 hr** |

---

## Execution order

1. **PX0** — unblocks build
2. **PX1 + PX2** — captures BEFORE any port work (RULE ZERO)
3. **PX3** — classifier built from captures
4. **PX4** — biggest visual fix (replace text labels with NES tilemap)
5. **PX5 + PX6** — item icons + cursor exact
6. **PX7** — VScroll animation (cosmetic but visible)
7. **PX8** — palette restoration
8. **PX9** — verification gate

---

## Risks

- **GP1 — Plane B priority swap may interact with HUD on Window.** Window plane covers top rows for HUD; subscreen on Plane B may render behind/above Window. Need to verify HUD visibility during pause matches NES.

- **GP2 — Plane B size mismatch.** Plane B is currently 64x32 cells = 256 px tall in PR-2 Option F. NES subscreen is 30 rows = 240 px. Fits if we trim 2 rows. Otherwise need 64x64 mode + bigger plane reconfig.

- **GP3 — VSRAM scroll wrap.** 32-row plane wraps at 256 px. NES subscreen spans across nametable boundary via VScroll up to $EF (=239). Need Plane B at 64x64 (512 px tall) for clean range.

- **GP4 — NES subscreen CHR may not be in atlas.** NES subscreen uses tile_ids that may not be in current BG sparse LUT or items_chr_x4 atlas. PX1 capture will reveal which tile_ids are needed; PX4 may force-include them via gen_bg_sparse.py.

- **GP5 — Item palette routing.** NES uses cycling palette per item slot (slots 0/2/4/7/B color-vary, slots $16/$19/$1A/$1B flash). Genesis OAM pal field has 2 bits = 4 palettes. May need ephemeral CRAM swap per-frame for full NES color rotation fidelity.

- **GP6 — Frame timing mismatch.** Genesis runs SGDK VBlank chain at 60 Hz; NES NTSC also 60 Hz. Scroll-frame counts should map 1:1 but DMA queue / cache flushes may add latency.

- **GP7 — User-modified enemy_render.c stashed changes.** Resolve the merge conflict to whichever side compiles (likely "Updated stashed") and verify enemy rendering still works after. Phase E0 fix may be inside one side.

---

# Phase 6: Pause Inventory Subscreen (2026-05-19)

**Context.** User: "time to do the whole pause interface. When I hit start it needs to match [NES]. For now. The debug mode can have all items unlocked."

**Current state after 3-agent investigation:**

1. **Pause TOGGLE works.** `RoomRom/src/main.c:2281` — bare START edge-press calls `roomrom_pause_toggle_voluntary()`. Sets `g_paused` flag, freezes AI ticks at line 1751/1874. Pause input swallow at 2289. NES-spec voluntary/involuntary state machine in `src/state/pause_state.c`.

2. **Inventory SUBSCREEN NOT rendered.** Pause pauses, but no UI change. HUD keeps refreshing on Window plane. Plane A keeps showing gameplay frozen.

3. **Inventory STATE fully wired.** `src/state/inventory.h` + `.c` mirror NES $657-$67E byte-for-byte. All 27+ items tracked. Save/load works (3-slot SRAM, src/state/save_serializer). **Gap:** sword_level lives in ObjMetastate ($0AC), no persistent cell.

4. **NES reference clean.** `Z_05.asm:152-350` `UpdateMenuAndMeters` + `UpdateMenu` state machine. Scroll-based transition: VScroll from $EF down to $41 over ~22 frames; row-by-row transfer via `SubmenuTransferBufSelectorsUW/OW`; `Submenu_CueTransferRowUW/OW` queues subscreen tiles per row. Item icons drawn as sprites via `DrawItemInInventory` (`Z_07.asm:868-924`). State cells: `MenuState` $E1, `SubmenuScrollProgress` $5E, `CurScanRoomId` $5D.

5. **Genesis layout differences from NES.** NES PPU vertical scroll between two nametables = one technique. Genesis VDP has independent Plane A + Plane B + Window. Cleanest match: vertical scroll Plane A; subscreen lives in Plane A rows below visible (or above, depending on encoding).

**Goal.** Pressing Start mid-gameplay opens the NES Z1 inventory subscreen — visually + functionally byte-equivalent: scroll-in animation, item icons in correct slots, B-item cursor, map view, dungeon info. Debug build pre-fills all items unlocked.

**Scope cuts for V1:**
- Match NES VISUAL — items, layout, cursor (priority)
- Match NES TIMING — scroll speed, frame counts (priority)
- Subscreen for OW (Triforce + items) AND UW (dungeon map + items) (priority)
- Map view with room-visit tracking (priority)
- Cursor wraparound + selection sound (P2)
- Compass arrow pointing at triforce (P2)

---

## Task P6.1: Debug "all items unlocked" helper

**Why.** User explicitly requested for Debug.md. Lets user immediately see populated inventory subscreen without playing through Z1 to collect items.

**Files:**
- Create: `src/game/items/debug_unlock_all.c` + `.h`
- Wire-in: `src/debug/a4_probe_main.c` debug_enter path

**Steps:**
- [ ] P6.1.1: New `debug_unlock_all_items()` function. Set every `inventory_t` field to max:
  - items bitfield = 0xFF (all 8 base items)
  - bombs = max_bombs = 16
  - arrow = 2 (silver), bow = 1
  - candle = 2 (red), food = 1, potion = 2 (red)
  - raft = book = ladder = magic_key = bracelet = letter = 1
  - ring = 2, compass_q1 = compass_l9 = map_q1 = map_l9 = 0xFF (all dungeons)
  - rupees = 255 (or 999 if 16-bit), keys = 99
  - heart_values = 0xFF (max 8 hearts), heart_partial = 0
  - triforce = 0xFF (all 8 pieces collected)
  - boomerang_wood = boomerang_magic = magic_shield = 1
  - sword_level needs separate handling — write to ObjMetastate(0) or wherever Link sword tier reads from
- [ ] P6.1.2: Call once at debug_enter gameplay path (after roomrom_debug_enter or in main_loop init).
- [ ] P6.1.3: Build + verify via probe — read inventory_t cells, confirm populated.

**Cost: 30-60 min.**

---

## Task P6.2: Inventory subscreen BG CHR + tilemap

**Why.** Need to know which tiles render the subscreen layout. NES uses dedicated subscreen CHR + nametable rows.

**Files:**
- Read NES `Z_05.asm:6763` (Submenu_CueTransferRowUW), `:6837` (OW) — list which tile_ids per row
- Genesis BG sparse atlas already includes most BG tiles per Phase 4 audit; verify subscreen tiles ($00..$2F text glyphs, item-icon background, map cells) are in LUT
- Likely need: src/game/inventory/inventory_render.c + .h (new files)

**Steps:**
- [ ] P6.2.1: Trace NES UpdateMenu State 0 init — what tile bytes get loaded for subscreen? Output: list of NES tile_ids referenced.
- [ ] P6.2.2: Verify Genesis BG sparse atlas has all those tile_ids for OW + UW sub-pals. Run `tools/probes/full_atlas_audit_v2.py` and check.
- [ ] P6.2.3: Build static subscreen nametable layout — 32 columns × ~24 rows describing the inventory layout (item slots, map area, text labels).
- [ ] P6.2.4: Write `inventory_build_nametable(target_buf, ow_vs_uw)` — fills 32×24 attribute buffer with tile_ids + sub_pals.

**Cost: 2-3 hr.**

---

## Task P6.3: Scroll-in animation

**Why.** NES scrolls subscreen DOWN from above (or UP from below — TBD by reading $E1 MenuState). VScroll register animates over ~22 frames.

**Genesis approach.** Two options:
- **(a) Plane A vertical scroll.** Write subscreen tilemap to Plane A rows above visible area; animate VSRAM[0] to scroll plane down. Mirrors NES exactly.
- **(b) Plane B for subscreen.** Plane B always has inventory; Plane A scrolls down + Plane B scrolls into view. Possibly higher-quality animation but more complex.

Option (a) recommended.

**Files:**
- New: `src/game/inventory/inventory_runtime.c`
- Modify: `RoomRom/src/main.c` pause flow (route to inventory_runtime when paused)

**Steps:**
- [ ] P6.3.1: Map NES UpdateMenuCommon1-5 (`Z_05.asm:190-350`) per-state behavior to scroll progression.
- [ ] P6.3.2: Write `inventory_runtime_tick()` — called per-frame when g_paused != OFF. Reads MenuState ($E1) + SubmenuScrollProgress ($5E), advances scroll position.
- [ ] P6.3.3: VSRAM write to Plane A vscroll slot 0 each frame.
- [ ] P6.3.4: At scroll-complete state, swap input handler from pause-resume to subscreen-input.

**Cost: 3-4 hr.**

---

## Task P6.4: Item icons (sprite-based render)

**Why.** Subscreen renders item icons (sword, bow, boomerang, etc.) as SPRITES over the BG. NES DrawItemInInventory (`Z_07.asm:868`) per-slot.

**Files:**
- Existing `RoomRom/src/atlas/items_chr_x4.h` — item tile constants already
- New: `src/game/inventory/inventory_sprites.c`

**Steps:**
- [ ] P6.4.1: For each inventory slot 0..31, lookup item ownership + select tile_id from items_chr_x4.
- [ ] P6.4.2: Write SAT entries (Genesis VDP_setSprite) for each owned item at the slot's screen position.
- [ ] P6.4.3: Sub-pal routing — selected B-item flashes (cycle CRAM pal entry).
- [ ] P6.4.4: Empty slots stay blank (no sprite written).

**Cost: 2-3 hr.**

---

## Task P6.5: B-item cursor + selection input

**Why.** D-pad moves cursor between B-item-slot positions. A selects. NES SelectedItemSlot ($656) updated.

**Files:**
- `src/game/inventory/inventory_input.c` (new)
- Cursor sprite rendered via inventory_sprites.c

**Steps:**
- [ ] P6.5.1: Read D-pad edge-press from joypad state. Compute new cursor position.
- [ ] P6.5.2: Render cursor sprite (NES uses small ornamental tile) at current slot.
- [ ] P6.5.3: A press: write SelectedItemSlot ($656) — Link gameplay reads this for B-item.

**Cost: 1-2 hr.**

---

## Task P6.6: Map view

**Why.** Subscreen shows the OW or UW dungeon map. Highlights visited rooms. Per-quest map state.

**Files:**
- `src/game/inventory/inventory_map.c` (new)
- Reads existing room-visit tracking (search for `visited_rooms` or similar)

**Steps:**
- [ ] P6.6.1: Find existing visited-rooms bitmap or add one.
- [ ] P6.6.2: Render 8×16 (OW) or 8×8 (UW) map grid using BG tiles, highlight visited rooms.
- [ ] P6.6.3: Show Link's current room marker.
- [ ] P6.6.4: Compass arrow → pointing at triforce piece location (P2).

**Cost: 2-3 hr.**

---

## Task P6.7: Scroll-out + resume

**Why.** Second Start press scrolls subscreen back out; gameplay resumes.

**Steps:**
- [ ] P6.7.1: Second Start edge-press: transition to MenuState scroll-out states.
- [ ] P6.7.2: Animate VScroll back to $00 over ~22 frames.
- [ ] P6.7.3: At complete: clear pause flag, resume gameplay tick.

**Cost: 30 min - 1 hr.**

---

## Task P6.8: Verification

**Why.** Confirm NES-equivalent visual + timing.

**Steps:**
- [ ] P6.8.1: Capture NES Z1 pause sequence — boot to OW, press Start, screenshot every 8 frames.
- [ ] P6.8.2: Capture Genesis Debug.md pause sequence (with debug-unlock-all populated) similarly.
- [ ] P6.8.3: PNG diff via existing `tools/probes/png_diff_atlas.py` adapted for pause-screen states.
- [ ] P6.8.4: Document acceptable divergences in `docs/atlas/inventory_subscreen_parity.md`.

**Cost: 2-3 hr.**

---

## Cost summary

| Task | Effort |
|---|---|
| P6.1 Debug unlock-all helper | 30-60 min |
| P6.2 Subscreen BG CHR + tilemap | 2-3 hr |
| P6.3 Scroll-in animation | 3-4 hr |
| P6.4 Item icons (sprites) | 2-3 hr |
| P6.5 B-item cursor + selection | 1-2 hr |
| P6.6 Map view | 2-3 hr |
| P6.7 Scroll-out + resume | 30-60 min |
| P6.8 Verification | 2-3 hr |
| **Total Phase 6** | **13-21 hr** |

---

## Execution order

1. **P6.1 first** — debug unlock-all is small + makes subsequent verification easy
2. **P6.2 + P6.3 in tandem** — tilemap + scroll-in get visible signal early
3. **P6.4 + P6.5 next** — items + cursor on top of static layout
4. **P6.6** — map view (independent, can defer if time-budget tight)
5. **P6.7** — scroll-out completes the loop
6. **P6.8** — verify

---

## Risks

- **G27 — Plane A vscroll vs HUD on Window.** Window plane covers top rows for HUD; pause-state must keep HUD visible OR transform it into subscreen header. NES HUD becomes part of subscreen during pause. Genesis Window covers absolute screen rows; Plane A scroll under it. Visual cohesion needs care.

- **G28 — Subscreen CHR tiles may not be in current BG sparse LUT.** NES inventory uses tile_ids beyond gameplay scope ($00..$2F text glyphs already present; map cells + item-slot decoration may not be). Phase 4 audit found 532 sparse tiles total — may need to extend.

- **G29 — Sword level cell.** Genesis inventory_t lacks sword_level (lives in ObjMetastate(0)). For "all items unlocked" need to write to actual Link sword cell.

- **G30 — Pause input swallow.** Current pause swallows D-pad input (RoomRom/src/main.c:2289). Subscreen NEEDS D-pad to move cursor. Re-route D-pad to subscreen handler when MenuState != 0.

- **G31 — Save serializer extends.** If sword_level added to inventory_t, save_serializer needs +1 byte. May invalidate existing save slots.

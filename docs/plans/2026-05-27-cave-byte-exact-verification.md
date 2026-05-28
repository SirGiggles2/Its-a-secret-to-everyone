# Cave Byte-Exact Verification Implementation Plan

**Goal:** Prove (or disprove) byte-for-byte that every cave $6A-$7D renders identical sprites + animation frames to NES Zelda 1 — via real NES-vs-Genesis OAM/PALRAM/CHR/animation-cadence byte-diff, not screenshot eyeballing.

**Architecture:** Capture per-frame golden bundles from NES Z1 (NesHawk) at frames {0,8,16,24,60,120} per cave (covers bonfire 2-tile cycle + steady state). Capture same frames from Debug.md. Normalize NES 4-byte OAM → Genesis 8-byte SAT + tile-id translate via MANIFEST.json + PALRAM→CRAM via misc_palettes LUT. Byte-diff each domain. Every mismatch = a real bug to fix. Honest yes/no comes ONLY from the differ exit code.

**Tech Stack:** BizHawk 2.11 Lua (NesHawk + genplus-gx), Python 3.14, existing GDMP/NDMP bundle format, existing nes_to_cram LUT from diff_scenario.py.

**Estimated Time:** 14 tasks × ~20 min = ~5 hours to first per-cave verdict; +N hours fixing each surfaced divergence.

---

## Prerequisites

- [x] NES Z1 ROM at `C:\Users\Jake Diggity\Documents\GitHub\Legend of Zelda, The (USA).nes`
- [x] Debug.md built (current: I0+I1a fixes landed)
- [x] BizHawk at `...\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe`
- [x] Existing: `probe_nes_one.lua`, `probe_one_gen.lua`, `run_sweep.py`, `diff_scenario.py` (STAT/PAL/OBJTYPE only — extend, don't replace)
- [x] `data/chr/MANIFEST.json` (NES tile_id → Gen VRAM) + `data/misc/palettes.c` (NES color → CRAM LUT)

---

## Honest baseline

**What "56/56 PASS" actually means today:** scene == CAVE + ObjType[1] == cave_id. That is DISPATCH. It says NOTHING about whether the bonfire is the right tile, the NPC is the right sprite, the palette byte-matches, or the animation advances at the NES rate.

**This plan replaces "looks right" with a differ exit code.** No claim of byte-perfect is permitted until `cave_byte_diff.py --strict` exits 0.

---

## Task 1: NES multi-frame cave golden probe

**Files:**
- Create: `tools/parity/cave_golden/probe_nes_cave_golden.lua`

**Step 1: Write probe.** Per cave_id $6A..$7D: force cave mode (GameMode=$0B/$0C, RoomId=cave_id, ObjType+1=cave_id, NPC+bonfire slot positions per Z_01.asm:282 SetUpCommonCaveObjects), advance to stable, then capture OAM(256)+PALRAM(32)+CHR(8192) at relative frames {0,8,16,24,60,120}. FrameCounter $0015 forced to 0 at capture-start for determinism. Emit per-cave per-frame bundle.

```lua
-- tools/parity/cave_golden/probe_nes_cave_golden.lua
local CAVE = CAVE_ID or 0x6A
local OUT = string.format("C:\\tmp\\cave_golden\\nes_%02X", CAVE)
local FRAMES = {0, 8, 16, 24, 60, 120}

local function R(o) return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function OAM(o) return memory.read_u8(o, "OAM") end
local function PAL(o) return memory.read_u8(o, "PALRAM") end
local function CHR(o) return memory.read_u8(o, "CHR") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b,h,s) for _=1,h do joypad.set({[b]=true},1); emu.frameadvance() end
  joypad.set({},1); for _=1,s do emu.frameadvance() end end

os.execute('mkdir "' .. OUT .. '" 2>nul')

-- boot (file-select dance, same as probe_nes_full_room_dump.lua:65-74)
idle(360); press("Start",4,60)
press("Down",4,20); press("Down",4,20); press("Down",4,20)
press("Start",4,60); press("Start",4,60)
for _=1,5 do press("Down",4,8) end
for _=1,5 do press("Right",4,8) end
press("Start",4,60); for _=1,5 do press("Up",4,12) end
press("Start",4,180); idle(180)

-- OW briefly to populate SRAM (LBA_E), then force cave
W(0x0010,0x00); W(0x00EB,0x77); W(0x0012,0x06); idle(60)
W(0x062D, QUEST or 1)
W(0x00EB, CAVE)            -- RoomId
W(0x0098, 0x08)           -- Link face up
local mode = (CAVE >= 0x7B) and 0x0C or 0x0B
W(0x0012, mode)
idle(60)                  -- InitCave + InitCaveContinue settle
W(0x0350, CAVE)           -- ObjType+1 = cave_id (post-init, in case overwritten)
W(0x00AD, 0x00)           -- CavePersonState
W(0x00AC, 0x40)           -- Link halt
W(0x0071, 0x78); W(0x0085, 0x80)  -- NPC slot 1 pos
idle(30)
W(0x0015, 0x00)           -- FrameCounter = 0 (determinism)

local prev = 0
for _, target in ipairs(FRAMES) do
  idle(target - prev); prev = target
  local f = io.open(string.format("%s\\f%03d.bin", OUT, target), "wb")
  f:write("NCGD")                                  -- NES Cave GolDen
  f:write(string.char(target & 0xFF))
  for i=0,255 do f:write(string.char(OAM(i))) end  -- OAM 256
  for i=0,31  do f:write(string.char(PAL(i))) end  -- PALRAM 32
  for i=0,8191 do f:write(string.char(CHR(i))) end -- CHR 8KB (BG+SPR pattern)
  f:close()
end
client.screenshot(OUT .. "\\shot.png")
client.exit()
```

**Step 2: Verify probe runs for one cave.** Stage NES ROM, run probe with CAVE_ID=0x6A via prelude.

```bash
cp "C:/Users/Jake Diggity/Documents/GitHub/Legend of Zelda, The (USA).nes" /c/tmp/Z1.nes
printf 'CAVE_ID=0x6A\nQUEST=1\ndofile("...probe_nes_cave_golden.lua")\n' > /c/tmp/nes_cave_prelude.lua
# launch BizHawk via skill, --lua=/c/tmp/nes_cave_prelude.lua /c/tmp/Z1.nes
ls /c/tmp/cave_golden/nes_6A/
```

Expected: `f000.bin f008.bin f016.bin f024.bin f060.bin f120.bin shot.png` each ~8.3KB.

**Step 3: Commit.**
```bash
git add tools/parity/cave_golden/probe_nes_cave_golden.lua
git commit -m "tools(cave-golden): NES multi-frame cave OAM/PAL/CHR probe"
```

---

## Task 2: NES golden sweep orchestrator (20 caves)

**Files:**
- Create: `tools/parity/cave_golden/run_nes_golden.py`

**Step 1:** Clone `run_sweep.py` structure. For each cave_id $6A..$7D: write prelude with CAVE_ID, launch BizHawk + NES ROM, wait for `nes_<id>/f120.bin`, next.

**Step 2: Run.**
```bash
python tools/parity/cave_golden/run_nes_golden.py
ls /c/tmp/cave_golden/ | grep nes_ | wc -l
```
Expected: `20`.

**Step 3: Commit goldens** (binary assets — verification ground truth).
```bash
mkdir -p tools/parity/cave_golden/nes
cp -r /c/tmp/cave_golden/nes_* tools/parity/cave_golden/nes/
git add tools/parity/cave_golden/
git commit -m "tools(cave-golden): 20 NES cave golden bundles (6 frames each)"
```

---

## Task 3: Genesis multi-frame cave golden probe

**Files:**
- Create: `tools/parity/cave_golden/probe_gen_cave_golden.lua`

**Step 1:** Reuse `probe_one_gen.lua` cave-entry path (boot → navigate → force-warp). After cave scene confirmed (s_scene==2), force FrameCounter mirror to 0, capture SAT(640)+CRAM(128)+VRAM(per referenced tiles)+68K-RAM-ObjType at same relative frames {0,8,16,24,60,120}. Emit `gen_<id>/fNNN.bin`.

Key: Gen SAT at VDP, read via existing dom_block("SAT_"). CRAM 128 bytes. For CHR comparison, read VRAM at the tile slots the SAT entries reference.

**Step 2: Verify one cave.**
```bash
# prelude CAVE_ID=0x6A, launch Gen + Debug.md
ls /c/tmp/cave_golden/gen_6A/
```
Expected: 6 frame bundles + shot.png.

**Step 3: Commit.**
```bash
git add tools/parity/cave_golden/probe_gen_cave_golden.lua
git commit -m "tools(cave-golden): Genesis multi-frame cave SAT/CRAM/VRAM probe"
```

---

## Task 4: Genesis golden sweep (20 caves)

**Files:**
- Create: `tools/parity/cave_golden/run_gen_golden.py`

**Step 1-2:** Clone run_nes_golden.py for Debug.md. Run. Expect 20 `gen_<id>/` dirs.

**Step 3: Commit** (gen goldens are regenerated per build — gitignore, or commit only NES side).

---

## Task 5: OAM→SAT normalization library

**Files:**
- Create: `tools/parity/cave_golden/normalize.py`

**Step 1: Write failing test.**
```python
# tools/parity/cave_golden/test_normalize.py
from normalize import nes_oam_to_records, gen_sat_to_records, nes_tile_to_gen
def test_nes_oam_record():
    # NES OAM sprite 0: Y=$80 tile=$5C attr=$02 X=$48
    oam = bytes([0x80,0x5C,0x02,0x48] + [0xF0]*252)
    recs = nes_oam_to_records(oam)
    assert recs[0] == {"y":0x80,"tile":0x5C,"pal":2,"flip_h":0,"flip_v":0,"prio":0,"x":0x48}
    # $F0 Y = offscreen = filtered
    assert all(r["y"] != 0xF0 for r in recs)
```

**Step 2: Run → fail (no module).**
```bash
cd tools/parity/cave_golden && python -m pytest test_normalize.py
```

**Step 3: Implement.** `nes_oam_to_records`: 64 sprites × 4 bytes → dicts, drop Y>=$F0. `gen_sat_to_records`: 80 slots × 8 bytes → dicts. `nes_tile_to_gen`: load MANIFEST.json, map. Palette attr: NES OAM attr&3 = sub-pal; Gen SAT pal field.

**Step 4: Run → pass.**

**Step 5: Commit.**

---

## Task 6: cave_byte_diff.py — the verdict tool

**Files:**
- Create: `tools/parity/cave_golden/cave_byte_diff.py`

**Step 1:** For each cave_id, each frame: load nes_<id>/fNNN.bin + gen_<id>/fNNN.bin. Compare:
- **PALRAM→CRAM**: nes PAL 32 bytes → CRAM via nes_to_cram LUT (reuse diff_scenario.py loader). Byte-equal vs gen CRAM 128. EXACT.
- **OAM→SAT**: nes_oam_to_records vs gen_sat_to_records. Match by (x,y) ±0; tile via nes_tile_to_gen; pal/flip/prio EXACT. Report missing/extra/mismatched sprites.
- **CHR**: nes CHR tile bytes for each referenced tile → expected gen VRAM bytes (after 2bpp→4bpp expand). Hash compare.
- **Animation cadence**: across frames {0,8,16}, NES bonfire tile sequence ($5C→$9E→...) must match Gen sequence frame-for-frame.

Emit `tools/parity/cave_golden/report/<cave_id>.md` per-domain PASS/FAIL + first divergence byte. Aggregate `report/summary.md` 20-row table. Exit 0 iff ALL caves ALL domains PASS.

**Step 2: Run.**
```bash
python tools/parity/cave_golden/cave_byte_diff.py --strict; echo "exit=$?"
```
Expected (first run): `exit=1` with a list of real divergences. THIS IS THE HONEST ANSWER.

**Step 3: Commit tool + first report.**

---

## Task 7-N: Fix each surfaced divergence

For EACH FAIL row in report/summary.md:

**Step 1: Read the per-cave report.** Identify domain (PAL / OAM-tile / OAM-pos / CHR / cadence) + first divergence byte.

**Step 2: Trace to owning C function.**
- PAL fail → `cave_palette.c` / sprite palette load
- OAM tile fail → `k_obj_animations[cave_id+1]` (draw_dispatch.c:73) or sprite descriptor
- OAM pos fail → `cave_init` slot positions (cave_dispatch.c:113)
- CHR fail → `data/chr/MANIFEST.json` atlas gap → add tile
- cadence fail → `z07_animate_object_walking` rate

**Step 3: Probe NES for ground truth at the divergent cell** (Rule Zero — never guess the fix).

**Step 4: Patch smallest owning function. Rebuild. Re-run differ for that ONE cave.**
```bash
Debug.bat && python tools/parity/cave_golden/run_gen_golden.py --filter <cave_id>
python tools/parity/cave_golden/cave_byte_diff.py --filter <cave_id>; echo exit=$?
```

**Step 5: Commit per fix.** Repeat until `cave_byte_diff.py --strict` exits 0 for all 20.

---

## Verification (the only honest yes/no)

```bash
python tools/parity/cave_golden/run_gen_golden.py        # capture all 20 Gen
python tools/parity/cave_golden/cave_byte_diff.py --strict
echo "exit=$?"
```

- `exit=0` → EVERY cave byte-matches NES on PALRAM + OAM + CHR + animation cadence across 6 frame phases. ONLY THEN may "byte-perfect" be claimed.
- `exit=1` → report/summary.md lists exactly which cave + which domain + which byte. Not done. Keep fixing.

Tag when green: `caves-byte-exact-2026-MM-DD`.

---

## Why prior "56/56" was insufficient (so this never recurs)

| Old check | What it proved | What it MISSED |
|-----------|----------------|----------------|
| s_scene==CAVE | dispatch fired | every pixel |
| ObjType[1]==cave_id | right cave loaded | sprite tile, palette, position, animation |
| PNG looks like a cave | gross layout | byte-level tile/color/frame accuracy |

The differ closes every gap in column 3. No screenshots in the PASS gate.

---

## Execution Options

**1. Sequential (this session)** — Tasks 1-6 build the verifier (~3h), then 7-N fix loop.

**2. Parallel** — Tasks 1-2 (NES) and 3-4 (Gen) are independent; run both probe sweeps back-to-back (single BizHawk, but no code dependency). Task 5 (normalize) can be written while sweeps run.

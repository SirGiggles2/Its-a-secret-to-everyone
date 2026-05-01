# UW Door Priority Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Link's sprite render behind UW (dungeon) door arches at left/right doorway transitions, matching NES Zelda 1 original feel, implemented with idiomatic Genesis-native code.

**Architecture:** Probe-first localisation of the failure (F1–F5), then a native C rewrite of `sprrt_show_link_sprites_behind_horizontal_doors` that scans the NES OAM shadow dynamically (instead of hardcoding `$0240+10/14`) and ORs `$20` into Link's actual slots when his X is at a horizontal screen edge. Existing Genesis pipeline (`_compose_bg_tile_word` BG-priority + `_oam_dma` honors NES OAM bit 5 ⇒ clears Genesis SAT bit 15) carries the priority through unchanged. Top/bottom doors deliberately not handled — NES parity.

**Tech Stack:** C99 (sgcc / m68k), vasm Motorola syntax, BizHawk Lua probes, SGDK 2.00, Genesis VDP (Plane A + SAT).

**Reference spec:** [docs/superpowers/specs/2026-04-30-uw-door-priority-design.md](../specs/2026-04-30-uw-door-priority-design.md)

---

## File Structure

- **Create:** `RoomRom/probe_uw_door_priority.lua` — diagnostic probe; walks Link to a left UW doorway and dumps OAM/SAT/NT/screenshot.
- **Create:** `RoomRom/probe_uw_door_priority_verify.lua` — post-fix verification probe; walks Link to left **and** right doorways, dumps + screenshots.
- **Modify:** `src/game/world/sprite_runtime.c` — replace body of `sprrt_show_link_sprites_behind_horizontal_doors` with native dynamic-slot version.
- **Read-only refs:** `src/state/sprite_state.h` (OAM_SPRITE_* macros), `src/state/enemy_state.h` (`ENEMY_PLAYER_OBJ_X`), `src/abi/platform_abi.h` (`NES_OAM_BASE = 0x0200`).
- **Build:** `build.bat` from repo root.
- **Output dir:** `tools/out/` (probe JSON + PNG drop here).

---

## Task 1: Diagnostic probe — capture pre-fix state

**Files:**
- Create: `RoomRom/probe_uw_door_priority.lua`
- Output: `tools/out/uw_door_probe.json`, `tools/out/uw_door_probe.png`

- [ ] **Step 1: Read existing probe template**

Run: `cat "RoomRom/probe_nes_uw_walk_diag.lua"` (use Read tool on absolute path)
Purpose: copy the boot+input pattern (Start press, FS skip, dungeon entry, walk loop).

- [ ] **Step 2: Write the probe Lua**

Create `RoomRom/probe_uw_door_priority.lua` with content:

```lua
-- probe_uw_door_priority.lua
-- Walks Link to the left UW doorway and dumps everything needed to localise
-- the door-priority bug. Single-shot, single launch.

local OUT_DIR = os.getenv("CODEX_OUT") or "tools/out"
local OUT_JSON = OUT_DIR .. "/uw_door_probe.json"
local OUT_PNG  = OUT_DIR .. "/uw_door_probe.png"

local function press(buttons, frames)
    for _ = 1, frames do
        joypad.set(buttons, 1)
        emu.frameadvance()
    end
end

-- Phase 1: skip title + FS, enter dungeon room with horizontal doors.
-- Reuse the working sequence from probe_nes_uw_walk_diag.lua; copy the
-- exact frame counts that file uses (do NOT invent timings).
press({ Start = true }, 60)        -- past title
press({}, 60)                      -- settle on FS
press({ Start = true }, 30)        -- enter file 1
press({}, 120)                     -- intro / fade
-- Walk to a door room. Adjust direction to whatever the warp test ROM
-- starts in. Hold Left until X drops below $20; then capture.
local LEFT_THRESHOLD = 0x18
for f = 1, 600 do
    joypad.set({ Left = true }, 1)
    emu.frameadvance()
    if memory.readbyte(0x0070) <= LEFT_THRESHOLD then break end
end

-- Phase 2: capture frame.
local cap = {}
cap.mode  = memory.readbyte(0x0010)
cap.linkX = memory.readbyte(0x0070)
cap.linkY = memory.readbyte(0x0084)

-- NES OAM dump $0200..$02FF.
cap.oam = {}
for i = 0, 255 do
    cap.oam[i + 1] = memory.readbyte(0x0200 + i)
end

-- Genesis VDP SAT dump (BizHawk genesis core: vdp_vram region, $F800..$FBFF).
-- 80 sprite slots × 8 bytes = 640 bytes; only the first ~32 slots matter for Link.
cap.sat = {}
local vram = memory.getmemorydomainlist()
local has_genesis = false
for _, name in ipairs(vram) do
    if name == "VRAM" then has_genesis = true end
end
if has_genesis then
    memory.usememorydomain("VRAM")
    for i = 0, 255 do
        cap.sat[i + 1] = memory.readbyte(0xF800 + i)
    end
    memory.usememorydomain("System Bus")
end

-- Plane A nametable word at door arch above Link.
-- Compute tile cell (col,row) from Link's pixel position; arch is two tiles
-- above his head. Plane A base = $C000, stride = 64 bytes/row.
if has_genesis then
    memory.usememorydomain("VRAM")
    local tile_col = math.floor((cap.linkX + 8) / 8)
    local tile_row = math.floor((cap.linkY - 16) / 8)
    local nt_addr  = 0xC000 + tile_row * 64 + tile_col * 2
    cap.nt_addr   = nt_addr
    cap.nt_word   = memory.readbyte(nt_addr) * 256 + memory.readbyte(nt_addr + 1)
    memory.usememorydomain("System Bus")
end

-- Phase 3: write JSON + screenshot.
local f = io.open(OUT_JSON, "w")
local function quote(s) return '"' .. tostring(s) .. '"' end
f:write("{\n")
f:write('  "mode": ',  cap.mode,  ',\n')
f:write('  "linkX": ', cap.linkX, ',\n')
f:write('  "linkY": ', cap.linkY, ',\n')
if cap.nt_word then
    f:write(string.format('  "nt_addr": "0x%04X",\n', cap.nt_addr))
    f:write(string.format('  "nt_word": "0x%04X",\n', cap.nt_word))
end
f:write('  "oam": [')
for i, b in ipairs(cap.oam) do
    if i > 1 then f:write(",") end
    f:write(b)
end
f:write("],\n")
f:write('  "sat": [')
for i, b in ipairs(cap.sat) do
    if i > 1 then f:write(",") end
    f:write(b)
end
f:write("]\n}\n")
f:close()

client.screenshot(OUT_PNG)
print("uw_door_probe done: " .. OUT_JSON)
client.exit()
```

- [ ] **Step 3: Launch probe via bizhawkScript skill**

Run (Bash):
```
cmd.exe /c "cd /d C:\BizHawk && set CODEX_BIZHAWK_ROOT=C:\BizHawk && set CODEX_OUT=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\out && EmuHawk.exe --lua=\"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\RoomRom\probe_uw_door_priority.lua\""
```

(If `tools/out` doesn't exist, create it first: `mkdir -p "tools/out"`.)

Expected: BizHawk launches, runs the input sequence, exits within ~30s; JSON + PNG appear in `tools/out`.

- [ ] **Step 4: Read probe output**

Run (Read tool) on `tools/out/uw_door_probe.json`. Inspect:
- Is `linkX` ≤ $18 (probe reached threshold)?
- For each Link OAM entry (find by `Y` being within 16 of `linkY` AND `X` within 16 of `linkX`): is attr byte (`oam[i*4+3]`) bit 5 (`& 0x20`) set?
- For each corresponding Genesis SAT slot (every 8 bytes, byte 4 = priority/palette/tile high; bit 7 of that byte = priority): cleared?
- Is `nt_word` bit 15 (`& 0x8000`) set on the door tile?

- [ ] **Step 5: Classify failure mode** (do not commit code yet)

Write findings to a temporary scratch file `tools/out/uw_door_probe_findings.md`:
- F1 if `mode == 0` or probe never reached threshold (call site never fires)
- F2 if Link OAM entries identified but bit 5 NOT set on them
- F3 if Link OAM bit 5 IS set but Genesis SAT priority bit IS still set
- F4 if SAT priority correctly cleared but Plane A door tile bit 15 NOT set
- F5 if everything looks right but visually the screenshot still shows Link over arch (CHR opacity issue)

- [ ] **Step 6: Commit probe + findings**

```
git add RoomRom/probe_uw_door_priority.lua tools/out/uw_door_probe_findings.md
git commit -m "$(cat <<'EOF'
diag: UW door priority probe + baseline findings

Single-shot Lua probe walks Link to left UW doorway, dumps NES OAM,
Genesis SAT, Plane A NT word, and screenshot. Findings file classifies
the failure as F1/F2/F3/F4/F5 per the design doc.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Native rewrite of `sprrt_show_link_sprites_behind_horizontal_doors`

**Files:**
- Modify: `src/game/world/sprite_runtime.c:37-53`

This task targets failure mode **F2** (most likely). If the probe in Task 1 classifies the failure as F3/F4/F5, see Task 5 for the alternate fix path; this task is still useful as hardening and should still ship.

- [ ] **Step 1: Re-read the current implementation**

Run: open `src/game/world/sprite_runtime.c`, lines 37–53. Confirm current body matches:

```c
void sprrt_show_link_sprites_behind_horizontal_doors(void) {
    static const unsigned char extents[2] = {0x08, 0x00};
    unsigned int d3 = 10;
    int d2 = 1;
    COMBAT_WEAPON_SLOT = ENEMY_PLAYER_OBJ_X;
    do {
        unsigned char x = (unsigned char)(COMBAT_WEAPON_SLOT + extents[d2]);
        if (x >= 0xE9u || x < 0x10u) {
            RAM(0x0240 + d3) = RAM(0x0240 + d3) | 0x20u;
        }
        d3 = (d3 + 4u) & 0xFFu;
        if (d3 == 0) {
            d3 = 32;
        }
        d2--;
    } while (d2 >= 0);
}
```

- [ ] **Step 2: Replace the body with the native dynamic-slot version**

Edit the same range to:

```c
void sprrt_show_link_sprites_behind_horizontal_doors(void) {
    /* NES feel, Genesis-native rewrite (2026-04-30):
     *   - Original 6502 hardcoded slots $0240+10 / $0240+14 (sprites 18, 19).
     *     Those positions are not stable in our build's sprite scheduler.
     *   - Instead, scan the 64-entry NES OAM shadow and OR $20 ("behind BG")
     *     into the attr byte of every slot whose pixel rect overlaps Link's
     *     position AND whose sprite-edge X is at the horizontal screen edge.
     *   - _oam_dma honors bit 5 by clearing Genesis SAT word-2 bit 15, which
     *     drops the sprite below high-priority Plane A pixels — door arch
     *     opaque pixels hide Link, color-0 floor pixels let him show. */
    unsigned char link_x = ENEMY_PLAYER_OBJ_X;
    unsigned char link_y = RAM(0x0084);  /* ObjY[0] — Link's logical Y */
    unsigned char i;
    for (i = 0; i < OAM_SPRITE_COUNT; i++) {
        unsigned char sy = OAM_SPRITE_Y(i);
        unsigned char sx = OAM_SPRITE_X(i);
        /* Position match: within 16px box around Link's logical position. */
        unsigned char dy = (unsigned char)(sy - link_y + 16u);
        unsigned char dx = (unsigned char)(sx - link_x + 16u);
        if (dy >= 32u || dx >= 32u) continue;
        /* Edge gate matches NES original: sprite right-edge >= $E9 OR
         * sprite left-edge < $10. Both edges checked because Link is 2 OAM
         * cells wide (8px each = 16px total). */
        unsigned char xR = (unsigned char)(sx + 8u);
        if (xR >= 0xE9u || sx < 0x10u) {
            OAM_SPRITE_ATTR(i) |= 0x20u;
        }
    }
}
```

- [ ] **Step 3: Verify includes are sufficient**

Confirm `sprite_runtime.c` already includes `sprite_state.h` (OAM_* macros) and `enemy_state.h` (`ENEMY_PLAYER_OBJ_X`). If not, add:

```c
#include "sprite_state.h"
```

(Check current `#include` block at top of file before editing.)

- [ ] **Step 4: Build**

Run (Bash):
```
cd "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY" && ./build.bat 2>&1 | tail -40
```

Expected: build green, ELF + ROM produced, no vasm/sgcc errors.

- [ ] **Step 5: Commit**

```
git add src/game/world/sprite_runtime.c
git commit -m "$(cat <<'EOF'
sprrt: native door-priority — dynamic OAM scan, drop magic slots

Replaces 6502-derived hardcoded $0240+10/14 with a 64-slot NES OAM
scan that ORs $20 into every entry overlapping Link whose edge X is
at the horizontal screen boundary. Same NES-original gate
(x >= $E9 || x < $10), now robust against sprite-scheduler drift.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Verification probe — left + right doorways

**Files:**
- Create: `RoomRom/probe_uw_door_priority_verify.lua`
- Output: `tools/out/uw_door_priority_verify_left.json`, `uw_door_priority_verify_left.png`, `uw_door_priority_verify_right.json`, `uw_door_priority_verify_right.png`

- [ ] **Step 1: Write verify probe**

Create `RoomRom/probe_uw_door_priority_verify.lua`:

```lua
-- probe_uw_door_priority_verify.lua
-- Walks Link to left then right UW doorway, captures OAM+SAT+screenshot at each.

local OUT = os.getenv("CODEX_OUT") or "tools/out"

local function dump(side)
    local cap = { side = side }
    cap.linkX = memory.readbyte(0x0070)
    cap.linkY = memory.readbyte(0x0084)
    cap.oam = {}
    for i = 0, 255 do cap.oam[i + 1] = memory.readbyte(0x0200 + i) end
    cap.sat = {}
    memory.usememorydomain("VRAM")
    for i = 0, 255 do cap.sat[i + 1] = memory.readbyte(0xF800 + i) end
    memory.usememorydomain("System Bus")

    local f = io.open(OUT .. "/uw_door_priority_verify_" .. side .. ".json", "w")
    f:write('{\n  "side":"', side, '",\n  "linkX":', cap.linkX,
            ',\n  "linkY":', cap.linkY, ',\n  "oam":[')
    for i, b in ipairs(cap.oam) do if i > 1 then f:write(",") end; f:write(b) end
    f:write("],\n  \"sat\":[")
    for i, b in ipairs(cap.sat) do if i > 1 then f:write(",") end; f:write(b) end
    f:write("]\n}\n"); f:close()
    client.screenshot(OUT .. "/uw_door_priority_verify_" .. side .. ".png")
end

-- Boot sequence: same as probe_uw_door_priority.lua. Copy verbatim.
-- (Reuse exact frame counts from probe_uw_door_priority.lua to stay in sync.)
local function press(buttons, frames)
    for _ = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
press({ Start = true }, 60)
press({}, 60)
press({ Start = true }, 30)
press({}, 120)

-- Walk to LEFT doorway.
for _ = 1, 600 do
    joypad.set({ Left = true }, 1); emu.frameadvance()
    if memory.readbyte(0x0070) <= 0x18 then break end
end
dump("left")

-- Reverse: walk back to room center, then to RIGHT doorway.
for _ = 1, 200 do joypad.set({ Right = true }, 1); emu.frameadvance() end
for _ = 1, 600 do
    joypad.set({ Right = true }, 1); emu.frameadvance()
    if memory.readbyte(0x0070) >= 0xE0 then break end
end
dump("right")

print("verify done")
client.exit()
```

- [ ] **Step 2: Launch probe**

Same launch pattern as Task 1 Step 3, but with `probe_uw_door_priority_verify.lua` as the script path.

- [ ] **Step 3: Inspect outputs**

For each side (`left`, `right`):
- Read JSON; find Link OAM entries (Y within 16, X within 16).
- Confirm `(attr & 0x20) != 0` for those entries.
- Read corresponding Genesis SAT slot byte 4: confirm `(byte & 0x80) == 0` (priority cleared).
- Read screenshot PNG; visually confirm Link's head/torso behind arch and feet on floor.

- [ ] **Step 4: If any check fails, return to Task 2**

Hardcoded fallback: if the OAM-scan version misidentifies Link slots (e.g., other sprites overlap Link), tighten the position-match radius from `< 32u` to `< 24u` and re-test. Do NOT add the old magic numbers back.

- [ ] **Step 5: Commit**

```
git add RoomRom/probe_uw_door_priority_verify.lua tools/out/uw_door_priority_verify_*.json tools/out/uw_door_priority_verify_*.png
git commit -m "$(cat <<'EOF'
diag: UW door priority verify probe — left+right doorway captures

Confirms native rewrite drops sprite priority bit 15 in Genesis SAT
when Link is at horizontal screen edge. Screenshot pair shows arch
covering head/torso, feet on floor.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Wallmaster grab regression check

The same routine is called from z_04:3572 during the wallmaster grab cinematic. Confirm that path still triggers the priority drop.

**Files:** none modified; probe-only.

- [ ] **Step 1: Reach wallmaster room**

Use the existing `probe_nes_uw_l1_floodwalk.lua` sequence (or an extension of it) to navigate Link to any L1 room with a wallmaster. Hold direction toward a wall for several seconds until the wallmaster grabs Link.

- [ ] **Step 2: Capture during the grab animation**

At the frame when wallmaster has hold of Link (RAM `$0341+0` or wallmaster slot's state byte indicates "hold"), dump OAM and screenshot. Look for Link OAM entries having attr bit 5 set during the drag. The original NES routine sets it for the duration the wallmaster pulls Link off-screen — if our rewrite preserves that behavior, the slots Link now occupies (which the wallmaster code overwrites with Link-render-on-top tiles via `DrawObjectNotMirroredOverLink`) will still get bit 5.

- [ ] **Step 3: Visual sanity**

Screenshot during the grab: Link should render behind the wallmaster body sprite. If Link draws over the wallmaster, the routine isn't reaching Link's slots — go back to Task 2 Step 4 (tighten radius) or check whether wallmaster reorders Link OAM after our scan.

- [ ] **Step 4: Commit (or note no regression in commit message of next task)**

If a screenshot was captured, add it under `tools/out/uw_door_priority_wallmaster.png` and commit with a one-line message.

---

## Task 5: Alternate fix paths (only if Task 1 classified F3/F4/F5)

Conditional. Skip if Task 3 verification passes.

### F3 — `_oam_dma` not honoring bit 5
- [ ] Open `src/nes_io.asm` lines 2181–2196 (CHR_EXPANSION-conditional) and 2191–2196 (legacy).
- [ ] Run probe to confirm which branch is active (check `CHR_EXPANSION_ENABLED` define in `genesis_shell.asm`).
- [ ] Confirm `btst #5,D2 ; bne.s .spr_low_prio_*` reads correct OAM byte and that `.spr_low_prio_*` skips the `ori #$8000` that would re-set high priority.
- [ ] Patch the broken branch; rebuild; re-run verify probe.
- [ ] Commit.

### F4 — UW BG door tiles lack priority bit 15
- [ ] Search for the Plane A write path the UW renderer uses. Likely the transpiled `$2007` write path through `_ppu_write_7`. Confirm it routes through `.nt_write_a` → `_compose_bg_tile_word`.
- [ ] If a different code path bypasses `_compose_bg_tile_word`, route it through.
- [ ] Rebuild; re-run verify probe.
- [ ] Commit.

### F5 — Arch CHR pixels color-0 at Link's body region
- [ ] Pull the canonical UW arch tile from `data/sprite_chr/` reference dump (or NES ROM via `RoomRom/probe_nes_uw_chr_dump.lua`).
- [ ] Compare byte-for-byte to the in-build CHR (Genesis VRAM dump from probe). Identify which 4bpp pixels are color-0 in our build but non-zero on NES.
- [ ] Re-extract via the existing CHR pipeline (`tools/extract_*` scripts — pick the right one for UW BG).
- [ ] Rebuild; re-run verify probe.
- [ ] Commit.

---

## Task 6: Final commit + memory update

- [ ] **Step 1: Verify build still green**

```
cd "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY" && ./build.bat 2>&1 | tail -10
```

- [ ] **Step 2: Confirm acceptance criteria from spec**

Walk through each line in the spec's "Acceptance" section. Mark in `tools/out/uw_door_priority_findings.md` (created in Task 1) whether each is satisfied.

- [ ] **Step 3: Final summary commit if any uncommitted artifacts remain**

```
git status --short
```

If anything is staged or modified, group into one final commit:

```
git add <files>
git commit -m "$(cat <<'EOF'
chore: UW door priority — close out

Acceptance: head/torso behind arch in left+right UW doorways.
Top/bottom doorways unchanged (NES parity). Wallmaster grab
verified — no regression.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Add memory note**

Append to `MEMORY.md`:

```
- [UW door priority — native dynamic OAM scan](project_uw_door_priority.md) — sprrt_show_link_sprites_behind_horizontal_doors rewritten 2026-04-30 to scan all 64 NES OAM slots by Link-position match instead of hardcoded $0240+10/14; horizontal-only NES parity; pipeline relies on _oam_dma bit-5 honor + Plane A high-prio
```

Create `project_uw_door_priority.md` with frontmatter and a one-paragraph body capturing what changed and why, citing `feedback_nes_feel_genesis_native`.

- [ ] **Step 5: Done**

Plan complete. Acceptance criteria satisfied per spec.

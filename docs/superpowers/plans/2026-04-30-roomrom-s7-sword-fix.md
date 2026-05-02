# RoomRom S7 Sword Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken S7 v2 sword sprite source with the verified
`common_chr` `$20/$21` vertical sword tiles. UP/DOWN swings render the
real Z1 sword; LEFT/RIGHT swings hide the sprite without breaking the
combat state machine.

**Architecture:** Probe-first. Capture NES OAM + PPU pattern bytes during
a vertical sword swing, confirm `$20/$21` is the correct vertical-sword
source, then patch `RoomRom/src/roomrom_sprites.[ch]` and
`RoomRom/src/roomrom_combat.[ch]`. Vertical sword draws as `SPRITE_SIZE(1,2)`
(8x16) with PAL3, vflip on DOWN. Horizontal sword (LEFT/RIGHT) is
deferred to S7b — pattern table 1 / `sprites_chr` mapping is unverified.

**Tech Stack:** SGDK (Genesis), C (gcc m68k via SGDK toolchain),
BizHawk Lua (NES probe), `RoomRom\build.bat`, NES Zelda 1 USA ROM as
the source-of-truth emulator target.

**Worktree:** All work happens in
`C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1` on branch
`roomrom-s1`. Verify with `git worktree list` before any build / edit
/ copy. Main worktree lacks the RoomRom S2+ scaffold and is the wrong
target.

**Testing model:** No unit-test framework. Verification is runtime:
single-shot Lua probes against BizHawk (NES capture and Genesis SAT
verify) + visual screenshot diffs. Each task that changes behavior ends
with an emulator probe step that produces evidence saved to
`tools/out/`.

---

## File Structure

**Create:**
- `RoomRom/probe_nes_sword_capture.lua` — NES OAM + PPU pattern capture
  during a vertical sword swing. One-shot: boot, warp, force sword,
  press A, capture, exit.
- `RoomRom/probe_roomrom_sword_sat.lua` — Genesis SAT slot 1 verifier.
  Boots RoomRom build, simulates UP/DOWN/LEFT/RIGHT A-press,
  dumps SAT for slot 1 plus a screenshot per facing.
- `tools/out/nes_sword_capture.json` — captured tile IDs + flip flags
  per facing (probe output, gitignored or committed per existing
  `tools/out/` convention).
- `tools/out/nes_sword_ppu0.bin` — captured NES sprite pattern table 0
  bank (4096 bytes).

**Modify:**
- `RoomRom/src/roomrom_sprites.c` — sword CHR upload + sword sprite
  pose function.
- `RoomRom/src/roomrom_sprites.h` — sword block comment.
- `RoomRom/src/roomrom_combat.c` — vertical sword positioning.
- `RoomRom/src/roomrom_combat.h` — v3 reference comment.

**Untouched:**
- `RoomRom/src/main.c` — combat call sites already correct
  (`combat_init`, `try_swing`, `update`, `link_locked` all wired at
  lines 355, 412, 459-460, 484).
- All other RoomRom modules.

---

### Task 1: Worktree + branch sanity check

**Files:**
- None modified.

- [ ] **Step 1: Verify worktree**

Run:
```bash
git worktree list
```

Expected output includes the line:
```
C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY-roomrom-s1   <hash> [roomrom-s1]
```

If the current shell is in the main worktree (`FINAL TRY` without the
`-roomrom-s1` suffix), `cd` to the roomrom-s1 worktree before any
further step. All subsequent paths in this plan are relative to that
worktree's root.

- [ ] **Step 2: Confirm clean working tree**

Run:
```bash
git -C "/c/Users/Jake Diggity/Documents/GitHub/FINAL TRY-roomrom-s1" status --short
```

Expected: empty output (the spec commit `08fdd993` is already in).
If there are unrelated dirty files, stop and ask the operator how to
proceed — never `git stash` someone else's work-in-progress without
asking.

- [ ] **Step 3: No commit — gate only.**

---

### Task 2: NES sword-capture probe (boot + inventory force)

**Files:**
- Create: `RoomRom/probe_nes_sword_capture.lua`

- [ ] **Step 1: Write the probe scaffold**

```lua
-- probe_nes_sword_capture.lua
-- Boot NES Zelda 1 to OW, force sword inventory, settle Link, then
-- press A facing DOWN and again facing UP. Capture OAM each frame for
-- 20 frames after each press; identify the new (non-Link) OAM entry =
-- sword sprite. Dump PPU sprite pattern table 0 ($0000-$0FFF).
--
-- Outputs:
--   tools/out/nes_sword_capture.json   per-facing tile + offsets + flip
--   tools/out/nes_sword_ppu0.bin       4096-byte PPU $0000-$0FFF dump
--
-- Env contract:
--   CODEX_SWORD_OUT_JSON  override JSON output path
--   CODEX_SWORD_OUT_BIN   override PPU bin output path

local OUT_JSON = os.getenv("CODEX_SWORD_OUT_JSON")
                 or "tools/out/nes_sword_capture.json"
local OUT_BIN  = os.getenv("CODEX_SWORD_OUT_BIN")
                 or "tools/out/nes_sword_ppu0.bin"

-- RAM addresses (NES Z1 disasm).
local CUR_LEVEL          = 0x0010
local GAME_MODE          = 0x0012
local GAME_SUB           = 0x0013
local CUR_SAVE_SLOT      = 0x0016
local IS_UPDATING_MODE   = 0x0011
local TARGET_MODE        = 0x005B
local TARGET_MIRROR      = 0x0602
local CUR_PPU_MASK       = 0x00FE
local ROOM_ID            = 0x00EB
local NAME_PROGRESS      = 0x0421
local SAVE_ACTIVE0       = 0x0633
local SAVE_ACTIVE1       = 0x0634
local SAVE_ACTIVE2       = 0x0635
local ROOM_TRANS         = 0x004C
local LINK_X             = 0x0070
local LINK_Y             = 0x0084
local LINK_FACING        = 0x0098      -- $04 down, $08 up, $01 right, $02 left
local SWORD_INVENTORY    = 0x0657      -- $00 none, $01 wood, $02 white, $03 magical
local SWORD_STATE        = 0x00BD      -- per-slot state for sword (slot 13)
local SWORD_TIMER        = 0x03E0      -- $03D0 + slot 13 = $03DD; using composite
                                       -- (probe records both, picks the one moving).

local function u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr & 0xFFFF)
end

local function w8(addr, val)
    memory.usememorydomain("System Bus")
    memory.write_u8(addr & 0xFFFF, val & 0xFF)
end

local function read_domain_u8(domain, addr)
    local ok, v = pcall(function()
        memory.usememorydomain(domain)
        return memory.read_u8(addr)
    end)
    if ok then return v end
    return nil
end

local CHR_DOMAINS = {"PPU Bus", "PPU", "PPU RAM", "CHR VRAM", "CHR ROM", "VRAM"}
local function chr_u8(addr)
    for _, d in ipairs(CHR_DOMAINS) do
        local v = read_domain_u8(d, addr)
        if v ~= nil then return v end
    end
    return 0
end

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 0 }
local function schedule(button, hold_frames, release_frames)
    if input_state.hold_left > 0 or input_state.release_left > 0 then return end
    input_state.button = button
    input_state.hold_left = hold_frames or 1
    input_state.release_left = 0
    input_state.release_after = release_frames or 8
end
local function build_pad()
    local pad = {}
    if input_state.hold_left > 0 and input_state.button then
        pad[input_state.button] = true
        pad["P1 " .. input_state.button] = true
        input_state.hold_left = input_state.hold_left - 1
        if input_state.hold_left == 0 then
            input_state.release_left = input_state.release_after
        end
    elseif input_state.release_left > 0 then
        input_state.release_left = input_state.release_left - 1
    end
    return pad
end

local function boot_to_overworld()
    -- Same flow as probe_nes_uw_chr_dump.lua. Lifted verbatim.
    local BOOT_TO_FS1, SELECT_REGISTER, ENTER_REGISTER, TYPE_NAME,
          FINISH_NAME, WAIT_GAMEPLAY, START_GAME = 1,2,3,4,5,6,7
    local flow = BOOT_TO_FS1
    local last_name = u8(NAME_PROGRESS)
    local name_events = 0
    for frame = 1, 20000 do
        local mode = u8(GAME_MODE)
        local slot = u8(CUR_SAVE_SLOT)
        local name = u8(NAME_PROGRESS)
        local active0 = u8(SAVE_ACTIVE0)
        local active1 = u8(SAVE_ACTIVE1)
        local active2 = u8(SAVE_ACTIVE2)
        if flow == BOOT_TO_FS1 then
            if mode == 0x01 then flow = SELECT_REGISTER else schedule("Start", 2, 3) end
        elseif flow == SELECT_REGISTER then
            if slot == 0x03 then flow = ENTER_REGISTER else schedule("Down", 1, 10) end
        elseif flow == ENTER_REGISTER then
            if mode == 0x0E then flow = TYPE_NAME; last_name = name
            elseif mode == 0x01 then schedule("Start", 2, 14) end
        elseif flow == TYPE_NAME then
            if name ~= last_name then name_events = name_events + 1; last_name = name end
            if name_events >= 5 then flow = FINISH_NAME else schedule("A", 1, 10) end
        elseif flow == FINISH_NAME then
            if mode ~= 0x0E then flow = WAIT_GAMEPLAY
            elseif slot ~= 0x03 then schedule("Select", 1, 10)
            else schedule("Start", 2, 14) end
        elseif flow == WAIT_GAMEPLAY then
            if mode == 0x01 then flow = START_GAME end
        elseif flow == START_GAME then
            if mode ~= 0x01 then flow = WAIT_GAMEPLAY
            else
                local target_slot = 0x00
                if active0 == 0 and active1 ~= 0 then target_slot = 0x01
                elseif active0 == 0 and active1 == 0 and active2 ~= 0 then target_slot = 0x02 end
                if slot ~= target_slot then schedule(target_slot > slot and "Down" or "Up", 1, 10)
                else schedule("Start", 2, 14) end
            end
        end
        safe_set(build_pad())
        emu.frameadvance()
        if u8(CUR_LEVEL) == 0 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0
           and u8(ROOM_ID) == 0x77 and u8(ROOM_TRANS) == 0 then
            for _ = 1, 30 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

local function force_sword_inventory()
    -- $0657 = sword inventory: 1 = wooden sword.
    w8(SWORD_INVENTORY, 0x01)
    -- Settle 30 frames so HUD redraws.
    for _ = 1, 30 do safe_set({}); emu.frameadvance() end
end

local system_id = emu.getsystemid() or "?"
if system_id ~= "NES" then
    local f = io.open(OUT_JSON .. ".error", "w")
    if f then f:write("wrong_system_" .. system_id); f:close() end
    client.exit()
end

if not boot_to_overworld() then
    local f = io.open(OUT_JSON .. ".error", "w")
    if f then f:write("boot_failed"); f:close() end
    client.exit()
end

force_sword_inventory()
```

- [ ] **Step 2: Smoke-launch the scaffold**

Set env and launch BizHawk with the probe via the bizhawkScript pattern
(memory `skill_bizhawk_script`):

```bash
export CODEX_BIZHAWK_ROOT="C:/path/to/BizHawk"   # whatever the operator's path is
cd /c/Users/Jake\ Diggity/Documents/GitHub/FINAL\ TRY-roomrom-s1
"$CODEX_BIZHAWK_ROOT/EmuHawk.exe" --lua="$(pwd)/RoomRom/probe_nes_sword_capture.lua" \
    "/c/Users/Jake Diggity/Documents/GitHub/FINAL TRY-roomrom-s1/data/Legend of Zelda, The (USA).nes" &
```

Expected: BizHawk window opens, file-select runs, save slot is created,
overworld appears, HUD shows wooden sword icon. Then BizHawk exits
(scaffold runs `client.exit()` after sword force).

If file-select hangs: this is a different bug than the sword fix.
Document in the run notes; do not patch the boot flow.

- [ ] **Step 3: No commit yet — capture loop is still missing.**

---

### Task 3: NES sword-capture probe (capture loop + JSON output)

**Files:**
- Modify: `RoomRom/probe_nes_sword_capture.lua` (append below the
  `force_sword_inventory()` call).

- [ ] **Step 1: Append the capture loop**

```lua
-- Helper: face Link in a given direction by direct RAM write to $0098.
local FACING_DOWN  = 0x04
local FACING_UP    = 0x08
local FACING_LEFT  = 0x02
local FACING_RIGHT = 0x01

local function set_facing(facing_byte)
    w8(LINK_FACING, facing_byte)
    for _ = 1, 4 do safe_set({}); emu.frameadvance() end
end

-- Helper: gather all OAM tile IDs currently on screen, exclude HUD tiles
-- (Y < 0x40) and ground sprites that look like Link's body. Return list
-- of {slot, x, y, tile, attr} for any sprite whose Y is within
-- ±24 px of Link's Y.
local function snapshot_oam_near_link()
    local link_y = u8(LINK_Y)
    local out = {}
    for slot = 0, 63 do
        local base = 0x0200 + slot * 4    -- NES OAM mirror in CPU RAM
        memory.usememorydomain("System Bus")
        local y    = memory.read_u8(base + 0)
        local tile = memory.read_u8(base + 1)
        local attr = memory.read_u8(base + 2)
        local x    = memory.read_u8(base + 3)
        if y < 0xF0 and math.abs(y - link_y) <= 32 then
            table.insert(out, { slot = slot, x = x, y = y,
                                tile = tile, attr = attr })
        end
    end
    return out
end

-- Capture a single A-press in the current facing. Records OAM near Link
-- for 20 frames; finds the frame where SWORD_STATE != 0 and picks the
-- OAM entry that wasn't present in the pre-press snapshot.
local function capture_swing(facing_label, facing_byte)
    set_facing(facing_byte)
    local pre = snapshot_oam_near_link()
    local pre_keys = {}
    for _, s in ipairs(pre) do
        pre_keys[s.slot] = string.format("%02X|%02X|%02X|%02X",
            s.x, s.y, s.tile, s.attr)
    end

    schedule("A", 1, 0)
    -- Build pad once for the press frame.
    safe_set(build_pad()); emu.frameadvance()

    local found = nil
    for f = 1, 20 do
        local snap = snapshot_oam_near_link()
        for _, s in ipairs(snap) do
            local key = string.format("%02X|%02X|%02X|%02X",
                s.x, s.y, s.tile, s.attr)
            if pre_keys[s.slot] == nil
               or pre_keys[s.slot] ~= key then
                -- New / changed sprite during the swing window.
                if s.tile >= 0x10 and s.tile <= 0x40 then
                    -- Heuristic: vertical sword tile lives in $10-$3F.
                    found = found or {
                        facing = facing_label,
                        oam_slot = s.slot,
                        x = s.x,
                        y = s.y,
                        tile = s.tile,
                        attr = s.attr,
                        link_x = u8(LINK_X),
                        link_y = u8(LINK_Y),
                        captured_frame = f,
                    }
                end
            end
        end
        safe_set({}); emu.frameadvance()
    end

    -- Settle until sword state returns to 0.
    for _ = 1, 30 do safe_set({}); emu.frameadvance() end
    return found
end

local result = {
    down = capture_swing("down", FACING_DOWN),
    up   = capture_swing("up",   FACING_UP),
}

-- Dump full sprite pattern table 0 ($0000-$0FFF).
do
    local f = assert(io.open(OUT_BIN, "wb"))
    for addr = 0x0000, 0x0FFF do
        f:write(string.char(chr_u8(addr) % 256))
    end
    f:close()
end

-- Write JSON. (Tiny hand-rolled encoder; NES Lua has no json built-in.)
local function jval(v)
    if v == nil then return "null" end
    if type(v) == "number" then return tostring(v) end
    if type(v) == "string" then return '"' .. v .. '"' end
    if type(v) == "table" then
        local parts = {}
        for k, vv in pairs(v) do
            table.insert(parts, '"' .. k .. '":' .. jval(vv))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

do
    local f = assert(io.open(OUT_JSON, "w"))
    f:write(jval(result))
    f:close()
end

client.exit()
```

- [ ] **Step 2: Run the probe, capture output**

Launch via the same bizhawkScript pattern as Task 2 Step 2. Wait for
EmuHawk to exit on its own.

Expected files after run:
- `tools/out/nes_sword_capture.json` — contains `{"down":{...},"up":{...}}`
  with `tile`, `attr`, `x`, `y`, `link_x`, `link_y`.
- `tools/out/nes_sword_ppu0.bin` — 4096 bytes.

If either file is missing or `.error` exists, stop. Re-read the error,
adjust the probe, repeat. Do not move on to patching C.

- [ ] **Step 3: Inspect capture output**

Read the JSON:
```bash
cat tools/out/nes_sword_capture.json
```

Expected (working hypothesis):
```json
{"down":{"facing":"down","oam_slot":N,"x":X,"y":Y,
  "tile":32,"attr":A,"link_x":LX,"link_y":LY,"captured_frame":F},
 "up":  {"facing":"up","oam_slot":M,"x":X2,"y":Y2,
  "tile":32,"attr":A2,"link_x":LX2,"link_y":LY2,"captured_frame":F2}}
```

Decode bit 7 of each `attr` field — that's NES OAM vflip:

- If `down.attr & 0x80 == 0x00` and `up.attr & 0x80 == 0x80` → `$20/$21`
  is the **DOWN-pointing** canonical orientation. Spec assumed
  UP-canonical; flip the patch (UP gets vflip=1, DOWN gets vflip=0).
- If `down.attr & 0x80 == 0x80` and `up.attr & 0x80 == 0x00` → `$20/$21`
  is **UP-pointing** canonical. Patch as spec'd (UP no flip, DOWN
  vflip).

Record the verdict in plain text:
```bash
cat > tools/out/nes_sword_capture_verdict.txt <<EOF
NES sword tile (vertical): \$XX
Canonical orientation:    UP-pointing | DOWN-pointing
DOWN attr byte 2:         0xAA
UP attr byte 2:           0xBB
Y offset DOWN: <link_y - sword_y>  (expect ~ -16)
Y offset UP:   <link_y - sword_y>  (expect ~ +16)
EOF
```

(Replace placeholders with actual values from the JSON.)

If `tile` != `0x20` (32 decimal), stop. Update the design doc with the
real tile ID, re-run brainstorming-self-review, then resume from
Task 4 with the corrected tile ID.

- [ ] **Step 4: Commit**

```bash
git add RoomRom/probe_nes_sword_capture.lua \
        tools/out/nes_sword_capture.json \
        tools/out/nes_sword_ppu0.bin \
        tools/out/nes_sword_capture_verdict.txt
git commit -m "RoomRom S7 fix probe: capture NES sword OAM + PPU pattern table 0"
```

---

### Task 4: Replace sword CHR upload (sprites.c)

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c:115-132`

- [ ] **Step 1: Replace the 8-tile upload block**

Find this block (currently lines 115-132 of the file):

```c
    /* S7: upload 8 sword tiles ($18-$1B vertical, $82-$85 horizontal) into
     * SWORD_VRAM_TILE region in SGDK column-major order (TL, BL, TR, BR).
     * NES tile IDs verified by live OAM capture (probe_nes_sword.lua). */
    {
        static const unsigned char sword_nes[SWORD_VRAM_TILE_COUNT] = {
            /* Vertical (UP+DOWN): NES pairs $18+$19, $1A+$1B */
            0x18u, 0x19u, 0x1Au, 0x1Bu,
            /* Horizontal (LEFT+RIGHT): NES pairs $82+$83, $84+$85 */
            0x82u, 0x83u, 0x84u, 0x85u
        };
        unsigned char i;
        for (i = 0; i < SWORD_VRAM_TILE_COUNT; i++) {
            unsigned short nes_off = (unsigned short)sword_nes[i] * 32u;
            render_chr_upload(
                (unsigned short)((SWORD_VRAM_TILE + i) * 32u),
                common_chr + nes_off, 32u);
        }
    }
```

Replace with:

```c
    /* S7 v3 sword: vertical only.
     *
     * NES OAM tile $20 in 8x16 sprite mode = pattern-table-0 tiles
     * $20 (top) + $21 (bottom). RoomRom uploads those two 8x8 tiles
     * from common_chr into the SWORD_VRAM_TILE pair. UP/DOWN both
     * use this pair; vflip flag picks the orientation
     * (see roomrom_sprites_set_sword_pose).
     *
     * Verified 2026-04-30 via probe_nes_sword_capture.lua (output:
     * tools/out/nes_sword_capture.json).
     *
     * Horizontal sword tiles live in NES pattern table 1
     * (sprites_chr block) and are deferred to S7b. */
    {
        unsigned short top_off = (unsigned short)0x20u * 32u;
        unsigned short bot_off = (unsigned short)0x21u * 32u;
        render_chr_upload(
            (unsigned short)((SWORD_VRAM_TILE + 0u) * 32u),
            common_chr + top_off, 32u);
        render_chr_upload(
            (unsigned short)((SWORD_VRAM_TILE + 1u) * 32u),
            common_chr + bot_off, 32u);
    }
```

- [ ] **Step 2: Drop the now-unused macros**

Find this block near the top of the file (currently lines 40-43):

```c
#define SWORD_VRAM_TILE         (LINK_VRAM_TILE + LINK_POSE_COUNT * LINK_TILES_PER_POSE)
#define SWORD_VRAM_TILE_VERT    (SWORD_VRAM_TILE + 0u)
#define SWORD_VRAM_TILE_HORZ    (SWORD_VRAM_TILE + 4u)
#define SWORD_VRAM_TILE_COUNT   8u
```

Replace with:

```c
/* SWORD_VRAM_TILE: 2 contiguous 8x8 tiles. NES pattern-table-0 tiles
 * $20 (top) and $21 (bottom) of the 8x16 vertical-sword sprite.
 * Drawn as SPRITE_SIZE(1, 2) at slot 1. */
#define SWORD_VRAM_TILE         (LINK_VRAM_TILE + LINK_POSE_COUNT * LINK_TILES_PER_POSE)
```

- [ ] **Step 3: Update the comment block above SWORD_VRAM_TILE**

Find the multi-line comment that currently starts on line 28:

```c
/* Sword tiles follow Link's 32 pose tiles. 8 tiles total: 4 for vertical
 * (UP+DOWN share same art), 4 for horizontal (LEFT+RIGHT share, hflip
 * differs). Each direction is a 16x16 sprite (SPRITE_SIZE(2,2)).
 *
 * NES tile IDs sourced from live capture (probe_nes_sword.lua, 2026-04-30):
 *   Vertical:   $18, $19, $1A, $1B  (NES OAM in 8x16 mode: pairs $18+$19
 *                                    and $1A+$1B side by side)
 *   Horizontal: $82, $83, $84, $85  (hflip=1 for LEFT, hflip=0 for RIGHT)
 *
 * SGDK SPRITE_SIZE(2,2) tile order is column-major: TL, BL, TR, BR.
 * Genesis tile order in VRAM: SWORD_VRAM_TILE + 0..3 = vertical 4 tiles;
 *                             SWORD_VRAM_TILE + 4..7 = horizontal 4 tiles. */
```

Delete it. The replacement comment lives inline above
`SWORD_VRAM_TILE` (Step 2) and inside the new upload block (Step 1).

- [ ] **Step 4: Build**

```bash
cd "/c/Users/Jake Diggity/Documents/GitHub/FINAL TRY-roomrom-s1"
RoomRom/build.bat
```

Expected: build succeeds, `RoomRom/out/RoomRom.md` is produced.
If gcc complains about an undefined macro
(`SWORD_VRAM_TILE_VERT` / `SWORD_VRAM_TILE_HORZ` / `SWORD_VRAM_TILE_COUNT`),
that means a later step still references them — proceed to Task 5
which will rewrite `set_sword_pose` and remove those references.

- [ ] **Step 5: No commit yet — sword draw is still wrong (pose still
  uses 2x2). Move to Task 5.**

---

### Task 5: Rewrite set_sword_pose / spawn_link / clear_sword (sprites.c)

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c` (functions
  `roomrom_sprites_spawn_link`, `roomrom_sprites_set_sword_pose`,
  `roomrom_sprites_clear_sword`).

- [ ] **Step 1: Update spawn_link to use SPRITE_SIZE(1, 2)**

Find:

```c
void roomrom_sprites_spawn_link(short x, short y)
{
    /* Init slot 1 (sword) to hidden, terminator link, before first link draw. */
    VDP_setSpriteFull(1,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, SWORD_VRAM_TILE),
                      0);
    roomrom_sprites_set_link_pose(x, y, LINK_FACE_DOWN, 0u);
}
```

Already uses `SPRITE_SIZE(1, 2)` — leave unchanged. (Verify in the
real file before moving on; this is the one place v2 happened to be
correct.)

- [ ] **Step 2: Rewrite set_sword_pose**

Find:

```c
void roomrom_sprites_set_sword_pose(link_face_t face, short x, short y)
{
    unsigned short tile;
    unsigned char  hflip = 0u;
    switch (face) {
    case LINK_FACE_UP:
    case LINK_FACE_DOWN:
        tile = SWORD_VRAM_TILE_VERT;  /* same 4 tiles for both per NES capture */
        break;
    case LINK_FACE_LEFT:
        tile = SWORD_VRAM_TILE_HORZ;
        hflip = 1u;
        break;
    case LINK_FACE_RIGHT:
        tile = SWORD_VRAM_TILE_HORZ;
        break;
    default:
        roomrom_sprites_clear_sword();
        return;
    }
    VDP_setSpriteFull(1,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 2),  /* 16x16 (matches NES 2x 8x16 sprites) */
                      TILE_ATTR_FULL(PAL3, 0, 0, hflip, tile),
                      0);                  /* terminator */
    VDP_updateSprites(2, DMA);
}
```

Replace with:

```c
void roomrom_sprites_set_sword_pose(link_face_t face, short x, short y)
{
    /* Vertical-only in v3. UP = canonical (no flip), DOWN = vflip.
     * (Probe-confirmed orientation; flip if probe verdict says
     * common_chr $20/$21 is DOWN-canonical instead.)
     *
     * LEFT/RIGHT clear the sprite — horizontal tile source is in
     * sprites_chr pattern table 1 and is deferred to S7b. */
    unsigned char vflip = 0u;
    switch (face) {
    case LINK_FACE_UP:
        vflip = 0u;
        break;
    case LINK_FACE_DOWN:
        vflip = 1u;
        break;
    case LINK_FACE_LEFT:
    case LINK_FACE_RIGHT:
    default:
        roomrom_sprites_clear_sword();
        return;
    }
    VDP_setSpriteFull(1,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, vflip, 0, SWORD_VRAM_TILE),
                      0);
    VDP_updateSprites(2, DMA);
}
```

- [ ] **Step 3: Rewrite clear_sword to match SPRITE_SIZE(1, 2)**

Find:

```c
void roomrom_sprites_clear_sword(void)
{
    VDP_setSpriteFull(1,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, SWORD_VRAM_TILE),
                      0);
    VDP_updateSprites(2, DMA);
}
```

Replace with:

```c
void roomrom_sprites_clear_sword(void)
{
    VDP_setSpriteFull(1,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, SWORD_VRAM_TILE),
                      0);
    VDP_updateSprites(2, DMA);
}
```

- [ ] **Step 4: Build**

```bash
RoomRom/build.bat
```

Expected: build succeeds. If gcc still warns about unused
`SWORD_VRAM_TILE_VERT` / `_HORZ` / `_COUNT` — recheck Task 4 Step 2;
those macros must already be deleted.

- [ ] **Step 5: No commit yet — combat positioning still uses
  16x16 offsets. Continue to Task 6.**

---

### Task 6: Update sprites.h sword block comment

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.h:27-31`

- [ ] **Step 1: Replace the v2 sword comment**

Find:

```c
/* S7 combat: sword sprite (slot 1). Sword tile data uploaded inside
 * roomrom_sprites_upload_chr alongside Link poses. set_sword_pose draws
 * sword 8x16 in current facing direction at the given screen coords;
 * clear_sword hides it (Y off-screen). UP/DOWN supported in v1; LEFT/RIGHT
 * fall through to clear (TODO horizontal sword tiles). */
void roomrom_sprites_set_sword_pose(link_face_t face, short x, short y);
void roomrom_sprites_clear_sword(void);
```

Replace with:

```c
/* S7 v3 combat: sword sprite (slot 1). Vertical only.
 *
 * Sword tile data (2 tiles, NES $20 + $21 from common_chr) uploaded
 * inside roomrom_sprites_upload_chr alongside Link poses.
 * set_sword_pose draws an 8x16 sword (SPRITE_SIZE(1, 2), PAL3) at the
 * given screen coords: UP = no flip, DOWN = vflip. LEFT/RIGHT clear
 * the sprite (horizontal source is in sprites_chr / NES pattern
 * table 1, deferred to S7b). clear_sword hides slot 1 by parking it
 * off-screen. */
void roomrom_sprites_set_sword_pose(link_face_t face, short x, short y);
void roomrom_sprites_clear_sword(void);
```

- [ ] **Step 2: Build to confirm header still compiles**

```bash
RoomRom/build.bat
```

Expected: build succeeds (comment-only change shouldn't break the
build but verify).

- [ ] **Step 3: No commit yet — combat positioning still wrong.**

---

### Task 7: Fix sword positioning (combat.c)

**Files:**
- Modify: `RoomRom/src/roomrom_combat.c:40-56`

- [ ] **Step 1: Rewrite compute_sword_pos**

Find:

```c
/* Sword draw position offset from Link's 16x16 sprite top-left, all 4 facings.
 * Sword sprite is 16x16; Link is 16x16. Sword extends 16 pixels in the facing
 * direction. */
static void compute_sword_pos(link_face_t face, short link_x, short link_y,
                              short *out_x, short *out_y)
{
    short sx = link_x;
    short sy = link_y;
    switch (face) {
    case LINK_FACE_UP:    sy = (short)(link_y - 16); break;
    case LINK_FACE_DOWN:  sy = (short)(link_y + 16); break;
    case LINK_FACE_LEFT:  sx = (short)(link_x - 16); break;
    case LINK_FACE_RIGHT: sx = (short)(link_x + 16); break;
    }
    *out_x = sx;
    *out_y = sy;
}
```

Replace with:

```c
/* Sword draw position relative to Link's 16x16 top-left.
 * v3: vertical sword is an 8x16 sprite, centered on Link's X (offset
 * +4) and ±16 in the facing direction. LEFT/RIGHT positions are
 * never drawn (set_sword_pose clears slot 1 for those facings) but
 * the function still writes sane values so callers never read
 * uninitialized memory. */
static void compute_sword_pos(link_face_t face, short link_x, short link_y,
                              short *out_x, short *out_y)
{
    short sx = link_x;
    short sy = link_y;
    switch (face) {
    case LINK_FACE_UP:
        sx = (short)(link_x + 4);
        sy = (short)(link_y - 16);
        break;
    case LINK_FACE_DOWN:
        sx = (short)(link_x + 4);
        sy = (short)(link_y + 16);
        break;
    case LINK_FACE_LEFT:
    case LINK_FACE_RIGHT:
        /* Sprite cleared by set_sword_pose; values harmless. */
        break;
    }
    *out_x = sx;
    *out_y = sy;
}
```

- [ ] **Step 2: Build**

```bash
RoomRom/build.bat
```

Expected: build succeeds.

- [ ] **Step 3: No commit yet — combat header still describes v1.**

---

### Task 8: Update combat.h header comment

**Files:**
- Modify: `RoomRom/src/roomrom_combat.h:4-14`

- [ ] **Step 1: Replace the v1 reference comment**

Find:

```c
/* RoomRom S7: combat (sword + beam).
 *
 * NES Zelda 1 reference (z_05.asm WieldSword + z_07.asm UpdateSwordOrRod):
 *   - State 1 lasts 5 frames: sword extends out from Link in current facing
 *   - State 2 lasts 1 frame: sword retracts; Link returns to walk pose
 *   - Re-swing locked while state != 0
 *
 * v1 scope: UP/DOWN sword facings only (vertical sword tiles $20-$23 in
 * common_chr). LEFT/RIGHT sword tiles + sword beam projectile are TBD —
 * captured live in S7 follow-up.
 */
```

Replace with:

```c
/* RoomRom S7 v3: sword swing (vertical only).
 *
 * NES Zelda 1 reference (z_05.asm WieldSword + z_07.asm UpdateSwordOrRod):
 *   - State 1 lasts 5 frames: sword extends out from Link in current facing
 *   - State 2 lasts 1 frame: sword retracts; Link returns to walk pose
 *   - Re-swing locked while state != 0
 *
 * v3 scope: UP/DOWN draw the real Z1 sword sprite (common_chr tiles
 * $20/$21, verified 2026-04-30 via probe_nes_sword_capture.lua —
 * see tools/out/nes_sword_capture.json). LEFT/RIGHT swings still lock
 * Link for the swing window (state machine unchanged) but the sword
 * sprite is hidden — horizontal sword tiles live in sprites_chr / NES
 * pattern table 1 and are tracked as S7b. Sword beam projectile +
 * enemy hit detection are also S7b / S8.
 */
```

- [ ] **Step 2: Build**

```bash
RoomRom/build.bat
```

Expected: build succeeds.

- [ ] **Step 3: Commit the full sprite-source fix**

```bash
git add RoomRom/src/roomrom_sprites.c RoomRom/src/roomrom_sprites.h \
        RoomRom/src/roomrom_combat.c  RoomRom/src/roomrom_combat.h
git commit -m "RoomRom S7 v3: vertical sword from common_chr \$20/\$21

Replace the v2 8-tile sword upload (which read \$18-\$1B and \$82-\$85
from common_chr — the wrong byte offsets, since NES OAM tile values are
8x16 sprite-pair indices into a pattern table, not direct Genesis 8x8
indices) with a 2-tile upload of common_chr tiles \$20 + \$21. Draw as
SPRITE_SIZE(1, 2): UP = no flip, DOWN = vflip. LEFT/RIGHT clear slot 1
without breaking the swing-window Link freeze; horizontal sword source
lives in sprites_chr (NES pattern table 1) and is deferred to S7b.

Verified by probe_nes_sword_capture.lua — see
tools/out/nes_sword_capture.json (committed in the prior probe commit)."
```

---

### Task 9: Visual verification (UP / DOWN / LEFT / RIGHT)

**Files:**
- Create: `RoomRom/probe_roomrom_sword_sat.lua`

- [ ] **Step 1: Write the SAT verifier**

```lua
-- probe_roomrom_sword_sat.lua
-- Boot RoomRom build, walk briefly to settle, then for each facing
-- (DOWN, UP, LEFT, RIGHT) press the corresponding direction for a few
-- frames, press A, capture SAT slot 1 + a screenshot.
--
-- Outputs:
--   tools/out/roomrom_sword_<facing>.png   one screenshot per facing
--   tools/out/roomrom_sword_sat.txt        SAT slot 0 + slot 1 dump,
--                                          all four facings.
--
-- Env contract:
--   CODEX_SWORD_SAT_OUT_DIR  override output directory

local OUT_DIR = os.getenv("CODEX_SWORD_SAT_OUT_DIR") or "tools/out"

local SAT_BASE = 0xF800     -- Genesis VDP SAT in VRAM; SGDK default.
                            -- Probe reads from VDP via memory domain
                            -- "VRAM" if available; falls back to RAM
                            -- shadow if RoomRom keeps a copy.

local FACINGS = { "down", "up", "left", "right" }
local DIR_KEY = {
    down  = "Down",
    up    = "Up",
    left  = "Left",
    right = "Right",
}

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local function settle(frames)
    for _ = 1, frames do safe_set({}); emu.frameadvance() end
end

local function press(button, hold, release)
    for _ = 1, (hold or 1) do
        safe_set({ [button] = true, ["P1 " .. button] = true })
        emu.frameadvance()
    end
    for _ = 1, (release or 1) do safe_set({}); emu.frameadvance() end
end

local function read_vram_u8(addr)
    local domains = { "VRAM", "VDP", "VRAM (VDP)" }
    for _, d in ipairs(domains) do
        local ok, v = pcall(function()
            memory.usememorydomain(d)
            return memory.read_u8(addr)
        end)
        if ok then return v end
    end
    return 0
end

local function dump_sat_slot(slot)
    -- SGDK SAT layout: 8 bytes per slot.
    -- Bytes 0-1: Y, 2: size, 3: link, 4-5: tile+attr (low/high), 6-7: X.
    local base = SAT_BASE + slot * 8
    local bytes = {}
    for i = 0, 7 do bytes[i+1] = read_vram_u8(base + i) end
    return bytes
end

local function fmt_slot(slot)
    local b = dump_sat_slot(slot)
    return string.format(
        "slot %d: Y=%02X%02X size=%02X link=%02X TA=%02X%02X X=%02X%02X",
        slot, b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8])
end

local system_id = emu.getsystemid() or "?"
if system_id ~= "GEN" and system_id ~= "Genesis" then
    local f = io.open(OUT_DIR .. "/roomrom_sword_sat.error", "w")
    if f then f:write("wrong_system_" .. system_id); f:close() end
    client.exit()
end

-- Boot to playable state. RoomRom drops straight into OW with Link
-- visible — no FS to navigate.
settle(180)

local lines = {}
for _, facing in ipairs(FACINGS) do
    -- Walk into the facing for ~6 frames (enough to update s_link_face).
    press(DIR_KEY[facing], 6, 6)

    -- Press A.
    press("A", 1, 0)

    -- Wait 2 frames for swing to extend (state 1 frame 2-3 of 5).
    settle(2)

    -- Snapshot SAT slot 0 (Link) and slot 1 (sword).
    table.insert(lines,
        string.format("--- facing %s ---", facing))
    table.insert(lines, fmt_slot(0))
    table.insert(lines, fmt_slot(1))

    -- Screenshot.
    client.screenshot(string.format("%s/roomrom_sword_%s.png",
        OUT_DIR, facing))

    -- Wait for swing to end before next direction.
    settle(20)
end

do
    local f = assert(io.open(OUT_DIR .. "/roomrom_sword_sat.txt", "w"))
    f:write(table.concat(lines, "\n") .. "\n")
    f:close()
end

client.exit()
```

- [ ] **Step 2: Run the verifier**

Launch BizHawk via the bizhawkScript pattern, but pointing at the
freshly built RoomRom md instead of the NES ROM:

```bash
"$CODEX_BIZHAWK_ROOT/EmuHawk.exe" \
    --lua="$(pwd)/RoomRom/probe_roomrom_sword_sat.lua" \
    "$(pwd)/RoomRom/out/RoomRom.md" &
```

Expected outputs:
- `tools/out/roomrom_sword_down.png` — sword visible below Link, blade
  pointing down.
- `tools/out/roomrom_sword_up.png` — sword visible above Link, blade
  pointing up.
- `tools/out/roomrom_sword_left.png` — Link facing left, **no sword
  sprite** (slot 1 Y is large negative / off-screen).
- `tools/out/roomrom_sword_right.png` — same, no sword sprite.
- `tools/out/roomrom_sword_sat.txt` — slot 1 attrs:
  - down: `TA=??48 ...` where `??` low nibble = vflip set in attr.
    With SGDK `TILE_ATTR_FULL(PAL3, 0, vflip=1, hflip=0, SWORD_VRAM_TILE)`
    the encoded attr bits should show vflip=1 and palette=PAL3.
  - up: `TA=??48 ...` same tile, vflip=0.
  - left/right: Y bytes show off-screen position
    (`Y=FFE0 ...` or similar — `(s16)-32` cast).

- [ ] **Step 3: Read the screenshots**

Open each PNG via the Read tool and confirm visually:

1. `roomrom_sword_down.png`: sword sprite directly below Link, vertical
   blade pointing down. Not Link's hat or body. Not background tile.
2. `roomrom_sword_up.png`: sword sprite directly above Link, vertical
   blade pointing up. Same tiles as DOWN, vflipped.
3. `roomrom_sword_left.png`: only Link's left-facing pose visible.
   No sword sprite anywhere on screen.
4. `roomrom_sword_right.png`: only Link's right-facing pose visible.
   No sword sprite anywhere on screen.

If any check fails, do not move on to commit. Re-read
`tools/out/nes_sword_capture_verdict.txt` and the SAT dump; if vflip
is reversed (sword DOWN points up), swap the cases in
`set_sword_pose` (Task 5 Step 2) and rebuild.

- [ ] **Step 4: Commit verification artefacts**

```bash
git add RoomRom/probe_roomrom_sword_sat.lua \
        tools/out/roomrom_sword_down.png \
        tools/out/roomrom_sword_up.png \
        tools/out/roomrom_sword_left.png \
        tools/out/roomrom_sword_right.png \
        tools/out/roomrom_sword_sat.txt
git commit -m "RoomRom S7 v3 verify: SAT + screenshot evidence

Vertical sword renders correctly DOWN (vflipped) and UP (canonical).
LEFT/RIGHT facings show no sword sprite — slot 1 parked off-screen
during the swing window. SAT dump confirms slot 1 size = 1x2, palette
PAL3, tile = SWORD_VRAM_TILE."
```

---

### Task 10: Final ROM-ready check

**Files:**
- None modified.

- [ ] **Step 1: Confirm clean tree + history**

```bash
git -C "/c/Users/Jake Diggity/Documents/GitHub/FINAL TRY-roomrom-s1" status --short
git -C "/c/Users/Jake Diggity/Documents/GitHub/FINAL TRY-roomrom-s1" log --oneline -5
```

Expected: working tree clean. Most recent four commits are (in order):
```
<hash>  RoomRom S7 v3 verify: SAT + screenshot evidence
<hash>  RoomRom S7 v3: vertical sword from common_chr $20/$21
<hash>  RoomRom S7 fix probe: capture NES sword OAM + PPU pattern table 0
08fdd993  spec: RoomRom S7 fix — vertical sword from common_chr $20/$21
```

- [ ] **Step 2: Diff scope check**

```bash
git -C "/c/Users/Jake Diggity/Documents/GitHub/FINAL TRY-roomrom-s1" diff --stat 08fdd993..HEAD
```

Expected files in the diff stat (no others):
- `RoomRom/probe_nes_sword_capture.lua`
- `RoomRom/probe_roomrom_sword_sat.lua`
- `RoomRom/src/roomrom_combat.c`
- `RoomRom/src/roomrom_combat.h`
- `RoomRom/src/roomrom_sprites.c`
- `RoomRom/src/roomrom_sprites.h`
- `tools/out/nes_sword_capture.json`
- `tools/out/nes_sword_ppu0.bin`
- `tools/out/nes_sword_capture_verdict.txt`
- `tools/out/roomrom_sword_*.png` (4 files)
- `tools/out/roomrom_sword_sat.txt`

If anything else appears, undo it before declaring done — the slice is
intentionally minimal.

- [ ] **Step 3: Hand-off note**

The plan is complete. Open follow-ups (do NOT implement here):

- S7b: horizontal sword from `sprites_chr` (NES pattern table 1).
  Probe needs to capture LEFT/RIGHT swings + identify which 2 tiles
  in the loaded `sprites_chr` block hold the horizontal sword. Wire
  a separate VRAM slot (`SWORD_HORZ_VRAM_TILE`) and update
  `set_sword_pose` LEFT/RIGHT cases to draw `SPRITE_SIZE(2, 1)` with
  hflip on LEFT.
- S7c: sword beam projectile.
- S8: enemy hit detection (consumes sword bbox + beam bbox).

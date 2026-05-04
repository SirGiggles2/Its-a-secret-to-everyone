-- probe_roomrom_items_bundled.lua  (rev2 — synthesis of /octo:debate skeptic+pragmatist)
-- Phase 2 Task 2.2 close-gate evidence: one launch covers
-- sword swing + sword beam + boomerang + arrow + bomb + explosion.
-- Per /octo:debate synthesis:
--   * drop SAT slot readout (screenshots sufficient for atlas correctness)
--   * multi-frame screenshot strip per item action (catches transient sprites)
--   * settle >=30 frames between item triggers (clears combat lock between swings)
--   * 4-frame button hold (cheap insurance, edge-detect doesn't need it)
--   * add VRAM CHR-slot tile dump (cross-checks project_chr_extraction_items_blocker memory:
--     if boomerang/arrow/bomb tile bytes are all zero, items render but point at unloaded VRAM)

local OUT_DIR = "C:\\tmp\\items_probe"
local LOG_PATH = OUT_DIR .. "\\bundled.txt"

os.execute('mkdir "' .. OUT_DIR .. '" 2>nul')

local lines = {}
local function log(s) lines[#lines + 1] = s end

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end
local function settle(frames)
    for _ = 1, frames do safe_set({}); emu.frameadvance() end
end
local function press_held(pad, hold)
    for _ = 1, (hold or 1) do safe_set(pad); emu.frameadvance() end
end
local function tap(button, hold)
    press_held({ [button] = true, ["P1 " .. button] = true }, hold or 4)
    settle(2)
end

local function dump_cram_line(prefix)
    local ok, _ = pcall(function() memory.usememorydomain("CRAM") end)
    if not ok then return prefix .. " CRAM unavailable" end
    local parts = {}
    for i = 0, 31 do
        local lo = memory.read_u8(i * 2)     or 0
        local hi = memory.read_u8(i * 2 + 1) or 0
        parts[#parts + 1] = string.format("%02X%02X", lo, hi)
    end
    return prefix .. " CRAM " .. table.concat(parts, " ")
end

-- VRAM tile dump: read 32 bytes (one Genesis tile) from VRAM at tile_index.
-- A tile is "blank" if all 32 bytes are 0 (no CHR loaded into that slot).
local function dump_vram_tile(tile_index)
    local ok, _ = pcall(function() memory.usememorydomain("VRAM") end)
    if not ok then return "VRAM unavailable" end
    local base = tile_index * 32
    local nonzero = 0
    local first8 = {}
    for i = 0, 31 do
        local b = memory.read_u8(base + i) or 0
        if b ~= 0 then nonzero = nonzero + 1 end
        if i < 8 then first8[#first8 + 1] = string.format("%02X", b) end
    end
    return string.format("tile 0x%03X: nonzero=%d/32 first8=%s",
        tile_index, nonzero, table.concat(first8, " "))
end

-- snapshot: write screenshot at given label
local function snap(label)
    local png = OUT_DIR .. "\\" .. label .. ".png"
    client.screenshot(png)
end

-- strip_capture: capture screenshots every `stride` frames over `total_frames`
-- so transient sprites (beam, fuse, explosion) can't slip past one capture.
local function strip_capture(label_prefix, total_frames, stride)
    stride = stride or 4
    local count = 0
    for f = 1, total_frames do
        if (f - 1) % stride == 0 then
            count = count + 1
            snap(string.format("%s_f%02d", label_prefix, f - 1))
        end
        emu.frameadvance()
    end
    log(string.format("=== %s (%d frames, stride %d, %d captures) ===",
        label_prefix, total_frames, stride, count))
    log("  " .. dump_cram_line(label_prefix))
end

-- system info
log("system_id=" .. (emu.getsystemid() or "?"))
do
    local ok, list = pcall(function() return memory.getmemorydomainlist() end)
    if ok and list then
        log("memory domains:")
        local n = list.Count or #list
        for i = 0, n - 1 do log("  " .. tostring(list[i])) end
    end
end

-- boot settle
settle(240)
snap("00_boot")
log("=== 00_boot ===")
log("  " .. dump_cram_line("00_boot"))

-- VRAM CHR-slot tile dump: cross-check project_chr_extraction_items_blocker.
-- Tile indices below are the ROOMROM_ITEM_TILE_BASE_PAL(0) + atlas offset
-- per RoomRom/src/atlas/items_chr_x4.h.  ITEM_TILE_BASE on this build is
-- not statically known to the probe, but most SGDK projects place item CHR
-- in VRAM tile range 0x100-0x300.  Dump enough range to find any nonzero
-- region.  If everything is zero, CHR was never DMAed into VRAM.
log("--- VRAM tile-data sweep (looking for item CHR loaded) ---")
for _, ti in ipairs({ 0x100, 0x120, 0x140, 0x160, 0x180, 0x1A0, 0x1C0, 0x1E0,
                      0x200, 0x220, 0x240, 0x260, 0x280, 0x2A0, 0x2C0, 0x2E0,
                      0x300, 0x320, 0x340, 0x360 }) do
    log("  " .. dump_vram_tile(ti))
end

-- 1. Sword swing per facing.  Strip-capture 24 frames (stride 4 = 6 PNGs)
-- which spans the COMBAT_EXTEND swing window (~16 frames per combat.c).
local FACINGS = { "down", "up", "left", "right" }
local DIR_KEY = { down = "Down", up = "Up", left = "Left", right = "Right" }
for _, f in ipairs(FACINGS) do
    press_held({ [DIR_KEY[f]] = true, ["P1 " .. DIR_KEY[f]] = true }, 8)
    settle(4)
    tap("A", 4)
    strip_capture("01_sword_" .. f, 24, 4)
    settle(30)   -- clear combat lock before next iteration (skeptic's note)
end

-- 2. Sword beam — same as sword but full HP path (Z1 sword shot fires
-- when HP at max).  Probe doesn't manipulate HP, captures whatever fires.
for _, f in ipairs({ "right", "down" }) do
    press_held({ [DIR_KEY[f]] = true, ["P1 " .. DIR_KEY[f]] = true }, 4)
    settle(4)
    tap("A", 4)
    strip_capture("02_beam_" .. f, 30, 4)
    settle(30)
end

-- 3. Boomerang (default B-item slot, B button).  NES boomerang flight is
-- ~50 frames out + return; capture 60 to see launch + mid-flight.
for _, f in ipairs({ "down", "right" }) do
    press_held({ [DIR_KEY[f]] = true, ["P1 " .. DIR_KEY[f]] = true }, 4)
    settle(4)
    tap("B", 4)
    strip_capture("03_boomerang_" .. f, 60, 4)
    settle(40)
end

-- 4. Cycle B-item to arrow (Z once).
tap("Z", 4); settle(8)
for _, f in ipairs({ "right" }) do
    press_held({ [DIR_KEY[f]] = true, ["P1 " .. DIR_KEY[f]] = true }, 4)
    settle(4)
    tap("B", 4)
    strip_capture("04_arrow_" .. f, 30, 4)
    settle(30)
end

-- 5. Cycle B-item to bomb (Z once more) and fire.  Bomb fuse ~60-90 frames
-- then explosion ~30 frames.  Total capture window 120 with stride 6
-- (=20 PNGs) covers fuse start, fuse mid, explosion.
tap("Z", 4); settle(8)
press_held({ Down = true, ["P1 Down"] = true }, 4); settle(4)
tap("B", 4)
strip_capture("05_bomb", 120, 6)
settle(20)

-- write log
do
    local fh = assert(io.open(LOG_PATH, "w"))
    fh:write(table.concat(lines, "\n") .. "\n")
    fh:close()
end

client.exit()

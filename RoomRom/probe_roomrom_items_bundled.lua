-- probe_roomrom_items_bundled.lua
-- Phase 2 Task 2.2 close-gate evidence: one launch covers
-- sword swing + sword beam + boomerang + arrow + bomb + explosion.
-- Captures screenshot + SAT slot 1 + CRAM at each phase.
-- All output under RoomRom/out/items_probe/.

local OUT_DIR = "C:\\tmp\\items_probe"
local LOG_PATH = OUT_DIR .. "\\bundled.txt"

os.execute('mkdir "' .. OUT_DIR .. '" 2>nul')

local SAT_BASE = 0xF400
local SAT_DOMAINS = { "VRAM", "VRAM (VDP)", "VDP", "MD VRAM" }

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
    press_held({ [button] = true, ["P1 " .. button] = true }, hold or 1)
    settle(4)
end

local function try_read_u8(domain, addr)
    local ok, v = pcall(function()
        memory.usememorydomain(domain)
        return memory.read_u8(addr)
    end)
    if ok then return v end
    return nil
end

local function dump_sat_slot(slot)
    local base = SAT_BASE + slot * 8
    for _, d in ipairs(SAT_DOMAINS) do
        local b0 = try_read_u8(d, base)
        if b0 ~= nil then
            local bytes = { b0 }
            for i = 1, 7 do bytes[i + 1] = try_read_u8(d, base + i) or 0 end
            return d, bytes
        end
    end
    return nil, { 0, 0, 0, 0, 0, 0, 0, 0 }
end

local function fmt_slot(slot)
    local d, b = dump_sat_slot(slot)
    return string.format(
        "slot %d (dom=%s): Y=%02X%02X size=%02X link=%02X TA=%02X%02X X=%02X%02X",
        slot, d or "?", b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8])
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

local function checkpoint(label, slot_list)
    local png = OUT_DIR .. "\\" .. label .. ".png"
    client.screenshot(png)
    log("=== " .. label .. " ===")
    log("  png: " .. png)
    for _, s in ipairs(slot_list or { 0, 1, 2, 3 }) do
        log("  " .. fmt_slot(s))
    end
    log("  " .. dump_cram_line(label))
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
checkpoint("00_boot")

-- 1. Sword swing per facing (slot 1 = sword)
local FACINGS = { "down", "up", "left", "right" }
local DIR_KEY = { down = "Down", up = "Up", left = "Left", right = "Right" }
for _, f in ipairs(FACINGS) do
    press_held({ [DIR_KEY[f]] = true, ["P1 " .. DIR_KEY[f]] = true }, 8)
    settle(2)
    tap("A", 1)
    settle(8)
    checkpoint("01_sword_" .. f, { 0, 1 })
    settle(20)
end

-- 2. Sword beam (full HP — RoomRom may not gate this; A press anyway)
for _, f in ipairs({ "right", "down" }) do
    press_held({ [DIR_KEY[f]] = true, ["P1 " .. DIR_KEY[f]] = true }, 4)
    settle(2)
    tap("A", 1)
    settle(6)
    checkpoint("02_beam_" .. f, { 0, 1, 2 })
    settle(20)
end

-- 3. Boomerang (default B-item slot, B button)
for _, f in ipairs({ "down", "right" }) do
    press_held({ [DIR_KEY[f]] = true, ["P1 " .. DIR_KEY[f]] = true }, 4)
    settle(2)
    tap("B", 1)
    settle(8)
    checkpoint("03_boomerang_" .. f, { 0, 3 })
    settle(30)
end

-- 4. Cycle B-item to arrow (Z once)
tap("Z", 1); settle(4)
for _, f in ipairs({ "right" }) do
    press_held({ [DIR_KEY[f]] = true, ["P1 " .. DIR_KEY[f]] = true }, 4)
    settle(2)
    tap("B", 1)
    settle(6)
    checkpoint("04_arrow_" .. f, { 0, 4 })
    settle(20)
end

-- 5. Cycle B-item to bomb (Z once more)
tap("Z", 1); settle(4)
press_held({ Down = true, ["P1 Down"] = true }, 4); settle(2)
tap("B", 1)
settle(15)
checkpoint("05_bomb_fuse", { 0, 5, 6 })
settle(50)
checkpoint("06_explosion_mid", { 0, 5, 6 })
settle(40)

-- write log
do
    local fh = assert(io.open(LOG_PATH, "w"))
    fh:write(table.concat(lines, "\n") .. "\n")
    fh:close()
end

client.exit()

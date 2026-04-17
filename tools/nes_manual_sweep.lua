-- nes_manual_sweep.lua — NES OW 128-room sweep that piggybacks on a
-- user-initiated boot.
--
-- Usage:
--   1) Load vanilla NES Zelda in BizHawk with this Lua.
--   2) Manually register a name + start a save + enter overworld.
--      (If an existing save + load state works, even faster.)
--   3) Once Link is standing in overworld (mode=$05, sub=$00), the Lua
--      takes over, warps to every RoomId 0..127, captures each, and
--      writes builds/reports/ow_visible_sweep_nes.json.
--
-- Warp mechanism: instead of walking Link, poke RoomId + force
-- GameMode=$07 SubMode=$00 (InitMode7 entry). The game's own room-load
-- state machine then runs to completion and drops back to mode=$05.
-- Same trick as the turbo cheat, but sweep-driven.

local OUT_PATH = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\ow_visible_sweep_nes.json"

local ROOM_ID        = 0x00EB
local NEXT_ROOM_ID   = 0x00EC
local WHIRL_PREV     = 0x00EA
local WHIRL_STATE    = 0x0522
local CUR_LEVEL      = 0x0010
local GAME_MODE      = 0x0012
local GAME_SUB       = 0x0013
local IS_UPDATING    = 0x0011
local OBJ_DIR        = 0x0098
local OBJ_X          = 0x0070
local OBJ_Y          = 0x0084
local BUTTONS_PRESS  = 0x00F8
local BUTTONS_HELD   = 0x00FA
local CUR_VSCROLL    = 0x00FC
local CUR_HSCROLL    = 0x00FD
local CIRAM_BASE     = 0x0100   -- PPU $2100 mapped into CIRAM for read
local ATTR_BASE      = 0x03C0
local ROOM_ROWS      = 22
local ROOM_COLS      = 32
local PLAY_AREA_NT_TOP = 8

local function u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr)
end
local function w8(addr, val)
    memory.usememorydomain("System Bus")
    memory.write_u8(addr, val & 0xFF)
end

local function ciram_u8(addr)
    local domains = {"CIRAM (nametables)", "CIRAM", "Nametable RAM"}
    for _, d in ipairs(domains) do
        local ok, v = pcall(function()
            memory.usememorydomain(d)
            return memory.read_u8(addr)
        end)
        if ok then return v end
    end
    return 0
end

-- BizHawk NES core palette memory domain probe — try each without
-- fallback-to-system-bus (which spams out-of-range warnings).
local PPU_DOMAIN = nil
do
    for _, d in ipairs({"PPU Bus", "PPU Memory", "PPU", "Palette RAM", "OAM"}) do
        local ok = pcall(function()
            memory.usememorydomain(d)
        end)
        if ok then PPU_DOMAIN = d; break end
    end
end

local function ppu_bus_u8(addr)
    if not PPU_DOMAIN then return 0 end
    local ok, v = pcall(function()
        memory.usememorydomain(PPU_DOMAIN)
        return memory.read_u8(addr)
    end)
    if ok then return v end
    return 0
end

local function dump_visible_rows()
    local rows = {}
    for row = 0, ROOM_ROWS - 1 do
        local vals = {}
        local base = CIRAM_BASE + row * ROOM_COLS
        for col = 0, ROOM_COLS - 1 do
            vals[#vals + 1] = ciram_u8(base + col)
        end
        rows[#rows + 1] = vals
    end
    return rows
end

local function attr_palette_for(col, row)
    local attr_col = col >> 2
    local attr_row = row >> 2
    local byte = ciram_u8(ATTR_BASE + attr_row * 8 + attr_col)
    local qx = (col >> 1) & 1
    local qy = (row >> 1) & 1
    local shift = (qy * 2 + qx) * 2
    return (byte >> shift) & 3
end

local function dump_palette_rows()
    local rows = {}
    for row = 0, ROOM_ROWS - 1 do
        local vals = {}
        for col = 0, ROOM_COLS - 1 do
            vals[#vals + 1] = attr_palette_for(col, PLAY_AREA_NT_TOP + row)
        end
        rows[#rows + 1] = vals
    end
    return rows
end

-- Try the palette-RAM-as-32-byte-domain first (BizHawk nes exposes it
-- as "PPU Palette RAM" or similar at offset 0). Fall back to PPU domain
-- at $3F00. If neither, emit zeros (palette comparison will skip).
local PAL_DOMAIN = nil
local PAL_BASE = 0
do
    for _, d in ipairs({"PPU Palette RAM", "Palette RAM"}) do
        local ok = pcall(function()
            memory.usememorydomain(d)
            local _ = memory.read_u8(0)
        end)
        if ok then PAL_DOMAIN = d; PAL_BASE = 0; break end
    end
    if not PAL_DOMAIN then
        for _, d in ipairs({"PPU Memory", "PPU"}) do
            local ok = pcall(function()
                memory.usememorydomain(d)
                local _ = memory.read_u8(0x3F00)
            end)
            if ok then PAL_DOMAIN = d; PAL_BASE = 0x3F00; break end
        end
    end
end

local function dump_palette_ram()
    local vals = {}
    if not PAL_DOMAIN then
        for i = 1, 16 do vals[i] = 0 end
        return vals
    end
    memory.usememorydomain(PAL_DOMAIN)
    for i = 0, 15 do
        local ok, v = pcall(function() return memory.read_u8(PAL_BASE + i) end)
        vals[#vals + 1] = ok and v or 0
    end
    return vals
end

-- Wait for user to reach overworld idle.
local function wait_for_overworld()
    local printed = false
    while not (u8(CUR_LEVEL) == 0 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0) do
        if not printed then
            gui.text(10, 10, "Play until overworld idle; sweep auto-starts.")
            printed = true
        end
        emu.frameadvance()
    end
    -- also wait a few settle frames
    for _ = 1, 30 do emu.frameadvance() end
end

-- Warp via WhirlwindTeleport-style state forcing.
-- Sub0 of InitMode7 reads WhirlwindPrevRoomId when WhirlwindState != 0
-- and sets RoomId from it. Sub1..6 then run the room-load.
local function warp_to(target)
    w8(WHIRL_PREV, target)
    w8(WHIRL_STATE, 1)
    w8(OBJ_DIR, 0x04)          -- Down (non-up path in Sub2/3/5)
    w8(OBJ_X, 0x78)
    w8(OBJ_Y, 0x8D)
    w8(CUR_VSCROLL, 0)
    w8(CUR_HSCROLL, 0)
    w8(BUTTONS_PRESS, 0)
    w8(BUTTONS_HELD, 0)
    w8(IS_UPDATING, 1)
    w8(GAME_MODE, 0x07)
    w8(GAME_SUB, 0x00)
    -- Wait for mode to return to 5/0.
    for _ = 1, 240 do
        emu.frameadvance()
        if u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 then
            -- extra settle
            for _ = 1, 8 do emu.frameadvance() end
            return true
        end
    end
    return false
end

local function build_path()
    local p = {}
    for row = 0, 7 do
        if row % 2 == 0 then
            for col = 0, 15 do p[#p+1] = row * 16 + col end
        else
            for col = 15, 0, -1 do p[#p+1] = row * 16 + col end
        end
    end
    return p
end

local function json_array_1d(t)
    local s = {}
    for i = 1, #t do s[#s+1] = tostring(t[i]) end
    return "[" .. table.concat(s, ",") .. "]"
end
local function json_array_2d(rows)
    local s = {}
    for i = 1, #rows do s[#s+1] = json_array_1d(rows[i]) end
    return "[" .. table.concat(s, ",") .. "]"
end

local function main()
    wait_for_overworld()
    gui.text(10, 10, "Sweeping NES OW 128 rooms...")

    local visited = {}
    for _, target in ipairs(build_path()) do
        if not visited[target] then
            local ok = warp_to(target)
            visited[target] = {
                room_id = target,
                warp_ok = ok,
                visible_rows = dump_visible_rows(),
                palette_rows = dump_palette_rows(),
                palette_ram = dump_palette_ram(),
            }
        end
    end

    -- emit JSON
    local keys = {}
    for k, _ in pairs(visited) do keys[#keys+1] = k end
    table.sort(keys)
    local fh = assert(io.open(OUT_PATH, "w"))
    fh:write("{\n")
    fh:write('  "room_count": ', tostring(#keys), ',\n')
    fh:write('  "rooms": [\n')
    for i = 1, #keys do
        local r = visited[keys[i]]
        fh:write("    {\n")
        fh:write('      "room_id": ', tostring(r.room_id), ',\n')
        fh:write('      "visible_rows": ', json_array_2d(r.visible_rows), ',\n')
        fh:write('      "palette_rows": ', json_array_2d(r.palette_rows), ',\n')
        fh:write('      "palette_ram": ', json_array_1d(r.palette_ram), '\n')
        fh:write("    }")
        if i < #keys then fh:write(",") end
        fh:write("\n")
    end
    fh:write("  ]\n")
    fh:write("}\n")
    fh:close()
    gui.text(10, 10, string.format("Sweep done: %d rooms written.", #keys))
end

main()
while true do emu.frameadvance() end

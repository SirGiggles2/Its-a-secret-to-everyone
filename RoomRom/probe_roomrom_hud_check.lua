-- probe_roomrom_hud_check.lua
-- Boot RoomRom, wait for HUD to render, screenshot, dump plane A nametable
-- region for HUD verification, exit.

local OUT_PNG  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\roomrom_hud_after.png"
local OUT_JSON = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\roomrom_hud_after.json"

-- VDP plane A base address: SGDK default. Read from VDP register 2 (plane A nametable addr / 0x400)
local function read_vdp_reg2()
    local ok, val = pcall(function()
        memory.usememorydomain("VDP")
        return memory.read_u8(2)
    end)
    if ok then return val end
    return 0x30 -- SGDK default plane A base = 0xC000, reg2 stores top bits
end

-- Read VRAM word at given byte offset
local function vram_u16(off)
    memory.usememorydomain("VRAM")
    local hi = memory.read_u8(off)
    local lo = memory.read_u8(off + 1)
    return (hi << 8) | lo
end

for _ = 1, 240 do emu.frameadvance() end

client.screenshot(OUT_PNG)

-- Plane A is at VRAM 0xC000 by SGDK default. Plane is 64 cols wide (since VDP_setPlaneSize(32,32) used? main.c uses 32x32).
-- Actually main.c: VDP_setPlaneSize(32, 32, TRUE) -> plane is 32 cols x 32 rows.
-- Plane base depends on SGDK config. Common: BG_A at 0xE000 for 32x32 plane.
-- Probe both possible bases.
local PLANE_A_CANDIDATES = { 0xC000, 0xE000, 0xC000+0x40*0, 0xE000 }

local function read_hud_rows(base)
    local rows = {}
    for r = 0, 6 do
        local row = {}
        for c = 0, 31 do
            local off = base + (r * 32 + c) * 2
            row[#row + 1] = vram_u16(off)
        end
        rows[#rows + 1] = row
    end
    return rows
end

local f = assert(io.open(OUT_JSON, "w"))
f:write("{\n")
f:write('  "vdp_reg2": ', tostring(read_vdp_reg2()), ',\n')
f:write('  "hud_rows_at_E000": [')
local rows = read_hud_rows(0xE000)
for i = 1, #rows do
    if i > 1 then f:write(",") end
    f:write("[")
    local r = rows[i]
    for j = 1, #r do
        if j > 1 then f:write(",") end
        f:write(string.format("\"0x%04X\"", r[j]))
    end
    f:write("]")
end
f:write("]\n}\n")
f:close()

client.exit()

-- Phase D2 follow-up: scan all 80 SAT slots, identify enemy entries.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function VRAM(o) return memory.read_u8(o, "VRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

W(0x77D0, 0x46) W(0x77D1, 0x58)
W(0x77D2, 0x05) W(0x77D3, 0x80) W(0x77D4, 0x78)
W(0x77D5, 0x01) W(0x77D6, 0x01) W(0x77D7, 0x00) W(0x77D8, 0x77)
emu.frameadvance()
idle(20)

local f = io.open("C:/tmp/audit_chr_gen2.txt", "w")
f:write("# SAT full scan + tile dump for enemy-tile-range hits\n")
f:write(string.format("# Goriya should be at NES X=$%02X Y=$%02X\n", R(0x8070+1), R(0x8084+1)))
f:write("# Genesis SAT X = NES_X + 128, Y = NES_Y + 128\n\n")

local enemy_slots = {}
for s = 0, 79 do
    local sat_off = 0xF800 + s*8
    local y_hi = VRAM(sat_off)
    local y_lo = VRAM(sat_off + 1)
    local size_link = VRAM(sat_off + 2)
    local link_lo = VRAM(sat_off + 3)
    local attr_hi = VRAM(sat_off + 4)
    local attr_lo = VRAM(sat_off + 5)
    local x_hi = VRAM(sat_off + 6)
    local x_lo = VRAM(sat_off + 7)
    local y = (y_hi<<8)|y_lo
    local x = (x_hi<<8)|x_lo
    local tile_id = ((attr_hi & 0x07) << 8) | attr_lo
    -- Only log non-empty (Y not 0 and not way off-screen).
    if y ~= 0 and y < 0x200 then
        f:write(string.format("SAT[%2d] Y=%04X X=%04X tile=%4d (=$%03X) attr=%02X%02X size/link=%02X/%02X\n",
            s, y, x, tile_id, tile_id, attr_hi, attr_lo, size_link, link_lo))
        -- Flag entries in enemy VRAM range (1069-1182 = OWSP).
        if tile_id >= 1069 and tile_id <= 1182 then
            table.insert(enemy_slots, {slot=s, tile=tile_id, x=x, y=y})
        end
    end
end

f:write("\n# Entries in OWSP range (tiles 1069-1182):\n")
for _, e in ipairs(enemy_slots) do
    f:write(string.format("  slot=%d tile=%d X=%04X Y=%04X\n", e.slot, e.tile, e.x, e.y))
    -- Dump VRAM tile content.
    local base = e.tile * 32
    f:write(string.format("    Tile %d VRAM content (4bpp 8x8):\n", e.tile))
    for row = 0, 7 do
        local line = "      "
        for col = 0, 3 do
            line = line .. string.format("%02X ", VRAM(base + row*4 + col))
        end
        f:write(line .. "\n")
    end
end

client.screenshot("C:/tmp/audit_chr_gen2.png")
f:close()
client.exit()

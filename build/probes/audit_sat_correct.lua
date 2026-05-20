-- Re-scan SAT at correct address $F400.

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

local f = io.open("C:/tmp/audit_sat_correct.txt", "w")
f:write("# SAT scan at VRAM $F400\n")
local sat_base = 0xF400
for s = 0, 79 do
    local o = sat_base + s*8
    local y_hi = VRAM(o)
    local y_lo = VRAM(o + 1)
    local size = VRAM(o + 2)
    local link = VRAM(o + 3)
    local attr_hi = VRAM(o + 4)
    local attr_lo = VRAM(o + 5)
    local x_hi = VRAM(o + 6)
    local x_lo = VRAM(o + 7)
    local y = (y_hi<<8)|y_lo
    local x = (x_hi<<8)|x_lo
    local tile = ((attr_hi & 0x07) << 8) | attr_lo
    local palette = (attr_hi >> 5) & 3
    if y ~= 0 and y < 0x200 then
        f:write(string.format("SAT[%2d] Y=$%04X X=$%04X sz=%02X link=%02X tile=%4d pal=%d attr=%02X%02X\n",
            s, y, x, size, link, tile, palette, attr_hi, attr_lo))
    end
end

client.screenshot("C:/tmp/audit_sat_correct.png")
f:close()
client.exit()

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function VRAM(o) return memory.read_u8(o, "VRAM") end
local function CRAM(o) return memory.read_u8(o, "CRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

W(0x77D0, 0x46) W(0x77D1, 0x58)
W(0x77D2, 0x05) W(0x77D3, 0x80) W(0x77D4, 0x78)
W(0x77D5, 0x01) W(0x77D6, 0x01) W(0x77D7, 0x00) W(0x77D8, 0x77)
emu.frameadvance()
idle(30)

local f = io.open("C:/tmp/check_link.txt", "w")
f:write("# PAL1 (sprite palette) CRAM bytes 32..63\n")
for i = 0, 15 do
    local lo = CRAM(32 + i*2)
    local hi = CRAM(32 + i*2 + 1)
    f:write(string.format("PAL1[%2d] = %02X%02X\n", i, hi, lo))
end
f:write("\n# VRAM Link CHR tile 1025 (8x8 first tile)\n")
for r = 0, 7 do
    local line = string.format("row%d:", r)
    for c = 0, 3 do
        line = line .. string.format(" %02X", VRAM(1025*32 + r*4 + c))
    end
    f:write(line .. "\n")
end
f:write("\n# VRAM Link CHR tile 1041 (Link walk-down body — 16 tiles into Link block)\n")
for r = 0, 7 do
    local line = string.format("row%d:", r)
    for c = 0, 3 do
        line = line .. string.format(" %02X", VRAM(1041*32 + r*4 + c))
    end
    f:write(line .. "\n")
end
f:close()
client.exit()

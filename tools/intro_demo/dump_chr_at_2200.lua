-- Dump full PPU CHR ($0000-$1FFF) at frame 2200 specifically.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/intro_demo/nes_dump"

local function fc()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

while fc() < 2200 do emu.frameadvance() end

local f = io.open(OUT .. "/sp_chr_2200.bin", "wb")
for a = 0x0000, 0x0FFF do
    local ok, v = pcall(function() return memory.read_u8(a, "PPU Bus") end)
    f:write(string.char(ok and (v or 0) or 0))
end
f:close()

f = io.open(OUT .. "/bg_chr_2200.bin", "wb")
for a = 0x1000, 0x1FFF do
    local ok, v = pcall(function() return memory.read_u8(a, "PPU Bus") end)
    f:write(string.char(ok and (v or 0) or 0))
end
f:close()
print("dumped at frame 2200")

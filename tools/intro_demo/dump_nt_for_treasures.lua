-- Dump NES NT1+NT2 + scroll Y at frame 1950 (when "ALL OF TREASURES" centered).
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/intro_demo/nes_full"
local TARGET = 1950

local function fc()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

while fc() < TARGET do emu.frameadvance() end

local f = io.open(OUT .. "/nt_for_treasures.bin", "wb")
for a = 0x2000, 0x27FF do
    local ok, v = pcall(function() return memory.read_u8(a, "PPU Bus") end)
    f:write(string.char(ok and (v or 0) or 0))
end
f:close()

-- Also save scroll
f = io.open(OUT .. "/nt_for_treasures_meta.txt", "w")
f:write(string.format("frame=%d\nscroll_y=%d\n", fc(), mainmemory.read_u8(0xFC)))
f:close()
print("dumped")

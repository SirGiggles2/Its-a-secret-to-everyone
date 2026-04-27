-- Dump NES CIRAM (4096 bytes = NT1 + NT2 mirrored) at frame 1900 (when ALL OF TREASURES is visible).
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/intro_demo/nes_full"
local TARGET = 1900

local function fc()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end
while fc() < TARGET do emu.frameadvance() end

local f = io.open(OUT .. "/ciram_" .. TARGET .. ".bin", "wb")
for off = 0, 4095 do
    local ok, v = pcall(function() return memory.read_u8(off, "CIRAM (nametables)") end)
    f:write(string.char(ok and (v or 0) or 0))
end
f:close()
print("dumped CIRAM at " .. TARGET)

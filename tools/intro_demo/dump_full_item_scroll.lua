-- Dump PALRAM + OAM + CHR every 10 frames across full item scroll (2050-4700).
-- Output:
--   palram_<f>.bin (32 bytes)
--   oam_<f>.bin (256 bytes)
--   chr_<f>.bin (8192 bytes — full pattern table dump)

local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/intro_demo/nes_full"
local STEP = 10
local START_F = 2050
local END_F = 4700

local function fc()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

local function dump_domain(name, size, path)
    local f = io.open(path, "wb")
    for off = 0, size - 1 do
        local ok, v = pcall(function() return memory.read_u8(off, name) end)
        f:write(string.char(ok and (v or 0) or 0))
    end
    f:close()
end

while fc() < END_F do
    emu.frameadvance()
    local f = fc()
    if f >= START_F and f % STEP == 0 then
        dump_domain("PALRAM", 32, OUT .. "/palram_" .. f .. ".bin")
        dump_domain("OAM", 256, OUT .. "/oam_" .. f .. ".bin")
        dump_domain("CHR", 8192, OUT .. "/chr_" .. f .. ".bin")
    end
end
print("done")

-- Dump OAM every 100 frames from 2100 to 4500.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/intro_demo/nes_dump"

local function fc()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

while fc() < 4600 do
    emu.frameadvance()
    local f = fc()
    if f >= 2100 and f <= 4500 and f % 100 == 0 then
        local file = io.open(OUT .. "/oam_dense_" .. f .. ".bin", "wb")
        for o = 0, 255 do
            local ok, v = pcall(function() return memory.read_u8(o, "OAM") end)
            file:write(string.char(ok and (v or 0) or 0))
        end
        file:close()
    end
end
print("done")

-- dump_nes_nt.lua
-- Dumps NES PPU nametables (NT1 $2000 and NT2 $2400) to a binary file at frame 2200.
-- Each nametable = 32x30 cells (960 bytes) + 64 attribute bytes.
-- Output: NT1_960bytes | NT1_attr64bytes | NT2_960bytes | NT2_attr64bytes = 2048 bytes

local OUT_FILE = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/intro_demo/nes_nt_dump.bin"
local DUMP_FRAME = 2200

local function emu_frame()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

local function dump_nt()
    local f = io.open(OUT_FILE, "wb")
    if not f then return end
    -- Read NT1 ($2000-$23FF) and NT2 ($2400-$27FF) via PPU memory domain
    for addr = 0x2000, 0x27FF do
        local ok, v = pcall(function() return memory.read_u8(addr, "PPU Bus") end)
        f:write(string.char(ok and (v or 0) or 0))
    end
    f:close()
    print("Dumped NT1+NT2 to " .. OUT_FILE)
end

while emu_frame() < DUMP_FRAME do
    emu.frameadvance()
end
dump_nt()

-- Continue running so user can confirm visually
while emu_frame() < DUMP_FRAME + 100 do
    emu.frameadvance()
end

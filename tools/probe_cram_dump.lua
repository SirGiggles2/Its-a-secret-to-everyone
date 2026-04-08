-- Quick CRAM palette dump during item scroll
-- Captures the Genesis CRAM state at the same frame as the worst mismatch

local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/cram_dump.txt"
local f = io.open(OUT, "w")

f:write("# CRAM palette dump during item scroll\n\n")

local TARGET_FRAMES = {2300, 2601, 2641, 2700}

for _, target in ipairs(TARGET_FRAMES) do
    while emu.framecount() < target do
        emu.frameadvance()
    end

    f:write(string.format("=== Frame %d ===\n", emu.framecount()))

    -- Dump all 4 CRAM palettes (64 entries x 2 bytes = 128 bytes)
    for pal = 0, 3 do
        f:write(string.format("  PAL%d:", pal))
        for i = 0, 15 do
            local w = memory.read_u16_be(pal * 32 + i * 2, "CRAM")
            f:write(string.format(" %04X", w))
        end
        f:write("\n")
    end

    -- Dump first 8 sprite SAT entries to check palette bits + tile indices
    f:write("  SAT (first 8 sprites):\n")
    local sat_base = 0xF800
    for s = 0, 7 do
        local y    = memory.read_u16_be(sat_base + s*8 + 0, "VRAM")
        local sz   = memory.read_u16_be(sat_base + s*8 + 2, "VRAM")
        local tile = memory.read_u16_be(sat_base + s*8 + 4, "VRAM")
        local x    = memory.read_u16_be(sat_base + s*8 + 6, "VRAM")
        local pal_bits = (tile >> 13) & 0x3
        local tile_idx = tile & 0x7FF
        local pri = (tile >> 15) & 1
        local vf = (tile >> 12) & 1
        local hf = (tile >> 11) & 1
        f:write(string.format("    S%d: Y=%d X=%d tile=%d pal=%d pri=%d vf=%d hf=%d (raw=%04X)\n",
            s, y, x, tile_idx, pal_bits, pri, vf, hf, tile))
    end

    -- Read NES RAM sprite sub-palette state for comparison
    f:write("  NES sprite palettes (from NES RAM $3F10-$3F1F shadow):\n")
    local nes_base = 0xFF0000
    for sp = 0, 3 do
        f:write(string.format("    SP%d:", sp))
        for c = 0, 3 do
            local addr = 0x3F10 + sp*4 + c
            -- NES palette RAM is at PPU $3F00, but we need to read the Genesis
            -- shadow. The transpiled code stores NES palette writes. Let's read
            -- from the actual CRAM to verify.
            local cram_addr
            if c == 0 then
                f:write(" (bg0)")
            else
                if sp == 0 then cram_addr = 0x08 + c*2
                elseif sp == 1 then cram_addr = 0x10 + c*2
                elseif sp == 2 then cram_addr = 0x18 + c*2
                elseif sp == 3 then cram_addr = 0x28 + c*2
                end
                local w = memory.read_u16_be(cram_addr, "CRAM")
                f:write(string.format(" %04X@%02X", w, cram_addr))
            end
        end
        f:write("\n")
    end
    f:write("\n")
end

f:close()
print("CRAM dump written to " .. OUT)
client.exit()

-- bizhawk_sprite_sat_probe.lua
-- Reads Genesis Sprite Attribute Table (SAT) from VRAM $D800
-- and dumps the first 32 sprite entries to check positions, sizes, tile#, palette.
-- Also reads NES OAM shadow for comparison.
-- Captures at frame 200.

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_sprite_sat_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local function vram_u8(addr)
    for _, d in ipairs({"VRAM", "VDP VRAM"}) do
        local ok, v = pcall(function()
            memory.usememorydomain(d)
            return memory.read_u8(addr)
        end)
        if ok and v ~= nil then return v end
    end
    return 0
end

local function ram_u8(addr)
    for _, d in ipairs({"68K RAM", "Main RAM", "RAM"}) do
        local ok, v = pcall(function()
            memory.usememorydomain(d)
            return memory.read_u8(addr)
        end)
        if ok and v ~= nil then return v end
    end
    return 0
end

local function main()
    local CAPTURE_FRAME = 200
    log("=================================================================")
    log("Sprite SAT Probe  --  capturing at frame " .. CAPTURE_FRAME)
    log("=================================================================")

    for frame = 1, CAPTURE_FRAME + 2 do
        emu.frameadvance()
    end

    -- Genesis SAT is at VRAM $D800
    -- Each entry is 8 bytes:
    --   word 0: Y position (bits 9:0, value 128 = screen top)
    --   word 1: size & link (bits 8:0 = next link, bits 11:8 = size)
    --   word 2: tile attr (bit15=prio, 14:13=pal, 12=vflip, 11=hflip, 10:0=tile#)
    --   word 3: X position (bits 9:0, value 128 = screen left)
    local SAT_BASE = 0xD800

    log("")
    log("--- Genesis SAT (VRAM $D800) first 32 sprites ---")
    log("  #  Y      Link SzV SzH  Tile  Pal  Pri  X")
    local non_zero = 0
    for i = 0, 31 do
        local base = SAT_BASE + i * 8
        local w0 = (vram_u8(base+0) << 8) | vram_u8(base+1)
        local w1 = (vram_u8(base+2) << 8) | vram_u8(base+3)
        local w2 = (vram_u8(base+4) << 8) | vram_u8(base+5)
        local w3 = (vram_u8(base+6) << 8) | vram_u8(base+7)
        local y    = w0 & 0x3FF
        local link = w1 & 0x7F
        local szv  = (w1 >> 8) & 3
        local szh  = (w1 >> 10) & 3
        local tile = w2 & 0x7FF
        local pal  = (w2 >> 13) & 3
        local pri  = (w2 >> 15) & 1
        local x    = w3 & 0x3FF
        if y ~= 0 or x ~= 0 or tile ~= 0 then
            non_zero = non_zero + 1
            local yscreen = y - 128
            local xscreen = x - 128
            log(string.format("  %2d  %3d(%+4d)  %3d   %d    %d  %4d   %d    %d  %3d(%+4d)",
                i, y, yscreen, link, szv, szh, tile, pal, pri, x, xscreen))
        end
    end
    log(string.format("  Non-zero sprite entries: %d", non_zero))

    log("")
    log("--- NES OAM shadow ($FF0200-$FF02FF, first 32 sprites) ---")
    -- NES OAM: each sprite = 4 bytes at $0200+i*4: Y, tile, attr, X
    -- In Genesis RAM at NES_RAM_BASE+$0200 = $FF0200
    -- BizHawk RAM domain for Genesis is 64KB at $FF0000
    -- address offset = $0200
    log("  #   Y   Tile  Attr   X    (NES coords)")
    for i = 0, 31 do
        local base_nes = 0x0200 + i * 4
        local y_nes    = ram_u8(base_nes)
        local tile_nes = ram_u8(base_nes + 1)
        local attr_nes = ram_u8(base_nes + 2)
        local x_nes    = ram_u8(base_nes + 3)
        if y_nes ~= 0 or tile_nes ~= 0 then
            log(string.format("  %2d  %3d  $%02X   $%02X  %3d",
                i, y_nes, tile_nes, attr_nes, x_nes))
        end
    end

    -- Screenshot
    local ss_path = OUT_DIR .. "screenshot_sat_probe.png"
    client.screenshot(ss_path)
    log("")
    log("Screenshot: " .. ss_path)

    log("")
    log("=================================================================")
    log("SAT PROBE COMPLETE")
    log("=================================================================")
    f:close()
    client.exit()
end

main()

-- bizhawk_nes_palette_probe.lua
-- Runs against the NES ROM directly to read PPU palette ($3F00-$3F1F) at frame 200.
-- Also reads OAM (first 32 sprites) and a tile from CHR at $0240 (sprite tile $24).
-- Outputs to builds/reports/bizhawk_nes_palette_probe.txt
--
-- Run with: EmuHawk.exe --lua=...lua <path-to-NES-Zelda.nes>

local ROOT    = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_nes_palette_probe.txt"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local function ppu_u8(addr)
    for _, d in ipairs({"PPU", "PPU RAM", "VRAM"}) do
        local ok, v = pcall(function()
            memory.usememorydomain(d)
            return memory.read_u8(addr)
        end)
        if ok and v ~= nil then return v end
    end
    return nil
end

local function oam_u8(addr)
    for _, d in ipairs({"OAM", "Object Attribute Memory"}) do
        local ok, v = pcall(function()
            memory.usememorydomain(d)
            return memory.read_u8(addr)
        end)
        if ok and v ~= nil then return v end
    end
    return nil
end

local function list_domains()
    local ok, doms = pcall(function() return memory.getmemorydomainlist() end)
    if ok then
        return doms
    end
    return {}
end

local function main()
    local CAPTURE_FRAME = 200
    log("=================================================================")
    log("NES ROM Palette + OAM Probe  --  frame " .. CAPTURE_FRAME)
    log("=================================================================")

    -- List available memory domains
    local doms = list_domains()
    log("Memory domains available:")
    for _, d in ipairs(doms) do log("  " .. d) end
    log("")

    for frame = 1, CAPTURE_FRAME + 2 do
        emu.frameadvance()
    end

    -- Read NES PPU palette ($3F00-$3F1F)
    log("--- NES PPU Palette ($3F00-$3F1F) ---")
    for i = 0, 31 do
        local v = ppu_u8(0x3F00 + i)
        if v ~= nil then
            local label = (i < 16) and "BG" or "SP"
            local pal = (i >> 2) & 3
            local slot = i & 3
            log(string.format("  $3F%02X [%s pal%d slot%d] = $%02X", i, label, pal, slot, v))
        else
            log(string.format("  $3F%02X = (unreadable)", i))
        end
    end

    -- Read OAM (first 32 sprites = 128 bytes)
    log("")
    log("--- NES OAM (first 32 sprites) ---")
    log("  #   Y   Tile  Attr   X")
    for i = 0, 31 do
        local base = i * 4
        local y    = oam_u8(base)
        local tile = oam_u8(base+1)
        local attr = oam_u8(base+2)
        local x    = oam_u8(base+3)
        if y ~= nil and tile ~= nil then
            log(string.format("  %2d  %3d  $%02X   $%02X  %3d", i, y, tile, attr, x))
        end
    end

    -- CHR tile $24 (sprite CHR at PPU $0240)
    log("")
    log("--- NES CHR sprite tile $24 (PPU $0240, 16 bytes) ---")
    local row = ""
    for i = 0, 15 do
        local v = ppu_u8(0x0240 + i)
        if v ~= nil then
            row = row .. string.format("%02X ", v)
        else
            row = row .. "?? "
        end
    end
    log("  " .. row)

    local ss_path = OUT_DIR .. "screenshot_nes_palette.png"
    client.screenshot(ss_path)
    log("")
    log("Screenshot: " .. ss_path)

    log("=================================================================")
    log("NES PALETTE PROBE COMPLETE")
    log("=================================================================")
    f:close()
    client.exit()
end

main()

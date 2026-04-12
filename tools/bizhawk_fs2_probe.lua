-- bizhawk_fs2_probe.lua
-- Measure exact sprite Y positions + VSRAM on FS2 (REGISTER screen)
-- for NES and Genesis side-by-side comparison.

local ROOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR = ROOT .. "builds\\reports\\"
local SYSTEM = emu.getsystemid()
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local tag = "unknown"
if SYSTEM == "NES" then tag = "nes"
elseif SYSTEM == "GEN" or SYSTEM == "Genesis" then tag = "gen" end

local OUT_PATH = OUT_DIR .. "fs2_probe_" .. tag .. ".txt"
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

log("=== FS2 Sprite Position Probe (" .. tag .. ") ===")
log("system: " .. SYSTEM)

-- Memory helpers
local function try_dom(dom, offset, width)
    local ok, v = pcall(function()
        memory.usememorydomain(dom)
        if width == 1 then return memory.read_u8(offset)
        elseif width == 2 then return memory.read_u16_be(offset)
        else return memory.read_u32_be(offset) end
    end)
    return ok and v or nil
end

local function ram8(addr)
    if tag == "nes" then
        return try_dom("RAM", addr, 1) or try_dom("System Bus", addr, 1) or 0
    else
        local ofs = addr
        return try_dom("M68K BUS", 0xFF0000 + ofs, 1)
            or try_dom("68K RAM", ofs, 1)
            or try_dom("Main RAM", ofs, 1)
            or 0
    end
end

-- Boot: wait for title, press Start to reach FS1
for i = 1, 120 do
    emu.frameadvance()
end
-- Tap Start
for i = 1, 20 do
    if tag == "nes" then
        joypad.set({Start = true}, 1)
    else
        joypad.set({Start = true}, 1)
    end
    emu.frameadvance()
end
for i = 1, 10 do emu.frameadvance() end

-- Wait for Mode=$01 (file select)
local fs1_frame = nil
for i = 1, 300 do
    emu.frameadvance()
    local mode = ram8(0x0012)
    if mode == 0x01 and not fs1_frame then
        fs1_frame = i
    end
end
log("FS1 reached at frame offset: " .. tostring(fs1_frame))

-- Navigate: tap Down 3x to reach REGISTER YOUR NAME, then Start
for rep = 1, 3 do
    for i = 1, 5 do
        if tag == "nes" then
            joypad.set({Down = true}, 1)
        else
            joypad.set({Down = true}, 1)
        end
        emu.frameadvance()
    end
    for i = 1, 10 do emu.frameadvance() end
end

-- Press Start to enter FS2
for i = 1, 20 do
    if tag == "nes" then
        joypad.set({Start = true}, 1)
    else
        joypad.set({Start = true}, 1)
    end
    emu.frameadvance()
end

-- Wait for Mode=$0E
local fs2_frame = nil
for i = 1, 300 do
    emu.frameadvance()
    local mode = ram8(0x0012)
    if mode == 0x0E and not fs2_frame then
        fs2_frame = i
    end
end
log("FS2 reached at frame offset: " .. tostring(fs2_frame))

-- Let it settle
for i = 1, 60 do emu.frameadvance() end

-- Now dump all sprite OAM data (NES: $0200-$02FF, 64 entries × 4 bytes)
log("")
log("--- NES OAM buffer ($0200-$02FF) ---")
log("  spr#  Y     tile  attr  X")
for spr = 0, 15 do  -- first 16 sprites should cover Link + cursors
    local base = 0x0200 + spr * 4
    local y    = ram8(base + 0)
    local tile = ram8(base + 1)
    local attr = ram8(base + 2)
    local x    = ram8(base + 3)
    if y < 0xF0 then  -- visible sprites only
        log(string.format("  %2d   $%02X=%3d  $%02X  $%02X  $%02X=%3d",
            spr, y, y, tile, attr, x, x))
    end
end

-- Key NES RAM bytes
log("")
log("--- Key RAM values ---")
log(string.format("  GameMode ($0012): $%02X", ram8(0x0012)))
log(string.format("  CurSaveSlot ($0016): $%02X", ram8(0x0016)))
log(string.format("  $0000 (X seed): $%02X = %d", ram8(0x0000), ram8(0x0000)))
log(string.format("  $0001 (Y seed): $%02X = %d", ram8(0x0001), ram8(0x0001)))
log(string.format("  $0084 (cursor Y): $%02X = %d", ram8(0x0084), ram8(0x0084)))
log(string.format("  $0085 (cursor Y2): $%02X = %d", ram8(0x0085), ram8(0x0085)))
log(string.format("  $0070 (cursor X): $%02X = %d", ram8(0x0070), ram8(0x0070)))
log(string.format("  $0071 (cursor X2): $%02X = %d", ram8(0x0071), ram8(0x0071)))

-- Genesis-specific: dump VSRAM and SAT
if tag == "gen" then
    log("")
    log("--- Genesis VSRAM ---")
    local vsram0 = try_dom("M68K BUS", 0xFF0838, 2) or 0  -- ACTIVE_EVENT_VSRAM
    log(string.format("  ACTIVE_EVENT_VSRAM ($FF0838): $%04X = %d", vsram0, vsram0))

    log("")
    log("--- Genesis SAT (first 16 sprites from VRAM $F800) ---")
    log("  spr#   Y      size|link   tile_word    X")
    -- Read SAT from VRAM via M68K BUS (VDP RAM)
    for spr = 0, 15 do
        local base = 0xF800 + spr * 8
        local y_w = try_dom("VRAM", base, 2) or 0
        local sl  = try_dom("VRAM", base + 2, 2) or 0
        local tw  = try_dom("VRAM", base + 4, 2) or 0
        local x_w = try_dom("VRAM", base + 6, 2) or 0
        local y_scr = y_w - 128
        local x_scr = (x_w % 512) - 128
        if y_scr >= 0 and y_scr < 224 then
            log(string.format("  %2d   $%04X(scr=%3d)  $%04X  $%04X  $%04X(scr=%3d)",
                spr, y_w, y_scr, sl, tw, x_w, x_scr))
        end
    end
end

-- Take screenshot
local ss_path = "fs2_probe_" .. tag .. ".png"
client.screenshot(ss_path)
log("")
log("screenshot: " .. ss_path)
log("done.")
f:close()
client.exit()

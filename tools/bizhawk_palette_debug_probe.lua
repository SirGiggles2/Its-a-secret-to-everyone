-- bizhawk_palette_debug_probe.lua
-- Targeted: dumps DynTileBuf (NES RAM $0302-$0325) and tracks VDP CRAM writes.
-- Captures at frame 200.

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_palette_debug_probe.txt"
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local VDP_CTRL = 0x00C00004
local VDP_DATA = 0x00C00000
local NES_RAM  = 0x00FF0000  -- Genesis address of NES RAM base

-- Track CRAM writes by watching VDP_CTRL/DATA
local last_vdp_cmd = 0
local cram_writes = {}  -- {addr, value}

-- Watch VDP_CTRL (32-bit writes set CRAM address)
-- Watch VDP_DATA (16-bit writes send color)
-- We do this by polling each frame since BizHawk GPGX may not support mid-frame callbacks

local function read_nes_ram_byte(offset)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(NES_RAM + offset)
    end)
    return ok and v or 0xFF
end

local function read_genesis_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

local function read_cram_u16(addr)
    for _, d in ipairs({"CRAM", "VDP CRAM", "Color RAM"}) do
        local ok, v = pcall(function()
            memory.usememorydomain(d)
            return memory.read_u16_be(addr)
        end)
        if ok and v ~= nil then return v end
    end
    return 0
end

local frame = 0
local CAPTURE_FRAME = 200

event.onframeend(function()
    frame = frame + 1
    if frame ~= CAPTURE_FRAME then return end

    log("=================================================================")
    log("Palette Debug Probe  —  frame " .. frame)
    log("=================================================================")

    -- 1. Dump NES RAM state variables
    log("\n--- NES RAM State ---")
    local mode      = read_nes_ram_byte(0x0011)
    local tileSel   = read_nes_ram_byte(0x0014)
    local ppuCtrl   = read_nes_ram_byte(0x00FF)
    local ppuLatch  = read_nes_ram_byte(0x080A)  -- PPU_LATCH offset
    log(string.format("  $0011 (mode)        = $%02X", mode))
    log(string.format("  $0014 (tileBufSel)  = $%02X", tileSel))
    log(string.format("  $00FF (ppuCtrl)     = $%02X", ppuCtrl))

    -- 2. Dump DynTileBuf ($0301-$0326 = len + 36 data bytes)
    log("\n--- DynTileBuf (NES RAM $0301-$0326) ---")
    local line = ""
    for i = 0, 37 do
        local b = read_nes_ram_byte(0x0301 + i)
        line = line .. string.format("%02X ", b)
    end
    log("  " .. line)
    log("  (offset 0=$0301=len, offset 1=$0302=DynTileBuf[0]...)")

    -- 3. Dump the zero-page pointer ($0000/$0001 = ptr for TransferTileBuf)
    local ptr_lo = read_nes_ram_byte(0x0000)
    local ptr_hi = read_nes_ram_byte(0x0001)
    local ptr_val = ptr_hi * 256 + ptr_lo
    log(string.format("\n--- Zero-page ptr ($0000/$0001) ---"))
    log(string.format("  lo=$%02X hi=$%02X → NES ptr=$%04X → Genesis=$%06X",
        ptr_lo, ptr_hi, ptr_val, NES_RAM + ptr_val))

    -- 4. Dump CRAM entries 0-15 (first palette)
    log("\n--- CRAM (first 16 entries = palette 0) ---")
    for i = 0, 15 do
        local word = read_cram_u16(i * 2)
        local r = (word >> 1) & 7
        local g = (word >> 5) & 7
        local b = (word >> 9) & 7
        log(string.format("  CRAM[0][%02d] addr=%3d = $%04X  R=%d G=%d B=%d",
            i, i*2, word, r, g, b))
    end

    -- 5. Dump VDP registers from VDP_DATA shadow (if accessible)
    log("\n--- NES PPU_VADDR ($FF0800/$FF0801) ---")
    local ppu_vaddr_hi = read_nes_ram_byte(0x0800)
    local ppu_vaddr_lo = read_nes_ram_byte(0x0801)
    log(string.format("  PPU_VADDR = $%02X%02X", ppu_vaddr_hi, ppu_vaddr_lo))

    -- 6. Dump NES RAM $0300-$0340 in hex
    log("\n--- NES RAM $0300-$033F ---")
    local hexline = ""
    for i = 0, 63 do
        local b = read_nes_ram_byte(0x0300 + i)
        hexline = hexline .. string.format("%02X ", b)
        if (i+1) % 16 == 0 then
            log(string.format("  [$%04X] %s", 0x0300 + i - 15, hexline))
            hexline = ""
        end
    end

    -- 7. NES RAM $0000-$000F (zero page / ptr area)
    log("\n--- NES RAM $0000-$000F ---")
    local zpage = ""
    for i = 0, 15 do
        zpage = zpage .. string.format("%02X ", read_nes_ram_byte(i))
    end
    log("  " .. zpage)

    log("\n=================================================================")
    log("PALETTE DEBUG PROBE COMPLETE")
    log("=================================================================")
    f:close()
    client.exit()
end)

-- Run indefinitely until capture frame
while true do
    emu.frameadvance()
end

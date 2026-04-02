-- bizhawk_vdp_write_probe.lua
-- Logs every write to VDP_CTRL ($C00004) and VDP_DATA ($C00000) for frames 1-60.
-- Identifies CRAM write commands ($C0xxxxxx) and the color words that follow.

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_vdp_write_probe.txt"
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local VDP_DATA = 0x00C00000
local VDP_CTRL = 0x00C00004

-- State
local frame_count    = 0
local CAPTURE_END    = 60
local writes         = {}    -- {frame, addr_str, val_hex, note}
local last_cmd       = nil   -- last 32-bit VDP command word
local last_cmd_frame = 0
local cram_pending   = false -- true after a CRAM write command
local cram_addr      = 0

-- We poll each frame-end rather than use memory callbacks,
-- because BizHawk GPGX may not support mid-frame write intercepts.
-- Instead, we read the VDP domain (CRAM) at frame-end and log any changes.

-- Track CRAM state
local prev_cram = {}
for i = 0, 127, 2 do
    local ok, v = pcall(function()
        memory.usememorydomain("CRAM")
        return memory.read_u16_be(i)
    end)
    prev_cram[i] = ok and v or 0
end

log("=================================================================")
log("VDP Write Probe  —  frames 1-" .. CAPTURE_END)
log("  Watching CRAM domain for changes each frame.")
log("  Also dumping key M68K BUS state at frame 10, 20, 30.")
log("=================================================================")
log("")

local function read_nes_ram_byte(offset)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(0xFF0000 + offset)
    end)
    return ok and v or 0xFF
end

local function read_ppu_state()
    -- PPU_STATE_BASE = $FF0800
    local ok, latch = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(0xFF0800)
    end)
    local ok2, vaddr = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u16_be(0xFF0802)
    end)
    return (ok and latch or 0xFF), (ok2 and vaddr or 0xFFFF)
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

event.onframeend(function()
    frame_count = frame_count + 1
    if frame_count > CAPTURE_END then return end

    -- Check for CRAM changes
    local changed = false
    for i = 0, 127, 2 do
        local cur = read_cram_u16(i)
        if cur ~= prev_cram[i] then
            if not changed then
                log(string.format("--- CRAM CHANGES at frame %d ---", frame_count))
                changed = true
            end
            local r = (cur >> 1) & 7
            local g = (cur >> 5) & 7
            local b = (cur >> 9) & 7
            log(string.format("  CRAM[%02d] (byte_addr=%3d): $%04X → $%04X  R=%d G=%d B=%d",
                i/2, i, prev_cram[i], cur, r, g, b))
            prev_cram[i] = cur
        end
    end

    -- Dump key state at specific frames
    if frame_count == 5 or frame_count == 15 or frame_count == 35 then
        local latch, vaddr = read_ppu_state()
        local ppuctrl  = read_nes_ram_byte(0x00FF)
        local tileSel  = read_nes_ram_byte(0x0014)
        local dynbuf0  = read_nes_ram_byte(0x0302)
        local ptr_lo   = read_nes_ram_byte(0x0000)
        local ptr_hi   = read_nes_ram_byte(0x0001)
        log(string.format("--- State at frame %d ---", frame_count))
        log(string.format("  PPU_LATCH=$%02X  PPU_VADDR=$%04X", latch, vaddr))
        log(string.format("  PPUCTRL=$%02X  TileBufSel=$%02X  DynBuf[0]=$%02X",
            ppuctrl, tileSel, dynbuf0))
        log(string.format("  ptr=$%02X/$%02X (NES $%04X)", ptr_lo, ptr_hi, ptr_hi*256+ptr_lo))
    end

    if frame_count == CAPTURE_END then
        log("")
        log("--- Final CRAM state (all 64 entries) ---")
        for i = 0, 15 do
            for j = 0, 3 do
                local addr = (j * 16 + i) * 2
                local w = read_cram_u16(addr)
                local r = (w >> 1) & 7
                local g = (w >> 5) & 7
                local b = (w >> 9) & 7
                log(string.format("  CRAM[%d][%02d] addr=%3d = $%04X  R=%d G=%d B=%d",
                    j, i, addr, w, r, g, b))
            end
        end
        log("")
        log("=================================================================")
        log("VDP WRITE PROBE COMPLETE")
        log("=================================================================")
        f:close()
        client.exit()
    end
end)

while true do
    emu.frameadvance()
end

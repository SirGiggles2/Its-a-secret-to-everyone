-- bizhawk_cram_trace_probe.lua
-- Traces every CRAM change across 250 frames.
-- Also dumps PPU_VADDR, $0302 (DynBuf), and $0000/$0001 (ptr) at key intervals.

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_cram_trace_probe.txt"
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local frame_count = 0
local CAPTURE_END = 250

local function read_nes_ram_byte(offset)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(0xFF0000 + offset)
    end)
    return ok and v or 0xFF
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

-- Track CRAM state
local prev_cram = {}
for i = 0, 127, 2 do
    prev_cram[i] = read_cram_u16(i)
end

log("=================================================================")
log("CRAM Trace Probe  —  frames 1-" .. CAPTURE_END)
log("=================================================================")
log("")

event.onframeend(function()
    frame_count = frame_count + 1
    if frame_count > CAPTURE_END then return end

    -- Check for CRAM changes this frame
    local changed = false
    for i = 0, 127, 2 do
        local cur = read_cram_u16(i)
        if cur ~= prev_cram[i] then
            if not changed then
                log(string.format("--- CRAM CHANGES at frame %d ---", frame_count))
                -- Also dump state
                local ppu_latch  = read_nes_ram_byte(0x0800)
                local ppu_vaddr  = read_nes_ram_byte(0x0802) * 256 + read_nes_ram_byte(0x0803)
                local dynbuf0    = read_nes_ram_byte(0x0302)
                local ptr_lo     = read_nes_ram_byte(0x0000)
                local ptr_hi     = read_nes_ram_byte(0x0001)
                local ppuctrl    = read_nes_ram_byte(0x00FF)
                local ppuctrl_hw = read_nes_ram_byte(0x0804)
                local subphase   = read_nes_ram_byte(0x042D)
                log(string.format("  PPU_LATCH=$%02X PPU_VADDR=$%04X  DynBuf[0]=$%02X",
                    ppu_latch, ppu_vaddr, dynbuf0))
                log(string.format("  ptr=$%02X/$%02X (NES $%04X)  ppuCtrl=$%02X ppuCtrl_hw=$%02X subphase=$%02X",
                    ptr_lo, ptr_hi, ptr_hi*256+ptr_lo, ppuctrl, ppuctrl_hw, subphase))
                changed = true
            end
            local r = (cur >> 1) & 7
            local g = (cur >> 5) & 7
            local b = (cur >> 9) & 7
            local pr = (prev_cram[i] >> 1) & 7
            local pg = (prev_cram[i] >> 5) & 7
            local pb = (prev_cram[i] >> 9) & 7
            log(string.format("  CRAM byte_addr=%3d (pal=%d col=%d): $%04X(R%dG%dB%d) → $%04X(R%dG%dB%d)",
                i, i//32, (i%32)//2, prev_cram[i], pr, pg, pb, cur, r, g, b))
            prev_cram[i] = cur
        end
    end

    -- Dump state every 10 frames after NMI starts (frames 30-60)
    if (frame_count >= 30 and frame_count <= 60 and frame_count % 5 == 0) or
       frame_count == 10 or frame_count == 20 then
        local ppu_latch  = read_nes_ram_byte(0x0800)
        local ppu_vaddr  = read_nes_ram_byte(0x0802) * 256 + read_nes_ram_byte(0x0803)
        local dynbuf0    = read_nes_ram_byte(0x0302)
        local ptr_lo     = read_nes_ram_byte(0x0000)
        local ptr_hi     = read_nes_ram_byte(0x0001)
        local ppuctrl    = read_nes_ram_byte(0x00FF)
        local subphase   = read_nes_ram_byte(0x042D)
        local mode       = read_nes_ram_byte(0x0011)
        log(string.format("f%03d: PPU_VADDR=$%04X DynBuf=$%02X ptr=$%04X ppuCtrl=$%02X sub=$%02X mode=$%02X",
            frame_count, ppu_vaddr, dynbuf0, ptr_hi*256+ptr_lo, ppuctrl, subphase, mode))
    end

    if frame_count == CAPTURE_END then
        log("")
        log("--- Final CRAM (all 64 entries) ---")
        for i = 0, 63 do
            local addr = i * 2
            local w = read_cram_u16(addr)
            if w ~= 0 then
                local r = (w >> 1) & 7
                local g = (w >> 5) & 7
                local b = (w >> 9) & 7
                log(string.format("  CRAM[%d][%02d] addr=%3d = $%04X  R=%d G=%d B=%d",
                    i//16, i%16, addr, w, r, g, b))
            end
        end
        log("")
        log("=================================================================")
        log("CRAM TRACE PROBE COMPLETE")
        log("=================================================================")
        f:close()
        client.exit()
    end
end)

while true do
    emu.frameadvance()
end

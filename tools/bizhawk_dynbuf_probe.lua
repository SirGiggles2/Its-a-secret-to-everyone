-- bizhawk_dynbuf_probe.lua
-- Dumps DynTileBuf ($FF0302-$FF0325) contents at key frames to trace palette data.
-- Also tracks PPU_VADDR and CRAM[0] to verify palette write path.

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_dynbuf_probe.txt"
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local frame_count = 0
local CAPTURE_END = 350

local function rb(offset)
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

local function dump_dynbuf(label)
    local bytes = {}
    for i = 0, 35 do
        bytes[i] = rb(0x0302 + i)
    end
    local hex = ""
    for i = 0, 35 do
        hex = hex .. string.format("%02X ", bytes[i])
    end
    log(string.format("  DynTileBuf[0..35]: %s", hex))

    -- Decode structure if byte 0 looks like a PPU address
    if bytes[0] < 0x80 then
        local ppu_hi = bytes[0]
        local ppu_lo = bytes[1]
        local ctrl = bytes[2]
        local count = ctrl & 0x3F
        if count == 0 then count = 64 end
        log(string.format("  Decoded: PPU=$%02X%02X ctrl=$%02X count=%d incr=%s",
            ppu_hi, ppu_lo, ctrl, count, (ctrl & 0x40) ~= 0 and "+32" or "+1"))
        -- Show first 8 data bytes
        local data = ""
        for i = 3, math.min(10, 35) do
            data = data .. string.format("$%02X ", bytes[i])
        end
        log(string.format("  Data bytes[3..10]: %s", data))
    else
        log(string.format("  Sentinel: $%02X (buffer empty)", bytes[0]))
    end
end

local function dump_state(label)
    local ppuctrl  = rb(0x00FF)
    local ppuctrl_hw = rb(0x0804)
    local ppu_vaddr_hi = rb(0x0802)
    local ppu_vaddr_lo = rb(0x0803)
    local tilebufsel = rb(0x0014)
    local subphase = rb(0x042D)
    local mode = rb(0x0012)
    local isupd = rb(0x0011)
    local initgame = rb(0x00F4)
    local f5 = rb(0x00F5)
    local f6 = rb(0x00F6)
    local cram0 = read_cram_u16(0)
    local cram2 = read_cram_u16(2)
    local cram4 = read_cram_u16(4)
    local cram6 = read_cram_u16(6)

    log(string.format("%s (frame %d):", label, frame_count))
    log(string.format("  ppuCtrl=$%02X hw=$%02X VADDR=$%02X%02X TileBufSel=%d sub=$%02X mode=$%02X isUpd=$%02X initGame=$%02X",
        ppuctrl, ppuctrl_hw, ppu_vaddr_hi, ppu_vaddr_lo, tilebufsel, subphase, mode, isupd, initgame))
    log(string.format("  $F5=$%02X $F6=$%02X  CRAM[0]=$%04X CRAM[1]=$%04X CRAM[2]=$%04X CRAM[3]=$%04X",
        f5, f6, cram0, cram2, cram4, cram6))
    dump_dynbuf(label)
    log("")
end

log("=================================================================")
log("DynTileBuf Diagnostic Probe  —  frames 1-" .. CAPTURE_END)
log("=================================================================")
log("")

-- Track CRAM[0] for change detection
local prev_cram0 = 0

event.onframeend(function()
    frame_count = frame_count + 1
    if frame_count > CAPTURE_END then return end

    local cram0 = read_cram_u16(0)
    local dynbuf0 = rb(0x0302)
    local subphase = rb(0x042D)

    -- Dump at key frames
    if frame_count == 1 or frame_count == 10 or frame_count == 20 or frame_count == 30 then
        dump_state("Early init")
    end

    -- Dump every frame from 32 to 40 (around first NMI)
    if frame_count >= 32 and frame_count <= 40 then
        dump_state("NMI region")
    end

    -- Dump when DynBuf changes from $FF to non-$FF (palette data written)
    if frame_count > 30 and dynbuf0 ~= 0xFF and frame_count % 10 == 0 then
        dump_state("DynBuf active")
    end

    -- Dump every 20 frames in the 50-300 range
    if frame_count >= 50 and frame_count <= 300 and frame_count % 20 == 0 then
        dump_state("Periodic")
    end

    -- Dump when CRAM[0] changes
    if cram0 ~= prev_cram0 then
        dump_state("CRAM[0] CHANGED")
        prev_cram0 = cram0
    end

    -- Dump when subphase changes (track title init)
    if frame_count > 30 and frame_count < 300 then
        -- Check for subphase transitions
        if subphase == 1 or subphase == 2 then
            if frame_count % 5 == 0 then
                dump_state("Subphase=" .. subphase)
            end
        end
    end

    if frame_count == CAPTURE_END then
        log("")
        log("--- Final CRAM (BG palettes 0-3) ---")
        for pal = 0, 3 do
            local line = string.format("  Pal %d:", pal)
            for col = 0, 3 do
                local addr = pal * 32 + col * 2
                local w = read_cram_u16(addr)
                line = line .. string.format(" $%04X", w)
            end
            log(line)
        end
        log("")
        log("=================================================================")
        log("DYNBUF PROBE COMPLETE")
        log("=================================================================")
        f:close()
        client.exit()
    end
end)

while true do
    emu.frameadvance()
end

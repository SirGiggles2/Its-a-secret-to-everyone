-- bizhawk_vdp_data_intercept_probe.lua
-- Hooks writes to VDP_DATA ($C00000) and logs values + context.
-- Also reads DynTileBuf and NES palette bytes at the relevant frame.
-- Runs for 150 frames to cover the palette write at frame ~95.

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_vdp_data_intercept_probe.txt"
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local VDP_DATA = 0x00C00000
local VDP_CTRL = 0x00C00004
local CAPTURE_END = 150

local frame_count = 0

local function read_bus_u8(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(addr)
    end)
    return ok and v or 0xFF
end

local function read_bus_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0xFFFF
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

log("=================================================================")
log("VDP DATA Intercept Probe  -- frames 1-" .. CAPTURE_END)
log("=================================================================")
log("")

-- Track per-frame VDP_CTRL and VDP_DATA writes by polling CRAM each frame.
-- Also at frame 94-96, dump full DynTileBuf and ROM palette table.

local prev_cram = {}
for i = 0, 127, 2 do
    prev_cram[i] = read_cram_u16(i)
end

local function dump_dyntilebuf(label)
    log("--- " .. label .. " ---")
    local buf = {}
    for i = 0, 39 do
        table.insert(buf, string.format("%02X", read_bus_u8(0xFF0302 + i)))
    end
    log("  DynTileBuf[$0302..]: " .. table.concat(buf, " "))
    log(string.format("  ptr=$%02X/$%02X (NES $%04X)",
        read_bus_u8(0xFF0000), read_bus_u8(0xFF0001),
        read_bus_u8(0xFF0001)*256 + read_bus_u8(0xFF0000)))
    log(string.format("  TileBufSel=$%02X  subphase=$%02X  ppuCtrl=$%02X",
        read_bus_u8(0xFF0014), read_bus_u8(0xFF042D), read_bus_u8(0xFF00FF)))
    log(string.format("  PPU_VADDR=$%04X  PPU_LATCH=$%02X",
        read_bus_u16(0xFF0802), read_bus_u8(0xFF0800)))
end

local function dump_rom_palette_table()
    log("--- ROM nes_palette_to_genesis at $000007AE (checking $36 entry) ---")
    -- Entry $36 is at $00000722 + $36*2 = $0000078E
    local addr = 0x722
    log(string.format("  Entry $00 @ $%04X: $%04X", addr+0x00*2, read_bus_u16(addr+0x00*2)))
    log(string.format("  Entry $0F @ $%04X: $%04X", addr+0x0F*2, read_bus_u16(addr+0x0F*2)))
    log(string.format("  Entry $36 @ $%04X: $%04X", addr+0x36*2, read_bus_u16(addr+0x36*2)))
    log(string.format("  Entry $30 @ $%04X: $%04X", addr+0x30*2, read_bus_u16(addr+0x30*2)))
    log(string.format("  Entry $3B @ $%04X: $%04X", addr+0x3B*2, read_bus_u16(addr+0x3B*2)))
end

event.onframeend(function()
    frame_count = frame_count + 1
    if frame_count > CAPTURE_END then return end

    -- Dump state at frames before/during/after palette write
    if frame_count == 90 or frame_count == 93 or frame_count == 94 then
        dump_dyntilebuf("Pre-palette state at frame " .. frame_count)
    end

    if frame_count == 93 then
        dump_rom_palette_table()
    end

    -- Detect CRAM changes
    local changed = false
    for i = 0, 127, 2 do
        local cur = read_cram_u16(i)
        if cur ~= prev_cram[i] then
            if not changed then
                log(string.format("--- CRAM CHANGES at frame %d ---", frame_count))
                dump_dyntilebuf("State when CRAM changed (frame " .. frame_count .. ")")
                dump_rom_palette_table()
                changed = true
            end
            local r = (cur >> 1) & 7
            local g = (cur >> 5) & 7
            local b = (cur >> 9) & 7
            local pr = (prev_cram[i] >> 1) & 7
            local pg = (prev_cram[i] >> 5) & 7
            local pb = (prev_cram[i] >> 9) & 7
            log(string.format("  CRAM[%d][%02d] addr=%3d: $%04X(R%dG%dB%d) -> $%04X(R%dG%dB%d)",
                i//32, (i%32)//2, i, prev_cram[i], pr, pg, pb, cur, r, g, b))
            prev_cram[i] = cur
        end
    end

    if frame_count == CAPTURE_END then
        log("")
        log("=================================================================")
        log("INTERCEPT PROBE COMPLETE")
        log("=================================================================")
        f:close()
        client.exit()
    end
end)

while true do
    emu.frameadvance()
end

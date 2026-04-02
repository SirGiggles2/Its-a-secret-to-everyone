-- bizhawk_palette_d0_debug_probe.lua
-- Reads NES_RAM[$0900..$091F] at frame 96 to capture D0 values
-- written by the debug store in .t19_palette before the color lookup.
-- CRAM addr 0,2,4,...,30 maps to buf[0],buf[2],...,buf[30].

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_palette_d0_debug_probe.txt"
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local frame_count = 0

local function read_nes_u8(offset)
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

log("=================================================================")
log("Palette D0 Debug Probe  -- reads debug buf at $FF0900 after frame 95")
log("=================================================================")
log("")

event.onframeend(function()
    frame_count = frame_count + 1

    if frame_count == 96 then
        log("--- Debug buf $FF0900..$FF091F (raw D0 per CRAM slot) at frame 96 ---")
        log("  Slot 0 = $3F00 (palette 0 col 0), Slot 2 = $3F01, ...")
        for slot = 0, 15 do
            local cram_addr = slot * 2        -- 0, 2, 4, ..., 30
            local d0_raw = read_nes_u8(0x0900 + cram_addr)
            local cram_val = read_cram_u16(cram_addr)
            local r = (cram_val >> 1) & 7
            local g = (cram_val >> 5) & 7
            local b = (cram_val >> 9) & 7
            log(string.format("  BG pal slot %2d (CRAM addr %2d): D0=$%02X  CRAM=$%04X (R%dG%dB%d)",
                slot, cram_addr, d0_raw, cram_val, r, g, b))
        end
        log("")
        log("--- Also DynTileBuf[$0302..] ---")
        local buf = {}
        for i = 0, 39 do
            table.insert(buf, string.format("%02X", read_nes_u8(0x0302 + i)))
        end
        log("  " .. table.concat(buf, " "))
        log("")
        log("--- ptr / PPU state ---")
        log(string.format("  ptr=$%02X/$%02X  PPU_VADDR=$%04X  TileBufSel=$%02X",
            read_nes_u8(0x0000), read_nes_u8(0x0001),
            read_nes_u8(0x0802)*256 + read_nes_u8(0x0803),
            read_nes_u8(0x0014)))
        log("")
        log("=================================================================")
        log("PROBE COMPLETE")
        log("=================================================================")
        f:close()
        client.exit()
    end
end)

while true do
    emu.frameadvance()
end

-- bizhawk_cram0_trace_probe.lua
-- Traces CRAM entry 0 changes to find where $0466 comes from

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_cram0_trace_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s end

local function cram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("CRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

local function get_reg(name)
    local ok, v = pcall(function() return emu.getregister(name) end)
    return ok and v or 0
end

log("=================================================================")
log("CRAM Entry 0 Trace — watching for $0466")
log("=================================================================")

local prev_cram0 = 0
local changes = {}

-- Check CRAM[0] every frame
local frame_handler = event.onframeend(function()
    local f = emu.framecount()
    local c0 = cram_u16(0)
    if c0 ~= prev_cram0 then
        local pc = get_reg("M68K PC")
        changes[#changes+1] = string.format("frame %d: CRAM[0] changed $%04X -> $%04X  PC=$%06X",
            f, prev_cram0, c0, pc)
        prev_cram0 = c0
    end
end)

-- Also hook the palette write paths to see what NES color is being used
-- Hook _ppu_write_7 palette path: address around line 510-515
-- $3F00 write at .t19_palette

-- Hook the LUT lookup in .ttf_palette_range (line 1697: move.w (A3,D0.W),D0)
-- But we need the address from the listing. Let me hook a broader spot.

-- Hook: just before VDP_DATA write in .ttf_palette_range
-- From listing: $0CEC is around there. Let me hook the VDP_DATA write after palette lookup.

-- Actually, let me just dump CRAM[0] at key frame intervals AND log the
-- NES palette RAM that feeds it

-- Run 300 frames with per-frame monitoring
for i = 1, 300 do emu.frameadvance() end

log("")
log(string.format("Total CRAM[0] changes: %d", #changes))
log("")
for _, c in ipairs(changes) do log("  " .. c) end

-- Also dump the full CRAM state
log("")
log("─── Final CRAM state ─────────────────────────────────────")
for pal = 0, 3 do
    local entries = {}
    for c = 0, 15 do
        entries[#entries+1] = string.format("%04X", cram_u16(pal * 32 + c * 2))
    end
    log(string.format("  pal%d: %s", pal, table.concat(entries, " ")))
end

-- Dump NES palette shadow RAM
log("")
log("─── NES Palette RAM ($FF0300 area) ──────────────────────")
memory.usememorydomain("M68K BUS")
local bytes = {}
for i = 0, 31 do
    bytes[#bytes+1] = string.format("%02X", memory.read_u8(0xFF0300 + i))
end
log("  $FF0300: " .. table.concat(bytes, " "))

-- Also check what's at the actual NES palette mirror ($3F00 area in PPU shadow)
-- PPU state is at $FF0800+
log("")
log("─── PPU shadow state ─────────────────────────────────────")
for i = 0, 15 do
    log(string.format("  $FF%04X = $%02X", 0x0800 + i, memory.read_u8(0xFF0800 + i)))
end

-- Write
local fh = io.open(REPORT, "w")
for _, line in ipairs(lines) do fh:write(line .. "\n") end
fh:close()
print("CRAM0 trace written to: " .. REPORT)
client.exit()

-- bizhawk_cram_trace_probe.lua
-- Watches ALL CRAM entries every frame and logs changes with context

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_cram_trace_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s end

local function cram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("CRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

local function bus_u8(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(addr)
    end)
    return ok and v or 0
end

local function bus_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

local function get_reg(name)
    local ok, v = pcall(function() return emu.getregister(name) end)
    return ok and v or 0
end

log("=================================================================")
log("CRAM Trace Probe — detailed CRAM change tracking")
log("=================================================================")

local prev_cram = {}
for i = 0, 63 do prev_cram[i] = 0 end

local changes = {}

-- Check ALL CRAM entries every frame to find unexpected changes
local frame_handler = event.onframeend(function()
    local f = emu.framecount()
    for i = 0, 63 do
        local c = cram_u16(i * 2)
        if c ~= prev_cram[i] then
            local pc = get_reg("M68K PC")
            local sp = get_reg("M68K A7")
            local extra = ""
            if i <= 3 or (i >= 16 and i <= 19) or (i >= 32 and i <= 35) or (i >= 48 and i <= 51) then
                extra = string.format("  SP=$%08X", sp)
            end
            changes[#changes+1] = string.format(
                "f%03d: CRAM[%02d] $%04X -> $%04X  PC=$%06X%s",
                f, i, prev_cram[i], c, pc, extra)
            prev_cram[i] = c
        end
    end
end)

-- Run 100 frames (enough to catch the corruption)
for i = 1, 100 do emu.frameadvance() end

log("")
log(string.format("Total CRAM changes logged: %d", #changes))
log("")
for _, c in ipairs(changes) do log("  " .. c) end

-- Dump CRAM state
log("")
log("─── Final CRAM (frame 100) ──────────────────────────────")
for pal = 0, 3 do
    local entries = {}
    for c = 0, 15 do
        entries[#entries+1] = string.format("%04X", cram_u16(pal * 32 + c * 2))
    end
    log(string.format("  pal%d: %s", pal, table.concat(entries, " ")))
end

-- Also dump NES palette RAM
log("")
log("─── NES Palette RAM ─────────────────────────────────────")
memory.usememorydomain("M68K BUS")
local bytes = {}
for i = 0, 31 do
    bytes[#bytes+1] = string.format("%02X", memory.read_u8(0xFF0300 + i))
end
log("  $FF0300: " .. table.concat(bytes, " "))

-- Dump the palette LUT expectations
log("")
log("─── Expected CRAM from NES palette ──────────────────────")
for i = 0, 15 do
    local nes = memory.read_u8(0xFF0300 + i)
    log(string.format("  BG[%02d]: NES=$%02X (idx=%d)", i, nes, nes % 64))
end

-- Write report
local fh = io.open(REPORT, "w")
for _, line in ipairs(lines) do fh:write(line .. "\n") end
fh:close()
print("CRAM trace probe written to: " .. REPORT)
client.exit()

-- bizhawk_attr_exec_probe.lua (v2)
-- Hooks attribute handler with correct register names ("M68K D5" etc.)

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_attr_exec_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s end

local function get_reg(name)
    local ok, v = pcall(function() return emu.getregister(name) end)
    return ok and v or 0
end

local function vram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

-- Track record parsing
local record_samples = {}   -- PPU addr at $0AC8 (after andi)
local dispatch_samples = {} -- D5 at $0B10 (dispatch start)
local attr_dispatch = {}    -- D5 at $0B22 (blo .ttf_attr_range)
local attr_loop_hits = 0
local write_2x2_hits = 0
local write_one_hits = 0
local write_one_samples = {}
local bmi_terminator = {}

-- Hook: $0AC8 = move.b (A0)+,D6 — PPU addr in D5 is finalized
event.onmemoryexecute(function()
    local d5 = get_reg("M68K D5") & 0xFFFF
    local a0 = get_reg("M68K A0")
    if #record_samples < 80 then
        record_samples[#record_samples+1] = string.format("PPU=$%04X A0=$%08X", d5, a0)
    end
end, 0x0AC8, "record_addr")

-- Hook: $0B22 = blo .ttf_attr_range
event.onmemoryexecute(function()
    local d5 = get_reg("M68K D5") & 0xFFFF
    if #attr_dispatch < 20 then
        attr_dispatch[#attr_dispatch+1] = string.format("D5=$%04X", d5)
    end
end, 0x0B22, "attr_dispatch")

-- Hook: $0C00 = .ttf_attr_loop
event.onmemoryexecute(function()
    attr_loop_hits = attr_loop_hits + 1
    local d5 = get_reg("M68K D5") & 0xFFFF
    local d2 = get_reg("M68K D2") & 0xFF
    local d3 = get_reg("M68K D3") & 0xFFFF
    local d4 = get_reg("M68K D4") & 0xFF
    if attr_loop_hits <= 10 then
        log(string.format("  attr_loop#%d D5=$%04X D2=$%02X D3=%d D4=$%02X",
            attr_loop_hits, d5, d2, d3, d4))
    end
end, 0x0C00, "attr_loop")

-- Hook: $06D0 = _attr_write_2x2
event.onmemoryexecute(function()
    write_2x2_hits = write_2x2_hits + 1
end, 0x06D0, "write_2x2")

-- Hook: $06E2 = _attr_write_one_tile
event.onmemoryexecute(function()
    write_one_hits = write_one_hits + 1
    if #write_one_samples < 20 then
        local d2 = get_reg("M68K D2") & 0xFFFF
        local d3 = get_reg("M68K D3") & 0xFFFF
        local d5 = get_reg("M68K D5") & 0xFFFF
        write_one_samples[#write_one_samples+1] = string.format(
            "col=%d row=%d pal=$%04X", d2, d3, d5)
    end
end, 0x06E2, "write_one")

-- Hook: $0AB8 = bmi .ttf_done (terminator check)
event.onmemoryexecute(function()
    local d0 = get_reg("M68K D0") & 0xFF
    if d0 >= 0x80 and #bmi_terminator < 10 then
        local a0 = get_reg("M68K A0")
        bmi_terminator[#bmi_terminator+1] = string.format("D0=$%02X A0=$%08X", d0, a0)
    end
end, 0x0AB8, "bmi_check")

-- Run 300 frames
for i = 1, 300 do emu.frameadvance() end

log("=================================================================")
log("Attribute Exec Probe v2 — frame 300")
log("=================================================================")

log("")
log(string.format("Total records parsed: %d", #record_samples))
log("--- Record PPU addresses (first 40) ---")
for i = 1, math.min(40, #record_samples) do
    log(string.format("  rec#%d: %s", i, record_samples[i]))
end

log("")
log(string.format("Attr dispatch hits ($0B22): %d", #attr_dispatch))
log("--- D5 at attr dispatch (first 20) ---")
for _, s in ipairs(attr_dispatch) do log("  " .. s) end

log("")
log(string.format("attr_loop_hits ($0C00): %d", attr_loop_hits))
log(string.format("write_2x2_hits ($06D0): %d", write_2x2_hits))
log(string.format("write_one_hits ($06E2): %d", write_one_hits))

log("")
log("--- _attr_write_one_tile samples ---")
for _, s in ipairs(write_one_samples) do log("  " .. s) end

log("")
log("--- BMI terminator events ---")
if #bmi_terminator == 0 then log("  (none)")
else for _, s in ipairs(bmi_terminator) do log("  " .. s) end end

-- Palette distribution
log("")
local NT_BASE = 0xC000
local pal_counts = {[0]=0,[1]=0,[2]=0,[3]=0}
for row = 0, 27 do
    for col = 0, 31 do
        local word = vram_u16(NT_BASE + row * 128 + col * 2)
        local pal = (word >> 13) & 3
        pal_counts[pal] = pal_counts[pal] + 1
    end
end
log(string.format("Plane A palette: pal0=%d pal1=%d pal2=%d pal3=%d",
    pal_counts[0], pal_counts[1], pal_counts[2], pal_counts[3]))

-- Write
local fh = io.open(REPORT, "w")
for _, line in ipairs(lines) do fh:write(line .. "\n") end
fh:close()
print("Attr exec probe v2 written to: " .. REPORT)
client.exit()

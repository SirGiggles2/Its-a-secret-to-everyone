-- bizhawk_nt_palette_probe.lua
-- Dump full nametable words including palette/flip bits

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_nt_palette_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s end

local function vram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

for i = 1, 300 do emu.frameadvance() end

log("=== Nametable Palette Probe (frame 300) ===")
log("")

-- Dump rows 0-29 with full word (priority|pal|vf|hf|tile)
local pal_counts = {[0]=0, [1]=0, [2]=0, [3]=0}
for row = 0, 29 do
    local s = string.format("r%02d:", row)
    for col = 0, 31 do
        local addr = 0xC000 + row * 0x80 + col * 2
        local word = vram_u16(addr)
        local tile = word & 0x07FF
        local hf = (word >> 11) & 1
        local vf = (word >> 12) & 1
        local pal = (word >> 13) & 3
        local pri = (word >> 15) & 1
        pal_counts[pal] = pal_counts[pal] + 1
        -- Show as PAL:TILE (compact)
        s = s .. string.format(" %d:%03X", pal, tile)
    end
    log(s)
end

log("")
log("--- Palette distribution ---")
for p = 0, 3 do
    log(string.format("  Palette %d: %d tiles", p, pal_counts[p]))
end

-- Write report
local fh = io.open(REPORT, "w")
for _, line in ipairs(lines) do fh:write(line .. "\n") end
fh:close()
print("NT palette probe written to: " .. REPORT)
client.exit()

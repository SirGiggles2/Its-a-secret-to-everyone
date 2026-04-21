-- Measure actual HINT rate by poking a DMC trigger and counting hint_tick
-- fires over exactly 60 frames of DMC streaming.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/audio_probe.txt"
local lines = {}
local function log(s)
    lines[#lines+1] = s; print(s)
    local f = io.open(OUT, "w")
    if f then f:write(table.concat(lines,"\n").."\n"); f:close() end
end
local function r16(a)
    local v = 0
    pcall(function()
        memory.usememorydomain("68K RAM")
        v = memory.read_u16_be(a - 0xFF0000)
    end)
    return v
end
local function w16(a, v)
    pcall(function()
        memory.usememorydomain("68K RAM")
        memory.write_u16_be(a - 0xFF0000, v)
    end)
end
local function poke(a, v)
    pcall(function()
        memory.usememorydomain("68K RAM")
        memory.writebyte(a - 0xFF0000, v)
    end)
end

log("=== HINT rate probe ===")
-- Wait for game to settle past attract intro
for i = 1, 400 do emu.frameadvance() end

-- Reset counter and trigger a big sample (sample 2 is longest)
w16(0xFFE230, 0)
poke(0xFF0601, 0x02)

-- Wait 60 frames with the sample streaming
for i = 1, 60 do emu.frameadvance() end

local ticks = r16(0xFFE230)
log(string.format("60 frames -> hint_tick=%d ticks", ticks))
log(string.format("Effective HINT rate = %.1f Hz (ticks * 60fps)", ticks))
log(string.format("Effective per-frame line count = %.2f", ticks / 60))

log("=== done ===")
pcall(function() client.exit() end)

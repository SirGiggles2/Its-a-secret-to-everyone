-- pc_sampler_probe.lua — sampling profiler.
--
-- After A+B+C settle, sample M68K PC at every emu frame end for N frames.
-- Bucket PC by symbol (loaded from C:\tmp\Debug.nm.txt).
-- Output histogram of hot functions to C:\tmp\pc_sampler.log.

local NM_PATH = "C:\\tmp\\Debug.nm.txt"
local OUT_LOG = "C:\\tmp\\pc_sampler.log"
local SAMPLE_FRAMES = 600    -- ~10 wall-seconds at 60fps

-- Load symbol table: lines like "00000a16 T render_set_sprite_full".
-- Build sorted array {addr, name}; binary-search per sample.
local syms = {}
do
    local fh = io.open(NM_PATH, "r")
    for line in fh:lines() do
        local a, t, n = line:match("^(%x+)%s+([Tt])%s+(.+)$")
        if a and (t == "T" or t == "t") then
            syms[#syms + 1] = { addr = tonumber(a, 16), name = n }
        end
    end
    fh:close()
end
table.sort(syms, function(x, y) return x.addr < y.addr end)

local function find_sym(pc)
    -- binary search: largest addr <= pc
    local lo, hi = 1, #syms
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if syms[mid].addr <= pc then lo = mid else hi = mid - 1 end
    end
    return syms[lo].name
end

-- Boot
local function press(buttons, frames)
    for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
    for i = 1, frames do emu.frameadvance() end
end
idle(120)
press({A=true, B=true, C=true}, 30)
idle(360)

-- Sample PC at end of each emu frame for SAMPLE_FRAMES frames.
local hist = {}
for i = 1, SAMPLE_FRAMES do
    emu.frameadvance()
    local pc = emu.getregister("M68K PC")
    local s = find_sym(pc)
    hist[s] = (hist[s] or 0) + 1
end

-- Sort + emit histogram.
local arr = {}
for name, cnt in pairs(hist) do arr[#arr + 1] = { name = name, cnt = cnt } end
table.sort(arr, function(x, y) return x.cnt > y.cnt end)

local f = io.open(OUT_LOG, "w")
f:write("pc_sampler probe — 2026-05-15\n")
f:write("==============================\n")
f:write(string.format("Samples: %d (1 sample per emu frame at frame-end)\n\n", SAMPLE_FRAMES))
f:write(string.format("%-7s  %-8s  %s\n", "count", "pct", "symbol (or nearest preceding)"))
f:write("------- --------  --------------------------------------------\n")
for i = 1, math.min(40, #arr) do
    local e = arr[i]
    f:write(string.format("%-7d  %-8.2f  %s\n", e.cnt, 100.0 * e.cnt / SAMPLE_FRAMES, e.name))
end
f:close()
gui.text(8, 8, "pc_sampler — see C:\\tmp\\pc_sampler.log")
client.screenshot("C:\\tmp\\pc_sampler.png")

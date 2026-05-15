-- vscroll_up_v2.lua — fixed game_frame addr + Link x/y tracking + extended walk.

local OUTDIR = "C:\\tmp\\vscroll2\\"
local NM_PATH = "C:\\tmp\\Debug.nm.txt"
os.execute("mkdir " .. OUTDIR .. " 2>NUL")

-- Locate s_frame_counter address dynamically via nm dump.
local function find_addr(name)
    local fh = io.open(NM_PATH, "r")
    for line in fh:lines() do
        local a, t, n = line:match("^(%x+)%s+%S%s+(.+)$")
        if n == name then return tonumber(a, 16) & 0xFFFFFF end
    end
    fh:close()
    return nil
end

local function find_addr_clean(name)
    local fh = io.open(NM_PATH, "r")
    for line in fh:lines() do
        line = line:gsub("\r", "")
        local a, _, n = line:match("^(%x+)%s+(%S)%s+(.+)$")
        if n == name then fh:close(); return tonumber(a, 16) & 0xFFFFFF end
    end
    fh:close()
    return nil
end
local frame_counter_addr = find_addr_clean("s_frame_counter")
if not frame_counter_addr then frame_counter_addr = 0x00FF0104 end
local fc_offset = frame_counter_addr - 0xFF0000   -- offset within 68K RAM domain
print(string.format("s_frame_counter @ M68K $%06X  (68K RAM offset $%04X)",
    frame_counter_addr, fc_offset))

local syms = {}
do
    local fh = io.open(NM_PATH, "r")
    for line in fh:lines() do
        local a, t, n = line:match("^(%x+)%s+([Tt])%s+(.+)$")
        if a and (t == "T" or t == "t") then
            syms[#syms + 1] = { addr = tonumber(a, 16) & 0xFFFFFF, name = n }
        end
    end
    fh:close()
end
table.sort(syms, function(x, y) return x.addr < y.addr end)
local function find_sym(pc)
    local lo, hi = 1, #syms
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if syms[mid].addr <= pc then lo = mid else hi = mid - 1 end
    end
    return syms[lo].name
end

local function read_game_frames()
    -- 16-bit big-endian.
    return memory.read_u8(fc_offset, "68K RAM") * 256
         + memory.read_u8(fc_offset + 1, "68K RAM")
end
local function nesram(off)
    return memory.read_u8(0x8000 + off, "68K RAM")
end
local function read_link_x() return nesram(0x0070) end
local function read_link_y() return nesram(0x0084) end

-- Boot.
local function press(buttons, frames)
    for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
    for i = 1, frames do emu.frameadvance() end
end
idle(120)
press({A=true, B=true, C=true}, 30)
idle(360)

-- Capture state BEFORE walking.
client.screenshot(OUTDIR .. "pre_walk.png")
local fperf = io.open(OUTDIR .. "perframe.csv", "w")
fperf:write("emu,game,game_delta,link_x,link_y,pc,sym\n")

local hist = {}
local game_prev = read_game_frames()
local scroll_seen = false
local scroll_first_frame = -1
local screenshot_n = 0
local total_frames = 1200

for i = 1, total_frames do
    joypad.set({Up=true}, 1)
    emu.frameadvance()

    local game_cnt = read_game_frames()
    local game_delta = game_cnt - game_prev
    if game_delta < 0 then game_delta = game_delta + 65536 end
    local pc = emu.getregister("M68K PC")
    local sym = find_sym(pc)
    hist[sym] = (hist[sym] or 0) + 1
    local lx = read_link_x()
    local ly = read_link_y()

    fperf:write(string.format("%d,%d,%d,%d,%d,%X,%s\n",
        emu.framecount(), game_cnt, game_delta, lx, ly, pc, sym))

    -- Detect scroll-in-progress by Link Y staying constant while game frames advance
    -- OR by detecting any frame where game_delta = 0 (frame-skip)
    -- We'll just snapshot every 30 frames during the walk for visual.
    if i % 60 == 0 then
        screenshot_n = screenshot_n + 1
        client.screenshot(string.format(OUTDIR .. "walk_%03d.png", screenshot_n))
    end

    game_prev = game_cnt
end

-- Release UP, settle 60, final screenshot.
joypad.set({}, 1)
idle(60)
client.screenshot(OUTDIR .. "final.png")

fperf:close()

-- Summary.
local arr = {}
for n, c in pairs(hist) do arr[#arr + 1] = {name=n, cnt=c} end
table.sort(arr, function(x, y) return x.cnt > y.cnt end)
local fs = io.open(OUTDIR .. "summary.log", "w")
fs:write("vscroll_up_v2 — 2026-05-15\n")
fs:write("==========================\n\n")
fs:write(string.format("s_frame_counter @ M68K $%06X\n", frame_counter_addr))
fs:write(string.format("walked frames: %d\n", total_frames))
fs:write(string.format("Link final x=%d y=%d\n", read_link_x(), read_link_y()))
fs:write(string.format("Game frames advanced: %d\n", read_game_frames()))
fs:write("\nTop PC buckets:\n")
for i = 1, math.min(20, #arr) do
    fs:write(string.format("  %-6d %-6.2f  %s\n", arr[i].cnt, 100*arr[i].cnt/total_frames, arr[i].name))
end
fs:close()

gui.text(8, 8, "vscroll_up_v2 done")
client.exit()

-- vscroll_up_capture.lua
-- Reproduce + capture v-scroll UP transition (Tektite room 0x77 -> Octorok 0x67).
-- Per-frame: scroll_y, emu/game ratio, plane row at screen top, frame screenshot
-- at key scroll positions. One launch, all data.

local OUTDIR = "C:\\tmp\\vscroll\\"
local NM_PATH = "C:\\tmp\\Debug.nm.txt"
os.execute("mkdir " .. OUTDIR .. " 2>NUL")

-- Symbol table for PC bucketing.
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
    local lo, hi = 1, #syms
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if syms[mid].addr <= pc then lo = mid else hi = mid - 1 end
    end
    return syms[lo].name
end

local function read_game_frames()
    return memory.read_u8(0x7202, "68K RAM") * 256 + memory.read_u8(0x7203, "68K RAM")
end

-- Read BG_A vertical scroll register from VSRAM.
-- VSRAM addr 0 = BG_A scroll Y, addr 2 = BG_B scroll Y.
local function read_scroll_y()
    -- BizHawk Genesis: VSRAM domain
    local hi = memory.read_u8(0, "VSRAM")
    local lo = memory.read_u8(1, "VSRAM")
    local raw = hi * 256 + lo
    -- 11-bit value, but sign extension by hardware
    if raw >= 0x400 then raw = raw - 0x800 end
    return raw
end

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
-- Now in gameplay at room 0x77 (Tektite OW).

-- Walk Link straight UP. NES Z1 OW rooms scroll vertically when Link hits top edge.
-- Pre-scroll start: capture state.
local fperf = io.open(OUTDIR .. "perframe.csv", "w")
fperf:write("emu,game,game_delta,scroll_y,plane_row_top,pc,sym,joy,scroll_state\n")

local hist = {}
local screenshot_targets = {0, -8, -16, -32, -56, -88, -120, -150, -176}
local screenshots_taken = {}
for _, v in ipairs(screenshot_targets) do screenshots_taken[v] = false end

-- Hold UP for 600 frames (~10 wall sec). Should be more than enough to reach
-- room edge + complete v-scroll.
local game_prev = read_game_frames()
local total_frames = 600

-- s_scroll_state cell lives in C. Best-effort read via debug accessor area.
-- We just log "transition active" via game frame counter delta change rates.

for i = 1, total_frames do
    joypad.set({Up=true}, 1)
    emu.frameadvance()

    local game_cnt = read_game_frames()
    local game_delta = game_cnt - game_prev
    if game_delta < 0 then game_delta = game_delta + 65536 end
    local pc = emu.getregister("M68K PC")
    local sym = find_sym(pc)
    hist[sym] = (hist[sym] or 0) + 1
    local sy = read_scroll_y()
    local plane_row = (sy < 0 and (sy + 512) or sy) / 8
    plane_row = math.floor(plane_row) % 64

    fperf:write(string.format("%d,%d,%d,%d,%d,%X,%s,01,%d\n",
        emu.framecount(), game_cnt, game_delta, sy, plane_row, pc, sym, 0))

    -- Screenshot at any scroll_y close to a target.
    for _, target in ipairs(screenshot_targets) do
        if not screenshots_taken[target] and math.abs(sy - target) <= 4 then
            client.screenshot(string.format(OUTDIR .. "scroll_y_%d.png", target))
            screenshots_taken[target] = true
        end
    end

    game_prev = game_cnt
end

-- Release UP, settle 60 frames, final screenshot.
joypad.set({}, 1)
idle(60)
client.screenshot(OUTDIR .. "final.png")

-- Pre-scroll baseline screenshot would be at frame 0 of capture loop, but
-- by then UP may have already nudged Link. Take one BEFORE the UP-walk
-- session via a re-init: nope, just capture state now from "first frame
-- of loop" via the existing log.

fperf:close()

-- PC histogram.
local arr = {}
for n, c in pairs(hist) do arr[#arr + 1] = {name=n, cnt=c} end
table.sort(arr, function(x, y) return x.cnt > y.cnt end)
local fhist = io.open(OUTDIR .. "pchist.txt", "w")
fhist:write("PC histogram across UP-walk capture (sample at frame-end, " .. total_frames .. " frames)\n")
fhist:write("count   pct      symbol\n")
for i = 1, math.min(60, #arr) do
    fhist:write(string.format("%-7d %-7.2f  %s\n", arr[i].cnt, 100*arr[i].cnt/total_frames, arr[i].name))
end
fhist:close()

-- Summary.
local emu_total = emu.framecount() - 510  -- minus pre-walk boot frames
local fs = io.open(OUTDIR .. "summary.log", "w")
fs:write("vscroll_up_capture — 2026-05-15\n")
fs:write("===============================\n\n")
fs:write(string.format("frames walked-UP: %d\n", total_frames))
fs:write(string.format("final scroll_y:   %d (expect ~-176 for full v-scroll up)\n", read_scroll_y()))
fs:write("Screenshots saved at scroll_y targets:\n")
for _, t in ipairs(screenshot_targets) do
    fs:write(string.format("  scroll_y_%d.png  %s\n", t, screenshots_taken[t] and "OK" or "MISSED"))
end
fs:write("\nTop PC buckets:\n")
for i = 1, math.min(15, #arr) do
    fs:write(string.format("  %-6d %-6.2f  %s\n", arr[i].cnt, 100*arr[i].cnt/total_frames, arr[i].name))
end
fs:close()

gui.text(8, 8, "vscroll_up_capture done — see C:\\tmp\\vscroll\\")
client.exit()

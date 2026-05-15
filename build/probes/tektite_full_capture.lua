-- tektite_full_capture.lua
-- ONE probe, ALL data, one launch.
--
-- Outputs (C:\tmp\):
--   tektite_full.png            screenshot
--   tektite_full.log            human-readable summary + verdicts
--   tektite_full_pchist.txt     PC sampler histogram (600 frames)
--   tektite_full_sat.txt        full SAT dump slot 0..79
--   tektite_full_bga.txt        BG_A rows 0..7 cols 0..63 raw words
--   tektite_full_win.txt        Window plane rows 0..7 cols 0..31
--   tektite_full_cram.txt       full 64-entry CRAM
--   tektite_full_nesram.txt     NES RAM mirror $0000..$07FF
--   tektite_full_vregs.txt      VDP regs spot

local NM_PATH = "C:\\tmp\\Debug.nm.txt"
local OUT = "C:\\tmp\\tektite_full"

local function open_log(suffix) return io.open(OUT .. suffix, "w") end

-- ============================================================
-- 0. Load symbol table for PC bucketing.
-- ============================================================
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

-- ============================================================
-- 1. Boot to gameplay (title idle, A+B+C chord, settle).
-- ============================================================
local function press(buttons, frames)
    for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
    for i = 1, frames do emu.frameadvance() end
end
idle(120)
press({A=true, B=true, C=true}, 30)
idle(360)

-- ============================================================
-- 2. FPS + game-frame ratio measurement (600 frame window) +
--    PC sampling histogram in same window.
-- ============================================================
local function read_game_frames()
    return memory.read_u8(0x7202, "68K RAM") * 256
         + memory.read_u8(0x7203, "68K RAM")
end
local game_start = read_game_frames()
local emu_start = emu.framecount()
local wall_start = os.clock()
local hist = {}
local sample_n = 600
for i = 1, sample_n do
    emu.frameadvance()
    local pc = emu.getregister("M68K PC")
    local s = find_sym(pc)
    hist[s] = (hist[s] or 0) + 1
end
local emu_end = emu.framecount()
local game_end = read_game_frames()
local wall_end = os.clock()
local game_delta = game_end - game_start
if game_delta < 0 then game_delta = game_delta + 65536 end
local emu_delta = emu_end - emu_start
local wall_delta = wall_end - wall_start

-- ============================================================
-- 3. Screenshot.
-- ============================================================
client.screenshot(OUT .. ".png")

-- ============================================================
-- 4. Full SAT dump (80 slots).
-- ============================================================
do
    local f = open_log("_sat.txt")
    f:write("SAT dump slot=0..79  format: slot Y X size link tile pal prio raw\n")
    for slot = 0, 79 do
        local base = 0xF400 + slot * 8
        local y_hi = memory.read_u8(base + 0, "VRAM")
        local y_lo = memory.read_u8(base + 1, "VRAM")
        local size = memory.read_u8(base + 2, "VRAM")
        local link = memory.read_u8(base + 3, "VRAM")
        local at_hi= memory.read_u8(base + 4, "VRAM")
        local at_lo= memory.read_u8(base + 5, "VRAM")
        local x_hi = memory.read_u8(base + 6, "VRAM")
        local x_lo = memory.read_u8(base + 7, "VRAM")
        local y = ((y_hi & 0x03) * 256) + y_lo
        local x = ((x_hi & 0x03) * 256) + x_lo
        local tile = ((at_hi & 0x07) * 256) + at_lo
        local pal  = (at_hi >> 5) & 0x03
        local prio = (at_hi >> 7) & 0x01
        f:write(string.format(
            "%2d y=%4d x=%4d size=%02X link=%02X tile=%04X pal=%d prio=%d raw=%02X%02X.%02X%02X.%02X%02X.%02X%02X\n",
            slot, y, x, size, link, tile, pal, prio,
            y_hi, y_lo, size, link, at_hi, at_lo, x_hi, x_lo))
    end
    f:close()
end

-- ============================================================
-- 5. BG_A dump rows 0..7 cols 0..63 + Window plane rows 0..7
-- ============================================================
do
    local f = open_log("_bga.txt")
    f:write("BG_A (plane A) rows 0..7 cols 0..63 — word per cell (tile/pal/prio/flip)\n")
    for row = 0, 7 do
        f:write(string.format("row=%d:", row))
        for col = 0, 63 do
            local addr = 0xC000 + row * 128 + col * 2
            local w = memory.read_u8(addr, "VRAM") * 256 + memory.read_u8(addr + 1, "VRAM")
            f:write(string.format(" %04X", w))
        end
        f:write("\n")
    end
    f:close()
end
do
    local f = open_log("_win.txt")
    f:write("Window plane rows 0..7 cols 0..31 — word per cell\n")
    for row = 0, 7 do
        f:write(string.format("row=%d:", row))
        for col = 0, 31 do
            local addr = 0xE000 + row * 128 + col * 2
            local w = memory.read_u8(addr, "VRAM") * 256 + memory.read_u8(addr + 1, "VRAM")
            f:write(string.format(" %04X", w))
        end
        f:write("\n")
    end
    f:close()
end

-- ============================================================
-- 6. CRAM 64 entries.
-- ============================================================
do
    local f = open_log("_cram.txt")
    f:write("CRAM 64 colors (4 palettes x 16 colors)\n")
    for pal = 0, 3 do
        f:write(string.format("PAL%d:", pal))
        for c = 0, 15 do
            local addr = pal * 32 + c * 2
            local w = memory.read_u8(addr, "CRAM") * 256 + memory.read_u8(addr + 1, "CRAM")
            f:write(string.format(" %04X", w))
        end
        f:write("\n")
    end
    f:close()
end

-- ============================================================
-- 7. NES RAM mirror $0000..$07FF (via $FF8000+off, "68K RAM" domain offset $8000+off).
-- ============================================================
do
    local f = open_log("_nesram.txt")
    f:write("NES RAM mirror $0000..$07FF (Debug.md base = M68K $FF8000)\n")
    for base = 0x0000, 0x07F0, 0x10 do
        f:write(string.format("%04X:", base))
        for o = 0, 15 do
            f:write(string.format(" %02X", memory.read_u8(0x8000 + base + o, "68K RAM")))
        end
        f:write("\n")
    end
    f:close()
end

-- ============================================================
-- 8. PC histogram (top 60 buckets) + FPS verdict in main log.
-- ============================================================
local arr = {}
for name, cnt in pairs(hist) do arr[#arr + 1] = { name = name, cnt = cnt } end
table.sort(arr, function(x, y) return x.cnt > y.cnt end)
do
    local f = open_log("_pchist.txt")
    f:write("PC histogram (sample at frame-end, 600 frames)\n")
    f:write("count   pct      symbol\n")
    for i = 1, math.min(60, #arr) do
        f:write(string.format("%-7d %-7.2f  %s\n", arr[i].cnt, 100*arr[i].cnt/sample_n, arr[i].name))
    end
    f:close()
end

-- ============================================================
-- 9. Main summary log.
-- ============================================================
do
    local f = open_log(".log")
    f:write("tektite_full_capture — 2026-05-15\n")
    f:write("======================================\n\n")
    f:write("FPS / throttle measurement (600 emu frames):\n")
    f:write(string.format("  emu frames:    %d\n", emu_delta))
    f:write(string.format("  game frames:   %d\n", game_delta))
    f:write(string.format("  wall seconds:  %.3f\n", wall_delta))
    f:write(string.format("  wall FPS:      %.2f\n", emu_delta / math.max(wall_delta, 0.0001)))
    f:write(string.format("  emu/game:      %.3f (1.0 = no game-skip)\n", emu_delta / math.max(game_delta, 1)))
    f:write("\nProbe arm magic (default = 00 00):\n")
    f:write(string.format("  legacy [$FF73FC]=%02X [$FF73FD]=%02X\n",
        memory.read_u8(0x73FC, "68K RAM"), memory.read_u8(0x73FD, "68K RAM")))
    f:write(string.format("  current[$FF73F8]=%02X [$FF73F9]=%02X flags[$FF73FA]=%02X\n",
        memory.read_u8(0x73F8, "68K RAM"), memory.read_u8(0x73F9, "68K RAM"),
        memory.read_u8(0x73FA, "68K RAM")))

    -- Quick SAT summary
    local on_pf, off_pf = 0, 0
    for slot = 10, 63 do
        local base = 0xF400 + slot * 8
        local y_hi = memory.read_u8(base + 0, "VRAM")
        local y_lo = memory.read_u8(base + 1, "VRAM")
        local y = ((y_hi & 0x03) * 256) + y_lo
        if y > 32 and y < 240 then on_pf = on_pf + 1 else off_pf = off_pf + 1 end
    end
    f:write(string.format("\nSAT enemy bridge 10..63: %d on-playfield, %d off-screen/padded\n", on_pf, off_pf))

    f:write("\nFiles written:\n")
    f:write("  tektite_full.png\n")
    f:write("  tektite_full.log         (this file)\n")
    f:write("  tektite_full_pchist.txt  (PC histogram)\n")
    f:write("  tektite_full_sat.txt     (SAT slots 0..79)\n")
    f:write("  tektite_full_bga.txt     (BG_A rows 0..7 cols 0..63)\n")
    f:write("  tektite_full_win.txt     (Window rows 0..7 cols 0..31)\n")
    f:write("  tektite_full_cram.txt    (CRAM 64 colors)\n")
    f:write("  tektite_full_nesram.txt  (NES RAM $0000..$07FF)\n")

    f:write("\nTop 20 PC histogram buckets (live in _pchist.txt):\n")
    for i = 1, math.min(20, #arr) do
        f:write(string.format("  %-6d %-6.2f  %s\n", arr[i].cnt, 100*arr[i].cnt/sample_n, arr[i].name))
    end
    f:close()
end

gui.text(8, 8, "tektite_full_capture — done. See C:\\tmp\\tektite_full*.txt|log|png")
client.exit()

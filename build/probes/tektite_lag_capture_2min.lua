-- tektite_lag_capture_2min.lua
-- ONE probe, 2-minute run, MAX DATA.
--
-- Captures per-frame state for 7200 emu frames (~120s wall), scripted
-- movement so room state evolves, stutter detection, periodic full
-- dumps. Outputs under C:\tmp\tekcap\.

local OUTDIR = "C:\\tmp\\tekcap\\"
local NM_PATH = "C:\\tmp\\Debug.nm.txt"

-- ============================================================
-- 0. Ensure outdir + load symbol table.
-- ============================================================
os.execute("mkdir " .. OUTDIR .. " 2>NUL")

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
-- 1. Helpers.
-- ============================================================
local function read_game_frames()
    return memory.read_u8(0x7202, "68K RAM") * 256
         + memory.read_u8(0x7203, "68K RAM")
end
local function nesram(off)
    return memory.read_u8(0x8000 + off, "68K RAM")
end
local function dump_sat(f, label)
    f:write("=== SAT dump @ " .. label .. " ===\n")
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
        f:write(string.format("%2d y=%4d x=%4d size=%02X link=%02X tile=%04X pal=%d prio=%d\n",
            slot, y, x, size, link, tile, (at_hi>>5)&3, (at_hi>>7)&1))
    end
end
local function dump_nesram(f, label)
    f:write("=== NES RAM $0000..$07FF @ " .. label .. " ===\n")
    for base = 0x0000, 0x07F0, 0x10 do
        f:write(string.format("%04X:", base))
        for o = 0, 15 do
            f:write(string.format(" %02X", nesram(base + o)))
        end
        f:write("\n")
    end
end

-- ============================================================
-- 2. Boot to gameplay.
-- ============================================================
local function press(buttons, frames)
    for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
    for i = 1, frames do emu.frameadvance() end
end
idle(120)
press({A=true, B=true, C=true}, 30)
idle(240)
-- Now in gameplay.

-- ============================================================
-- 3. Scripted-movement table (2-min walkabout: alternating directions
-- so Link explores the room edges). Each entry = {dir, hold_frames}.
-- ============================================================
local movement = {
    {{}, 60},
    {{LEFT=true}, 90}, {{}, 30},
    {{RIGHT=true}, 90}, {{}, 30},
    {{UP=true}, 90}, {{}, 30},
    {{DOWN=true}, 90}, {{}, 30},
    {{RIGHT=true, UP=true}, 60}, {{}, 30},
    {{LEFT=true, DOWN=true}, 60}, {{}, 30},
    {{B=true}, 6}, {{}, 30},        -- B-item use
    {{A=true}, 6}, {{}, 30},        -- sword swing
    {{RIGHT=true}, 240}, {{}, 60},  -- long walk = scroll-right
    {{LEFT=true},  240}, {{}, 60},
    {{DOWN=true},  240}, {{}, 60},
    {{UP=true},    240}, {{}, 60},
    {{}, 120},                      -- idle
}

-- ============================================================
-- 4. Main capture loop: 7200 emu frames.
-- ============================================================
local fperf  = io.open(OUTDIR .. "perframe.csv", "w")
fperf:write("emu_frame,game_frame,game_delta,wall_ms,pc_end,pc_sym,joy_hex,mode,room,scene\n")

local fstutter = io.open(OUTDIR .. "stutters.txt", "w")
fstutter:write("emu_frame, game_delta(=0 means held), pc_at_end, sym, key NES cells\n")

local fhist = {}  -- PC histogram bucket name -> count
local total_emu = 7200
local emu_start = emu.framecount()
local game_prev = read_game_frames()
local wall_start = os.clock()

local mv_idx = 1
local mv_count = 0

-- Periodic dump file (SAT + NES RAM every 600 frames).
local fdumps = io.open(OUTDIR .. "periodic_dumps.txt", "w")

for i = 1, total_emu do
    -- Decide joypad input from movement script.
    if mv_idx <= #movement then
        local entry = movement[mv_idx]
        joypad.set(entry[1], 1)
        mv_count = mv_count + 1
        if mv_count >= entry[2] then
            mv_idx = mv_idx + 1
            mv_count = 0
        end
    end

    emu.frameadvance()

    local emu_cnt = emu.framecount()
    local game_cnt = read_game_frames()
    local game_delta = game_cnt - game_prev
    if game_delta < 0 then game_delta = game_delta + 65536 end
    local pc = emu.getregister("M68K PC")
    local sym = find_sym(pc)
    fhist[sym] = (fhist[sym] or 0) + 1
    local joy = joypad.get(1)
    local joy_hex = 0
    if joy.Up    then joy_hex = joy_hex | 0x01 end
    if joy.Down  then joy_hex = joy_hex | 0x02 end
    if joy.Left  then joy_hex = joy_hex | 0x04 end
    if joy.Right then joy_hex = joy_hex | 0x08 end
    if joy.A     then joy_hex = joy_hex | 0x10 end
    if joy.B     then joy_hex = joy_hex | 0x20 end
    if joy.C     then joy_hex = joy_hex | 0x40 end
    if joy.Start then joy_hex = joy_hex | 0x80 end
    local wall_ms = (os.clock() - wall_start) * 1000

    -- s_mode / s_room_id / s_scene live in C statics. Read via 68K RAM.
    -- s_room_id at $FF7204 (per build_debug map convention — best-effort).
    -- Easiest: just dump NES RAM key cells.
    local mode_cell = memory.read_u8(0x12, "68K RAM")  -- GameMode at $FF0012
    local room_cell = nesram(0x00EB)                    -- NES CurRoom $00EB
    local scene_cell = nesram(0x0010)                   -- NES CurLevel $0010

    fperf:write(string.format("%d,%d,%d,%.1f,%X,%s,%02X,%02X,%02X,%02X\n",
        emu_cnt, game_cnt, game_delta, wall_ms, pc, sym, joy_hex,
        mode_cell, room_cell, scene_cell))

    if game_delta ~= 1 then
        fstutter:write(string.format(
            "emu=%d game=%d delta=%d pc=%X sym=%s mode=%02X room=%02X scene=%02X joy=%02X\n",
            emu_cnt, game_cnt, game_delta, pc, sym,
            mode_cell, room_cell, scene_cell, joy_hex))
    end

    game_prev = game_cnt

    if i % 600 == 0 then
        local lbl = "emu+" .. i
        dump_sat(fdumps, lbl)
        dump_nesram(fdumps, lbl)
    end
end

local emu_end = emu.framecount()
local game_end = read_game_frames()
local wall_end = os.clock()

fperf:close()
fstutter:close()
fdumps:close()

-- ============================================================
-- 5. Final summary + PC histogram + final state dump.
-- ============================================================
do
    local arr = {}
    for n, c in pairs(fhist) do arr[#arr + 1] = {name=n, cnt=c} end
    table.sort(arr, function(x, y) return x.cnt > y.cnt end)
    local f = io.open(OUTDIR .. "pchist.txt", "w")
    f:write("PC histogram across 7200-frame capture (sample at frame-end)\n")
    f:write("NOTE: frame-end = usually VDP_waitVBlank. Top entries reflect idle PC.\n")
    f:write("count   pct      symbol\n")
    for i = 1, math.min(80, #arr) do
        f:write(string.format("%-7d %-7.2f  %s\n", arr[i].cnt, 100*arr[i].cnt/total_emu, arr[i].name))
    end
    f:close()
end

-- Final state snapshot.
local fsnap = io.open(OUTDIR .. "final_state.txt", "w")
dump_sat(fsnap, "end-of-capture")
dump_nesram(fsnap, "end-of-capture")
fsnap:close()

client.screenshot(OUTDIR .. "final.png")

-- Top-level summary.
do
    local emu_delta = emu_end - emu_start
    local f = io.open(OUTDIR .. "summary.log", "w")
    f:write("tektite_lag_capture_2min — 2026-05-15\n")
    f:write("=========================================\n")
    f:write(string.format("emu frames advanced: %d\n", emu_delta))
    f:write(string.format("game frames advanced: %d (game counter end value; see perframe.csv last row for actual delta)\n",
        game_end))
    f:write(string.format("wall seconds: %.3f\n", wall_end - wall_start))
    f:write(string.format("wall FPS: %.2f\n", emu_delta / (wall_end - wall_start)))
    f:write("\nFiles written under " .. OUTDIR .. ":\n")
    f:write("  perframe.csv         per-frame log (emu, game, delta, pc, joy, mode, room)\n")
    f:write("  stutters.txt         every frame where game_delta != 1\n")
    f:write("  pchist.txt           PC histogram (frame-end sample)\n")
    f:write("  periodic_dumps.txt   SAT+NESRAM every 600 frames\n")
    f:write("  final_state.txt      end-of-run SAT+NESRAM\n")
    f:write("  final.png            screenshot\n")
    f:close()
end

gui.text(8, 8, "tektite_lag_capture_2min — DONE. See " .. OUTDIR)
client.exit()

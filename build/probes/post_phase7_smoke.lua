-- post_phase7_smoke.lua — boot, walk OW path, dump every 60 frames.
-- Goal: spot remaining visible regressions after enemy visual restore.
-- Captures: 12 screenshots over 720 frames + per-frame Link x/y +
--           SAT enemy-bridge slot count + frame-fps + hot-path PC samples
--           + final NES key cells dump + final SAT enemy slots 10..40.
-- Output: C:\tmp\smoke7\

local OUTDIR = "C:\\tmp\\smoke7\\"
local NM_PATH = "C:\\tmp\\Debug.nm.txt"
os.execute("mkdir " .. OUTDIR .. " 2>NUL")

-- Symbol table for hot-path naming.
local syms = {}
local fc_offset = 0x0194
local fh = io.open(NM_PATH, "r")
if fh then
    for line in fh:lines() do
        line = line:gsub("\r", "")
        local a, t, n = line:match("^(%x+)%s+([Tt])%s+(.+)$")
        if a and (t == "T" or t == "t") then
            syms[#syms + 1] = { addr = tonumber(a, 16) & 0xFFFFFF, name = n }
        end
        local a2, _, n2 = line:match("^(%x+)%s+(%S)%s+(.+)$")
        if n2 == "s_frame_counter" then
            fc_offset = (tonumber(a2, 16) & 0xFFFFFF) - 0xFF0000
        end
    end
    fh:close()
end
table.sort(syms, function(x, y) return x.addr < y.addr end)
local function find_sym(pc)
    if #syms == 0 then return "?" end
    local lo, hi = 1, #syms
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if syms[mid].addr <= pc then lo = mid else hi = mid - 1 end
    end
    return syms[lo].name
end

local function press(buttons, frames)
    for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
    for i = 1, frames do emu.frameadvance() end
end
local function nesram(off) return memory.read_u8(0x8000 + off, "68K RAM") end
local function read_game_frames()
    return memory.read_u8(fc_offset, "68K RAM") * 256
         + memory.read_u8(fc_offset + 1, "68K RAM")
end
local function count_active_enemy_sat()
    -- SAT base $F400, slots 10..40. Active = size != 0 AND y in playfield.
    local n = 0
    for slot = 10, 40 do
        local base = 0xF400 + slot * 8
        local sz = memory.read_u8(base + 2, "VRAM")
        local y_hi = memory.read_u8(base, "VRAM")
        local y_lo = memory.read_u8(base + 1, "VRAM")
        local y = ((y_hi & 0x03) * 256) + y_lo
        if sz ~= 0 and y > 32 and y < 240 then n = n + 1 end
    end
    return n
end
local function count_alive_enemies()
    local n = 0
    for s = 1, 11 do
        if nesram(0x0492 + s) ~= 0 then n = n + 1 end
    end
    return n
end

-- Boot + arm stress harness.
idle(60)
memory.write_u8(0x73FC, 0x45, "68K RAM")  -- 'E'
memory.write_u8(0x73FD, 0x50, "68K RAM")  -- 'P'
idle(60)
press({A=true, B=true, C=true}, 30)
idle(180)

-- Capture loop: walk Right + Down alternating, snapshot every 60 frames.
local hist = {}
local fperf = io.open(OUTDIR .. "perframe.csv", "w")
fperf:write("emu,game,link_x,link_y,alive,sat_active,room,scene,pc,sym\n")

local total = 720
local snap_n = 0
for i = 1, total do
    local btn
    if i <= 120 then btn = {Right=true}
    elseif i <= 240 then btn = {Down=true}
    elseif i <= 360 then btn = {Left=true}
    elseif i <= 480 then btn = {Up=true}
    elseif i <= 600 then btn = {Right=true, A=true}  -- attack
    else btn = {} end
    joypad.set(btn, 1)
    emu.frameadvance()

    local pc = emu.getregister("M68K PC")
    local sym = find_sym(pc)
    hist[sym] = (hist[sym] or 0) + 1

    fperf:write(string.format("%d,%d,%d,%d,%d,%d,%d,%d,%X,%s\n",
        emu.framecount(), read_game_frames(),
        nesram(0x0070), nesram(0x0084),
        count_alive_enemies(), count_active_enemy_sat(),
        nesram(0x00EB), nesram(0x0010), pc, sym))

    if i % 60 == 0 then
        snap_n = snap_n + 1
        client.screenshot(string.format(OUTDIR .. "snap_%02d.png", snap_n))
    end
end
fperf:close()

-- Final report.
local f = io.open(OUTDIR .. "report.log", "w")
f:write("post_phase7_smoke — 2026-05-15\n")
f:write("============================\n\n")
f:write(string.format("Frames sampled: %d\n", total))
f:write(string.format("Game frames advanced: %d\n", read_game_frames()))
f:write(string.format("Snapshots written: %d\n\n", snap_n))

f:write("Final enemy state:\n")
local alive = 0
for s = 0, 11 do
    local t = nesram(0x034F + s)
    local a = nesram(0x0492 + s)
    local x = nesram(0x0070 + s)
    local y = nesram(0x0084 + s)
    local m = nesram(0x0490 + s)  -- ENEMY_METASTATE
    f:write(string.format("  slot %2d  TYPE=$%02X  ALIVE=$%02X  X=$%02X  Y=$%02X  META=$%02X\n",
        s, t, a, x, y, m))
    if a ~= 0 and s > 0 then alive = alive + 1 end
end
f:write(string.format("\nAlive count: %d\n\n", alive))

f:write("Final SAT slots 10..40 (enemy bridge):\n")
local active = 0
local sz_05 = 0
local sz_01 = 0
for slot = 10, 40 do
    local base = 0xF400 + slot * 8
    local y_hi = memory.read_u8(base, "VRAM")
    local y_lo = memory.read_u8(base + 1, "VRAM")
    local size = memory.read_u8(base + 2, "VRAM")
    local link = memory.read_u8(base + 3, "VRAM")
    local at_hi = memory.read_u8(base + 4, "VRAM")
    local at_lo = memory.read_u8(base + 5, "VRAM")
    local x_hi = memory.read_u8(base + 6, "VRAM")
    local x_lo = memory.read_u8(base + 7, "VRAM")
    local y = ((y_hi & 0x03) * 256) + y_lo
    local x = ((x_hi & 0x03) * 256) + x_lo
    local tile = ((at_hi & 0x07) * 256) + at_lo
    local on = (y > 32 and y < 240)
    f:write(string.format("  %3d  y=%4d x=%4d size=$%02X link=$%02X tile=$%04X attrs=$%04X %s\n",
        slot, y, x, size, link, tile, at_hi*256+at_lo, on and "ON" or ""))
    if on then active = active + 1 end
    if size == 0x05 then sz_05 = sz_05 + 1 end
    if size == 0x01 then sz_01 = sz_01 + 1 end
end
f:write(string.format("\nactive=%d  SIZE(2,2)=%d  SIZE(1,2)=%d\n\n", active, sz_05, sz_01))

f:write("Key NES cells:\n")
f:write(string.format("  $0010 SCENE       = $%02X\n", nesram(0x0010)))
f:write(string.format("  $00EB ROOM ID     = $%02X\n", nesram(0x00EB)))
f:write(string.format("  $0070 LINK X      = $%02X\n", nesram(0x0070)))
f:write(string.format("  $0084 LINK Y      = $%02X\n", nesram(0x0084)))
f:write(string.format("  $0015 FRAME CTR   = $%02X\n", nesram(0x0015)))
f:write(string.format("  $07FE SENTINEL    = $%02X\n", nesram(0x07FE)))
f:write(string.format("  $052A WORLD KILL  = $%02X\n\n", nesram(0x052A)))

-- Hot path top 25.
local arr = {}
for n, c in pairs(hist) do arr[#arr + 1] = {name=n, cnt=c} end
table.sort(arr, function(x, y) return x.cnt > y.cnt end)
f:write("Top 25 PC buckets:\n")
for i = 1, math.min(25, #arr) do
    f:write(string.format("  %5d  %5.2f%%  %s\n",
        arr[i].cnt, 100*arr[i].cnt/total, arr[i].name))
end
f:close()

gui.text(8, 8, "smoke7 done")
client.exit()

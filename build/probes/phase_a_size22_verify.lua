-- phase_a_size22_verify.lua — Phase A enemy SIZE(2,2) verification.
-- Boots ROM, enters debug game (A+B+C), settles, walks 60 frames to spawn
-- enemies, then dumps:
--   * SAT slots 10..40 (enemy bridge range): y, x, size, link, tile, attrs
--   * NES enemy slot state: TYPE, ALIVE, X, Y for slots 0..11
--   * Genesis frame counter delta vs emu frames over 300 sample frames (fps)
--   * VRAM byte dump of common sprite tile region (sanity)
--   * CRAM PAL0..PAL3 (palette sanity)
--   * NES_RAM key registers: $0010 scene, $00EB room, $0015 framectr
--   * Per-frame PC sample histogram (top 20 buckets) for hot path
--   * Screenshots: pre_walk, mid_walk, post_walk
-- Output: C:\tmp\phase_a\

local OUTDIR = "C:\\tmp\\phase_a\\"
local NM_PATH = "C:\\tmp\\Debug.nm.txt"
os.execute("mkdir " .. OUTDIR .. " 2>NUL")

local function press(buttons, frames)
    for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
    for i = 1, frames do emu.frameadvance() end
end
local function nesram(off) return memory.read_u8(0x8000 + off, "68K RAM") end

-- Symbol table.
local syms = {}
local fc_offset = 0x0104
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
local function read_game_frames()
    return memory.read_u8(fc_offset, "68K RAM") * 256
         + memory.read_u8(fc_offset + 1, "68K RAM")
end

-- Boot. ARM the 11-slot stress harness so we have enemies on screen.
-- ENEMY_LOOP_PROBE_CONTROL_BASE = $00FF73FC, magic = 'E' (0x45), 'P' (0x50).
idle(60)
memory.write_u8(0x73FC, 0x45, "68K RAM")  -- 'E'
memory.write_u8(0x73FD, 0x50, "68K RAM")  -- 'P'
idle(60)
press({A=true, B=true, C=true}, 30)
idle(420)
client.screenshot(OUTDIR .. "pre_walk.png")

-- Walk down 60 frames so Link moves and enemies become visible.
local hist = {}
local game_prev = read_game_frames()
local emu_prev = emu.framecount()
local sample_frames = 300

local fperf = io.open(OUTDIR .. "perframe.csv", "w")
fperf:write("emu,game,emu_delta,game_delta,link_x,link_y,pc,sym\n")

for i = 1, sample_frames do
    if i <= 60 then joypad.set({Down=true}, 1) else joypad.set({}, 1) end
    emu.frameadvance()
    local emu_cnt = emu.framecount()
    local game_cnt = read_game_frames()
    local emu_d = emu_cnt - emu_prev
    local game_d = game_cnt - game_prev
    if game_d < 0 then game_d = game_d + 65536 end
    local pc = emu.getregister("M68K PC")
    local sym = find_sym(pc)
    hist[sym] = (hist[sym] or 0) + 1
    fperf:write(string.format("%d,%d,%d,%d,%d,%d,%X,%s\n",
        emu_cnt, game_cnt, emu_d, game_d,
        nesram(0x0070), nesram(0x0084), pc, sym))
    if i == 150 then client.screenshot(OUTDIR .. "mid_walk.png") end
    emu_prev = emu_cnt
    game_prev = game_cnt
end
fperf:close()
client.screenshot(OUTDIR .. "post_walk.png")

-- Dump report.
local f = io.open(OUTDIR .. "report.log", "w")
f:write("phase_a_size22_verify — 2026-05-15\n")
f:write("=================================\n\n")

f:write(string.format("s_frame_counter @ 68K RAM offset $%04X\n", fc_offset))
f:write(string.format("emu frames sampled: %d\n", sample_frames))
f:write(string.format("game frames advanced: %d\n", read_game_frames()))
local total_game = read_game_frames()
local efps = (total_game / sample_frames) * 60.0
f:write(string.format("effective game fps: %.2f (target >=58)\n\n", efps))

-- NES enemy slot state.
f:write("NES enemy slot state ($034F TYPE, $0492 ALIVE, $0070 X, $0084 Y):\n")
local alive = 0
for s = 0, 11 do
    local t = nesram(0x034F + s)
    local a = nesram(0x0492 + s)
    local x = nesram(0x0070 + s)
    local y = nesram(0x0084 + s)
    f:write(string.format("  slot %2d  TYPE=$%02X  ALIVE=$%02X  X=$%02X  Y=$%02X\n",
        s, t, a, x, y))
    if a ~= 0 and s > 0 then alive = alive + 1 end
end
f:write(string.format("\nALIVE enemy count (slots 1..11): %d\n\n", alive))

-- SAT base: dump candidates so we can locate where VDP_setSpriteListAddress
-- actually placed it (RoomRom uses $F400, CombinedDebug used $AC00, others
-- $E800/$F800). Iterate slots 0..63 from each base; report any with non-
-- zero size byte. Phase A SIZE(2,2)=0x05 expected.
local sat_bases = {0xF400, 0xF800, 0xAC00, 0xE800, 0xD800, 0xBC00}
f:write("SAT scan — multiple candidate bases (looking for size=0x05):\n")
local best_base = 0
local best_count = 0
local best_size_05 = 0
for _, base in ipairs(sat_bases) do
    local nonzero = 0
    local size_05 = 0
    local size_01 = 0
    for slot = 0, 63 do
        local sz = memory.read_u8(base + slot * 8 + 2, "VRAM")
        if sz ~= 0 then nonzero = nonzero + 1 end
        if sz == 0x05 then size_05 = size_05 + 1 end
        if sz == 0x01 then size_01 = size_01 + 1 end
    end
    f:write(string.format("  base $%04X: nonzero_size=%2d  SIZE(2,2)=%2d  SIZE(1,2)=%2d\n",
        base, nonzero, size_05, size_01))
    if size_05 > best_size_05 then
        best_size_05 = size_05
        best_base = base
        best_count = nonzero
    end
end
if best_base == 0 then best_base = 0xF400 end
f:write(string.format("\nUsing best base $%04X for detail dump.\n", best_base))

f:write("\nSAT slots 0..40 (enemy bridge — Phase A SIZE(2,2)=0x05 expected):\n")
f:write("  slot  y     x     size  link  tile   attrs  status\n")
local size_05_count = 0
local size_01_count = 0
local active = 0
for slot = 0, 40 do
    local base = best_base + slot * 8
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
    local on = (y > 32 and y < 240)
    f:write(string.format("  %3d   %4d  %4d  $%02X   $%02X   $%04X $%04X  %s\n",
        slot, y, x, size, link, tile, (at_hi*256+at_lo), on and "ON" or ""))
    if on then active = active + 1 end
    if size == 0x05 then size_05_count = size_05_count + 1
    elseif size == 0x01 then size_01_count = size_01_count + 1 end
end
f:write(string.format("\nactive SAT enemy slots: %d\n", active))
f:write(string.format("SIZE(2,2)=0x05 entries: %d   SIZE(1,2)=0x01 entries: %d\n",
    size_05_count, size_01_count))
local pass_phase_a = (size_05_count > 0 and active > 0)
f:write(string.format("Phase A verdict: %s\n\n",
    pass_phase_a and "PASS" or "INCONCLUSIVE / FAIL"))

-- NES_RAM key cells.
f:write("NES key cells:\n")
f:write(string.format("  $0010 SCENE       = $%02X\n", nesram(0x0010)))
f:write(string.format("  $0015 FRAME CTR   = $%02X\n", nesram(0x0015)))
f:write(string.format("  $0084 LINK Y      = $%02X\n", nesram(0x0084)))
f:write(string.format("  $0070 LINK X      = $%02X\n", nesram(0x0070)))
f:write(string.format("  $00EB ROOM ID     = $%02X\n", nesram(0x00EB)))
f:write(string.format("  $07FE SENTINEL    = $%02X (sweep counter)\n", nesram(0x07FE)))
f:write("\n")

-- CRAM PAL0..PAL3.
f:write("CRAM palettes (4 banks x 16 entries):\n")
for p = 0, 3 do
    f:write(string.format("  PAL%d:", p))
    for c = 0, 15 do
        local lo = memory.read_u8(p * 32 + c * 2, "CRAM")
        local hi = memory.read_u8(p * 32 + c * 2 + 1, "CRAM")
        f:write(string.format(" %02X%02X", hi, lo))
    end
    f:write("\n")
end
f:write("\n")

-- VRAM tile area for COMMON sprite block (tile 1025..1040 = 16 tiles).
f:write("VRAM tile sample (tiles 1025..1028, COMMON sprite base):\n")
for tile = 1025, 1028 do
    f:write(string.format("  tile %d ($%04X) bytes 0..15:", tile, tile))
    for byte = 0, 15 do
        f:write(string.format(" %02X", memory.read_u8(tile * 32 + byte, "VRAM")))
    end
    f:write("\n")
end
f:write("\n")

-- Top 20 PC buckets.
local arr = {}
for n, c in pairs(hist) do arr[#arr + 1] = {name=n, cnt=c} end
table.sort(arr, function(x, y) return x.cnt > y.cnt end)
f:write("Top 20 PC buckets (hot path):\n")
for i = 1, math.min(20, #arr) do
    f:write(string.format("  %5d  %5.2f%%  %s\n",
        arr[i].cnt, 100*arr[i].cnt/sample_frames, arr[i].name))
end
f:close()

gui.text(8, 8, "phase_a verify done")
client.exit()

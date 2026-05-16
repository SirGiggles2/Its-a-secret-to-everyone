-- tektite_lag_perf_probe.lua
--
-- Quantify lag on the default Tektite OW room (room 0x77).
-- After A+B+C entry + settle, measure 600 emu frames vs game frames
-- (s_frame_counter at $FF7202..$FF7203). Dump enemy slot state.
--
-- Output: C:\tmp\tektite_lag_perf.log + tektite_lag_perf.png

local OUT_LOG = "C:\\tmp\\tektite_lag_perf.log"
local OUT_PNG = "C:\\tmp\\tektite_lag_perf.png"

local f = io.open(OUT_LOG, "w")
local function L(s) f:write(s .. "\n") end

local function hex(n, w) return string.format("%0" .. (w or 2) .. "X", n) end

-- Read M68K via 68K RAM (work RAM only) by stripping high $FF.
local function rd8(off68k)
    -- off68k is $FF0000..$FFFFFF — domain "68K RAM" maps 0..0xFFFF.
    return memory.read_u8(off68k - 0xFF0000, "68K RAM")
end

-- Read NES RAM mirror at $FF8000..$FF87FF (memory_palace base for Debug.md).
-- Per platform_abi.h:9-21: A4 = $00FF8000 in Debug.md.
local function nes_rd8(nes_off)
    local m68k_addr = 0xFF8000 + nes_off
    return rd8(m68k_addr)
end

L("tektite_lag_perf probe — 2026-05-15")
L("=======================================")

-- Stage 1: settle title, fire chord, let runtime stabilize.
local function press(buttons, frames)
    for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
    for i = 1, frames do emu.frameadvance() end
end

idle(120)
press({A=true, B=true, C=true}, 30)
idle(360)
-- 510 frames in. Game frame counter should be ticking now.

-- s_frame_counter location: search later. For now use emu.framecount delta
-- vs wall-clock to compute FPS directly.
-- Read game frame counter at $FF7202..$FF7203 (per
-- src/debug/probes/fps_armed_stress.lua method).
local function read_game_frames()
    return memory.read_u8(0x7202, "68K RAM") * 256
         + memory.read_u8(0x7203, "68K RAM")
end

local game_start = read_game_frames()
local emu_start = emu.framecount()
local time_start = os.clock()
idle(600)
local emu_end = emu.framecount()
local time_end = os.clock()
local game_stop = read_game_frames()

local game_delta = game_stop - game_start
if game_delta < 0 then game_delta = game_delta + 65536 end
local emu_delta = emu_end - emu_start
local wall_delta = time_end - time_start
L(string.format("Emu frames advanced:    %d", emu_delta))
L(string.format("Game frames advanced:   %d", game_delta))
L(string.format("Wall clock elapsed:     %.3f s", wall_delta))
if wall_delta > 0 then
    L(string.format("Effective wall FPS:     %.2f (60.00 = full speed)", emu_delta / wall_delta))
end
local ratio = emu_delta / math.max(game_delta, 1)
local game_fps = 60.0 / ratio
L(string.format("emu/game ratio:         %.3f  (1.0 = no lag)", ratio))
L(string.format("Effective GAME FPS:     %.2f (target 60.00)", game_fps))
if ratio > 1.5 then
    L("VERDICT: HEAVY LAG (>1.5x emu/game ratio)")
elseif ratio > 1.1 then
    L("VERDICT: minor lag (>1.1x)")
else
    L("VERDICT: 60fps, no measurable lag")
end

-- Stage 2: dump NES enemy slot state.
-- Per src/state/enemy_state.h / platform_abi.h, ENEMY_TYPE = OBJ($0341, slot)
-- with OBJ macro = base + (slot * 1). ENEMY_LOOP_SLOT_FIRST = 1, LAST = 11.
-- ENEMY_ALIVE_FLAG = OBJ(some offset, slot).
-- Slot layout (NES $03xx area), 1-based slots 1..11:
--   $0341 + slot = ENEMY_TYPE   (low byte = enemy id)
-- Use raw byte dump of the 12 type cells starting at $0341.
L("")
L("NES ObjType[0..11] @ $0341.. (slot 0 = Link, 1..11 enemies):")
for slot = 0, 11 do
    local t = nes_rd8(0x0341 + slot)
    L(string.format("  slot=%-2d  type=$%02X", slot, t))
end

-- ENEMY_ALIVE_FLAG — Z_05.asm:1693 ObjStunTimer + sentinel pattern.
-- platform_abi.h reserves ALIVE at $03B1.. (mirroring NES Z1 layout).
-- Just dump $03B0..$03BB as alive-flag candidates.
L("")
L("Slot alive area $03B0..$03BB:")
local s = "  "
for off = 0xB0, 0xBB do
    s = s .. hex(nes_rd8(0x0300 + off)) .. " "
end
L(s)

-- ENEMY_X = OBJ($0070, slot) and ENEMY_Y = OBJ($0080, slot) typically.
L("")
L("Slot X/Y (NES $0070..$008B):")
local xs = "  X: "
local ys = "  Y: "
for slot = 0, 11 do
    xs = xs .. hex(nes_rd8(0x0070 + slot)) .. " "
    ys = ys .. hex(nes_rd8(0x0080 + slot)) .. " "
end
L(xs)
L(ys)

-- Dump probe arm cells to confirm we're in default mode.
L("")
L("Probe arm magic state (should all be 0 for default A+B+C):")
local arm0 = rd8(0xFF73FC)
local arm1 = rd8(0xFF73FD)
L(string.format("  ENEMY_LOOP_PROBE_CONTROL_BASE[0..1] = %02X %02X (expect 00 00)", arm0, arm1))

-- Count active SAT entries by Y range, slot 10..63.
local sat_active = 0
local sat_offscreen = 0
for slot = 10, 63 do
    local base = 0xF400 + slot * 8
    local y_hi = memory.read_u8(base + 0, "VRAM")
    local y_lo = memory.read_u8(base + 1, "VRAM")
    local y = ((y_hi & 0x03) * 256) + y_lo
    if y > 32 and y < 240 then sat_active = sat_active + 1
    else sat_offscreen = sat_offscreen + 1 end
end
L("")
L("SAT enemy bridge slots 10..63:")
L(string.format("  on playfield (y 32..240): %d", sat_active))
L(string.format("  off-screen / padded:      %d", sat_offscreen))

client.screenshot(OUT_PNG)
L("")
L("Screenshot: " .. OUT_PNG)
f:close()

gui.text(8, 8, "tektite_lag_perf — see C:\\tmp\\tektite_lag_perf.log")

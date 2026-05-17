-- fps_ow_default.lua — measure gameplay FPS in default OW.
-- Arms the state mirror to get s_frame_counter (16-bit, increments
-- once per gameplay tick). Samples 600 emu frames; computes game_frames
-- and ratio = game/emu. 1.0 = 60fps, <1.0 = drops.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\fps_ow.txt"
local f = io.open(OUT, "w")

idle(60)
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
memory.write_u8(0x73FA, 0x00, "68K RAM") -- light mirror (just frame counter)

for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(60)

-- Phase A: idle (no input)
f:write("=== Phase A: idle ===\n")
local start_fc = R16BE(0x7202)
for i=1,600 do emu.frameadvance() end
local stop_fc = R16BE(0x7202)
local game = stop_fc - start_fc
if game < 0 then game = game + 65536 end
f:write(string.format("idle: 600 emu frames -> %d game frames, ratio=%.3f\n",
  game, game/600))

-- Phase B: hold direction (Link moves)
f:write("\n=== Phase B: hold UP 600f ===\n")
start_fc = R16BE(0x7202)
for i=1,600 do joypad.set({Up=true}, 1); emu.frameadvance() end
stop_fc = R16BE(0x7202)
game = stop_fc - start_fc
if game < 0 then game = game + 65536 end
f:write(string.format("UP: 600 emu frames -> %d game frames, ratio=%.3f\n",
  game, game/600))

-- Phase C: post-scroll
f:write("\n=== Phase C: post-scroll idle ===\n")
idle(60)
start_fc = R16BE(0x7202)
for i=1,600 do emu.frameadvance() end
stop_fc = R16BE(0x7202)
game = stop_fc - start_fc
if game < 0 then game = game + 65536 end
f:write(string.format("post-scroll idle: 600 emu frames -> %d game frames, ratio=%.3f\n",
  game, game/600))

f:write(string.format("\nFinal: scene=%d room=$%02X X=$%02X Y=$%02X\n",
  R(0x7204), R(0x7205), R(0x7207), R(0x7209)))

client.screenshot("C:\\tmp\\fps_ow.png")
f:write("\nDONE\n")
f:close()
gui.text(8, 8, "fps done")
idle(20)
client.exit()

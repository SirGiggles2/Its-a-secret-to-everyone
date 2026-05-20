-- fps_dense_room.lua — measure FPS in dense enemy room ($63 = octorok+lynel).
-- Teleport from boot $77 -> $63 (left 4, up 1). Compare to idle $77 baseline.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn,h,r)
  h=h or 4; r=r or 12
  for _=1,h do joypad.set({[btn]=true},1); emu.frameadvance() end
  for _=1,r do joypad.set({},1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\fps_dense.txt"
local f = io.open(OUT, "w")

idle(60)
-- Arm state mirror (52 50 ascii "RP")
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
memory.write_u8(0x73FA, 0x00, "68K RAM")

-- A+B+C chord -> gameplay
for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
idle(60)

local function count_enemies()
  local n = 0
  for s=1,11 do
    local t = R(MIRROR+0x034F+s)
    if t ~= 0 and t ~= 0x53 then n = n + 1 end
  end
  return n
end

local function fps_sample(label, frames)
  local start_fc = R16BE(0x7202)
  for i=1,frames do emu.frameadvance() end
  local stop_fc = R16BE(0x7202)
  local game = stop_fc - start_fc
  if game < 0 then game = game + 65536 end
  local ratio = game/frames
  f:write(string.format("%s: %d emu -> %d game frames, ratio=%.3f (%.1f fps eq) room=$%02X enemies=%d\n",
    label, frames, game, ratio, ratio*60.0, R(MIRROR+0x00EB), count_enemies()))
  return ratio
end

-- Phase A: idle in $77 (no enemies, boot room)
f:write("=== Phase A: idle in $77 ===\n")
fps_sample("idle $77", 300)

-- Teleport to $63: X, Left x4, Up x1, X (exit teleport mode)
tap("X")
for _=1,4 do tap("Left") end
tap("Up")
tap("X")
idle(40)

-- Phase B: idle in dense room
f:write("\n=== Phase B: idle in dense room ===\n")
fps_sample("idle dense", 300)

-- Phase C: combat in dense room (walk + swing)
f:write("\n=== Phase C: combat in dense room ===\n")
for i=1,30 do joypad.set({Left=true},1); emu.frameadvance() end
fps_sample("combat dense", 300)

-- Phase D: hold A (sword swing repeat)
f:write("\n=== Phase D: sword swing repeat ===\n")
fps_sample("swing dense", 300)

f:write(string.format("\nFinal: scene=%d room=$%02X X=$%02X Y=$%02X\n",
  R(0x7204), R(0x7205), R(0x7207), R(0x7209)))

client.screenshot("C:\\tmp\\fps_dense.png")
f:write("\nDONE\n")
f:close()
gui.text(8,8,"fps dense done")
idle(20)
client.exit()

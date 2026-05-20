-- fps_dense_v2.lua — FPS audit in dense room $63 with combat input.
-- Fix: slower tap timing for teleport edge-detection reliability.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn,h,r)
  h=h or 6; r=r or 30
  for _=1,h do joypad.set({[btn]=true},1); emu.frameadvance() end
  for _=1,r do joypad.set({},1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\fps_dense_v2.txt"
local f = io.open(OUT, "w")

idle(60)
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
memory.write_u8(0x73FA, 0x00, "68K RAM")

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

local function fps_sample(label, frames, input_fn)
  local start_fc = R16BE(0x7202)
  local start_em = emu.framecount()
  for i=1,frames do
    if input_fn then input_fn(i) end
    emu.frameadvance()
  end
  local stop_fc = R16BE(0x7202)
  local stop_em = emu.framecount()
  local game = stop_fc - start_fc
  if game < 0 then game = game + 65536 end
  local em = stop_em - start_em
  local ratio = game/em
  f:write(string.format("%-22s emu=%d game=%d ratio=%.3f (%.1f fps) room=$%02X enemies=%d\n",
    label, em, game, ratio, ratio*60.0,
    R(MIRROR+0x00EB), count_enemies()))
end

-- Phase A: idle $77 baseline
f:write("=== Phase A: idle $77 (boot, 0 enemies) ===\n")
fps_sample("idle $77", 300)

-- Teleport $77 -> $63 (4 lefts + 1 up)
tap("X")
tap("Left"); tap("Left"); tap("Left"); tap("Left")
tap("Up")
tap("X")
idle(40)
f:write(string.format("teleport done: room=$%02X enemies=%d\n",
  R(MIRROR+0x00EB), count_enemies()))

-- Phase B: idle in dense $63
f:write("\n=== Phase B: idle $63 (6 enemies) ===\n")
fps_sample("idle $63", 300)

-- Phase C: hold Left (Link walks toward enemies)
f:write("\n=== Phase C: walk left $63 ===\n")
fps_sample("walk-L $63", 300, function() joypad.set({Left=true},1) end)

-- Phase D: alternate A button (sword swings)
f:write("\n=== Phase D: A-mash $63 (sword swing) ===\n")
fps_sample("A-mash $63", 300, function(i)
  if (i % 30) < 4 then joypad.set({A=true},1) end
end)

-- Phase E: A + Left combined
f:write("\n=== Phase E: A+Left $63 ===\n")
fps_sample("A+L $63", 300, function(i)
  local inp = {Left=true}
  if (i % 30) < 4 then inp.A = true end
  joypad.set(inp, 1)
end)

client.screenshot("C:\\tmp\\fps_dense_v2.png")
f:write("\nDONE\n")
f:close()
gui.text(8,8,"fps v2 done")
idle(20)
client.exit()

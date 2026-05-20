-- walkable_67.lua — walk into $67 (north of spawn $77),
-- then sample walkN/col/row each frame while holding Up to find
-- exactly where the wall is. Also try LEFT/RIGHT/DOWN from clamp.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function S16BE(o)
  local v = R16BE(o); if v >= 0x8000 then v = v - 0x10000 end; return v
end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\walkable_67.txt"
local f = io.open(OUT, "w")

local function snap(tag)
  f:write(string.format("%-14s rm=$%02X X=$%04X Y=$%04X face=%d dir=%d walk=%d walkN=%d col=%d row=%d\n",
    tag, R(0x7205),
    S16BE(0x7206) & 0xFFFF, S16BE(0x7208) & 0xFFFF,
    R(0x720A), R(0x720B), R(0x7223), R(0x7224), R(0x7225), R(0x7226)))
end

idle(60)
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
memory.write_u8(0x73FA, 0x01, "68K RAM")

for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(30)
snap("spawn_77")

-- Walk north to $67
for i=1,200 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(20)
snap("after_to_67")

-- Sample every frame moving north
f:write("\n=== Frame-by-frame UP in $67 ===\n")
local last_y = -1
for i=1,250 do
  joypad.set({Up=true}, 1); emu.frameadvance()
  local y = S16BE(0x7208) & 0xFFFF
  if y ~= last_y then
    snap("U_y_"..string.format("%04X", y))
    last_y = y
  end
end
idle(20)
snap("up_clamped")

-- Try walking around the clamp
f:write("\n=== After UP-clamp, try LEFT then UP ===\n")
for i=1,30 do joypad.set({Left=true}, 1); emu.frameadvance() end
idle(10)
snap("post_left30")
for i=1,30 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(10)
snap("post_left30_up30")

f:write("\n=== UP-clamp recovery, try RIGHT then UP ===\n")
for i=1,60 do joypad.set({Right=true}, 1); emu.frameadvance() end
idle(10)
snap("post_right60")
for i=1,60 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(10)
snap("post_right60_up60")

-- Test row sweep: walk along top edge sampling walk/walkN per X
f:write("\n=== X sweep at top, hold UP each frame ===\n")
for i=1,200 do
  joypad.set({Left=true, Up=true}, 1); emu.frameadvance()
  if i % 10 == 0 then snap("LU_"..i) end
end
for i=1,300 do
  joypad.set({Right=true, Up=true}, 1); emu.frameadvance()
  if i % 10 == 0 then snap("RU_"..i) end
end

client.screenshot("C:\\tmp\\walkable_67.png")
f:write("\nDONE\n")
f:close()
gui.text(8, 8, "walk done")
idle(20)
client.exit()

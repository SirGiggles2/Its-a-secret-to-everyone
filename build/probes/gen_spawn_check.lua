-- gen_spawn_check.lua — verify Genesis cloud at room entry.
-- Walks to room $67, captures SAT + VRAM at tile 1137 (NES $70).

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function VR(o) return memory.read_u8(o, "VRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)
-- Walk Up until ROOM_ID changes to $67, then capture. ROOM_ID = $7205.
local entered = false
for i=1,400 do
  joypad.set({Up=true}, 1)
  emu.frameadvance()
  if R(0x7205) == 0x67 then entered = true; break end
end
joypad.set({}, 1)

local f = io.open("C:\\tmp\\gen_spawn_check.txt", "w")

-- Capture frame-by-frame for 60 frames after scroll. METASTATE = $0405.
for fr=0,59 do
  emu.frameadvance()
  local line = string.format("f%2d:", fr)
  for s=1,11 do
    local t = R(0x834F + s)
    if t ~= 0 then
      line = line .. string.format(" s%d:t$%02X st$%02X meta$%02X tm$%02X X$%02X Y$%02X",
        s, t, R(0x80AC+s), R(0x8405+s), R(0x8028+s), R(0x8070+s), R(0x8084+s))
    end
  end
  f:write(line .. "\n")
  if fr == 0 or fr == 10 or fr == 30 then
    client.screenshot(string.format("C:\\tmp\\gen_spawn_%02d.png", fr))
  end
end

-- Dump Genesis VRAM tile 1137 (NES $70 = cloud)
f:write("\n=== Genesis VRAM tile 1137 (NES $70 cloud) ===\n")
for row=0,7 do
  local off = 1137 * 32 + row * 4
  f:write(string.format("  row%d: %02X %02X %02X %02X\n",
    row, VR(off), VR(off+1), VR(off+2), VR(off+3)))
end
f:write("\n=== Genesis VRAM tile 1139 (NES $72 cloud right) ===\n")
for row=0,7 do
  local off = 1139 * 32 + row * 4
  f:write(string.format("  row%d: %02X %02X %02X %02X\n",
    row, VR(off), VR(off+1), VR(off+2), VR(off+3)))
end

-- Dump SAT
f:write("\n=== Final SAT ($F400) ===\n")
for s=0,30 do
  local off = 0xF400 + s*8
  local y = memory.read_u16_be(off, "VRAM")
  local sz = VR(off+2)
  local link = VR(off+3)
  local ta = memory.read_u16_be(off+4, "VRAM")
  local x = memory.read_u16_be(off+6, "VRAM")
  local tile = ta & 0x7FF
  if y ~= 0 or ta ~= 0 or x ~= 0 then
    f:write(string.format("  sat%2d: y=$%04X sz=$%02X link=$%02X tile=%d attr=$%04X x=$%04X\n",
      s, y, sz, link, tile, ta, x))
  end
end

f:close()
client.exit()

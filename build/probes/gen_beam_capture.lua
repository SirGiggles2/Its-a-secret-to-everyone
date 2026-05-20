-- Capture beam slot 2 SAT over multiple frames while firing
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end; joypad.set({},1); emu.frameadvance() end

idle(240)
press({A=true,B=true,C=true}, 8); idle(60)

-- Heal Link to full HP for beam fire
memory.writebyte(0x866F, 0xFF, "68K RAM")  -- HeartValues max/cur
memory.writebyte(0x8670, 0x00, "68K RAM")  -- partial
idle(10)

-- Try direction up + sword swing
local f = io.open("C:\\tmp\\beam_capture.txt", "w")
f:write("=== Beam capture across frames + directions ===\n")

local function dump_slot2(label)
  local off = 0xF400 + 2*8
  local y = memory.read_u16_be(off+0, "VRAM")
  local sl = memory.read_u8(off+2, "VRAM")
  local lk = memory.read_u8(off+3, "VRAM")
  local a = memory.read_u16_be(off+4, "VRAM")
  local x = memory.read_u16_be(off+6, "VRAM")
  f:write(string.format("%s: y=%d (px %d) sz=$%02X lk=%d attr=$%04X x=%d (px %d) tile=%d pal=%d hf=%d vf=%d\n",
    label, y, y-128, sl, lk, a, x, x-128, a%0x800, (a>>13)%4, (a>>11)%2, (a>>12)%2))
end

-- Face UP
press({Up=true}, 5)
press({A=true}, 1)   -- swing
for i=1,10 do
  dump_slot2(string.format("UP frame %d", i))
  idle(1)
end

idle(60)
-- Face DOWN
press({Down=true}, 5)
press({A=true}, 1)
for i=1,10 do
  dump_slot2(string.format("DN frame %d", i))
  idle(1)
end

idle(60)
-- Face LEFT
press({Left=true}, 5)
press({A=true}, 1)
for i=1,10 do
  dump_slot2(string.format("LT frame %d", i))
  idle(1)
end

idle(60)
-- Face RIGHT
press({Right=true}, 5)
press({A=true}, 1)
for i=1,10 do
  dump_slot2(string.format("RT frame %d", i))
  idle(1)
end

f:close()
client.screenshot("C:\\tmp\\beam_final.png")
client.exit()

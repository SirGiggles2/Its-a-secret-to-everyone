-- NES room $66 spawn capture.
local function R(o) return memory.read_u8(o, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

idle(120); tap("Start"); idle(30); tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)

-- Walk Up to $67
for _=1,400 do joypad.set({Up=true},1); emu.frameadvance(); if R(0x00EB) == 0x67 then break end end
joypad.set({},1); idle(30)
-- Walk Left to $66
for _=1,400 do joypad.set({Left=true},1); emu.frameadvance(); if R(0x00EB) == 0x66 then break end end
joypad.set({},1)
-- Wait for slot 1 populate
for _=1,500 do if R(0x0350) ~= 0 then break end; emu.frameadvance() end

local f = io.open("C:/tmp/spawn_66_nes.txt", "w")
f:write(string.format("=== NES room $66 spawn (RoomId=$%02X) ===\n", R(0x00EB)))
for s=1,11 do
  local t = R(0x034F+s)
  if t ~= 0 then
    f:write(string.format("slot %2d: type=$%02X X=$%02X Y=$%02X dir=$%02X qspd=$%02X\n",
      s, t, R(0x0070+s), R(0x0084+s), R(0x0098+s), R(0x03BC+s)))
  end
end
f:write(string.format("LinkX=$%02X LinkY=$%02X LinkDir=$%02X\n", R(0x0070), R(0x0084), R(0x0098)))
f:write(string.format("ObjectFirstUnwalkableTile=$%02X\n", R(0x034A)))
client.screenshot("C:/tmp/spawn_66_nes.png")
f:close()
client.exit()

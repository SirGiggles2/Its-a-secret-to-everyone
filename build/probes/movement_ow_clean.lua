-- movement_ow_clean.lua — teleport to non-cave-entry OW room,
-- then verify Link movement actually translates X/Y by holding D-pad.

local function R(o) return memory.read_u8(0x8000 + o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press_once(b, hold, after)
  joypad.set(b, 1)
  emu.frameadvance()
  for _=2,hold do joypad.set(b,1); emu.frameadvance() end
  idle(after or 6)
end

local OUT = "C:\\tmp\\movement_ow_clean.txt"
local f = io.open(OUT, "w")

idle(60)
-- Enter gameplay via A+B+C
for i=1,20 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(30)

f:write("=== state after entry ===\n")
f:write(string.format("scene=%d gamemode=$%02X RoomId=$%02X Link=(%02X,%02X)\n",
  R(0xFB), R(0x12), R(0xEB), R(0x70), R(0x84)))

-- Press X to enter MODE_TELEPORT (clears MODE_WALK)
press_once({X=true}, 3, 10)
press_once({X=true}, 3, 10)  -- press twice (some toggle modes vs cycles)
-- Try with single X
idle(20)

-- Teleport via D-pad (RIGHT moves to col+1 if mode is teleport)
press_once({Right=true}, 3, 30)
f:write(string.format("after teleport-right: RoomId=$%02X Link=(%02X,%02X)\n",
  R(0xEB), R(0x70), R(0x84)))

-- Exit teleport mode (X press again)
press_once({X=true}, 3, 15)

f:write(string.format("after X-toggle-back: Link=(%02X,%02X)\n", R(0x70), R(0x84)))

-- Now WALK test: hold Right 60 frames
f:write("\n=== WALK RIGHT 60f ===\n")
local startX, startY = R(0x70), R(0x84)
for i=1,60 do
  joypad.set({Right=true}, 1)
  emu.frameadvance()
  if i % 10 == 0 then
    f:write(string.format("  f=%02d FA=$%02X LinkX=$%02X Y=$%02X face=$%02X st=$%02X\n",
      i, R(0xFA), R(0x70), R(0x84), R(0x98), R(0xAC)))
  end
end
f:write(string.format("delta X=%d Y=%d\n", R(0x70)-startX, R(0x84)-startY))

f:write("\n=== WALK DOWN 60f ===\n")
startX, startY = R(0x70), R(0x84)
for i=1,60 do
  joypad.set({Down=true}, 1)
  emu.frameadvance()
  if i % 10 == 0 then
    f:write(string.format("  f=%02d FA=$%02X LinkX=$%02X Y=$%02X face=$%02X st=$%02X\n",
      i, R(0xFA), R(0x70), R(0x84), R(0x98), R(0xAC)))
  end
end
f:write(string.format("delta X=%d Y=%d\n", R(0x70)-startX, R(0x84)-startY))

client.screenshot("C:\\tmp\\movement_ow_clean.png")
f:write("\nDONE\n")
f:close()
gui.text(8, 8, "clean probe done")
idle(30)
client.exit()

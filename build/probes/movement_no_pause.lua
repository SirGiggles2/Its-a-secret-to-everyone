-- movement_no_pause.lua — verify Link moves when pause not toggled.
-- Reproduce previous probe but SKIP bare Start press.

local function R(o) return memory.read_u8(0x8000 + o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\movement_no_pause.txt"
local f = io.open(OUT, "w")

idle(60)
-- A+B+C to enter gameplay
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(60)

f:write("=== POST_ABC (no Start press) ===\n")
f:write(string.format("gamemode=$%02X frame=$%02X RoomId=$%02X\n", R(0x12), R(0x15), R(0xEB)))
f:write(string.format("Link X=$%02X Y=$%02X face=$%02X state=$%02X\n", R(0x70), R(0x84), R(0x98), R(0xAC)))

-- Hold RIGHT for 30 frames, sample every 5
f:write("\n=== HOLD RIGHT 30f ===\n")
for i=1,30 do
  joypad.set({Right=true}, 1)
  emu.frameadvance()
  if i % 5 == 0 then
    f:write(string.format("  f=%02d F8=$%02X FA=$%02X LinkX=$%02X Y=$%02X face=$%02X st=$%02X\n",
      i, R(0xF8), R(0xFA), R(0x70), R(0x84), R(0x98), R(0xAC)))
  end
end

f:write("\n=== HOLD LEFT 30f ===\n")
for i=1,30 do
  joypad.set({Left=true}, 1)
  emu.frameadvance()
  if i % 5 == 0 then
    f:write(string.format("  f=%02d F8=$%02X FA=$%02X LinkX=$%02X Y=$%02X face=$%02X st=$%02X\n",
      i, R(0xF8), R(0xFA), R(0x70), R(0x84), R(0x98), R(0xAC)))
  end
end

f:write("\n=== HOLD DOWN 60f ===\n")
for i=1,60 do
  joypad.set({Down=true}, 1)
  emu.frameadvance()
  if i % 10 == 0 then
    f:write(string.format("  f=%02d F8=$%02X FA=$%02X LinkX=$%02X Y=$%02X face=$%02X st=$%02X\n",
      i, R(0xF8), R(0xFA), R(0x70), R(0x84), R(0x98), R(0xAC)))
  end
end

f:write("\n=== HOLD UP 60f ===\n")
for i=1,60 do
  joypad.set({Up=true}, 1)
  emu.frameadvance()
  if i % 10 == 0 then
    f:write(string.format("  f=%02d F8=$%02X FA=$%02X LinkX=$%02X Y=$%02X face=$%02X st=$%02X\n",
      i, R(0xF8), R(0xFA), R(0x70), R(0x84), R(0x98), R(0xAC)))
  end
end

-- Shot at end while moving
client.screenshot("C:\\tmp\\movement_no_pause.png")
f:write("\nDONE\n")
f:close()
gui.text(8, 8, "no-pause done")
idle(30)
client.exit()

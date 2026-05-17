-- input_probe.lua — verify controller adapter writes $00F8/$00FA;
-- verify Link X/Y respond to direction. Single screenshot + trace log.

local function R(o) return memory.read_u8(0x8000 + o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, n) for _=1,n do joypad.set(b, 1); emu.frameadvance() end end

local OUT = "C:\\tmp\\input_probe.txt"
local f = io.open(OUT, "w")

-- BOOT into debug mode
idle(60)
press({A=true,B=true,C=true}, 30)
idle(60)
press({Start=true}, 4)
idle(60)

f:write("=== AT_REST (no input) ===\n")
f:write(string.format("gamemode=$%02X frame=$%02X RoomId=$%02X\n", R(0x12), R(0x15), R(0xEB)))
f:write(string.format("Link X=$%02X Y=$%02X face=$%02X state=$%02X\n", R(0x70), R(0x84), R(0x98), R(0xAC)))
f:write(string.format("ButtonsPressed($F8)=$%02X ButtonsDown($FA)=$%02X\n", R(0xF8), R(0xFA)))
f:write(string.format("Edge($F9)=$%02X NewlyP($FB)=$%02X\n", R(0xF9), R(0xFB)))

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

f:write("\n=== HOLD UP 30f ===\n")
for i=1,30 do
  joypad.set({Up=true}, 1)
  emu.frameadvance()
  if i % 5 == 0 then
    f:write(string.format("  f=%02d F8=$%02X FA=$%02X LinkX=$%02X Y=$%02X face=$%02X st=$%02X\n",
      i, R(0xF8), R(0xFA), R(0x70), R(0x84), R(0x98), R(0xAC)))
  end
end

f:write("\n=== HOLD DOWN 30f ===\n")
for i=1,30 do
  joypad.set({Down=true}, 1)
  emu.frameadvance()
  if i % 5 == 0 then
    f:write(string.format("  f=%02d F8=$%02X FA=$%02X LinkX=$%02X Y=$%02X face=$%02X st=$%02X\n",
      i, R(0xF8), R(0xFA), R(0x70), R(0x84), R(0x98), R(0xAC)))
  end
end

f:write("\n=== TAP B (sword) 8f ===\n")
for i=1,8 do
  joypad.set({B=true}, 1)
  emu.frameadvance()
  f:write(string.format("  f=%02d F8=$%02X FA=$%02X LinkX=$%02X Y=$%02X face=$%02X st=$%02X\n",
    i, R(0xF8), R(0xFA), R(0x70), R(0x84), R(0x98), R(0xAC)))
end

idle(30)
client.screenshot("C:\\tmp\\input_probe.png")
f:write("\nDONE\n")
f:close()
gui.text(8, 8, "input probe done")
idle(30)
client.exit()

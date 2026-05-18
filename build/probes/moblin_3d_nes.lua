-- moblin_3d_nes.lua — NES: walk to OW room $3D, screenshot
local function R(o) return memory.read_u8(o, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

-- Title screen flow
idle(120); tap("Start"); idle(30); tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)

-- Start room is $77. Walk to $3D: row 3 col D from row 7 col 7.
-- Need up x4 to row 3, right x6 to col D.
-- Walk Up four screens
for u=1,400 do
  joypad.set({Up=true},1); emu.frameadvance()
  local r = R(0x00EB)
  if (r >> 4) == 3 then break end
end
joypad.set({},1); idle(30)

-- Walk Right toward col D
for u=1,800 do
  joypad.set({Right=true},1); emu.frameadvance()
  local r = R(0x00EB)
  if r == 0x3D then break end
end
joypad.set({},1); idle(60)

local f = io.open("C:/tmp/moblin_3d_nes.txt", "w")
f:write(string.format("=== NES room $%02X ===\n", R(0x00EB)))
for s=1,11 do
  local t = R(0x034F+s)
  if t ~= 0 then
    f:write(string.format("slot %d: type=$%02X X=$%02X Y=$%02X dir=$%02X attr=$%02X\n",
      s, t, R(0x0070+s), R(0x0084+s), R(0x0098+s), R(0x04BF+s)))
  end
end
f:close()
client.screenshot("C:/tmp/moblin_3d_nes.png")
client.exit()

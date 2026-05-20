-- teleport_freeze.lua — capture state after teleport freeze.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn,h,r)
  h=h or 4; r=r or 12
  for _=1,h do joypad.set({[btn]=true},1); emu.frameadvance() end
  for _=1,r do joypad.set({},1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\tp_freeze.txt"
local f = io.open(OUT, "w")

idle(60)
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
memory.write_u8(0x73FA, 0x00, "68K RAM")

for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
idle(60)

-- Teleport to $63 with longer pauses
tap("X", 6, 30)
tap("Left", 6, 30)
tap("Left", 6, 30)
tap("Left", 6, 30)
tap("Left", 6, 30)
tap("Up", 6, 30)
tap("X", 6, 30)
idle(30)

client.screenshot("C:\\tmp\\tp_freeze_1.png")
f:write(string.format("=== after teleport+screenshot1 ===\n"))
f:write(string.format("fc=%d room=$%02X mode=$%02X scene=%d link=(%02X,%02X)\n",
  R16BE(0x7202), R(MIRROR+0x00EB), R(MIRROR+0x0012), R(0x7204),
  R(MIRROR+0x0070), R(MIRROR+0x0084)))

-- Read NES game state directly (not just mirror)
f:write(string.format("nes_game_mode=$%02X cur_room=$%02X link_hp=$%02X link_x=$%02X link_y=$%02X\n",
  R(MIRROR+0x0012), R(MIRROR+0x00EB), R(MIRROR+0x066F),
  R(MIRROR+0x0070), R(MIRROR+0x0084)))

-- Read first 6 enemy ObjTypes
local et = {}
for s=1,6 do table.insert(et, string.format("[%d]=$%02X", s, R(MIRROR+0x034F+s))) end
f:write("enemies: " .. table.concat(et, " ") .. "\n")

idle(120)
client.screenshot("C:\\tmp\\tp_freeze_2.png")
f:write(string.format("\n=== after idle120 ===\n"))
f:write(string.format("fc=%d room=$%02X mode=$%02X\n",
  R16BE(0x7202), R(MIRROR+0x00EB), R(MIRROR+0x0012)))

idle(300)
client.screenshot("C:\\tmp\\tp_freeze_3.png")
f:write(string.format("\n=== after idle300 (300 more emu frames) ===\n"))
f:write(string.format("fc=%d room=$%02X mode=$%02X\n",
  R16BE(0x7202), R(MIRROR+0x00EB), R(MIRROR+0x0012)))

f:close()
gui.text(8,8,"tp freeze done")
idle(20)
client.exit()

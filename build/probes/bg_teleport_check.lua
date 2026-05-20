-- bg_teleport_check.lua — screenshot at each step to find BG break.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn, hold, release)
  hold = hold or 2
  release = release or 8
  for _=1,hold do joypad.set({[btn]=true}, 1); emu.frameadvance() end
  for _=1,release do joypad.set({}, 1); emu.frameadvance() end
end

local MIRROR = 0x8000

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(80)

client.screenshot("C:\\tmp\\bg_77.png")  -- debug_enter result (boot $77)
local r0 = R(MIRROR+0x00EB)

tap("X")  -- enter teleport mode
idle(20)
client.screenshot("C:\\tmp\\bg_x.png")  -- after pressing X (still $77)
local r1 = R(MIRROR+0x00EB)

tap("Up", 4, 20)
idle(40)
client.screenshot("C:\\tmp\\bg_up1.png")  -- after 1 Up tap
local r2 = R(MIRROR+0x00EB)

tap("Up", 4, 20)
idle(40)
client.screenshot("C:\\tmp\\bg_up2.png")  -- after 2nd Up tap
local r3 = R(MIRROR+0x00EB)

local f = io.open("C:\\tmp\\bg_check.txt", "w")
f:write(string.format("after_debug_enter room=$%02X\n", r0))
f:write(string.format("after_X         room=$%02X\n", r1))
f:write(string.format("after_Up1       room=$%02X\n", r2))
f:write(string.format("after_Up2       room=$%02X\n", r3))
f:close()
gui.text(8,8,"done")
idle(20)
client.exit()

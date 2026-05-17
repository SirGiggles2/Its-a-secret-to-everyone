-- scene_sweep.lua — exercise multiple scenes and capture screenshots.
-- 1. Boot OW (room $77)
-- 2. Scroll into a few different OW rooms (north, east, west)
-- 3. Toggle SCENE_UW (Start chord per project_roomrom_debug_teleport)
-- 4. Capture UW room
-- 5. Return to OW
-- Note: roomrom_debug_teleport mentions Start toggles SCENE_OW/UW.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\scene_sweep.txt"
local f = io.open(OUT, "w")

-- Boot + debug chord + state mirror arm
idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)

local function state(label)
  local s = string.format("%s scene=%d room=$%02X x=$%02X y=$%02X fc=%d",
    label, R(0x7204), R(0x7205), R(0x7207), R(0x7209), R16BE(0x7202))
  f:write(s .. "\n")
  return s
end

state("[01 boot OW]")
client.screenshot("C:\\tmp\\sweep_01_ow_start.png")

-- Walk in cross pattern
for _=1,200 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(20)
state("[02 walked Up 200f]")
client.screenshot("C:\\tmp\\sweep_02_ow_north.png")

for _=1,200 do joypad.set({Right=true}, 1); emu.frameadvance() end
idle(20)
state("[03 walked Right 200f]")
client.screenshot("C:\\tmp\\sweep_03_ow_east.png")

for _=1,200 do joypad.set({Down=true}, 1); emu.frameadvance() end
idle(20)
state("[04 walked Down 200f]")
client.screenshot("C:\\tmp\\sweep_04_ow_south.png")

-- Try SCENE_UW via Start tap (per project_roomrom_debug_teleport)
for i=1,5 do joypad.set({Start=true}, 1); emu.frameadvance() end
for _=1,60 do joypad.set({}, 1); emu.frameadvance() end
state("[05 post-Start]")
client.screenshot("C:\\tmp\\sweep_05_after_start.png")

-- Walk around in whatever scene we're in
for _=1,120 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(20)
state("[06 walked Up in scene]")
client.screenshot("C:\\tmp\\sweep_06_scene_north.png")

-- Press Start again to maybe toggle back
for i=1,5 do joypad.set({Start=true}, 1); emu.frameadvance() end
for _=1,60 do joypad.set({}, 1); emu.frameadvance() end
state("[07 post-Start-2]")
client.screenshot("C:\\tmp\\sweep_07_after_start2.png")

f:write("\nDONE\n")
f:close()
idle(15)
client.exit()

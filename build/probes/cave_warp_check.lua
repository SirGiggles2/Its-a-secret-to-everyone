-- cave_warp_check.lua — walk Link north from $77 boot pos onto cave tile,
-- verify game_mode transitions (overworld -> cave subscene).
local function R(o) return memory.read_u8(o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\cave_warp.txt"
local f = io.open(OUT, "w")

local function snap(label)
  f:write(string.format(
    "%s room=$%02X mode=$%02X subscene=$%02X link=(%02X,%02X) face=$%02X\n",
    label,
    R(MIRROR+0x00EB),
    R(MIRROR+0x0012),
    R(MIRROR+0x001A),
    R(MIRROR+0x0070),
    R(MIRROR+0x0084),
    R(MIRROR+0x000F)))
end

idle(60)
-- A+B+C chord to enter gameplay
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(80)
snap("boot")

-- Walk Up for 300 frames, snap every 30
for chunk=1,10 do
  for _=1,30 do joypad.set({Up=true}, 1); emu.frameadvance() end
  snap(string.format("up+%03d", chunk*30))
end

-- Release + idle
for _=1,60 do joypad.set({}, 1); emu.frameadvance() end
snap("settle")

client.screenshot("C:\\tmp\\cave_warp.png")
f:close()
gui.text(8,8,"done")
idle(20)
client.exit()

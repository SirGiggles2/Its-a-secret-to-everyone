-- cave_warp_scan.lua — scan metatile columns in room $77 for cave-entrance.
-- Link X=$78 boot, rule 3 needs (X & 0x0F)==0. Walk to $70 first, try Up.
-- If mode stays $05, return to $77 (via teleport), shift X, retry.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn,h,r)
  h=h or 4; r=r or 12
  for _=1,h do joypad.set({[btn]=true},1); emu.frameadvance() end
  for _=1,r do joypad.set({},1); emu.frameadvance() end
end
local function hold(btn,n)
  for _=1,n do joypad.set({[btn]=true},1); emu.frameadvance() end
  for _=1,8 do joypad.set({},1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\cave_warp_scan.txt"
local f = io.open(OUT, "w")

local function snap(lbl)
  f:write(string.format("%-12s room=$%02X mode=$%02X subscene=$%02X link=(%02X,%02X)\n",
    lbl, R(MIRROR+0x00EB), R(MIRROR+0x0012), R(MIRROR+0x001A),
    R(MIRROR+0x0070), R(MIRROR+0x0084)))
end

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
idle(80)
snap("boot")

-- Boot in $77, Link at (78,8D). Try walking up through each metatile column.
-- Strategy: nudge Link X with Left/Right, hold Up 60 frames, snap, check mode.

local targets = {0x70, 0x80, 0x90, 0x60, 0xA0, 0x50, 0xB0, 0x40, 0xC0}
for i,tx in ipairs(targets) do
  local cur_x = R(MIRROR+0x0070)
  local dx = tx - cur_x
  if dx < 0 then
    for _=1,(-dx) do joypad.set({Left=true},1); emu.frameadvance() end
  elseif dx > 0 then
    for _=1,dx do joypad.set({Right=true},1); emu.frameadvance() end
  end
  for _=1,8 do joypad.set({},1); emu.frameadvance() end
  snap(string.format("aligned $%02X", tx))
  -- Walk up 80 frames
  for _=1,80 do joypad.set({Up=true},1); emu.frameadvance() end
  for _=1,8 do joypad.set({},1); emu.frameadvance() end
  snap(string.format("after-up $%02X", tx))
  -- If mode changed, stop
  if R(MIRROR+0x0012) ~= 0x05 then
    f:write(string.format("!! WARP FIRED at X=$%02X !!\n", tx))
    break
  end
  -- If room changed (scrolled north), abort — Link left $77
  if R(MIRROR+0x00EB) ~= 0x77 then
    f:write(string.format("scrolled out of $77 (now $%02X) at X=$%02X\n",
      R(MIRROR+0x00EB), tx))
    break
  end
end

snap("end")
client.screenshot("C:\\tmp\\cave_warp_scan.png")
f:close()
gui.text(8,8,"done")
idle(20)
client.exit()

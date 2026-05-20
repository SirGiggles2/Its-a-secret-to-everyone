-- enemy_tick_check.lua — teleport to enemy room, verify per-frame position advance.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn, hold, release)
  hold = hold or 4
  release = release or 14
  for _=1,hold do joypad.set({[btn]=true}, 1); emu.frameadvance() end
  for _=1,release do joypad.set({}, 1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\enemy_tick.txt"
local f = io.open(OUT, "w")

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(80)

tap("X")    -- teleport mode
tap("Up")   -- $77 -> $67
tap("Up")   -- $67 -> $57
idle(20)

local function snapshot_enemies(label)
  f:write(string.format("\n[%s] room=$%02X frame=$%02X\n",
    label, R(MIRROR+0x00EB), R(MIRROR+0x0015)))
  for s=1,11 do
    local t = R(MIRROR+0x034F+s)
    if t ~= 0 then
      local fl = R(MIRROR+0x0098+s)
      local x = R(MIRROR+0x0070+s)
      local y = R(MIRROR+0x0084+s)
      local st = R(MIRROR+0x00AC+s)
      local anim = R(MIRROR+0x03D0+s)
      f:write(string.format(
        "  slot %2d type=%02X flag=%02X state=%02X anim=%02X (%02X,%02X)\n",
        s,t,fl,st,anim,x,y))
    end
  end
end

snapshot_enemies("t=0 (after teleport)")
idle(15)
snapshot_enemies("t=+15")
idle(30)
snapshot_enemies("t=+45")
idle(60)
snapshot_enemies("t=+105")

client.screenshot("C:\\tmp\\enemy_tick.png")
f:close()
gui.text(8,8,"done")
idle(20)
client.exit()

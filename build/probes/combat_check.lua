-- combat_check.lua — teleport to $67, walk left + swing sword, verify kills.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn, hold, release)
  hold = hold or 4
  release = release or 14
  for _=1,hold do joypad.set({[btn]=true}, 1); emu.frameadvance() end
  for _=1,release do joypad.set({}, 1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\combat.txt"
local f = io.open(OUT, "w")

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(80)

-- Get to $67 (one teleport up from $77)
tap("X")
tap("Up")
tap("X")  -- exit teleport mode back to walk
idle(20)

local function count_enemies(label)
  local n = 0
  local types = {}
  for s=1,11 do
    local t = R(MIRROR+0x034F+s)
    if t ~= 0 and t ~= 0x53 then  -- exclude dust cloud
      n = n + 1
      table.insert(types, string.format("[%d]=$%02X", s, t))
    end
  end
  f:write(string.format("\n%s room=$%02X enemies=%d %s\n",
    label, R(MIRROR+0x00EB), n, table.concat(types, " ")))
  return n
end

count_enemies("baseline (after teleport+exit)")

-- Walk left + swing sword. Repeat. Octorok HP=1, one hit kills.
for cycle=1,12 do
  -- Move left toward enemy at (50,9D), Link starts at (78,8D)
  for _=1,8 do joypad.set({Left=true}, 1); emu.frameadvance() end
  -- Move down a bit
  for _=1,4 do joypad.set({Down=true}, 1); emu.frameadvance() end
  -- Release + swing sword (A button edge)
  for _=1,4 do joypad.set({}, 1); emu.frameadvance() end
  for _=1,2 do joypad.set({A=true}, 1); emu.frameadvance() end
  for _=1,20 do joypad.set({}, 1); emu.frameadvance() end
  count_enemies("cycle " .. cycle)
end

f:write(string.format("\nlink_pos=(%02X,%02X) face=%02X\n",
  R(MIRROR+0x0070), R(MIRROR+0x0084), R(MIRROR+0x000F)))

client.screenshot("C:\\tmp\\combat.png")
f:close()
gui.text(8,8,"done")
idle(20)
client.exit()

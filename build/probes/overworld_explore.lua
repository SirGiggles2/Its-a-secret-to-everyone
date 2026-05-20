-- overworld_explore.lua — walk through several rooms, capture screenshots
-- at each new room. Goal: visit ~6 rooms, check for enemies, doors, etc.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press_dir(dir, n)
  for i=1,n do joypad.set({[dir]=true}, 1); emu.frameadvance() end
end

local OUT = "C:\\tmp\\ow_explore.txt"
local f = io.open(OUT, "w")

local function dump_sat(label, max_slots)
  f:write(string.format("-- SAT @ %s --\n", label))
  local active = 0
  for i=0,max_slots-1 do
    local y = memory.read_u16_be(0xF400 + i*8 + 0, "VRAM")
    if y > 0x80 and y < 0x200 then  -- on-screen
      local sz = memory.read_u8(0xF400 + i*8 + 2, "VRAM")
      local attr = memory.read_u16_be(0xF400 + i*8 + 4, "VRAM")
      local x = memory.read_u16_be(0xF400 + i*8 + 6, "VRAM")
      f:write(string.format("  slot %02d Y=%04X X=%04X sz=%02X tile=%d pal=%d\n",
        i, y, x, sz, attr & 0x7FF, (attr >> 13) & 0x3))
      active = active + 1
    end
  end
  f:write(string.format("  on-screen sprites: %d\n", active))
end

idle(60)
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
memory.write_u8(0x73FA, 0x01, "68K RAM")

for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(30)

local function snap(label)
  f:write(string.format("\n=== %s ===\nscene=%d rm=$%02X X=$%02X Y=$%02X face=%d\n",
    label, R(0x7204), R(0x7205), R(0x7207), R(0x7209), R(0x720A)))
  dump_sat(label, 16)
  client.screenshot("C:\\tmp\\ow_explore_" .. label .. ".png")
end

snap("01_start_77")

-- Walk UP to scroll to $67
press_dir("Up", 200)
idle(60)
snap("02_north_67")

-- Continue UP to $57 (further north)
press_dir("Up", 200)
idle(60)
snap("03_north_57")

-- Walk LEFT to $56
press_dir("Left", 200)
idle(60)
snap("04_west_56")

-- Walk DOWN to find different room
press_dir("Down", 200)
idle(60)
snap("05_down_66")

-- Try RIGHT
press_dir("Right", 250)
idle(60)
snap("06_right_67again")

-- Down to 77
press_dir("Down", 250)
idle(60)
snap("07_down_77")

-- Now from 77 try UP back into cave
press_dir("Up", 250)
idle(60)
snap("08_back_north")

f:write("\nDONE\n")
f:close()
gui.text(8, 8, "explore done")
idle(20)
client.exit()

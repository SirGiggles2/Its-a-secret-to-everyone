-- visual_compare.lua — capture multiple screenshots in OW, post-walk,
-- after walking down to non-start room. Plus full SAT + CRAM dump.

local function R(o) return memory.read_u8(0x8000 + o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local function dump(label)
  client.screenshot("C:\\tmp\\vc_" .. label .. ".png")
  local f = io.open("C:\\tmp\\vc_" .. label .. ".txt", "w")
  f:write("=== " .. label .. " ===\n")
  f:write(string.format("scene=%d gamemode=$%02X RoomId=$%02X\n", R(0xFB), R(0x12), R(0xEB)))
  f:write(string.format("Link X=$%02X Y=$%02X face=$%02X state=$%02X\n",
    R(0x70), R(0x84), R(0x98), R(0xAC)))

  -- CRAM
  f:write("\n-- CRAM --\n")
  for pal=0,3 do
    f:write(string.format("PAL%d:", pal))
    for c=0,15 do
      f:write(string.format(" %04X", memory.read_u16_be(pal*32 + c*2, "CRAM")))
    end
    f:write("\n")
  end
  f:close()
end

idle(60)
dump("00_title")

-- ABC enter
for i=1,20 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(30)
dump("01_post_abc")

-- Walk right + down briefly so Link sprite refreshes
for i=1,15 do joypad.set({Right=true}, 1); emu.frameadvance() end
idle(20)
dump("02_walked_right")

for i=1,30 do joypad.set({Down=true}, 1); emu.frameadvance() end
idle(20)
dump("03_walked_down")

-- Sword swing (A)
for i=1,3 do joypad.set({A=true}, 1); emu.frameadvance() end
idle(20)
dump("04_sword")

-- Try scroll to next OW room
for i=1,150 do joypad.set({Down=true}, 1); emu.frameadvance() end
idle(60)
dump("05_scrolled_down")

for i=1,120 do joypad.set({Right=true}, 1); emu.frameadvance() end
idle(60)
dump("06_scrolled_right")

gui.text(8, 8, "compare done")
idle(20)
client.exit()

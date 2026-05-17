-- baseline_full_state.lua — capture full game state across boot/OW/UW
-- One probe, multiple snapshots, dumps to C:\tmp\baseline_*

local function R(off) return memory.read_u8(0x8000 + off, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, n) for _=1,n do joypad.set(b, 1); emu.frameadvance() end end

local function snap(label)
  client.screenshot("C:\\tmp\\baseline_" .. label .. ".png")
  local f = io.open("C:\\tmp\\baseline_" .. label .. ".txt", "w")
  f:write("=== " .. label .. " ===\n")
  f:write(string.format("gamemode=$%02X frame=$%02X\n", R(0x0012), R(0x0015)))
  f:write(string.format("RoomId=$%02X PrevRoomId=$%02X\n", R(0x00EB), R(0x00EC)))
  f:write(string.format("Link X=$%02X Y=$%02X face=$%02X state=$%02X\n",
      R(0x0070), R(0x0084), R(0x0098), R(0x00AC)))
  f:write(string.format("Hearts=$%02X partial=$%02X HeartContainers=$%02X\n",
      R(0x066F), R(0x0670), R(0x066E)))
  f:write(string.format("Rupees=$%02X bombs=$%02X keys=$%02X sword=$%02X\n",
      R(0x066D), R(0x0658), R(0x0666), R(0x0657)))
  f:write(string.format("Scene=$%02X Level=$%02X\n", R(0x00FB), R(0x010A)))
  f:write(string.format("SongRequest=$%02X SongCurrent=$%02X\n", R(0x00FC), R(0x00FD)))

  f:write("\n--- CRAM (64 entries, palette 0..3) ---\n")
  for pal=0,3 do
    f:write(string.format("PAL%d:", pal))
    for c=0,15 do
      f:write(string.format(" %04X", memory.read_u16_be(pal*32 + c*2, "CRAM")))
    end
    f:write("\n")
  end

  f:write("\n--- SAT (sprite 0..15, link=0 ends chain) ---\n")
  for s=0,15 do
    local base = s * 8
    local y    = memory.read_u16_be(base+0, "VRAM")
    local sz   = memory.read_u8(base+2, "VRAM")
    local link = memory.read_u8(base+3, "VRAM")
    local attr = memory.read_u16_be(base+4, "VRAM")
    local x    = memory.read_u16_be(base+6, "VRAM")
    f:write(string.format("  s%02d Y=%04X sz=%02X link=%02X attr=%04X X=%04X\n",
        s, y, sz, link, attr, x))
  end

  f:write("\n--- Enemy slots (1..11 alive only) ---\n")
  for slot=1,11 do
    local alive = R(0x0492+slot)
    if alive ~= 0 then
      f:write(string.format("  slot%02d alive=%02X type=%02X X=%02X Y=%02X hp=%02X st=%02X\n",
          slot, alive, R(0x034F+slot), R(0x0070+slot), R(0x0084+slot),
          R(0x0485+slot), R(0x00AC+slot)))
    end
  end
  f:close()
end

-- BOOT: wait for title/intro
idle(60)
snap("00_initial")

-- Press A+B+C to enter gameplay
press({A=true,B=true,C=true}, 30)
idle(120)
snap("01_post_abc")

-- Try Start to wake/advance
press({Start=true}, 4)
idle(60)
snap("02_post_start")

-- Walk right
press({Right=true}, 40)
idle(30)
snap("03_walk_right")

-- Walk down
press({Down=true}, 40)
idle(30)
snap("04_walk_down")

-- Try sword swing
press({B=true}, 8)
idle(30)
snap("05_sword")

-- Move into next OW screen
press({Right=true}, 90)
idle(60)
snap("06_scroll_right")

-- Try cave entry (Down on entrance tile? just try)
press({Down=true}, 60)
idle(120)
snap("07_after_down")

gui.text(8, 8, "BASELINE DONE")
idle(30)
client.exit()

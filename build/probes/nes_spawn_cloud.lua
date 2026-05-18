-- nes_spawn_cloud.lua — capture NES Z1 spawn cloud OAM during room
-- entry. Walks to room $67, then captures OAM every 3 frames for 30
-- frames so we see cloud transitions $01 -> $02 -> $03 -> active.

local function R(o) return memory.read_u8(o, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

idle(120)
tap("Start"); idle(30)
tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)

-- Walk up to scroll into room $67 — STOP AS SOON AS scroll completes.
-- Room is at $67 once Link's Y leaves room $77. Watch room id at $00EB.
for fr=1,400 do
  joypad.set({Up=true},1)
  emu.frameadvance()
  if R(0x00EB) == 0x67 then break end
end
joypad.set({},1)

-- Capture cloud anim. NES sets metastate=$01 + ObjTimer=slot_index on
-- InitObject. Cloud animates for ~slot+18 frames. Capture every 2
-- frames for 30 captures.
local f = io.open("C:\\tmp\\nes_spawn_cloud.txt", "w")
f:write(string.format("=== Spawn cloud capture (room id = $%02X) ===\n", R(0x00EB)))
for cap=0,29 do
  f:write(string.format("\n--- capture %d (frame_off=%d) ---\n", cap, cap*2))
  for s=1,11 do
    local t = R(0x034F+s)
    if t ~= 0 then
      local ms = R(0x00AC+s)
      local ot = R(0x0028+s)
      f:write(string.format("  slot %2d: type=$%02X X=$%02X Y=$%02X dir=$%02X meta=$%02X timer=$%02X\n",
        s, t, R(0x0070+s), R(0x0084+s), R(0x0098+s), ms, ot))
    end
  end
  -- Scan OAM for any sprite with tile that looks like cloud
  -- (typically tiles $34, $70, $72, $74 per NES bomb item table)
  for o=0,63 do
    local off = 0x0200 + o*4
    local y = R(off)
    local t = R(off+1)
    if y ~= 0xF8 and y ~= 0 and t ~= 0 then
      if t == 0x34 or t == 0x70 or t == 0x72 or t == 0x74 or
         (t >= 0x60 and t <= 0x6F) then
        f:write(string.format("    OAM%2d: Y=$%02X tile=$%02X attr=$%02X X=$%02X (CANDIDATE)\n",
          o, y, t, R(off+2), R(off+3)))
      end
    end
  end
  if cap % 5 == 0 then
    client.screenshot(string.format("C:\\tmp\\nes_spawn_cloud_%02d.png", cap))
  end
  emu.frameadvance(); emu.frameadvance()
end
f:close()
client.exit()

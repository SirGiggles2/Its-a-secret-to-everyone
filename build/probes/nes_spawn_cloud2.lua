-- nes_spawn_cloud2.lua — fine-grained NES spawn capture. Captures
-- every frame for 200 frames after room id changes to $67. Dumps
-- per-frame: slot state + OAM cloud-tile scan + screenshot every 10f.

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

-- Walk up; stop at room $67
for fr=1,400 do
  joypad.set({Up=true},1)
  emu.frameadvance()
  if R(0x00EB) == 0x67 then break end
end
joypad.set({},1)

local f = io.open("C:\\tmp\\nes_spawn_cloud2.txt", "w")
f:write(string.format("=== Frame-by-frame post room=$67 (200 frames) ===\n"))

for fr=0,199 do
  local types_active = 0
  local metas = ""
  for s=1,11 do
    local t = R(0x034F+s)
    if t ~= 0 then
      types_active = types_active + 1
      metas = metas .. string.format(" s%d:t$%02X m$%02X tm$%02X", s, t, R(0x00AC+s), R(0x0028+s))
    end
  end
  -- Scan OAM for any unusual sprites
  local oam_str = ""
  for o=0,63 do
    local off = 0x0200 + o*4
    local y = R(off)
    local t = R(off+1)
    if y ~= 0xF8 and y < 0xE0 and t ~= 0 and t ~= 0x61 then
      -- Skip HUD (y < $20)
      if y >= 0x20 then
        oam_str = oam_str .. string.format(" o%d:y$%02X t$%02X x$%02X", o, y, t, R(off+3))
        if string.len(oam_str) > 200 then oam_str = oam_str .. "..."; break end
      end
    end
  end
  if types_active > 0 or string.len(oam_str) > 0 then
    f:write(string.format("f%3d:%s |OAM:%s\n", fr, metas, oam_str))
  end
  if fr % 5 == 0 then
    client.screenshot(string.format("C:\\tmp\\nes_sc2_%03d.png", fr))
  end
  emu.frameadvance()
end
f:close()
client.exit()

-- NES Z1 beam capture in 4 directions. Full HP, swing sword, observe beam OAM.

local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(b,h,g) h=h or 4; g=g or 6
  for _=1,h do joypad.set({[b]=true},1); emu.frameadvance() end
  for _=1,g do joypad.set({},1); emu.frameadvance() end
end
local function R(a) return memory.read_u8(a, "RAM") end
local function W(a,v) memory.writebyte(a, v, "RAM") end

-- Boot + nav to OW
idle(240)
tap("Start",4,30); idle(30)
tap("Start",4,30)
for _=1,3 do tap("Down",4,6) end
tap("Start",4,30); idle(60)
for _=1,6 do tap("Down",4,4) end
tap("Start",4,30); idle(60)
for _=1,4 do tap("Up",4,6) end
tap("Start",4,30); idle(60)
tap("Start",4,30); idle(120)

-- Force sword level + full HP
W(0x0657, 0x07)  -- Items bit 0 = boomerang etc — sword separate
-- NES Z1 sword level at $066B-ish OR ObjMetastate. Try ObjState slot 0
-- ObjMetastate at $00AC slot 0. NES Z1 stores sword as InvSword separate.
-- Probably $066B unused. Z1 sword via Items+0 bit?
W(0x066F, 0xFF)  -- HeartValues max+cur full
W(0x0670, 0x00)
-- Inv items don't include sword; sword is "always present" or via flag.
-- Z1 stores in WhichObtainedThings $66B / $66C. Try $066B.
W(0x066B, 0x01)  -- maybe SwordLevel
idle(2)

local function dump_oam(label, f)
  f:write(string.format("\n--- %s ---\n", label))
  f:write("slot Y    Tile Attr X     pal hf vf\n")
  for i = 0, 63 do
    local y = memory.readbyte(i*4+0, "OAM")
    local t = memory.readbyte(i*4+1, "OAM")
    local a = memory.readbyte(i*4+2, "OAM")
    local x = memory.readbyte(i*4+3, "OAM")
    if y < 0xEF and t ~= 0xFF then
      -- Beam tile likely $20 sword vert or $24 sword horz
      local note = ""
      if t == 0x20 or t == 0x24 then note = " <-- SWORD/BEAM tile" end
      f:write(string.format("  %2d $%02X  $%02X  $%02X $%02X   %d  %d  %d%s\n",
        i, y, t, a, x, a%4, (a>>6)%2, (a>>7)%2, note))
    end
  end
end

local f = io.open("C:\\tmp\\nes_beam_4dir.txt", "w")

-- Direction UP
tap("Up",30,5); idle(5)
tap("A",1,0)
for fr = 1, 8 do
  dump_oam(string.format("UP fr%d link_y=$%02X link_x=$%02X", fr, R(0x0084), R(0x0070)), f)
  idle(1)
end
idle(60)

-- Direction DOWN
tap("Down",30,5); idle(5)
tap("A",1,0)
for fr = 1, 8 do
  dump_oam(string.format("DOWN fr%d", fr), f)
  idle(1)
end
idle(60)

-- Direction LEFT
tap("Left",30,5); idle(5)
tap("A",1,0)
for fr = 1, 8 do
  dump_oam(string.format("LEFT fr%d", fr), f)
  idle(1)
end
idle(60)

-- Direction RIGHT
tap("Right",30,5); idle(5)
tap("A",1,0)
for fr = 1, 8 do
  dump_oam(string.format("RIGHT fr%d", fr), f)
  idle(1)
end

f:close()
client.screenshot("C:\\tmp\\nes_beam_final.png")
client.exit()

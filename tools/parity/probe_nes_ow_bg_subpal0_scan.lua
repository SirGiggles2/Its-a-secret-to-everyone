-- Scan all 128 OW rooms, capture BG sub-pal 0..3 NES PALRAM bytes.
-- Outputs C array embeddable for per-room BG palette patches.
local function R(o) return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function PAL(o) return memory.read_u8(o, "PALRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, hold, settle)
  for _=1,hold do joypad.set({[b]=true}, 1); emu.frameadvance() end
  joypad.set({}, 1); for _=1,settle do emu.frameadvance() end
end

idle(360); press("Start", 4, 60)
press("Down",4,20); press("Down",4,20); press("Down",4,20)
press("Start",4,60); press("Start",4,60)
for _=1,5 do press("Down",4,8) end
for _=1,5 do press("Right",4,8) end
press("Start",4,60)
for _=1,5 do press("Up",4,12) end
press("Start",4,180); idle(180)

local f = io.open("C:/tmp/nes_ow_bg_palram.txt","w")
f:write("/* NES OW BG PALRAM ($3F00..$3F0F) captured per-room. */\n")
f:write("const unsigned char k_ow_bg_palram_per_room[128][16] = {\n")
for room = 0, 127 do
  W(0x0010, 0x00)
  W(0x00EB, room)
  W(0x0012, 0x06)
  idle(120)
  idle(60)
  f:write(string.format("    [0x%02X] = { ", room))
  for i = 0, 15 do
    f:write(string.format("0x%02X", PAL(i)))
    if i < 15 then f:write(", ") end
  end
  f:write(" },\n")
end
f:write("};\n")
f:close()
client.exit()

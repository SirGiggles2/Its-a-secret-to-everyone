-- Dump NES PT0 cloud tiles $70-$75 raw CHR bytes.
local function R(o) return memory.read_u8(o, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

idle(120); tap("Start"); idle(30); tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)
for fr=1,400 do joypad.set({Up=true},1); emu.frameadvance(); if R(0x00EB)==0x67 then break end end
joypad.set({},1); idle(102)

local f = io.open("C:/tmp/nes_cloud_tiles.txt", "w")
if not f then client.exit(); return end
f:write("PT0 cloud tiles $70-$75 (NES 2bpp):\n")
for tile_id=0x70,0x75 do
  f:write(string.format("tile $%02X: ", tile_id))
  for i=0,15 do
    f:write(string.format("%02X ", memory.read_u8(tile_id*0x10 + i, "CHR")))
  end
  f:write("\n")
end
f:close()
client.exit()

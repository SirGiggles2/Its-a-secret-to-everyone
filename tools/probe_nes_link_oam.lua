local root = [[C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF]]
local out = root .. [[\builds\reports\nes_link_oam.txt]]
memory.usememorydomain('System Bus')
local function press(buttons)
  joypad.set(buttons,1)
  emu.frameadvance()
  joypad.set({},1)
  emu.frameadvance()
end
for _=1,240 do emu.frameadvance() end
press({Start=true})
for _=1,180 do emu.frameadvance() end
press({Start=true})
for _=1,1500 do emu.frameadvance() end
memory.usememorydomain('OAM')
local f=assert(io.open(out,'w'))
for i=0,63 do
  local base=i*4
  local y=memory.read_u8(base)
  local tile=memory.read_u8(base+1)
  local attr=memory.read_u8(base+2)
  local x=memory.read_u8(base+3)
  if y < 0xEF then
    f:write(string.format('spr%02d y=%02X tile=%02X attr=%02X x=%02X\n', i,y,tile,attr,x))
  end
end
f:close()
client.exit()

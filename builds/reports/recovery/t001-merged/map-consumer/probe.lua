local root='C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/recovery/t001-merged/map-consumer/'
local function r(a) return memory.read_u8(0x8000+a,'68K RAM') end
local function pw(a,v) memory.write_u8(a,v,'68K RAM') end
local function tick(buttons) joypad.set(buttons or {},1);emu.frameadvance() end
local function arm() pw(0x73F8,0x52);pw(0x73F9,0x50);pw(0x73FA,1) end
local function sat(slot)
 local a=0xF400+slot*8
 return {y=memory.read_u16_be(a,'VRAM'),attr=memory.read_u16_be(a+4,'VRAM'),next=memory.read_u16_be(a+2,'VRAM')&0x7F}
end
local function warp(level,room)
 arm();pw(0x73FB,1);pw(0x73FC,level);pw(0x73FD,1);pw(0x73FE,room);pw(0x73FF,0x5A)
 for _=1,240 do
  tick()
  if memory.read_u8(0x73FF,'68K RAM')==0 and memory.read_u8(0x7205,'68K RAM')==room and memory.read_u8(0x7210,'68K RAM')==level then
   return
  end
 end
 error('room warp failed')
end
local function run()
 client.speedmode(400)
 for _=1,30 do tick() end
 local entered=false
 for frame=1,1500 do
  arm();tick(frame%30<4 and {A=true,B=true,C=true} or {})
  if memory.read_u8(0x7200,'68K RAM')==0x57 and memory.read_u8(0x7201,'68K RAM')==0x50 then entered=true;break end
 end
 assert(entered,'gameplay mirror missing')
 local f=assert(io.open(root..'trace.txt','w'))
 pw(0x8668,0)
 warp(1,0x46)
 for _=1,5 do tick() end
 local ma=r(0x668)
 client.screenshot(root..'map-awarded.png')
 f:write(string.format('L1 room46 map=%02X taken=%d\n',ma,memory.read_u8(0x726D,'68K RAM')));f:flush()
 assert(ma==1 and memory.read_u8(0x726D,'68K RAM')==1,'map room award did not reach inventory')
 pw(0x8667,0)
 for _=1,3 do tick() end
 local hidden=sat(13)
 warp(1,0x62)
 for _=1,5 do tick() end
 local ca=r(0x667)
 local visible=sat(13)
 client.screenshot(root..'compass-awarded.png')
 f:write(string.format('L1 room62 compass=%02X taken=%d marker y=%d->%d tile=%d\n',ca,memory.read_u8(0x726D,'68K RAM'),hidden.y,visible.y,visible.attr&0x7FF));f:flush()
 assert(ca==1 and memory.read_u8(0x726D,'68K RAM')==1,'compass room award did not reach inventory')
 assert(hidden.y==96 and visible.y~=96,'gameplay compass marker did not follow award')
 for _=1,3 do tick({Start=true}) end
 for _=1,90 do tick() end
 local icons={map=0,compass=0,target=0}
 local slot=0
 for _=1,80 do
  local s=sat(slot);local tile=s.attr&0x7FF
  if tile==1292 then icons.map=icons.map+1 end
  if tile==1290 then icons.compass=icons.compass+1 end
  if tile==1294 then icons.target=icons.target+1 end
  slot=s.next;if slot==0 then break end
 end
 f:write(string.format('pause icons map=%d compass=%d target=%d\n',icons.map,icons.compass,icons.target));f:flush()
 client.screenshot(root..'pause-owned.png')
 assert(icons.map==1 and icons.compass==2 and icons.target==1,'pause map/compass icons disagree with awarded inventory')
 f:write('PASS native room-entry map/compass awards reflected in gameplay HUD and pause inventory\n');f:close();client.exit()
end
local ok,e=pcall(run)
if not ok then local f=assert(io.open(root..'error.txt','w'));f:write(tostring(e));f:close();client.exit() end


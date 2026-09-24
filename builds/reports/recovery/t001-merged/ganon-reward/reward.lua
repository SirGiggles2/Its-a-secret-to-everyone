local OUT="C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/recovery/t001-merged/ganon-reward/"
local function main()
  local function r(a) return memory.read_u8(0x8000+a,"68K RAM") end
  local function w(a,v) memory.write_u8(0x8000+a,v,"68K RAM") end
  local function rc(a) return memory.read_u8(a,"68K RAM") end
  local function wc(a,v) memory.write_u8(a,v,"68K RAM") end
  local function tick() joypad.set({},1);emu.frameadvance() end
  local function arm() wc(0x73F8,0x52);wc(0x73F9,0x50);wc(0x73FA,1) end
  local f=assert(io.open(OUT.."reward.txt","w"))
  client.speedmode(400)
  for i=1,30 do tick() end
  local entered=false
  for i=1,1500 do
    arm();joypad.set(i%30<4 and {A=true,B=true,C=true} or {},1);emu.frameadvance()
    if rc(0x7200)==0x57 and rc(0x7201)==0x50 and rc(0x7203)>5 then entered=true;break end
  end
  assert(entered,"no gameplay mirror")
  arm();wc(0x73FB,1);wc(0x73FC,9);wc(0x73FD,1);wc(0x73FE,0x42);wc(0x73FF,0x5A)
  local ack=false
  for i=1,240 do tick();if rc(0x73FF)==0 and rc(0x7204)==1 and rc(0x7205)==0x42 then ack=true;break end end
  assert(ack,"no room entry")
  local combat=false
  for i=1,450 do tick();if r(0x0445)==2 then combat=true;break end end
  assert(combat and r(0x0350)==0x3E,"no Ganon combat state")
  local function swing(timer)
    w(0x0029,timer);w(0x0486,0x10)
    w(0x0657,1) -- wooden sword: 0x10 damage
    joypad.set({A=true},1);emu.frameadvance()
    joypad.set({},1)
    local swordFrames=0
    for i=1,12 do
      if r(0x00B9)==2 then
        swordFrames=swordFrames+1
        local sx,sy=r(0x007D),r(0x0091)
        -- Put Ganon's midpoint on the native published sword hitbox.
        w(0x0071,(sx-8)&0xFF);w(0x0085,(sy-10)&0xFF)
      end
      w(0x04F0,2) -- keep Link clear of incidental contact during this local test
      tick()
      f:write(string.format("swing timerStart=%02X f=%d state=%02X hp=%02X sword=%02X swordXY=%02X,%02X bossXY=%02X,%02X timer=%02X\n",timer,i,r(0x00AD),r(0x0486),r(0x00B9),r(0x007D),r(0x0091),r(0x0071),r(0x0085),r(0x0029)))
      if r(0x00AD)~=0 then break end
    end
    return swordFrames
  end
  local visibleFrames=swing(0x30)
  assert(visibleFrames>0 and r(0x00AD)==0 and r(0x0486)==0x10,"visible sword rejection failed")
  for i=1,60 do tick() end -- let the native swing and input lock finish
  f:write(string.format("between linkState=%02X sword=%02X bossPhase=%02X mode=%02X\n",r(0x00AC),r(0x00B9),r(0x0445),r(0x0012)))
  local invisibleFrames=swing(0)
  f:write(string.format("result visibleFrames=%d invisibleFrames=%d state=%02X hp=%02X\n",visibleFrames,invisibleFrames,r(0x00AD),r(0x0486)))
  assert(r(0x00B9)==2 and r(0x00AD)~=0 and r(0x0486)==0xF0,"sword-to-brown transition failed")
  for i=1,60 do tick() end
  w(0x0659,1);w(0x065A,1);w(0x066D,10)
  joypad.set({Z=true},1);emu.frameadvance();tick()
  local function fire(level)
    w(0x0659,level)
    joypad.set({B=true},1);emu.frameadvance()
    local seen=r(0x00BE)~=0
    for i=1,30 do
      if r(0x00BE)==0x10 then
        seen=true
        local ax,ay=r(0x0082),r(0x0096)
        w(0x0071,(ax-10)&0xFF);w(0x0085,(ay-10)&0xFF)
      end
      w(0x04F0,2)
      tick()
      f:write(string.format("arrow tier=%d f=%d phase=%02X state=%02X arrow=%02X arrowXY=%02X,%02X bossXY=%02X,%02X\n",level,i,r(0x042D),r(0x00AD),r(0x00BE),r(0x0082),r(0x0096),r(0x0071),r(0x0085)))
      if r(0x042D)~=0 then break end
    end
    assert(seen,"native arrow never fired")
  end
  fire(1)
  assert(r(0x042D)==0,"ordinary arrow incorrectly started death")
  for i=1,80 do tick() end
  assert(r(0x00AD)~=0,"brown state expired before silver arrow")
  fire(2)
  assert(r(0x042D)~=0,"silver arrow did not start death")
  for i=1,230 do
    if i<=100 then joypad.set({Right=true},1);emu.frameadvance() else tick() end
    if i==79 or i==159 or i==210 or i==230 then
      f:write(string.format("death f=%d phase=%02X roomItemLife=%02X killCount=%02X linkXY=%02X,%02X scene=%02X room=%02X itemMeta=%02X taken=%02X\n",i,r(0x042D),r(0x00BF),r(0x034F),r(0x0070),r(0x0084),rc(0x7204),rc(0x7205),rc(0x726C),rc(0x726D)))
      if i==210 then client.screenshot(OUT.."reward.png") end
    end
  end
  local satX=memory.read_u16_be(0xF400+7*8+6,"VRAM")-128
  local satY=memory.read_u16_be(0xF400+7*8,"VRAM")-128
  f:write(string.format("rewardPosition native=%02X,%02X sat=%02X,%02X\n",r(0x0083),r(0x0097),satX,satY))
  f:close()
  assert(satX==r(0x0083) and satY==r(0x0097),"reward sprite does not follow native slot 19")
  assert(r(0x042D)>=0xA0 and r(0x00BF)==0 and r(0x034F)==1,
    "death did not activate room item exactly once")
  assert(rc(0x726D)==0,"staged Link took reward before presentation check")
  local picked=false
  for i=1,170 do
    joypad.set({Left=true},1);emu.frameadvance()
    if rc(0x726D)~=0 then
      picked=true
      f=assert(io.open(OUT.."reward-pickup.txt","w"))
      f:write(string.format("pickup f=%d linkXY=%02X,%02X item=%02X taken=%02X fanfare=%02X timer=%02X linkState=%02X mode=%02X\n",i,r(0x0070),r(0x0084),rc(0x726C),rc(0x726D),r(0x0509),r(0x0028),r(0x00AC),r(0x0012)))
      client.screenshot(OUT.."reward-pickup.png")
      break
    end
  end
  assert(picked,"Power Triforce was not taken on approach")
  for i=1,240 do tick() end
  f:write(string.format("settled fanfare=%02X timer=%02X linkState=%02X mode=%02X room=%02X taken=%02X\n",r(0x0509),r(0x0028),r(0x00AC),r(0x0012),rc(0x7205),rc(0x726D)))
  f:close()
  assert(r(0x0509)==0 and r(0x0028)==0 and rc(0x726D)==1,
    "Power Triforce fanfare did not settle")
  local depart=assert(io.open(OUT.."departure.txt","w"))
  for i=1,220 do
    joypad.set({Up=true},1);emu.frameadvance()
    if i%30==0 or rc(0x7205)~=0x42 then
      depart:write(string.format("f=%d room=%02X mode=%02X linkXY=%02X,%02X taken=%02X bossFlag=%02X secret=%02X opened=%02X shutter=%02X doors=%02X,%02X,%02X,%02X has=%02X\n",
        i,rc(0x7205),r(0x0012),r(0x0070),r(0x0084),rc(0x726D),r(0x0672),r(0x04CD),rc(0x722C),r(0x04CE),rc(0x7228),rc(0x7229),rc(0x722A),rc(0x722B),rc(0x722E)))
    end
    if rc(0x7205)~=0x42 then client.screenshot(OUT.."departure.png");break end
  end
  depart:close()
  if rc(0x7205)==0x32 then
    for i=1,90 do tick() end
    client.screenshot(OUT.."zelda-room.png")
    local z=assert(io.open(OUT.."zelda-room.txt","w"))
    z:write(string.format("room=%02X mode=%02X type1=%02X type2=%02X linkXY=%02X,%02X\n",
      rc(0x7205),r(0x0012),r(0x0350),r(0x0351),r(0x0070),r(0x0084)))
    local reached=false
    for i=1,180 do
      joypad.set({Up=true},1);emu.frameadvance()
      if i%20==0 or r(0x00AD)~=0 or r(0x0012)==0x13 then
        z:write(string.format("approach f=%d link=%02X,%02X zeldaState=%02X timer=%02X mode=%02X\n",
          i,r(0x0070),r(0x0084),r(0x00AD),r(0x0029),r(0x0012)))
      end
      if r(0x00AD)~=0 then reached=true;client.screenshot(OUT.."zelda-rescue.png");break end
    end
    assert(reached,"Zelda rescue interaction did not trigger")
    for i=1,260 do
      tick()
      if i%20==0 or r(0x0012)==0x13 then
        z:write(string.format("wait f=%d mode=%02X sub=%02X timer=%02X state=%02X type=%02X\n",
          i,r(0x0012),r(0x0013),r(0x0029),r(0x00AD),r(0x0350)))
      end
      if r(0x0012)==0x13 then break end
    end
    z:write(string.format("ending mode=%02X sub=%02X link=%02X,%02X zeldaState=%02X timer=%02X\n",
      r(0x0012),r(0x0013),r(0x0070),r(0x0084),r(0x00AD),r(0x0029)))
    client.screenshot(OUT.."ending-handoff.png")
    assert(r(0x0012)==0x13,"Zelda did not hand off to ending mode")
    z:close()
  end
  client.exit()
end
local ok,err=pcall(main)
if not ok then
  local f=io.open(OUT.."reward-error.txt","w")
  if f then f:write(tostring(err));f:close() end
  client.exit()
end

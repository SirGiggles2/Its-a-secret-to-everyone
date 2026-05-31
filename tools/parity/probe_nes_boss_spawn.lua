-- probe_nes_boss_spawn.lua — Phase 1 authoritative NES boss-spawn capture.
--
-- WHY: the old boss probes poke GameMode $12=$06->$05, which lands in the
-- room but SKIPS Z1 InitMode4/InitMode_EnterRoom (@PlaceObjects) — verified
-- live to spawn NOTHING. This probe reuses the PROVEN spawn path from
-- RoomRom/probe_nes_uw_dump.lua: force_room via GameMode $03 / GameSub $02,
-- which progresses through InitMode4 (objects spawn) to mode 5 (play).
--
-- Per level (NES loads the correct per-level LevelBlockAttrs): dump the live
-- LBA C ($697E) + D ($69FE) for all 128 rooms, compute monster_list_id =
-- (C&0x3F)|(D&0x80?0x40:0) per room, find the room(s) whose list_id == this
-- level's boss ObjType, DRIVE that room, confirm slot 1 holds the boss
-- ObjType (spawn-success), and capture slots + CIRAM NT + attr + PALRAM +
-- the LBA bytes. Resolves (RULE ZERO, live) the authoritative boss room id
-- per level AND the level->block routing — superseding static guesses.
--
-- Env (set by tools/parity/run_boss_spawn_capture.py):
--   CODEX_BOSS_LEVEL  int 1..9
--   CODEX_BOSS_QUEST  int 1..2
--   CODEX_BOSS_MAP    "orig" | "redux" (metadata)
--   CODEX_BOSS_OUT    output JSON path
--
-- NES RAM via "System Bus" (direct addr). CIRAM/PALRAM via dedicated domains.

----------------------------------------------------------------------
-- RAM map (NES Z1)
----------------------------------------------------------------------
local IS_UPDATING_MODE = 0x0011
local CUR_LEVEL        = 0x0010
local GAME_MODE        = 0x0012
local GAME_SUB         = 0x0013
local CUR_SAVE_SLOT    = 0x0016
local TARGET_MODE      = 0x005B
local DOORWAY_DIR      = 0x0053
local TRIGGERED_DOOR_CMD = 0x0054
local TRIGGERED_DOOR_DIR = 0x0055
local ROOM_TRANS       = 0x004C
local ROOM_ID          = 0x00EB
local NEXT_ROOM_ID     = 0x00EC
local CUR_OPENED_DOORS = 0x00EE
local CUR_PPU_MASK     = 0x00FE
local OPEN_DOORWAY_MASK = 0x033F
local FADE_CYCLE       = 0x051C
local PREV_OPENED_DOORS = 0x0521
local SPAWN_CYCLE      = 0x0524
local CUR_EDGE_SPAWN   = 0x0525
local CAVE_SOURCE_ROOM = 0x0526
local CELLAR_SRC_ROOM  = 0x0527
local NAME_PROGRESS    = 0x0421
local TARGET_MIRROR    = 0x0602
local LEVEL_INFO_START_ROOM = 0x6BAD
local LEVEL_INFO_BOSS_ROOM  = 0x6BBC
local LBA_C            = 0x697E   -- LevelBlockAttrsC[room]
local LBA_D            = 0x69FE   -- LevelBlockAttrsD[room]
local QUEST_NUMBERS    = 0x062D
local SAVE_ACTIVE0, SAVE_ACTIVE1, SAVE_ACTIVE2 = 0x0633, 0x0634, 0x0635
-- enemy slot arrays (NES Z1)
local OBJ_TYPE  = 0x034F
local OBJ_X     = 0x0070
local OBJ_Y     = 0x0084
local OBJ_DIR   = 0x008C
local OBJ_STATE = 0x00AC
local OBJ_HP    = 0x0485   -- MON_HP
local OBJ_ATTR  = 0x04BF
local CIRAM_BASE, ATTR_BASE = 0x0000, 0x03C0

local MAX_BOOT_FRAMES, MAX_WARP_FRAMES, MAX_SETTLE_FRAMES, STABLE_WINDOW = 20000, 1200, 1500, 12

-- Per-level boss ObjType(s) (Z_07 InitObject_JumpTable). L9 = Patra + Ganon.
local BOSS_OT = {
  [1]={0x3D}, [2]={0x31}, [3]={0x3C}, [4]={0x43}, [5]={0x38},
  [6]={0x33}, [7]={0x3D}, [8]={0x45}, [9]={0x47,0x3E},
}
local function is_boss_ot(t)
  return (t>=0x31 and t<=0x34) or (t>=0x38 and t<=0x3E) or (t>=0x41 and t<=0x48)
end

----------------------------------------------------------------------
-- Memory helpers
----------------------------------------------------------------------
local function u8(addr) memory.usememorydomain("System Bus"); return memory.read_u8(addr & 0xFFFF) end
local function w8(addr,v) memory.usememorydomain("System Bus"); memory.write_u8(addr & 0xFFFF, v & 0xFF) end
local function read_domain_u8(domain, addr)
  local ok,v = pcall(function() memory.usememorydomain(domain); return memory.read_u8(addr) end)
  if ok then return v end; return nil
end
local function ciram_u8(addr)
  for _,d in ipairs({"CIRAM (nametables)","CIRAM","Nametable RAM"}) do
    local v=read_domain_u8(d,addr); if v~=nil then return v end
  end
  return 0
end
local PAL_DOMAIN=nil
do
  local ok,doms=pcall(memory.getmemorydomainlist)
  if ok and doms then for _,d in ipairs(doms) do
    local name=(type(d)=="table") and (d.Name or tostring(d)) or tostring(d)
    local lo=name:lower()
    if lo:find("pal") then local so,sz=pcall(memory.getmemorydomainsize,name)
      if so and sz and sz<=64 then PAL_DOMAIN=name; break end end
  end end
end
local function palram_u8(addr) if PAL_DOMAIN then local v=read_domain_u8(PAL_DOMAIN,addr); if v~=nil then return v end end return 0 end

----------------------------------------------------------------------
-- Input scheduler + boot/warp (verbatim from probe_nes_uw_dump.lua — proven)
----------------------------------------------------------------------
local function safe_set(pad) local ok=pcall(function() joypad.set(pad or {},1) end); if not ok then joypad.set(pad or {}) end end
local input_state={button=nil,hold_left=0,release_left=0,release_after=0}
local function schedule(b,h,r) if input_state.hold_left>0 or input_state.release_left>0 then return end
  input_state.button=b; input_state.hold_left=h or 1; input_state.release_left=0; input_state.release_after=r or 8 end
local function build_pad() local pad={}
  if input_state.hold_left>0 and input_state.button then pad[input_state.button]=true; pad["P1 "..input_state.button]=true
    input_state.hold_left=input_state.hold_left-1; if input_state.hold_left==0 then input_state.release_left=input_state.release_after end
  elseif input_state.release_left>0 then input_state.release_left=input_state.release_left-1 end
  return pad end

local function boot_to_overworld()
  local BOOT,SEL,ENT,TYPE,FIN,WAIT,START=1,2,3,4,5,6,7
  local flow=BOOT; local last_name=u8(NAME_PROGRESS); local name_events=0
  for frame=1,MAX_BOOT_FRAMES do
    local mode=u8(GAME_MODE); local slot=u8(CUR_SAVE_SLOT); local name=u8(NAME_PROGRESS)
    local a0=u8(SAVE_ACTIVE0); local a1=u8(SAVE_ACTIVE1); local a2=u8(SAVE_ACTIVE2)
    if flow==BOOT then if mode==0x01 then flow=SEL else schedule("Start",2,3) end
    elseif flow==SEL then if slot==0x03 then flow=ENT else schedule("Down",1,10) end
    elseif flow==ENT then if mode==0x0E then flow=TYPE; last_name=name elseif mode==0x01 then schedule("Start",2,14) end
    elseif flow==TYPE then if name~=last_name then name_events=name_events+1; last_name=name end
      if name_events>=5 then flow=FIN else schedule("A",1,10) end
    elseif flow==FIN then if mode~=0x0E then flow=WAIT elseif slot~=0x03 then schedule("Select",1,10) else schedule("Start",2,14) end
    elseif flow==WAIT then if mode==0x01 then flow=START end
    elseif flow==START then if mode~=0x01 then flow=WAIT else
      local ts=0x00; if a0==0 and a1~=0 then ts=0x01 elseif a0==0 and a1==0 and a2~=0 then ts=0x02 end
      if slot~=ts then schedule(ts>slot and "Down" or "Up",1,10) else schedule("Start",2,14) end end
    end
    safe_set(build_pad()); emu.frameadvance()
    if u8(CUR_LEVEL)==0 and u8(GAME_MODE)==0x05 and u8(GAME_SUB)==0 and u8(ROOM_ID)==0x77 and u8(ROOM_TRANS)==0 then
      for _=1,30 do safe_set({}); emu.frameadvance() end; return true end
  end
  return false
end
local function force_quest(q) if q==2 then local slot=u8(CUR_SAVE_SLOT); w8(QUEST_NUMBERS+slot,1) end end
local function warp_to_level(level)
  w8(CUR_LEVEL,level); w8(TARGET_MODE,0x02); w8(TARGET_MIRROR,0x02); w8(GAME_MODE,0x10); w8(GAME_SUB,0x00); safe_set({})
  for f=1,MAX_WARP_FRAMES do emu.frameadvance()
    if u8(CUR_LEVEL)==level and u8(GAME_MODE)==0x05 and u8(GAME_SUB)==0 then
      local stable=0
      for _=1,60 do emu.frameadvance()
        if u8(CUR_LEVEL)==level and u8(GAME_MODE)==0x05 and u8(GAME_SUB)==0 then stable=stable+1; if stable>=30 then return true end else stable=0 end
      end
    end
  end
  return false
end
local function reset_transition_ram()
  for _,a in ipairs({ROOM_TRANS,DOORWAY_DIR,TRIGGERED_DOOR_CMD,TRIGGERED_DOOR_DIR,CUR_OPENED_DOORS,
                     OPEN_DOORWAY_MASK,PREV_OPENED_DOORS,SPAWN_CYCLE,CUR_EDGE_SPAWN,CAVE_SOURCE_ROOM,
                     CELLAR_SRC_ROOM,FADE_CYCLE}) do w8(a,0) end
end
local function force_room(target)
  reset_transition_ram()
  w8(LEVEL_INFO_START_ROOM,target); w8(ROOM_ID,target); w8(NEXT_ROOM_ID,target)
  w8(GAME_MODE,0x03); w8(GAME_SUB,0x02); w8(IS_UPDATING_MODE,0x00)  -- spawn path (-> InitMode4 -> mode5)
end

----------------------------------------------------------------------
-- Dumps
----------------------------------------------------------------------
local function dump_nt() local rows={} for r=0,29 do local row={} local b=CIRAM_BASE+r*32
  for c=0,31 do row[#row+1]=ciram_u8(b+c) end rows[#rows+1]=row end return rows end
local function dump_attr() local v={} for i=0,63 do v[#v+1]=ciram_u8(ATTR_BASE+i) end return v end
local function dump_palram() local v={} for i=0,31 do v[#v+1]=palram_u8(i) end return v end
local function dump_slots() local s={} for i=1,19 do
  local t=u8(OBJ_TYPE+i)
  if t~=0 and t~=0xFF then s[#s+1]={slot=i,t=t,x=u8(OBJ_X+i),y=u8(OBJ_Y+i),dir=u8(OBJ_DIR+i),st=u8(OBJ_STATE+i),hp=u8(OBJ_HP+i),attr=u8(OBJ_ATTR+i)} end
end return s end

-- Settle to mode 5 play (objects spawned en route via InitMode4), stable NT.
local function settle(target)
  local stable,prev=0,nil
  for f=1,MAX_SETTLE_FRAMES do emu.frameadvance()
    local mode,sub,upd,mask,rid=u8(GAME_MODE),u8(GAME_SUB),u8(IS_UPDATING_MODE),u8(CUR_PPU_MASK),u8(ROOM_ID)
    if mode==0x05 and sub==0x00 and upd==0x01 and (mask%0x20)>=0x18 and rid==target then
      local nt=dump_nt(); local at=dump_attr(); local h=5381
      for r=1,#nt do for c=1,#nt[r] do h=(h*33+nt[r][c])%4294967296 end end
      for i=1,#at do h=(h*33+at[i])%4294967296 end
      if prev~=nil and h==prev then stable=stable+1; if stable>=STABLE_WINDOW then return true,nt,at,dump_palram(),f end
      else stable=0; prev=h end
    else stable=0; prev=nil end
  end
  return false,nil,nil,nil,MAX_SETTLE_FRAMES
end

----------------------------------------------------------------------
-- JSON
----------------------------------------------------------------------
local function j1(t) local s={} for i=1,#t do s[#s+1]=tostring(t[i]) end return "["..table.concat(s,",").."]" end
local function j2(rows) local s={} for i=1,#rows do s[#s+1]=j1(rows[i]) end return "["..table.concat(s,",").."]" end
local function esc(s) s=tostring(s or ""); s=s:gsub("\\","\\\\"):gsub('"','\\"'); return '"'..s..'"' end

----------------------------------------------------------------------
-- Main: per level, dump live LBA, compute boss room(s), drive + capture
----------------------------------------------------------------------
local LEVEL=tonumber(os.getenv("CODEX_BOSS_LEVEL") or "1") or 1
local QUEST=tonumber(os.getenv("CODEX_BOSS_QUEST") or "1") or 1
local MAP=os.getenv("CODEX_BOSS_MAP") or "orig"
local OUT=os.getenv("CODEX_BOSS_OUT") or "tools/parity/out/nes_boss_spawn.json"

local system_id=emu.getsystemid() or "?"
local boot_ok,warp_ok=false,false
local lba={}            -- per-room {c,d,list_id}
local captures={}       -- per boss-room capture
local fatal=nil

if system_id~="NES" then fatal="wrong_system_"..system_id
else
  boot_ok=boot_to_overworld()
  if not boot_ok then fatal="boot_failed" else
    force_quest(QUEST)
    warp_ok=warp_to_level(LEVEL)
    if not warp_ok then fatal="warp_failed" else
      -- Dump the live per-level LBA the NES installed for this level.
      for rm=0,127 do
        local c=u8(LBA_C+rm); local d=u8(LBA_D+rm)
        local lid=(c & 0x3F) | ((d & 0x80)~=0 and 0x40 or 0)
        lba[rm]={c=c,d=d,lid=lid}
      end
      -- Candidate boss rooms = rooms whose list_id == this level's boss ObjType.
      local cands={}
      for _,ot in ipairs(BOSS_OT[LEVEL] or {}) do
        for rm=0,127 do if lba[rm].lid==ot then cands[#cands+1]={rm=rm,ot=ot} end end
      end
      -- Always also probe LevelInfo_BossRoomId as a cross-check candidate.
      local bri=u8(LEVEL_INFO_BOSS_ROOM)
      cands[#cands+1]={rm=bri,ot=0,note="LevelInfo_BossRoomId"}
      for _,cd in ipairs(cands) do
        force_room(cd.rm)
        local ok,nt,at,pal,frames=settle(cd.rm)
        local slots=ok and dump_slots() or {}
        local spawned=false
        for _,s in ipairs(slots) do if is_boss_ot(s.t) then spawned=true end end
        captures[#captures+1]={rm=cd.rm,want_ot=cd.ot,note=cd.note,settle_ok=ok,frames=frames,
          spawned_boss=spawned, slots=slots, nt=nt, attr=at, palram=pal,
          lba_c=lba[cd.rm].c, lba_d=lba[cd.rm].d, lba_lid=lba[cd.rm].lid,
          actual_level=u8(CUR_LEVEL), boss_room_id=bri}
      end
    end
  end
end

local f=assert(io.open(OUT,"w"))
f:write("{\n")
f:write('  "system_id": ',esc(system_id),',\n')
f:write('  "level": ',tostring(LEVEL),', "quest": ',tostring(QUEST),', "map": ',esc(MAP),',\n')
f:write('  "boot_ok": ',tostring(boot_ok),', "warp_ok": ',tostring(warp_ok),',\n')
if fatal then f:write('  "fatal": ',esc(fatal),',\n') end
-- full LBA C/D arrays for S3 diff
local cc,dd={},{} for rm=0,127 do cc[#cc+1]=lba[rm] and lba[rm].c or 0; dd[#dd+1]=lba[rm] and lba[rm].d or 0 end
f:write('  "lba_c": ',j1(cc),',\n')
f:write('  "lba_d": ',j1(dd),',\n')
f:write('  "captures": [\n')
for i,cap in ipairs(captures) do
  f:write("    {")
  f:write('"room": ',tostring(cap.rm),', "want_ot": ',tostring(cap.want_ot),', ')
  if cap.note then f:write('"note": ',esc(cap.note),', ') end
  f:write('"settle_ok": ',tostring(cap.settle_ok),', "frames": ',tostring(cap.frames),', ')
  f:write('"spawned_boss": ',tostring(cap.spawned_boss),', ')
  f:write('"actual_level": ',tostring(cap.actual_level),', "boss_room_id": ',tostring(cap.boss_room_id),', ')
  f:write('"lba_c": ',tostring(cap.lba_c),', "lba_d": ',tostring(cap.lba_d),', "lba_lid": ',tostring(cap.lba_lid),', ')
  f:write('"slots": [')
  for si,s in ipairs(cap.slots) do
    f:write('{"slot":',tostring(s.slot),',"t":',tostring(s.t),',"x":',tostring(s.x),',"y":',tostring(s.y),
            ',"dir":',tostring(s.dir),',"st":',tostring(s.st),',"hp":',tostring(s.hp),',"attr":',tostring(s.attr),'}')
    if si<#cap.slots then f:write(',') end
  end
  f:write(']')
  if cap.settle_ok then
    f:write(', "nt": ',j2(cap.nt),', "attr": ',j1(cap.attr),', "palram": ',j1(cap.palram))
  end
  f:write("}")
  if i<#captures then f:write(",") end
  f:write("\n")
end
f:write("  ]\n}\n")
f:close()
client.exit()

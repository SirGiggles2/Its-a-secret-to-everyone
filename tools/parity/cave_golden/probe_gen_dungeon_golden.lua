-- probe_gen_dungeon_golden.lua — Genesis (Debug.md) per-dungeon-room golden.
--
-- Mirror of probe_gen_cave_golden.lua but for UW (dungeon) scenes. Boots,
-- teleports to the dungeon's OW entrance room, forces the entrance warp tile
-- (the warp coordinator routes selector<$40 -> dungeon UW, Phase A), polls
-- for scene==SCENE_UW, settles, captures full VRAM+CRAM+SAT+68K RAM at the
-- same frame phases so cave_byte_diff.py can diff vs the NES golden.
--
-- Globals (run_dungeon_sweep prelude): LEVEL, QUEST, OW_ROOM, UW_ROOM, OUT_DIR.

LEVEL   = LEVEL   or 1
QUEST   = QUEST   or 1
OW_ROOM = OW_ROOM or 0x37
UW_ROOM = UW_ROOM or 0x73
OUT_DIR = OUT_DIR or "C:\\tmp\\cave_golden"

local OUT = string.format("%s\\gen_L%dQ%d_R%02X", OUT_DIR, LEVEL, QUEST, UW_ROOM)
os.execute('if not exist "' .. OUT .. '" mkdir "' .. OUT .. '"')

local FRAMES = {0, 8, 16, 24, 60, 120}
local OFF_SCENE       = 0x0281
local OFF_IN_GAMEPLAY = 0x0274
local OFF_FRAME_CTR   = 0x0015
local OFF_LINK_X      = 0x1564
local OFF_LINK_Y      = 0x1566
local SCENE_UW        = 1

local function r8(o)   return memory.read_u8(o, "68K RAM") end
local function w8(o,v) memory.write_u8(o, v, "68K RAM") end
local function nes_r8(a) return r8(0x8000 + a) end
local function read_scene() return r8(OFF_SCENE) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b) joypad.set(b) end
local function press_for(b, n)
    press(b); emu.frameadvance(); press({}); idle(math.max(0, n - 1))
end
local function write_link_xy(x, y)
    w8(OFF_LINK_X,(x>>8)&0xFF); w8(OFF_LINK_X+1,x&0xFF)
    w8(OFF_LINK_Y,(y>>8)&0xFF); w8(OFF_LINK_Y+1,y&0xFF)
end
local function force_warp_tile(col,row,tile)
    w8(0x8000 + 0x6530 + col*0x16 + row, tile)
    w8(0x0285 + col*22 + row, tile)
end
local function force_mode_walk() for i=0x027A,0x027D do w8(i,0) end end

local function boot_to_gameplay()
    for frame=1,1500 do
        if frame>=30 and frame<=600 and (frame%30)==0 then
            press({["P1 A"]=true,["P1 B"]=true,["P1 C"]=true})
        end
        emu.frameadvance()
        if r8(OFF_IN_GAMEPLAY)==1 then idle(60); return true end
    end
    return false
end

local function read_room() return r8(0x0041) end
local function navigate_to_room(target)
    write_link_xy(0x78,0x70); press_for({["P1 X"]=true},8)
    for _=1,64 do
        local cur=read_room(); if cur==target then break end
        local cc,cr=cur&0x0F,(cur>>4)&0x07
        local tc,tr=target&0x0F,(target>>4)&0x07
        if cc>tc then press_for({["P1 Left"]=true},16)
        elseif cc<tc then press_for({["P1 Right"]=true},16)
        elseif cr>tr then press_for({["P1 Up"]=true},16)
        elseif cr<tr then press_for({["P1 Down"]=true},16)
        else break end
    end
    press_for({["P1 X"]=true},8); idle(30)
end

-- Enter the dungeon: same forced $24 entrance the cave probe uses; the OW
-- warp coordinator routes this OW room (selector<$40) to the UW dungeon
-- instead of a cave. Poll for scene==UW.
local function LOG(s) local f=io.open("C:/tmp/dun_dbg.txt","a"); if f then f:write(s.."\n"); f:close() end; print(s) end
-- Enter via the probe-warp ctrl interface (main.c:2936-2957): arm 'R'/'P' at
-- $FF73F8, write dest scene/level/quest/room + trigger $5A; the gameplay tick
-- fires roomrom_main_apply_warp_outcome() -- the SAME load path as the live
-- in-game warp coordinator (palette, CHR, enemy spawn, NES RAM mirror sync).
-- This sidesteps detect_warp_ow's Rule3/4/5 entrance-alignment (which needs
-- real Link movement onto the room's entrance tile) while producing the exact
-- UW room a real traversal would. Live OW-walk entry verified separately.
local function enter_dungeon(room)
    w8(0x73F8, 0x52); w8(0x73F9, 0x50)   -- ARM0='R' ARM1='P'
    w8(0x73FB, 0x01)                     -- ctrl[3] dest_scene = SCENE_UW
    w8(0x73FC, LEVEL)                    -- ctrl[4] dest_level
    w8(0x73FD, QUEST)                    -- ctrl[5] dest_quest
    w8(0x73FE, room)                     -- ctrl[6] dest_room_id
    w8(0x73FF, 0x5A)                     -- ctrl[7] trigger
    for k=1,180 do
        emu.frameadvance()
        if read_scene()==SCENE_UW then
            LOG(string.format("UW room=$%02X reached f=%d rm41=$%02X rmEB=$%02X",
                room, k, nes_r8(0x0041), nes_r8(0x00EB)))
            idle(8); return true
        end
    end
    LOG(string.format("enter_dungeon FAIL room=$%02X scene=%d", room, read_scene()))
    return false
end

local function vram_block(s,sz) local b={} for i=0,sz-1 do b[#b+1]=string.char(memory.read_u8(s+i,"VRAM")) end return table.concat(b) end
local function dom_block(d,sz) local b={} for i=0,sz-1 do b[#b+1]=string.char(memory.read_u8(i,d)) end return table.concat(b) end
local function capture(out, room, fp)
    local path=string.format("%s\\f%03d.bin",out,fp)
    local f=io.open(path,"wb")
    f:write("GCGD"); f:write(string.char(fp&0xFF)); f:write(string.char(room&0xFF))
    f:write(string.char(read_scene())); f:write(string.char(nes_r8(0x0041)))  -- RoomId
    f:write(dom_block("CRAM",128)); f:write(vram_block(0x0000,0x10000))
    f:write(dom_block("68K RAM",0x10000)); f:write(dom_block("VSRAM",80))
    f:close()
end

-- ROOMS (optional global): list of room ids to sweep in one launch (each
-- warped via the probe-warp ctrl). Defaults to {UW_ROOM}.
local rooms = ROOMS or { UW_ROOM }
print(string.format("Gen dungeon golden: L%dQ%d rooms=%d",LEVEL,QUEST,#rooms))
if not boot_to_gameplay() then print("BOOT FAIL"); client.exit(); return end
for _, room in ipairs(rooms) do
    local out = string.format("%s\\gen_L%dQ%d_R%02X", OUT_DIR, LEVEL, QUEST, room)
    os.execute('if not exist "' .. out .. '" mkdir "' .. out .. '"')
    if not enter_dungeon(room) then
        capture(out, room, 0)
        LOG(string.format("DUNGEON ENTRY FAIL room=$%02X (scene!=UW) — partial", room))
    else
        idle(90)
        w8(0x8000 + 0x00AC, 0x40)  -- halt Link for static frame
        idle(8)
        w8(OFF_FRAME_CTR, 0x00)
        local prev=0
        for _,t in ipairs(FRAMES) do idle(t-prev); prev=t; capture(out, room, t) end
        client.screenshot(out .. "\\shot.png")
        LOG(string.format("OK gen L%d room=$%02X scene=%d", LEVEL, room, read_scene()))
    end
end
print("done: Gen L"..LEVEL.."Q"..QUEST)
client.exit()

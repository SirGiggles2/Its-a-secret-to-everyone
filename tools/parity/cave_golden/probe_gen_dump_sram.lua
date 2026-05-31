-- probe_gen_dump_sram.lua — dump Gen runtime NES-mirror SRAM after a UW warp,
-- to byte-diff vs the live NES SRAM dumps (nes_levelsram/*.bin). Proves the
-- regenerated rooms_dungeons[] install reproduces NES SRAM for LevelBlock A-F
-- + LevelInfo. Warps to a room in LEVELS list, dumps $687E..$6C7D (1024B) =
-- 68K RAM offset $8000+$687E.. per level.
local LEVELS = LEVELS or {1, 7}
local function r8(o) return memory.read_u8(o, "68K RAM") end
local function w8(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function LOG(s) local f=io.open("C:/tmp/gen_sram_dbg.txt","a"); if f then f:write(s.."\n"); f:close() end; print(s) end
local OFF_SCENE=0x0281; local OFF_IN_GAMEPLAY=0x0274; local SCENE_UW=1
local OUT="C:\\tmp\\gen_levelsram"; os.execute('if not exist "'..OUT..'" mkdir "'..OUT..'"')
-- start room per level (manifest start_room_id).
local START={[1]=0x73,[2]=0x7D,[3]=0x7C,[4]=0x71,[5]=0x76,[6]=0x79,[7]=0x7F,[8]=0x79,[9]=0x74}

local function boot()
    for f=1,1500 do
        if f>=30 and f<=600 and (f%30)==0 then joypad.set({["P1 A"]=true,["P1 B"]=true,["P1 C"]=true}) end
        emu.frameadvance()
        if r8(OFF_IN_GAMEPLAY)==1 then idle(60); return true end
    end
    return false
end
local function warp(level,room)
    w8(0x73F8,0x52); w8(0x73F9,0x50); w8(0x73FB,0x01); w8(0x73FC,level)
    w8(0x73FD,0x01); w8(0x73FE,room); w8(0x73FF,0x5A)
    for k=1,180 do emu.frameadvance(); if r8(OFF_SCENE)==SCENE_UW then idle(90); return true end end
    return false
end
local function dump(level)
    local p=string.format("%s\\gen_sram_L%dQ1.bin",OUT,level)
    local f=io.open(p,"wb")
    for a=0x687E,0x6C7D do f:write(string.char(r8(0x8000+a))) end
    f:close()
end

LOG("=== Gen SRAM dump ===")
if not boot() then LOG("BOOT FAIL"); client.exit(); return end
for _,lvl in ipairs(LEVELS) do
    if warp(lvl, START[lvl]) then LOG(string.format("L%d dumped (scene=%d)",lvl,r8(OFF_SCENE))) else LOG("L"..lvl.." WARP FAIL") end
    dump(lvl)
end
LOG("done"); client.exit()

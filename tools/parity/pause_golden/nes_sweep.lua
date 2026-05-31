-- nes_sweep.lua — SINGLE-launch NES golden sweep (no relaunch -> no EmuHawk
-- single-instance arg-forward popups). Boots once, then for each level in
-- SWEEP_LEVELS: warp (TargetMode), open subscreen, settle, capture the NCGD
-- bundle to nes_uw_L<n>/. Cells + capture format copied verbatim from the
-- reviewed pause_capture_nes.lua.
OUT_DIR = OUT_DIR or "C:/tmp/pause_golden"
SWEEP_LEVELS = SWEEP_LEVELS or {1,2,3,4,5,6,7,8,9}

local CELL_FRAME_COUNTER=0x0015; local CELL_CUR_LEVEL=0x0010; local CELL_GAME_MODE=0x0012
local CELL_ROOM_ID=0x00EB; local CELL_SCROLL_PROG=0x005E; local CELL_MENU_STATE=0x00E1
local CELL_CUR_VSCROLL=0x00FC; local CELL_PPUCTRL=0x00FF; local CELL_SELECTED_SLOT=0x0656
local function R(o) return memory.read_u8(o,"RAM") end
local function W(o,v) memory.write_u8(o,v,"RAM") end
local function SBr(a) memory.usememorydomain("System Bus"); return memory.read_u8(a&0xFFFF) end
local function SBw(a,v) memory.usememorydomain("System Bus"); memory.write_u8(a&0xFFFF,v&0xFF) end
local function OAM(o) return memory.read_u8(o,"OAM") end
local function PAL(o) return memory.read_u8(o,"PALRAM") end
local function CHR(o) return memory.read_u8(o,"VRAM") end
local function NT(o)  return memory.read_u8(o,"CIRAM (nametables)") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local OUT
local function LOG(s) local fh=io.open(OUT.."/log.txt","a"); if fh then fh:write(s.."\n"); fh:close() end; print(s) end
local function tap(btn,hold,gap) hold=hold or 4; gap=gap or 6
    for _=1,hold do joypad.set({[btn]=true},1); emu.frameadvance() end
    for _=1,gap do joypad.set({},1); emu.frameadvance() end end

local function boot_to_gameplay()
    for f=1,1800 do local gm=R(CELL_GAME_MODE)
        if gm>=0x05 and gm<=0x07 then idle(20); return true end
        if (f%16)==0 then joypad.set({Start=true},1) else joypad.set({},1) end
        emu.frameadvance() end
    return false end
local function poke_full_inventory()
    W(0x0657,0xFF) W(0x0658,0x10) W(0x0659,0x02) W(0x065A,0x01) W(0x065C,0x01) W(0x065F,0x01)
    W(0x065B,0x02) W(0x065D,0x01) W(0x065E,0x02) W(0x0660,0x01) W(0x0661,0x01) W(0x0662,0x02)
    W(0x0663,0x01) W(0x0664,0x01) W(0x0665,0x01) W(0x0666,0x02) W(0x0667,0xFF) W(0x0668,0xFF)
    W(0x0669,0xFF) W(0x066A,0xFF) W(0x066C,0x01) W(0x066D,0xFF) W(0x066E,0x63) W(0x066F,0xFF)
    W(0x0670,0xFF) W(0x0671,0xFF) W(0x0674,0x01) W(0x0675,0x01) W(0x0676,0x02) W(0x067C,0x10)
    W(0x0656,0x00) idle(2) end
local function warp(L)
    SBw(0x0010,L); SBw(0x005B,0x02); SBw(0x0602,0x02); SBw(0x0012,0x10)
    for _=1,300 do emu.frameadvance()
        if SBr(0x0012)==0x05 and SBr(0x0013)==0 and SBr(0x0010)==L then break end end
    idle(40)
    return SBr(0x0010)==L and SBr(0x0012)==0x05 end
local function capture(name)
    local f=io.open(OUT.."/"..name,"wb")
    f:write("NCGD"); f:write(string.char(R(CELL_FRAME_COUNTER)&0xFF))
    f:write(string.char(R(CELL_MENU_STATE)&0xFF)); f:write(string.char(R(CELL_GAME_MODE)))
    f:write(string.char(R(CELL_CUR_LEVEL)))
    for i=0,255 do f:write(string.char(OAM(i))) end
    for i=0,31 do f:write(string.char(PAL(i))) end
    for i=0,8191 do f:write(string.char(CHR(i))) end
    f:write(string.char(R(CELL_PPUCTRL)))
    for i=0,2047 do f:write(string.char(NT(i))) end
    f:close() end
local function log_ladder(csv,maxf,donep)
    local f=io.open(OUT.."/"..csv,"w"); f:write("frame,CurVScroll,MenuState,ScrollProgress,FrameCounter\n")
    for k=0,maxf-1 do f:write(string.format("%d,%d,%d,%d,%d\n",k,R(CELL_CUR_VSCROLL),R(CELL_MENU_STATE),R(CELL_SCROLL_PROG),R(CELL_FRAME_COUNTER)))
        if donep() then break end; emu.frameadvance() end
    f:close() end
local function adv_bit3(want) for _=1,40 do if ((R(CELL_FRAME_COUNTER)>>3)&1)==want then return end; emu.frameadvance() end end
local function close_menu() if R(CELL_MENU_STATE)~=0 then tap("Start",4,30); for _=1,20 do if R(CELL_MENU_STATE)==0 then break end idle(8) end end end

local function HB(s) local fh=io.open(OUT_DIR.."/sweep.txt","a"); if fh then fh:write(s.."\n"); fh:close() end; print(s) end
HB("=== nes_sweep start ===")
if not boot_to_gameplay() then HB("BOOT FAIL"); client.exit(); return end
HB("booted gm=$"..string.format("%02X",R(CELL_GAME_MODE)))
poke_full_inventory()
for _,L in ipairs(SWEEP_LEVELS) do
    OUT = string.format("%s/nes_uw_L%d", OUT_DIR, L)
    os.execute('if not exist "'..OUT:gsub("/","\\")..'" mkdir "'..OUT:gsub("/","\\")..'"')
    HB(string.format("L%d begin",L))
    local ok,err = pcall(function()
    close_menu()
    if not warp(L) then HB(string.format("L%d WARP FAIL gm=$%02X lvl=$%02X",L,SBr(0x0012),SBr(0x0010)))
    else
        close_menu()
        tap("Start",4,2)
        log_ladder("scroll_open.csv",90,function() return R(CELL_MENU_STATE)==7 end)
        local stab=0
        for _=1,300 do if R(CELL_MENU_STATE)==7 and R(CELL_CUR_VSCROLL)==0x41 then stab=stab+1 else stab=0 end
            if stab>=10 then break end; idle(1) end
        W(CELL_SELECTED_SLOT,0x00); idle(6)
        adv_bit3(0); capture("active.bin")
        adv_bit3(0); capture("blink0.bin")
        adv_bit3(1); capture("blink1.bin")
        tap("Start",4,2)
        log_ladder("scroll_close.csv",90,function() return R(CELL_MENU_STATE)==0 end)
        LOG(string.format("L%d captured room=$%02X rot$6BAB=$%02X",L,SBr(0x00EB),SBr(0x6BAB)))
    end
    end)  -- pcall
    if not ok then HB(string.format("L%d ERROR: %s",L,tostring(err))) end
end
HB("=== sweep done ==="); print("sweep done"); client.exit()

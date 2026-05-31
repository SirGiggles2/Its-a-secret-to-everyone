-- gen_sweep.lua — SINGLE-launch Genesis golden sweep (no relaunch -> no
-- EmuHawk single-instance popups). Boots once, then for each level in
-- SWEEP_LEVELS: poke target-level cell $07F6, MODE->UW, open subscreen,
-- capture GCGD to gen_uw_L<n>/, close, MODE->OW. Waterbox genplus: work RAM
-- = "M68K BUS" @ $FF8000+off (NO "68K RAM"); BG/CRAM use VRAM/CRAM domains.
OUT_DIR = OUT_DIR or "C:/tmp/pause_golden"
SWEEP_LEVELS = SWEEP_LEVELS or {1,2,3,4,5,6,7,8,9}
-- Work-RAM domain varies by core: genplus = "68K RAM" (64KB, nes_ram@$8000);
-- Waterbox genplus = "M68K BUS" (16MB, nes_ram@$FF8000). Detect at runtime
-- (after the core is up) — never assume (RULE V3).
for _=1,8 do emu.frameadvance() end
local WD, WB = nil, nil
for _,d in ipairs(memory.getmemorydomainlist()) do
    if d=="68K RAM" then WD="68K RAM"; WB=0x8000 end
end
if not WD then WD="M68K BUS"; WB=0xFF8000 end
local function nr(a) return memory.read_u8(WB+a,WD) end       -- nes_ram mirror (+$8000)
local function nw(a,v) memory.write_u8(WB+a,v,WD) end
local function lr(a) return memory.read_u8((WB-0x8000)+a,WD) end -- low C-global (in_gameplay)
local function vsram0() return (memory.read_u8(0,"VSRAM")<<8)|memory.read_u8(1,"VSRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local OUT
local function LOG(s) local fh=io.open(OUT_DIR.."/gen_sweep.txt","a"); if fh then fh:write(s.."\n"); fh:close() end; print(s) end
local function press_for(b,n) joypad.set(b); emu.frameadvance(); joypad.set({}); idle(math.max(0,n-1)) end
local OFF_IN_GAMEPLAY=0x0274

local function boot()
    for f=1,1500 do
        if f>=30 and f<=700 and (f%30)==0 then joypad.set({["P1 A"]=true,["P1 B"]=true,["P1 C"]=true}) end
        emu.frameadvance()
        if lr(OFF_IN_GAMEPLAY)==1 then joypad.set({}); idle(60); return true end
    end
    return false end
local function scene() return nr(0x07E8) end        -- s_scene sentinel: 0=OW 1=UW
local function mode_tap() press_for({["P1 Mode"]=true},6); idle(60) end

local function vram_block(start,size) local b={} for i=0,size-1 do b[#b+1]=string.char(memory.read_u8(start+i,"VRAM")) end return table.concat(b) end
local function capture(name)
    local f=io.open(OUT.."/"..name,"wb")
    f:write("GCGD"); f:write(string.char(0)); f:write(string.char(0))
    f:write(string.char(scene())); f:write(string.char(nr(0x0350)))
    local c={} for i=0,127 do c[#c+1]=string.char(memory.read_u8(i,"CRAM")) end; f:write(table.concat(c))
    f:write(vram_block(0x0000,0x10000))
    local wbase = WB - 0x8000   -- full work-RAM base (0 for "68K RAM", $FF0000 for "M68K BUS")
    local r={} for i=0,0xFFFF do r[#r+1]=string.char(memory.read_u8(wbase+i,WD)) end; f:write(table.concat(r))
    local v={} for i=0,79 do v[#v+1]=string.char(memory.read_u8(i,"VSRAM")) end; f:write(table.concat(v))
    f:close() end
local function log_ladder(csv,maxf)
    local f=io.open(OUT.."/"..csv,"w"); f:write("frame,VSRAM0,VSRAM1,scene,in_gameplay\n")
    local stable,last=0,-1
    for k=0,maxf-1 do local v=vsram0()
        f:write(string.format("%d,%d,0,%d,%d\n",k,v,scene(),lr(OFF_IN_GAMEPLAY)))
        if v==last then stable=stable+1 else stable=0 end; last=v
        if stable>=20 then break end; emu.frameadvance() end
    f:close() end

local function go(target) for _=1,5 do if scene()==target then return true end mode_tap() end return scene()==target end
LOG("=== gen_sweep start dom="..tostring(WD).." ===")
if not boot() then LOG("BOOT FAIL"); client.exit(); return end
LOG("booted in_gameplay="..lr(OFF_IN_GAMEPLAY).." scene="..scene())
for _,L in ipairs(SWEEP_LEVELS) do
    OUT=string.format("%s/gen_uw_L%d",OUT_DIR,L)
    os.execute('if not exist "'..OUT:gsub("/","\\")..'" mkdir "'..OUT:gsub("/","\\")..'"')
    if not go(0) then LOG(string.format("L%d FAIL reach OW (scene=%d)",L,scene())) end
    nw(0x07FA, L)                          -- target level cell $07FA (free)
    if not go(1) then LOG(string.format("L%d FAIL reach UW (scene=%d)",L,scene())) end
    LOG(string.format("L%d after MODE: scene=%d CurLevel$10=%d echo$07FB=%d",L,scene(),nr(0x0010),nr(0x07FB)))
    press_for({["P1 Start"]=true},4)
    log_ladder("scroll_open.csv",90)
    idle(10)
    capture("active.bin"); capture("blink0.bin"); idle(8); capture("blink1.bin")
    press_for({["P1 Start"]=true},4)
    log_ladder("scroll_close.csv",90)
    LOG(string.format("L%d captured (scene=%d CurLevel=%d)",L,scene(),nr(0x0010)))
end
print("gen sweep done"); client.exit()

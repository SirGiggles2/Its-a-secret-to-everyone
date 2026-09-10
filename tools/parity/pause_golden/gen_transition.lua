-- gen_transition.lua — boot, MODE->UW L1, open the subscreen, screenshot the
-- mid-scroll frames to see the transition the user sees. Waterbox genplus.
OUT_DIR = OUT_DIR or "C:/tmp/pause_golden"
local OUT = OUT_DIR .. "/trans_gen"
os.execute('if not exist "'..OUT:gsub("/","\\")..'" mkdir "'..OUT:gsub("/","\\")..'"')
for _=1,8 do emu.frameadvance() end
local WD,WB=nil,nil
for _,d in ipairs(memory.getmemorydomainlist()) do if d=="68K RAM" then WD="68K RAM"; WB=0x8000 end end
if not WD then WD="M68K BUS"; WB=0xFF8000 end
local function nr(a) return memory.read_u8(WB+a,WD) end
local function lr(a) return memory.read_u8((WB-0x8000)+a,WD) end
local function vsram0() return (memory.read_u8(0,"VSRAM")<<8)|memory.read_u8(1,"VSRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function LOG(s) local fh=io.open(OUT.."/log.txt","a"); if fh then fh:write(s.."\n"); fh:close() end; print(s) end
-- boot to gameplay
for f=1,1500 do if f>=30 and f<=700 and (f%30)==0 then joypad.set({["P1 A"]=true,["P1 B"]=true,["P1 C"]=true}) end; emu.frameadvance(); if lr(0x0274)==1 then idle(60); break end end
-- MODE -> UW
joypad.set({["P1 Mode"]=true}); emu.frameadvance(); joypad.set({}); idle(90)
LOG(string.format("pre-open scene=%d CurLevel=%d vsram0=%d", nr(0x07E8), nr(0x0010), vsram0()))
-- open subscreen
joypad.set({["P1 Start"]=true}); emu.frameadvance(); joypad.set({})
for s=0,17 do
    client.screenshot(string.format("%s/f%02d.png", OUT, s*2))
    LOG(string.format("f%02d: vsram0=%d", s*2, vsram0()))
    idle(2)
end
client.screenshot(OUT.."/settled.png")
client.exit()

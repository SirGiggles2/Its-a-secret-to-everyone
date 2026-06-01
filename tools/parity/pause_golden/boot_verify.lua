-- boot_verify.lua — boot via BOOT_CHORD ("abc"=A+B+C quest1, "xyz"=X+Y+Z
-- quest2), then read the installed LevelBlockAttrsA[$73] to confirm which
-- quest block loaded (Q1=$A2, Q2=$06). M68K BUS, nes_ram @ $FF8000.
OUT_DIR = OUT_DIR or "C:/tmp/pause_golden"
BOOT_CHORD = BOOT_CHORD or "abc"
for _=1,8 do emu.frameadvance() end
local WD,WB = nil,nil
for _,d in ipairs(memory.getmemorydomainlist()) do if d=="68K RAM" then WD="68K RAM"; WB=0x8000 end end
if not WD then WD="M68K BUS"; WB=0xFF8000 end
local function nr(a) return memory.read_u8(WB+a,WD) end
local function lr(a) return memory.read_u8((WB-0x8000)+a,WD) end
local function LOG(s) local fh=io.open(OUT_DIR.."/boot_verify.txt","a"); if fh then fh:write(s.."\n"); fh:close() end; print(s) end
local chord = (BOOT_CHORD=="xyz")
    and {["P1 X"]=true,["P1 Y"]=true,["P1 Z"]=true}
    or  {["P1 A"]=true,["P1 B"]=true,["P1 C"]=true}
local booted=false
for f=1,1500 do
    if f>=30 and f<=900 and (f%30)==0 then joypad.set(chord) else joypad.set({}) end
    emu.frameadvance()
    if lr(0x0274)==1 then booted=true; for _=1,60 do emu.frameadvance() end; break end
end
-- MODE -> UW so the per-quest LevelBlock install runs.
joypad.set({["P1 Mode"]=true}); emu.frameadvance(); joypad.set({})
for _=1,90 do emu.frameadvance() end
LOG(string.format("CHORD=%s booted=%s scene$07E8=%d CurLevel$10=%d AttrsA[$73]=$%02X (Q1=$A2 Q2=$06)",
    BOOT_CHORD, tostring(booted), nr(0x07E8), nr(0x0010), nr(0x687E+0x73)))
client.exit()

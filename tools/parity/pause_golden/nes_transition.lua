-- nes_transition.lua — warp UW L1, open the subscreen, screenshot several
-- MID-SCROLL frames so the transition can be compared to Genesis visually.
OUT_DIR = OUT_DIR or "C:/tmp/pause_golden"
local OUT = OUT_DIR .. "/trans_nes"
os.execute('if not exist "'..OUT:gsub("/","\\")..'" mkdir "'..OUT:gsub("/","\\")..'"')
local function R(o) return memory.read_u8(o,"RAM") end
local function W(o,v) memory.write_u8(o,v,"RAM") end
local function SBr(a) memory.usememorydomain("System Bus"); return memory.read_u8(a&0xFFFF) end
local function SBw(a,v) memory.usememorydomain("System Bus"); memory.write_u8(a&0xFFFF,v&0xFF) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function LOG(s) local fh=io.open(OUT.."/log.txt","a"); if fh then fh:write(s.."\n"); fh:close() end; print(s) end
-- boot to GAMEPLAY (gm 0x05-0x07), like pause_capture_nes.
for f=1,1800 do local gm=R(0x0012)
    if gm>=0x05 and gm<=0x07 then idle(20); break end
    if (f%16)==0 then joypad.set({Start=true}) else joypad.set({}) end
    emu.frameadvance() end
-- warp L1, wait gm=$05 AND submode=0 (room fully loaded).
SBw(0x0010,1); SBw(0x005B,2); SBw(0x0602,2); SBw(0x0012,0x10)
for _=1,300 do emu.frameadvance(); if SBr(0x0012)==0x05 and SBr(0x0013)==0 and SBr(0x0010)==1 then break end end
idle(60)
-- full inventory so subscreen is populated
W(0x0657,0xFF) W(0x067C,0x10) idle(4)
-- ensure menu closed, then open: hold Start 4 frames (proven tap), release.
LOG(string.format("pre-open MenuState=$%02X VScroll=$%02X", R(0x00E1), R(0x00FC)))
for _=1,4 do joypad.set({Start=true}); emu.frameadvance() end
for _=1,3 do joypad.set({}); emu.frameadvance() end
-- screenshot every 2 frames through the scroll-in.
for s=0,15 do
    client.screenshot(string.format("%s/f%02d.png", OUT, s*2))
    LOG(string.format("f%02d: VScroll$FC=$%02X MenuState$E1=$%02X", s*2, R(0x00FC), R(0x00E1)))
    idle(2)
end
client.screenshot(OUT.."/settled.png")
client.exit()

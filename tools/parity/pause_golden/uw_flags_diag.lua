-- uw_flags_diag.lua — READ-ONLY Gen ground truth, CLEAN boot. Waterbox
-- genplus: nes_ram is M68K BUS @ $FF8000+offset (triangulated: AttrsA sig
-- @ $FFE87E = nes_ram[$687E]; $AA sentinel @ $FF87E0 = nes_ram[$07E0]).
-- Boot to gameplay (in_gameplay=$0274), MODE->UW, settle, dump 32 KB
-- nes_ram ($FF8000..$FFFFFF) for offline NES-vs-Gen door-attr diff.
OUT_DIR = OUT_DIR or "C:/tmp/pause_golden"
local OUT = OUT_DIR
local function LOG(s)
    local fh = io.open(OUT .. "/diag.txt", "a")
    if fh then fh:write(s .. "\n"); fh:close() end
    print(s)
end
local function idle(n) for _=1,n do emu.frameadvance() end end
local NBASE = 0xFF8000
local function nr(a) return memory.read_u8(NBASE + a, "M68K BUS") end

idle(8)
-- Boot to gameplay (in_gameplay $0274 == 1), A+B+C chord through title/story.
local booted = false
for frame = 1, 1500 do
    if frame >= 30 and frame <= 700 and (frame % 30) == 0 then
        joypad.set({["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
    end
    emu.frameadvance()
    if nr(0x0274) == 1 then booted = true; idle(60); break end
end
LOG("booted(in_gameplay)=" .. tostring(booted))
-- Enter UW (MODE), settle.
joypad.set({["P1 Mode"]=true}); emu.frameadvance(); joypad.set({}); idle(120)

LOG(string.format("CurLevel($0010)=%d  scene($07E8)=$%02X  AAsentinel($07E0)=$%02X room($07E1)=$%02X",
    nr(0x0010), nr(0x07E8), nr(0x07E0), nr(0x07E1)))
LOG(string.format("AttrsA[$73]=$%02X AttrsB[$73]=$%02X  rot$6BAB=$%02X tri$6BAE=$%02X start$6BAD=$%02X",
    nr(0x687E+0x73), nr(0x68FE+0x73), nr(0x6BAB), nr(0x6BAE), nr(0x6BAD)))
local ptr = nr(0x6BAF) | (nr(0x6BB0) << 8)
LOG(string.format("WorldFlagsPtr=$%04X  room$73 flags via ptr=$%02X", ptr, nr((ptr + 0x73) & 0xFFFF)))
local vis = {}
for r = 0, 0x7F do if (nr((ptr + r) & 0xFFFF) & 0x20) ~= 0 then vis[#vis+1] = string.format("$%02X", r) end end
LOG("visited via ptr: " .. (#vis == 0 and "NONE" or table.concat(vis, " ")))

local f = io.open(OUT .. "/workram.bin", "wb"); local t = {}
for a = 0, 0x7FFF do t[#t+1] = string.char(nr(a)); if #t == 4096 then f:write(table.concat(t)); t = {} end end
if #t > 0 then f:write(table.concat(t)) end
f:close()
LOG("dumped nes_ram $0000-$7FFF -> workram.bin ; === done ===")
client.exit()

-- probe_gen_boss_scan_l56.lua — find L5 Digdogger ($38) + L6 Gohma ($33)
-- boss rooms by warp-scanning the list-type candidate rooms and letting the
-- engine resolve each room's ObjList (the boss spawns into slot 1 when the
-- room is its boss room). Block-0 (L1-6) rooms with monster_list_id >= $62
-- are the candidates (Gohma/Digdogger use lists, not direct type ids).
-- Lightweight: warp + read slot-1 ObjType only, no full dumps.
--
-- Same control-block contract as probe_gen_boss_direct.lua. M68K BUS core.

local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/gen_boss_scan_l56.txt"

local function dom(n) for _,d in ipairs(memory.getmemorydomainlist()) do if d==n then return true end end return false end
local RAM,BASE = "68K RAM",0
if dom("68K RAM") then RAM,BASE="68K RAM",0
elseif dom("M68K RAM") then RAM,BASE="M68K RAM",0
elseif dom("M68K BUS") then RAM,BASE="M68K BUS",0xFF0000 end
local function R(o) return memory.read_u8(BASE+o,RAM) end
local function W(o,v) memory.write_u8(BASE+o,v,RAM) end
local function NES(a) return R(0x8000+a) end
local CTRL=0x73F8; local MIR=0x7200

-- candidates: block-0 list-type rooms (from LBA scan)
local cand = {0x09,0x0A,0x19,0x1B,0x1D,0x27,0x28,0x29,0x2C,0x2D,0x30,0x32,
              0x38,0x3A,0x3B,0x3C,0x3F,0x49,0x4C,0x5A,0x5D}

-- boot
for _=1,120 do emu.frameadvance() end
for _=1,8 do joypad.set({["P1 A"]=true,["P1 B"]=true,["P1 C"]=true}); emu.frameadvance() end
joypad.set({})
for _=1,600 do emu.frameadvance(); if R(0x7000)==0xA4 and R(0x7001)==0x4A then break end end
for _=1,60 do emu.frameadvance() end
W(CTRL+0,0); W(CTRL+6,0); W(CTRL+7,0); W(CTRL+0,0x52); W(CTRL+1,0x50)

local function warp(level,room)
  for a=1,3 do
    W(CTRL+2,0); W(CTRL+3,1); W(CTRL+4,level); W(CTRL+5,0); W(CTRL+6,room); W(CTRL+7,0x5A)
    for _=1,90 do emu.frameadvance(); if R(CTRL+7)==0 then break end end
    for _=1,30 do emu.frameadvance() end
    if R(MIR+4)==1 and R(MIR+5)==room then return true end
  end
  return false
end

local f = assert(io.open(OUT,"w"))
f:write("ram="..RAM.."\n")
for _,lvl in ipairs({5,6}) do
  f:write(string.format("=== level %d (looking for %s) ===\n", lvl, lvl==5 and "$38 Digdogger" or "$33 Gohma"))
  for _,rm in ipairs(cand) do
    local ok = warp(lvl, rm)
    -- read slots 1..6 ObjType
    local types={}
    for s=1,6 do types[#types+1]=string.format("$%02X",NES(0x034F+s)) end
    f:write(string.format("  L%d r$%02X warp=%s slots1-6: %s\n", lvl, rm, tostring(ok), table.concat(types," ")))
    f:flush()
  end
end
f:close()
print("wrote "..OUT)
client.exit()

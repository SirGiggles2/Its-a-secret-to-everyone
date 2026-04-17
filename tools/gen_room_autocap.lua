-- gen_room_autocap.lua — headless capture of CURRENT Gen room.
-- Auto-loads the interactive capture's savestate, runs 30 settle frames,
-- dumps gen_room_XX.json, exits.
local OUT_DIR = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms"
local STATE_FILE = OUT_DIR .. "\\_gen_state.State"

local BUS = 0xFF0000
local ROOM_ID = BUS + 0xEB
local PLAYMAP_BASE = BUS + 0x6530
local NT_CACHE_BASE = BUS + 0x0840
local PLANE_A_VRAM = 0xC000
local PLANE_A_PITCH = 128
local PLANE_A_TOP_ROW = 8
local ROOM_ROWS = 22
local ROOM_COLS = 32

local function u8(addr) memory.usememorydomain("M68K BUS"); return memory.read_u8(addr) end
local function vram_u16(addr)
    local ok, v = pcall(function() memory.usememorydomain("VRAM"); return memory.read_u16_be(addr) end)
    return ok and v or 0
end
local function cram_u16(i)
    local ok, v = pcall(function() memory.usememorydomain("CRAM"); return memory.read_u16_be(i*2) end)
    return ok and v or 0
end

pcall(function() savestate.load(STATE_FILE) end)
for _=1,30 do emu.frameadvance() end

-- Force LayOutRoom to re-run for the current room so P38/other
-- transpile patches produce a fresh playmap instead of using the
-- stale bytes frozen in the savestate.
local function w8(a,v) memory.usememorydomain("M68K BUS"); memory.write_u8(a, v & 0xFF) end
local cur = u8(ROOM_ID)
w8(0x00FF00EA, (cur - 1) & 0xFF)   -- WhirlwindPrevRoomId = cur-1
w8(0x00FF0522, 1)                  -- WhirlwindTeleportingState
w8(0x00FF00E7, 1)                  -- WarpDir door-bit = Right
w8(0x00FF0098, 1)                  -- ObjDir = Right
w8(0x00FF0011, 1)                  -- IsUpdatingMode = Init table
w8(0x00FF0012, 7)                  -- GameMode = InitMode7
w8(0x00FF0013, 0)                  -- SubMode = 0
-- Wait for mode 7 cycle to complete and return to 5/0.
for _=1,240 do
    emu.frameadvance()
    if u8(ROOM_ID) == cur and u8(0x00FF0012) == 5 and u8(0x00FF0013) == 0 then break end
end
-- Settle.
for _=1,15 do emu.frameadvance() end

local function dump_playmap_rows()
    local rows={}
    for row=0,ROOM_ROWS-1 do
        local v={}; for col=0,ROOM_COLS-1 do v[#v+1]=u8(PLAYMAP_BASE+row+col*ROOM_ROWS) end
        rows[#rows+1]=v
    end
    return rows
end
local function dump_nt_cache_rows()
    local rows={}
    for row=0,ROOM_ROWS-1 do
        local v={}; local nt=PLANE_A_TOP_ROW+row; local base=NT_CACHE_BASE+nt*32
        for col=0,ROOM_COLS-1 do v[#v+1]=u8(base+col) end
        rows[#rows+1]=v
    end
    return rows
end
local function dump_palette_rows()
    local rows={}
    for row=0,ROOM_ROWS-1 do
        local v={}; local nt=PLANE_A_TOP_ROW+row; local rb=PLANE_A_VRAM+nt*PLANE_A_PITCH
        for col=0,ROOM_COLS-1 do local w=vram_u16(rb+col*2); v[#v+1]=(w>>13)&3 end
        rows[#rows+1]=v
    end
    memory.usememorydomain("M68K BUS")
    return rows
end
local function dump_cram_bg()
    local v={}; for i=0,15 do v[#v+1]=cram_u16(i) end
    memory.usememorydomain("M68K BUS"); return v
end
local function j1(t) local s={}; for i=1,#t do s[#s+1]=tostring(t[i]) end; return "["..table.concat(s,",").."]" end
local function j2(r) local s={}; for i=1,#r do s[#s+1]=j1(r[i]) end; return "["..table.concat(s,",").."]" end

local rid = u8(ROOM_ID)
local path = string.format("%s\\gen_room_%02X.json", OUT_DIR, rid)
local fh = assert(io.open(path, "w"))
fh:write("{\n")
fh:write('  "system": "gen",\n')
fh:write('  "room_id": ',tostring(rid),',\n')
fh:write('  "playmap_rows": ',j2(dump_playmap_rows()),',\n')
fh:write('  "nt_cache_rows": ',j2(dump_nt_cache_rows()),',\n')
fh:write('  "palette_rows": ',j2(dump_palette_rows()),',\n')
fh:write('  "cram_bg": ',j1(dump_cram_bg()),'\n')
fh:write("}\n")
fh:close()
client.exit()

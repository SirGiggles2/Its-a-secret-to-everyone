-- nes_warp_to.lua — headless: load NES state, whirlwind-warp to target
-- room (from _next_room.txt or _next_dir.txt+source), capture, exit.

local OUT_DIR    = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms"
local STATE_FILE = OUT_DIR .. "\\_nes_state.State"
local TARGET_FILE = OUT_DIR .. "\\_nes_target_room.txt"

local ROOM_ID    = 0x00EB
local GAME_MODE  = 0x0012
local GAME_SUB   = 0x0013
local ROOM_TRANS = 0x004C
local CIRAM_BASE = 0x0100
local ATTR_BASE  = 0x03C0
local ROOM_ROWS  = 22
local ROOM_COLS  = 32
local PLAY_AREA_NT_TOP = 8

local function u8(a) memory.usememorydomain("System Bus"); return memory.read_u8(a) end
local function w8(a, v) memory.usememorydomain("System Bus"); memory.write_u8(a, v & 0xFF) end
local function ciram_u8(a)
    for _, d in ipairs({"CIRAM (nametables)", "CIRAM", "Nametable RAM"}) do
        local ok, v = pcall(function() memory.usememorydomain(d); return memory.read_u8(a) end)
        if ok then return v end
    end
    return 0
end

local PAL_DOMAIN, PAL_BASE = nil, 0
do
    local ok_list, domains = pcall(memory.getmemorydomainlist)
    if ok_list and domains then
        for _, d in ipairs(domains) do
            local name = (type(d) == "table") and (d.Name or tostring(d)) or tostring(d)
            if name:lower():find("palette") then
                local sz_ok, sz = pcall(memory.getmemorydomainsize, name)
                if sz_ok and sz and sz <= 64 then PAL_DOMAIN=name; PAL_BASE=0; break end
            end
        end
    end
end

local function dump_visible()
    local r={}; for row=0,ROOM_ROWS-1 do local v={}; local b=CIRAM_BASE+row*ROOM_COLS; for col=0,ROOM_COLS-1 do v[#v+1]=ciram_u8(b+col) end r[#r+1]=v end; return r
end
local function dump_palette_rows()
    local r={}
    for row=0,ROOM_ROWS-1 do
        local v={}
        for col=0,ROOM_COLS-1 do
            local nt=PLAY_AREA_NT_TOP+row
            local ac, ar = col>>2, nt>>2
            local byte = ciram_u8(ATTR_BASE + ar*8 + ac)
            local qx, qy = (col>>1)&1, (nt>>1)&1
            v[#v+1] = (byte >> ((qy*2+qx)*2)) & 3
        end
        r[#r+1] = v
    end
    return r
end
local function dump_palette_ram()
    local v={}; if not PAL_DOMAIN then for i=1,16 do v[i]=0 end; return v end
    memory.usememorydomain(PAL_DOMAIN)
    for i=0,15 do
        local ok, x = pcall(function() return memory.read_u8(PAL_BASE+i) end)
        v[#v+1] = ok and x or 0
    end
    return v
end
local function j1(t) local s={}; for i=1,#t do s[#s+1]=tostring(t[i]) end; return "["..table.concat(s,",").."]" end
local function j2(r) local s={}; for i=1,#r do s[#s+1]=j1(r[i]) end; return "["..table.concat(s,",").."]" end

local function read_target()
    local f = io.open(TARGET_FILE, "r"); if not f then return nil end
    local s = f:read("*l") or ""; f:close()
    s = s:gsub("%s+", "")
    return tonumber(s, 16)
end

pcall(function() savestate.load(STATE_FILE) end)
for _=1,30 do emu.frameadvance() end

local target = read_target()
if not target then
    gui.text(10,10,"no _nes_target_room.txt; exiting.")
    for _=1,30 do emu.frameadvance() end
    client.exit(); return
end

local source = u8(ROOM_ID)
local row_diff = ((target >> 4) - (source >> 4))
local col_diff = ((target & 0xF) - (source & 0xF))
-- Direction inferred from adjacency (target is adjacent).
local dir_bit = 0; local obj_dir = 0
if col_diff > 0 then dir_bit = 0x01; obj_dir = 0x01      -- Right
elseif col_diff < 0 then dir_bit = 0x02; obj_dir = 0x02  -- Left
elseif row_diff > 0 then dir_bit = 0x04; obj_dir = 0x04  -- Down
elseif row_diff < 0 then dir_bit = 0x08; obj_dir = 0x08  -- Up
end

-- Whirlwind-style: $00EA = source, $0522 = 1, $00E7 = direction-door-bit,
-- $0098 = ObjDir, mode=7 sub=0 → Sub0 sets RoomId=source, Sub1 computes
-- NextRoomId = source + offset = target, runs LayOutRoom for target,
-- scroll/transition runs, plane refreshes.
w8(0x00EA, source)
w8(0x0522, 1)
w8(0x00E7, dir_bit)
w8(0x0098, obj_dir)
w8(0x0011, 1)    -- IsUpdatingMode = Init
w8(0x0012, 7)
w8(0x0013, 0)

for _=1,600 do
    emu.frameadvance()
    if u8(GAME_MODE) == 5 and u8(GAME_SUB) == 0 and u8(ROOM_TRANS) == 0 then break end
end

local rid = u8(ROOM_ID)
local path = string.format("%s\\nes_room_%02X.json", OUT_DIR, rid)
local fh = assert(io.open(path, "w"))
fh:write("{\n")
fh:write('  "system": "nes",\n')
fh:write('  "room_id": ',tostring(rid),',\n')
fh:write('  "source": ',tostring(source),',\n')
fh:write('  "target": ',tostring(target),',\n')
fh:write('  "visible_rows": ',j2(dump_visible()),',\n')
fh:write('  "palette_rows": ',j2(dump_palette_rows()),',\n')
fh:write('  "palette_ram": ',j1(dump_palette_ram()),'\n')
fh:write("}\n")
fh:close()
pcall(function() savestate.save(STATE_FILE) end)
client.exit()

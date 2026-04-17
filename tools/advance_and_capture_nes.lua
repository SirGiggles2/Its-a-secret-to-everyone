-- advance_and_capture_nes.lua — NES walk-one-step + capture + save state.
-- Mirrors advance_and_capture_gen.lua; applies inline turbo+no-clip
-- each frame while walking so collision doesn't stall us.

local OUT_DIR    = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms"
local ROLLING_STATE = OUT_DIR .. "\\_nes_state.State"
local DIR_FILE   = OUT_DIR .. "\\_next_dir.txt"
local LOAD_ROOM_FILE = OUT_DIR .. "\\_nes_load_room.txt"
local function per_room_state(rid)
    return string.format("%s\\_nes_state_%02X.State", OUT_DIR, rid)
end

local ROOM_ID       = 0x00EB
local OBJ_X         = 0x0070
local OBJ_Y         = 0x0084
local BUTTONS_HELD  = 0x00FA
local CUR_LEVEL     = 0x0010
local GAME_MODE     = 0x0012
local GAME_SUB      = 0x0013
local ROOM_TRANS    = 0x004C
local CIRAM_BASE    = 0x0100
local ATTR_BASE     = 0x03C0
local ROOM_ROWS     = 22
local ROOM_COLS     = 32
local PLAY_AREA_NT_TOP = 8
local BOOST         = 6
local X_MIN, X_MAX  = 0x0A, 0xE6
local Y_MIN, Y_MAX  = 0x40, 0xD0

local function u8(a) memory.usememorydomain("System Bus"); return memory.read_u8(a) end
local function w8(a, v) memory.usememorydomain("System Bus"); memory.write_u8(a, v & 0xFF) end
local function ciram_u8(a)
    for _, d in ipairs({"CIRAM (nametables)", "CIRAM", "Nametable RAM"}) do
        local ok, v = pcall(function() memory.usememorydomain(d); return memory.read_u8(a) end)
        if ok then return v end
    end
    return 0
end

-- Palette domain probe (size-gated to avoid 4KB-domain warnings).
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

local function read_dir()
    local f = io.open(DIR_FILE, "r"); if not f then return nil end
    local line = f:read("*l") or ""; f:close()
    line = line:gsub("%s+", "")
    if line == "Up" or line == "Down" or line == "Left" or line == "Right" then return line end
    return nil
end

-- Clear game block flags so turbo + no-clip works.
local function clear_block_flags()
    w8(0x000E, 0); w8(0x0053, 0); w8(0x0394, 0)
end

-- Apply turbo boost in held direction each frame.
local function apply_turbo()
    local held = u8(BUTTONS_HELD) & 0x0F
    if held == 0 then return end
    if (held & 0x08) ~= 0 then local y=u8(OBJ_Y); if y>Y_MIN then w8(OBJ_Y, y-BOOST) end end
    if (held & 0x04) ~= 0 then local y=u8(OBJ_Y); if y<Y_MAX then w8(OBJ_Y, y+BOOST) end end
    if (held & 0x02) ~= 0 then local x=u8(OBJ_X); if x>X_MIN then w8(OBJ_X, x-BOOST) end end
    if (held & 0x01) ~= 0 then local x=u8(OBJ_X); if x<X_MAX then w8(OBJ_X, x+BOOST) end end
end

local function load_state()
    local f = io.open(LOAD_ROOM_FILE, "r")
    if f then
        local s = f:read("*l") or ""
        f:close()
        s = s:gsub("%s+", "")
        if s ~= "" then
            local rid = tonumber(s, 16)
            if rid then
                local snap = per_room_state(rid)
                if io.open(snap, "rb") then
                    pcall(function() savestate.load(snap) end)
                    return
                end
            end
        end
    end
    pcall(function() savestate.load(ROLLING_STATE) end)
end
load_state()
for _=1,30 do joypad.set({},1); emu.frameadvance() end

local dir = read_dir()
if not dir then
    gui.text(10, 10, "advance_nes: no _next_dir.txt; exiting.")
    for _=1,30 do emu.frameadvance() end
    client.exit()
    return
end

-- Walk one step.
local start_room = u8(ROOM_ID)
local changed = false
for frame = 1, 900 do
    if u8(CUR_LEVEL) == 0 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 then
        clear_block_flags()
    end
    joypad.set({[dir]=true}, 1)
    if u8(CUR_LEVEL) == 0 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 then
        apply_turbo()
    end
    emu.frameadvance()
    if u8(ROOM_ID) ~= start_room then changed = true; break end
end

-- Settle.
for _=1,120 do
    joypad.set({},1)
    emu.frameadvance()
    if u8(GAME_MODE)==0x05 and u8(GAME_SUB)==0 and u8(ROOM_TRANS)==0 then break end
end

-- Capture.
local rid = u8(ROOM_ID)
local path = string.format("%s\\nes_room_%02X.json", OUT_DIR, rid)
local fh = assert(io.open(path, "w"))
fh:write("{\n")
fh:write('  "system": "nes",\n')
fh:write('  "room_id": ',tostring(rid),',\n')
fh:write('  "walked_from": ',tostring(start_room),',\n')
fh:write('  "direction": "',dir,'",\n')
fh:write('  "room_changed": ',tostring(changed),',\n')
fh:write('  "visible_rows": ',j2(dump_visible()),',\n')
fh:write('  "palette_rows": ',j2(dump_palette_rows()),',\n')
fh:write('  "palette_ram": ',j1(dump_palette_ram()),'\n')
fh:write("}\n")
fh:close()

pcall(function() savestate.save(ROLLING_STATE) end)
pcall(function() savestate.save(per_room_state(rid)) end)
for _=1,5 do emu.frameadvance() end
client.exit()

-- advance_and_capture_gen.lua — one step, one capture, exit.
-- Reads direction ("Up"/"Down"/"Left"/"Right") from _next_dir.txt,
-- auto-loads saved state, holds direction on Gen pad until ROOM_ID
-- changes, captures to gen_room_XX.json, saves state, exits.

local OUT_DIR    = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms"
local ROLLING_STATE = OUT_DIR .. "\\_gen_state.State"
local DIR_FILE   = OUT_DIR .. "\\_next_dir.txt"
-- Driver may pass a specific state-room in _gen_load_room.txt to load
-- that per-room snapshot instead of the rolling state. Empty = rolling.
local LOAD_ROOM_FILE = OUT_DIR .. "\\_gen_load_room.txt"

local function per_room_state(rid)
    return string.format("%s\\_gen_state_%02X.State", OUT_DIR, rid)
end

local BUS = 0xFF0000
local ROOM_ID    = BUS + 0xEB
local GAME_MODE  = BUS + 0x12
local GAME_SUB   = BUS + 0x13
local ROOM_TRANS = BUS + 0x4C

local PLAYMAP_BASE   = BUS + 0x6530
local NT_CACHE_BASE  = BUS + 0x0840
local PLANE_A_VRAM   = 0xC000
local PLANE_A_PITCH  = 128
local PLANE_A_TOP_ROW = 8
local ROOM_ROWS = 22
local ROOM_COLS = 32

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end
local function vram_u16(a)
    local ok, v = pcall(function() memory.usememorydomain("VRAM"); return memory.read_u16_be(a) end)
    return ok and v or 0
end
local function cram_u16(i)
    local ok, v = pcall(function() memory.usememorydomain("CRAM"); return memory.read_u16_be(i*2) end)
    return ok and v or 0
end

local function dump_playmap()
    local r={}; for row=0,ROOM_ROWS-1 do local v={}; for col=0,ROOM_COLS-1 do v[#v+1]=u8(PLAYMAP_BASE+row+col*ROOM_ROWS) end r[#r+1]=v end; return r
end
local function dump_nt_cache()
    local r={}; for row=0,ROOM_ROWS-1 do local v={}; local nt=PLANE_A_TOP_ROW+row; local b=NT_CACHE_BASE+nt*32; for col=0,ROOM_COLS-1 do v[#v+1]=u8(b+col) end r[#r+1]=v end; return r
end
local function dump_palette_rows()
    local r={}; for row=0,ROOM_ROWS-1 do local v={}; local nt=PLANE_A_TOP_ROW+row; local rb=PLANE_A_VRAM+nt*PLANE_A_PITCH; for col=0,ROOM_COLS-1 do local w=vram_u16(rb+col*2); v[#v+1]=(w>>13)&3 end r[#r+1]=v end; memory.usememorydomain("M68K BUS"); return r
end
local function dump_cram() local v={}; for i=0,15 do v[#v+1]=cram_u16(i) end; memory.usememorydomain("M68K BUS"); return v end
local function j1(t) local s={}; for i=1,#t do s[#s+1]=tostring(t[i]) end; return "["..table.concat(s,",").."]" end
local function j2(r) local s={}; for i=1,#r do s[#s+1]=j1(r[i]) end; return "["..table.concat(s,",").."]" end

local function read_dir()
    local f = io.open(DIR_FILE, "r")
    if not f then return nil end
    local line = f:read("*l") or ""
    f:close()
    line = line:gsub("%s+", "")
    if line == "Up" or line == "Down" or line == "Left" or line == "Right" then return line end
    return nil
end

-- Load state: try per-room snapshot first if requested, else rolling.
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
    gui.text(10, 10, "advance_gen: no _next_dir.txt; exiting.")
    for _=1,30 do emu.frameadvance() end
    client.exit()
    return
end

-- Hold dir until ROOM_ID changes or settle-timeout.
local OBJ_X = BUS + 0x70
local OBJ_Y = BUS + 0x84
local BTNS_PRESS = BUS + 0xF8
local BTNS_HELD  = BUS + 0xFA
-- Reverse NES ROL layout: bit 3=Up, bit 2=Down, bit 1=Left, bit 0=Right.
local DIR_BIT = ({Up=0x08, Down=0x04, Left=0x02, Right=0x01})[dir]

local start_room = u8(ROOM_ID)
local pre_x, pre_y = u8(OBJ_X), u8(OBJ_Y)
local changed = false
-- Whirlwind-style teleport to the adjacent room. Compute target from
-- start_room + direction offset, then set WhirlwindTeleportingState +
-- WhirlwindPrevRoomId and kick InitMode7. Sub0 will RoomId = target,
-- Sub1..Finish run the natural scroll+layout, plane refreshes.
local function w8(a, v) memory.usememorydomain("M68K BUS"); memory.write_u8(a, v & 0xFF) end
local OFFSETS = { Up = -16, Down = 16, Left = -1, Right = 1 }
local target = (start_room + OFFSETS[dir]) & 0xFF
-- $00EA must be SOURCE room (not target). Sub0 sets RoomId = $00EA =
-- source. Sub1 then calls CalculateNextRoom which advances NextRoomId
-- = source + $00E7-offset = target. Sub1 then sets RoomId = NextRoomId
-- = target, and LayOutRoom runs with the correct RoomId.
w8(BUS + 0xEA, start_room)        -- WhirlwindPrevRoomId = source
w8(BUS + 0x522, 1)                -- WhirlwindTeleportingState
w8(BUS + 0x98, DIR_BIT)           -- ObjDir
w8(BUS + 0xE7, DIR_BIT)           -- WarpDir / door-bit
w8(BUS + 0x11, 1)                 -- IsUpdatingMode = Init table
w8(BUS + 0x12, 7)                 -- GameMode = InitMode7
w8(BUS + 0x13, 0)                 -- SubMode = 0
-- Wait for mode to return to 5/sub 0.
for frame = 1, 600 do
    joypad.set({}, 1)
    emu.frameadvance()
    if u8(GAME_MODE) == 5 and u8(GAME_SUB) == 0 and u8(ROOM_TRANS) == 0 then
        changed = (u8(ROOM_ID) == target)
        break
    end
end
local post_x, post_y = u8(OBJ_X), u8(OBJ_Y)

-- Settle.
for _=1,120 do
    joypad.set({},1)
    emu.frameadvance()
    if u8(GAME_MODE)==0x05 and u8(GAME_SUB)==0 and u8(ROOM_TRANS)==0 then break end
end

-- Capture.
local rid = u8(ROOM_ID)
local path = string.format("%s\\gen_room_%02X.json", OUT_DIR, rid)
local fh = assert(io.open(path, "w"))
fh:write("{\n")
fh:write('  "system": "gen",\n')
fh:write('  "room_id": ',tostring(rid),',\n')
fh:write('  "walked_from": ',tostring(start_room),',\n')
fh:write('  "direction": "',dir,'",\n')
fh:write('  "room_changed": ',tostring(changed),',\n')
fh:write('  "pre_x": ',tostring(pre_x),', "pre_y": ',tostring(pre_y),',\n')
fh:write('  "post_x": ',tostring(post_x),', "post_y": ',tostring(post_y),',\n')
fh:write('  "post_mode": ',tostring(u8(GAME_MODE)),', "post_sub": ',tostring(u8(GAME_SUB)),',\n')
fh:write('  "obj_ac": ',tostring(u8(BUS+0xAC)),', "obj_c0": ',tostring(u8(BUS+0xC0)),',\n')
fh:write('  "input_dir": ',tostring(u8(BUS+0x3F8)),', "obj_dir": ',tostring(u8(BUS+0x98)),',\n')
fh:write('  "playmap_rows": ',j2(dump_playmap()),',\n')
fh:write('  "nt_cache_rows": ',j2(dump_nt_cache()),',\n')
fh:write('  "palette_rows": ',j2(dump_palette_rows()),',\n')
fh:write('  "cram_bg": ',j1(dump_cram()),'\n')
fh:write("}\n")
fh:close()

-- Save state for next iteration — both rolling + per-room snapshot.
pcall(function() savestate.save(ROLLING_STATE) end)
pcall(function() savestate.save(per_room_state(rid)) end)

for _=1,5 do emu.frameadvance() end
client.exit()

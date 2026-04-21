-- gen_auto_capture_73.lua — autopilot walk from $76 to $73, capture JSON.

local OUT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms\\gen_room_73.json"
local STATE_FILE = "C:\\tmp\\_gen_state.State"
local TARGET_ROOM = 0x73
local SETTLE_FRAMES = 360  -- wait this many frames after reaching target before capturing (enemies need time to spawn)

pcall(function() savestate.load(STATE_FILE) end)

local NES_RAM = 0xFF0000
local ROOM_ID = NES_RAM + 0xEB
local GAME_MODE = NES_RAM + 0x12
local GAME_SUB = NES_RAM + 0x13
local PLAYMAP_BASE = NES_RAM + 0x6530
local NT_CACHE_BASE = 0xFF0840
local PLANE_A_VRAM = 0xC000
local PLANE_A_PITCH = 128
local PLANE_A_TOP_ROW = 8
local ROOM_ROWS, ROOM_COLS = 22, 32

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end
local function vram_u16(a)
    local ok, v = pcall(function() memory.usememorydomain("VRAM"); return memory.read_u16_be(a) end)
    memory.usememorydomain("M68K BUS")
    return ok and v or 0
end
local function cram_u16(i)
    local ok, v = pcall(function() memory.usememorydomain("CRAM"); return memory.read_u16_be(i*2) end)
    memory.usememorydomain("M68K BUS")
    return ok and v or 0
end

local function dump_playmap()
    local rows = {}
    for row = 0, ROOM_ROWS-1 do
        local v = {}
        for col = 0, ROOM_COLS-1 do v[#v+1] = u8(PLAYMAP_BASE + row + col*ROOM_ROWS) end
        rows[#rows+1] = v
    end
    return rows
end
local function dump_nt_cache()
    local rows = {}
    for row = 0, ROOM_ROWS-1 do
        local v = {}
        for col = 0, ROOM_COLS-1 do v[#v+1] = u8(NT_CACHE_BASE + (PLANE_A_TOP_ROW+row)*32 + col) end
        rows[#rows+1] = v
    end
    return rows
end
local function dump_palette_rows()
    local rows = {}
    for row = 0, ROOM_ROWS-1 do
        local v = {}
        local base = PLANE_A_VRAM + (PLANE_A_TOP_ROW+row)*PLANE_A_PITCH
        for col = 0, ROOM_COLS-1 do
            local w = vram_u16(base + col*2)
            v[#v+1] = (w >> 13) & 3
        end
        rows[#rows+1] = v
    end
    return rows
end
local function dump_cram_bg()
    local v = {}
    for i=0,15 do v[#v+1] = cram_u16(i) end
    return v
end

local function dump_enemies()
    -- Object slots $0350..$035B (types), $0070..$007B (X), $0084..$008F (Y).
    local types, xs, ys = {}, {}, {}
    for i = 0, 11 do
        types[#types+1] = u8(NES_RAM + 0x0350 + i)
        xs[#xs+1]    = u8(NES_RAM + 0x0070 + i)
        ys[#ys+1]    = u8(NES_RAM + 0x0084 + i)
    end
    return types, xs, ys
end

local function j1(t) local s={}; for i=1,#t do s[#s+1]=tostring(t[i]) end; return "["..table.concat(s,",").."]" end
local function j2(rs) local s={}; for i=1,#rs do s[#s+1]=j1(rs[i]) end; return "["..table.concat(s,",").."]" end

local function capture()
    local rid = u8(ROOM_ID)
    local fh = io.open(OUT, "w")
    if not fh then return end
    fh:write("{\n")
    fh:write('  "system": "gen",\n')
    fh:write('  "room_id": ', tostring(rid), ',\n')
    fh:write('  "playmap_rows": ', j2(dump_playmap()), ',\n')
    fh:write('  "nt_cache_rows": ', j2(dump_nt_cache()), ',\n')
    fh:write('  "palette_rows": ', j2(dump_palette_rows()), ',\n')
    fh:write('  "cram_bg": ', j1(dump_cram_bg()), ',\n')
    local types, xs, ys = dump_enemies()
    fh:write('  "enemy_types": ', j1(types), ',\n')
    fh:write('  "enemy_x": ', j1(xs), ',\n')
    fh:write('  "enemy_y": ', j1(ys), '\n')
    fh:write("}\n"); fh:close()
    return rid
end

local frame_n = 0
local reached_frame = nil
local captured = false
while true do
    emu.frameadvance()
    frame_n = frame_n + 1
    local rid = u8(ROOM_ID)
    local mode = u8(GAME_MODE)
    gui.text(10, 10, string.format("room=$%02X mode=$%02X frame=%d %s",
        rid, mode, frame_n,
        captured and "[CAPTURED]" or (reached_frame and "[SETTLING]" or "[WALKING]")))

    if not captured then
        if rid == TARGET_ROOM and mode == 0x05 then
            if not reached_frame then reached_frame = frame_n end
            if frame_n - reached_frame >= SETTLE_FRAMES then
                local captured_rid = capture()
                if captured_rid == TARGET_ROOM then
                    captured = true
                    gui.text(10, 30, "Saved: " .. OUT)
                end
            end
        else
            reached_frame = nil
            -- Hold Left to walk west
            local joy = {}
            if frame_n >= 40 then joy["Left"] = true end
            joypad.set(joy, 1)
        end
    end

    if captured and frame_n - reached_frame > SETTLE_FRAMES + 60 then
        -- Let trace finish flushing, then exit
        client.exit()
    end
end

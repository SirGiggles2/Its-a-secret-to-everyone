-- nes_auto_capture_73.lua — autopilot walk to room $73 on NES, dump playmap.

local OUT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms\\nes_room_73.json"
local STATE_FILE = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms\\_nes_state.State"
local TARGET_ROOM = 0x73
local SETTLE_FRAMES = 360

pcall(function() savestate.load(STATE_FILE) end)

local ROOM_ID       = 0x00EB
local OBJ_X         = 0x0070
local OBJ_Y         = 0x0084
local BUTTONS_HELD  = 0x00FA
local CUR_LEVEL     = 0x0010
local GAME_MODE     = 0x0012
local GAME_SUB      = 0x0013
local CIRAM_BASE    = 0x0100
local ATTR_BASE     = 0x03C0
local ROOM_ROWS, ROOM_COLS = 22, 32
local PLAY_AREA_NT_TOP = 8
local BOOST = 6
local X_MIN, X_MAX = 0x0A, 0xE6
local Y_MIN, Y_MAX = 0x40, 0xD0

local function u8(addr)
    memory.usememorydomain("System Bus"); return memory.read_u8(addr)
end
local function w8(addr, val)
    memory.usememorydomain("System Bus"); memory.write_u8(addr, val & 0xFF)
end
local function ciram_u8(addr)
    for _, d in ipairs({"CIRAM (nametables)", "CIRAM", "Nametable RAM"}) do
        local ok, v = pcall(function() memory.usememorydomain(d); return memory.read_u8(addr) end)
        if ok then return v end
    end
    return 0
end

local function dump_visible()
    local rows = {}
    for row = 0, ROOM_ROWS-1 do
        local v = {}
        for col = 0, ROOM_COLS-1 do v[#v+1] = ciram_u8(CIRAM_BASE + row*ROOM_COLS + col) end
        rows[#rows+1] = v
    end
    return rows
end
local function dump_palette()
    local rows = {}
    for row = 0, ROOM_ROWS-1 do
        local v = {}
        for col = 0, ROOM_COLS-1 do
            local ntrow = PLAY_AREA_NT_TOP + row
            local ac, ar = col >> 2, ntrow >> 2
            local byte = ciram_u8(ATTR_BASE + ar*8 + ac)
            local qx, qy = (col>>1) & 1, (ntrow>>1) & 1
            v[#v+1] = (byte >> ((qy*2 + qx) * 2)) & 3
        end
        rows[#rows+1] = v
    end
    return rows
end
local function dump_playmap()
    local rows = {}
    for row = 0, ROOM_ROWS-1 do
        local v = {}
        for col = 0, ROOM_COLS-1 do v[#v+1] = u8(0x6530 + row + col*ROOM_ROWS) end
        rows[#rows+1] = v
    end
    return rows
end

local function j1(t) local s={}; for i=1,#t do s[#s+1]=tostring(t[i]) end; return "["..table.concat(s,",").."]" end
local function j2(rs) local s={}; for i=1,#rs do s[#s+1]=j1(rs[i]) end; return "["..table.concat(s,",").."]" end

local function capture()
    local rid = u8(ROOM_ID)
    local fh = io.open(OUT, "w")
    if not fh then return end
    fh:write("{\n")
    fh:write('  "system": "nes",\n')
    fh:write('  "room_id": ', tostring(rid), ',\n')
    fh:write('  "visible_rows": ', j2(dump_visible()), ',\n')
    fh:write('  "playmap_rows": ', j2(dump_playmap()), ',\n')
    fh:write('  "palette_rows": ', j2(dump_palette()), ',\n')
    fh:write('  "palette_ram": [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\n')
    local types, xs, ys = {}, {}, {}
    for i=0,11 do
        types[#types+1] = u8(0x0350 + i)
        xs[#xs+1] = u8(OBJ_X + i)
        ys[#ys+1] = u8(OBJ_Y + i)
    end
    fh:write('  "enemy_types": ', j1(types), ',\n')
    fh:write('  "enemy_x": ', j1(xs), ',\n')
    fh:write('  "enemy_y": ', j1(ys), '\n')
    fh:write("}\n"); fh:close()
    return rid
end

local function clear_block_flags()
    w8(0x000E, 0); w8(0x0053, 0); w8(0x0394, 0)
end

local frame_n = 0
local reached_frame = nil
local captured = false

while true do
    emu.frameadvance()
    frame_n = frame_n + 1
    local rid = u8(ROOM_ID)
    local mode = u8(GAME_MODE)
    local sub = u8(GAME_SUB)
    gui.text(10, 10, string.format("NES room=$%02X mode=$%02X frame=%d", rid, mode, frame_n))

    if u8(CUR_LEVEL) == 0 and mode == 0x05 and sub == 0 then
        clear_block_flags()
        if not captured then
            if rid == TARGET_ROOM then
                if not reached_frame then reached_frame = frame_n end
                if frame_n - reached_frame >= SETTLE_FRAMES then
                    local rc = capture()
                    if rc == TARGET_ROOM then
                        captured = true
                        gui.text(10, 30, "Saved: " .. OUT)
                    end
                end
            else
                reached_frame = nil
                -- Drive Left via joypad + turbo boost
                joypad.set({ Left = true }, 1)
                -- Also apply turbo boost to x coordinate
                local x = u8(OBJ_X)
                if x > X_MIN then w8(OBJ_X, x - BOOST) end
            end
        end
    end

    if captured and frame_n - reached_frame > SETTLE_FRAMES + 60 then
        client.exit()
    end
end

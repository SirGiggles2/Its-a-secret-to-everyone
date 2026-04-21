-- bulk_walk_sweep_gen.lua
-- Load Gen state at room $77 (must exist from gen_room_capture), then
-- walk Link through all 128 OW rooms using the ROM's in-built
-- TURBO_LINK + no-clip. Capture each room to gen_room_XX.json.
-- Walking (not warping) is used so Plane A is refreshed by the game's
-- real scroll transition each hop.

local OUT_DIR    = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms"
local STATE_FILE = OUT_DIR .. "\\_gen_state.State"

local BUS = 0xFF0000
local ROOM_ID     = BUS + 0xEB
local CUR_LEVEL   = BUS + 0x10
local GAME_MODE   = BUS + 0x12
local GAME_SUB    = BUS + 0x13
local ROOM_TRANS  = BUS + 0x4C

local PLAYMAP_BASE = BUS + 0x6530
local NT_CACHE_BASE = BUS + 0x0840
local PLANE_A_VRAM = 0xC000
local PLANE_A_PITCH = 128
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
local function dump_cram()
    local v={}; for i=0,15 do v[#v+1]=cram_u16(i) end; memory.usememorydomain("M68K BUS"); return v
end
local function j1(t) local s={}; for i=1,#t do s[#s+1]=tostring(t[i]) end; return "["..table.concat(s,",").."]" end
local function j2(r) local s={}; for i=1,#r do s[#s+1]=j1(r[i]) end; return "["..table.concat(s,",").."]" end

local function capture_current()
    local rid = u8(ROOM_ID)
    local path = string.format("%s\\gen_room_%02X.json", OUT_DIR, rid)
    local fh = io.open(path, "w")
    if not fh then return rid, nil end
    fh:write("{\n")
    fh:write('  "system": "gen",\n')
    fh:write('  "room_id": ',tostring(rid),',\n')
    fh:write('  "playmap_rows": ',j2(dump_playmap()),',\n')
    fh:write('  "nt_cache_rows": ',j2(dump_nt_cache()),',\n')
    fh:write('  "palette_rows": ',j2(dump_palette_rows()),',\n')
    fh:write('  "cram_bg": ',j1(dump_cram()),'\n')
    fh:write("}\n")
    fh:close()
    return rid, path
end

local function wait_settled(max_frames)
    max_frames = max_frames or 240
    for _ = 1, max_frames do
        joypad.set({}, 1)
        emu.frameadvance()
        if u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 and u8(ROOM_TRANS) == 0 then
            for _=1,10 do joypad.set({},1); emu.frameadvance() end
            return true
        end
    end
    return false
end

-- Hold direction until room changes; return true on success.
local function walk_dir(btn, max_frames)
    max_frames = max_frames or 600
    local start_room = u8(ROOM_ID)
    for _ = 1, max_frames do
        joypad.set({[btn]=true}, 1)
        emu.frameadvance()
        if u8(ROOM_ID) ~= start_room then
            return wait_settled(600)
        end
    end
    return false
end

-- Compute direction from current room toward target (single-step adjacency).
local function dir_toward(cur, target)
    local cur_row, cur_col = cur >> 4, cur & 0x0F
    local tgt_row, tgt_col = target >> 4, target & 0x0F
    if tgt_col > cur_col then return "Right" end
    if tgt_col < cur_col then return "Left" end
    if tgt_row > cur_row then return "Down" end
    if tgt_row < cur_row then return "Up" end
    return nil
end

-- Serpentine 128-room path starting from $77.
-- Visit order designed to adjacency-walk: from $77 do left to $70, up
-- to $60..$00 in full-row serpentine, down to $10, $20 .. $70.
local function build_path()
    -- Simple row-major: walk each row left-to-right or right-to-left.
    -- Starting position is $77; we insert a prefix to reach $00 first.
    local path = {}
    -- phase 1: $77 -> $70 (left across row 7)
    for c = 6, 0, -1 do path[#path+1] = 7*16 + c end
    -- phase 2: $70 -> $00 (up the column col 0)
    for r = 6, 0, -1 do path[#path+1] = r*16 + 0 end
    -- phase 3: serpentine all rows starting from $00.
    -- Row 0 forward, row 1 backward, ...
    for row = 0, 7 do
        if row % 2 == 0 then
            for col = (row == 0 and 1 or 0), 15 do path[#path+1] = row*16 + col end
        else
            for col = 15, 0, -1 do path[#path+1] = row*16 + col end
        end
    end
    return path
end

local function main()
    pcall(function() savestate.load(STATE_FILE) end)
    os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

    -- Settle after state load
    for _=1,30 do joypad.set({},1); emu.frameadvance() end

    -- Always capture starting room first.
    local _, start_path = capture_current()
    gui.text(10, 10, string.format("Capture start room $%02X", u8(ROOM_ID)))

    local captured = {}
    captured[u8(ROOM_ID)] = true

    local path = build_path()
    local step = 0
    for _, target in ipairs(path) do
        step = step + 1
        local cur = u8(ROOM_ID)
        if cur ~= target then
            local d = dir_toward(cur, target)
            if d then
                walk_dir(d, 900)
            end
        end
        local now = u8(ROOM_ID)
        if not captured[now] then
            capture_current()
            captured[now] = true
        end
        gui.text(10, 10, string.format("Step %d/%d  cur=$%02X  tgt=$%02X  captured=%d",
            step, #path, now, target, (function() local n=0; for _ in pairs(captured) do n=n+1 end; return n end)()))
    end

    gui.text(10, 10, string.format("Gen sweep DONE: captured %d rooms",
        (function() local n=0; for _ in pairs(captured) do n=n+1 end; return n end)()))
    client.exit()
end

main()

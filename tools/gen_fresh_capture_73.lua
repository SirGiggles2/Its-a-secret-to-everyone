-- gen_fresh_capture_73.lua — from fresh boot, handle title / file-select
-- / register-name / start-game flow deterministically, walk left from
-- $77 to $73, settle 360 frames, capture gen_room_73.json.

local OUT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms\\gen_room_73.json"
local TARGET_ROOM = 0x73
local SETTLE_FRAMES = 360
local TARGET_NAME_PROGRESS = 3
local BOOT_TIMEOUT = 600

local NES_RAM = 0xFF0000
local ROOM_ID    = NES_RAM + 0xEB
local GAME_MODE  = NES_RAM + 0x12
local GAME_SUB   = NES_RAM + 0x13
local CUR_LEVEL  = NES_RAM + 0x10
local CUR_SLOT   = NES_RAM + 0x16
local NAME_OFS   = NES_RAM + 0x0421
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

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

-- Input scheduler: hold button for `hold` frames, then release for `rel`
-- frames before next schedule can arm.
local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 8 }
local function schedule(button, hold, rel)
    if input_state.hold_left > 0 or input_state.release_left > 0 then return false end
    input_state.button = button
    input_state.hold_left = hold or 2
    input_state.release_after = rel or 10
    return true
end
local function current_pad()
    local pad = {}
    if input_state.hold_left > 0 and input_state.button then
        pad[input_state.button] = true
        pad["P1 " .. input_state.button] = true
        input_state.hold_left = input_state.hold_left - 1
        if input_state.hold_left == 0 then
            input_state.release_left = input_state.release_after
        end
    elseif input_state.release_left > 0 then
        input_state.release_left = input_state.release_left - 1
    end
    return pad
end

-- Flow states.
local S_BOOT         = 1
local S_SELECT_REG   = 2   -- move cur_slot to 3 (REGISTER)
local S_ENTER_REG    = 3   -- press Start to go Mode1 -> Mode $0E
local S_TYPE_NAME    = 4   -- press A a few times to tick $0421
local S_CYCLE_END    = 5   -- press Select until cur_slot=3 (END)
local S_CONFIRM_END  = 6   -- press Start, wait for mode != $0E
local S_WAIT_FS1     = 7   -- wait for mode==1 after register
local S_TO_SLOT0     = 8   -- press Up until cur_slot=0 (NAME 1)
local S_START_GAME   = 9   -- press Start, wait for mode==5
local S_WALK         = 10  -- walk left to $73
local S_SETTLE       = 11
local S_CAPTURED     = 12

local state = S_BOOT
local name_progress = 0
local last_name_ofs = nil
local reached_frame = nil
local captured_frame = nil

for frame = 1, 30000 do
    local pad = current_pad()
    safe_set(pad)
    emu.frameadvance()

    local mode = u8(GAME_MODE)
    local sub  = u8(GAME_SUB)
    local lvl  = u8(CUR_LEVEL)
    local rid  = u8(ROOM_ID)
    local slot = u8(CUR_SLOT)
    local nofs = u8(NAME_OFS)

    gui.text(10, 10, string.format("s=%d m=$%02X sub=$%02X slot=$%02X rm=$%02X f=%d",
        state, mode, sub, slot, rid, frame))

    if state == S_BOOT then
        if mode == 0x01 then
            state = S_SELECT_REG
            last_name_ofs = nofs
        elseif frame > BOOT_TIMEOUT then
            print("boot timeout")
            break
        else
            schedule("Start", 2, 5)
        end
    elseif state == S_SELECT_REG then
        if mode ~= 0x01 then state = S_WAIT_FS1
        elseif slot == 0x03 then state = S_ENTER_REG
        else schedule("Down", 1, 12) end
    elseif state == S_ENTER_REG then
        if mode == 0x0E then
            state = S_TYPE_NAME
            last_name_ofs = nofs
        elseif mode == 0x01 then
            schedule("Start", 2, 14)
        end
    elseif state == S_TYPE_NAME then
        if mode ~= 0x0E then state = S_WAIT_FS1
        else
            if nofs ~= last_name_ofs then
                name_progress = name_progress + 1
                last_name_ofs = nofs
            end
            if name_progress >= TARGET_NAME_PROGRESS then
                state = S_CYCLE_END
            else
                schedule("A", 1, 10)
            end
        end
    elseif state == S_CYCLE_END then
        if mode ~= 0x0E then state = S_WAIT_FS1
        elseif slot == 0x03 then state = S_CONFIRM_END
        else schedule("Select", 1, 12) end
    elseif state == S_CONFIRM_END then
        if mode ~= 0x0E then state = S_WAIT_FS1
        else schedule("Start", 2, 14) end
    elseif state == S_WAIT_FS1 then
        if mode == 0x01 then state = S_TO_SLOT0 end
    elseif state == S_TO_SLOT0 then
        if mode ~= 0x01 then state = S_WAIT_FS1
        elseif slot == 0x00 then state = S_START_GAME
        else schedule("Up", 1, 12) end
    elseif state == S_START_GAME then
        if mode == 0x05 and lvl == 0 then
            state = S_WALK
        elseif mode == 0x01 then
            schedule("Start", 2, 14)
        end
    elseif state == S_WALK then
        if mode ~= 0x05 then
            -- wait
        elseif rid == TARGET_ROOM then
            state = S_SETTLE
            reached_frame = frame
        else
            -- hold left continuously; input scheduler isn't used here
            pad = { Left = true, ["P1 Left"] = true }
            safe_set(pad)
        end
    elseif state == S_SETTLE then
        if frame - reached_frame >= SETTLE_FRAMES then
            if capture() == TARGET_ROOM then
                state = S_CAPTURED
                captured_frame = frame
                gui.text(10, 30, "Saved")
            end
        end
    elseif state == S_CAPTURED then
        if frame - captured_frame > 60 then client.exit() end
    end
end

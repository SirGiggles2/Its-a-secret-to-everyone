-- fresh_boot_position_log.lua — fresh-boot → walk $77→$73 → log 360 logical ticks.
-- Combines gen_fresh_capture_73 boot-flow with position_log capture.
-- Output file tag via env var POSITION_LOG_TAG (default "gen").

local TAG = os.getenv("POSITION_LOG_TAG") or "gen"
local OUT = "C:\\tmp\\position_log_" .. TAG .. ".txt"
local TARGET_ROOM = 0x73
local TICKS_TO_CAPTURE = 360
local TARGET_NAME_PROGRESS = 3
local BOOT_TIMEOUT = 600

local BUS = 0xFF0000
local ROOM_ID     = BUS + 0xEB
local GAME_MODE   = BUS + 0x12
local GAME_SUB    = BUS + 0x13
local CUR_LEVEL   = BUS + 0x10
local CUR_SLOT    = BUS + 0x16
local NAME_OFS    = BUS + 0x0421
local FRAME_COUNTER = BUS + 0x15
local OBJ_TYPE    = BUS + 0x0350
local OBJ_X       = BUS + 0x0070
local OBJ_Y       = BUS + 0x0084
local OBJ_DIR     = BUS + 0x0098
local OBJ_POS_FRAC = BUS + 0x03A8
local OBJ_GRID_OFS = BUS + 0x0394

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

local function capture_slots(base)
    local parts = {}
    for i = 0, 11 do parts[#parts+1] = string.format("%02X", u8(base + i)) end
    return table.concat(parts, ",")
end

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

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

-- Flow states reused from gen_fresh_capture_73.lua.
local S_BOOT        = 1
local S_SELECT_REG  = 2
local S_ENTER_REG   = 3
local S_TYPE_NAME   = 4
local S_CYCLE_END   = 5
local S_CONFIRM_END = 6
local S_WAIT_FS1    = 7
local S_TO_SLOT0    = 8
local S_START_GAME  = 9
local S_WALK        = 10
local S_LOG         = 11
local S_DONE        = 12

local state = S_BOOT
local name_progress = 0
local last_name_ofs = nil
local ticks_captured = 0
local last_fc = nil
local fh = nil
local emu_frame_at_log_start = nil

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

    gui.text(10, 10, string.format("tag=%s s=%d m=$%02X rm=$%02X f=%d logged=%d",
        TAG, state, mode, rid, frame, ticks_captured))

    if state == S_BOOT then
        if mode == 0x01 then state = S_SELECT_REG; last_name_ofs = nofs
        elseif frame > BOOT_TIMEOUT then print("boot timeout"); break
        else schedule("Start", 2, 5) end
    elseif state == S_SELECT_REG then
        if mode ~= 0x01 then state = S_WAIT_FS1
        elseif slot == 0x03 then state = S_ENTER_REG
        else schedule("Down", 1, 12) end
    elseif state == S_ENTER_REG then
        if mode == 0x0E then state = S_TYPE_NAME; last_name_ofs = nofs
        elseif mode == 0x01 then schedule("Start", 2, 14) end
    elseif state == S_TYPE_NAME then
        if mode ~= 0x0E then state = S_WAIT_FS1
        else
            if nofs ~= last_name_ofs then
                name_progress = name_progress + 1
                last_name_ofs = nofs
            end
            if name_progress >= TARGET_NAME_PROGRESS then state = S_CYCLE_END
            else schedule("A", 1, 10) end
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
        if mode == 0x05 and lvl == 0 then state = S_WALK
        elseif mode == 0x01 then schedule("Start", 2, 14) end
    elseif state == S_WALK then
        if mode ~= 0x05 then
            -- wait
        elseif rid == TARGET_ROOM then
            state = S_LOG
            fh = assert(io.open(OUT, "w"))
            fh:write(string.format("# position_log tag=%s ticks=%d room target=$%02X\n",
                TAG, TICKS_TO_CAPTURE, TARGET_ROOM))
            fh:write("# columns: logical_tick,emu_frame,room,mode,sub,types,xs,ys,dirs,pos_frac,grid_ofs\n")
            last_fc = u8(FRAME_COUNTER)
            emu_frame_at_log_start = frame
        else
            pad = { Left = true, ["P1 Left"] = true }
            safe_set(pad)
        end
    elseif state == S_LOG then
        local fc = u8(FRAME_COUNTER)
        if fc ~= last_fc then
            last_fc = fc
            ticks_captured = ticks_captured + 1
            fh:write(string.format("%d,%d,%02X,%02X,%02X,%s,%s,%s,%s,%s,%s\n",
                ticks_captured, frame - emu_frame_at_log_start,
                u8(ROOM_ID), u8(GAME_MODE), u8(GAME_SUB),
                capture_slots(OBJ_TYPE),
                capture_slots(OBJ_X),
                capture_slots(OBJ_Y),
                capture_slots(OBJ_DIR),
                capture_slots(OBJ_POS_FRAC),
                capture_slots(OBJ_GRID_OFS)))
            if ticks_captured >= TICKS_TO_CAPTURE then
                fh:close()
                state = S_DONE
            end
        end
    elseif state == S_DONE then
        -- Spin a few frames then exit so the user can see the "Saved" overlay.
        if frame - emu_frame_at_log_start > 2000 then client.exit() end
    end
end

if fh then pcall(function() fh:close() end) end
client.exit()

local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_cave_room67_probe.txt"

local ROOM_CONTEXT_MODE = 0xFF0056
local CAVE_TRANSITION_MODE = 0xFF005E
local ROOM_ID = 0xFF003C
local LINK_X = 0xFF0048
local LINK_Y = 0xFF004A
local FRAME_COUNTER = 0xFF0002

local TARGET_ROOM = 0x0067
local TARGET_EXIT_X = 112
local TARGET_EXIT_Y = 77
local CAVE_INTERIOR_X = 112

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local log_file = assert(io.open(OUT_PATH, "w"))

local function log(msg)
    log_file:write(msg .. "\n")
    log_file:flush()
    print(msg)
end

local function read_u16(addr)
    memory.usememorydomain("M68K BUS")
    return memory.read_u16_be(addr)
end

local function frame_with_input(pad)
    joypad.set(pad)
    emu.frameadvance()
end

local function wait_for(predicate, max_frames, pad)
    for frame = 1, max_frames do
        frame_with_input(pad or {})
        if predicate() then
            return frame
        end
    end
    return nil
end

local function move_to_room_67()
    for _ = 1, 80 do
        if read_u16(ROOM_ID) ~= 0x0077 then
            break
        end
        if read_u16(LINK_X) >= 160 then
            break
        end
        frame_with_input({ ["P1 Right"] = true })
    end

    local settled = wait_for(function()
        return read_u16(ROOM_ID) == TARGET_ROOM and read_u16(0xFF004C) == 0
    end, 220, { ["P1 Up"] = true })
    if settled == nil then
        error("failed to settle into room 0067")
    end
    log(string.format("arrived room=%04X x=%d y=%d after %d frames", read_u16(ROOM_ID), read_u16(LINK_X), read_u16(LINK_Y), settled))
end

local function seek_room67_cave_entry()
    for _ = 1, 260 do
        local x = read_u16(LINK_X)
        local y = read_u16(LINK_Y)
        local pad = {}

        if y > 76 then
            pad["P1 Up"] = true
        end

        if x < (TARGET_EXIT_X - 4) then
            pad["P1 Right"] = true
        elseif x > (TARGET_EXIT_X + 4) then
            pad["P1 Left"] = true
        else
            pad["P1 Up"] = true
        end

        frame_with_input(pad)
        if read_u16(ROOM_CONTEXT_MODE) == 1 then
            return true
        end
    end

    return false
end

local function main()
    for _ = 1, 20 do
        frame_with_input({})
    end

    local start_room = read_u16(ROOM_ID)
    local start_x = read_u16(LINK_X)
    local start_y = read_u16(LINK_Y)
    log(string.format("start room=%04X x=%d y=%d", start_room, start_x, start_y))
    if start_room ~= 0x0077 then
        error(string.format("unexpected start room %04X", start_room))
    end

    move_to_room_67()
    if not seek_room67_cave_entry() then
        error("never entered cave from room 0067")
    end

    log(string.format("entered cave room=%04X x=%d y=%d", read_u16(ROOM_ID), read_u16(LINK_X), read_u16(LINK_Y)))

    local enter_started = wait_for(function()
        return read_u16(CAVE_TRANSITION_MODE) == 1
    end, 120, {})
    if enter_started == nil then
        error("room 0067 enter transition never started")
    end

    local enter_steps = 0
    local enter_prev = nil
    local enter_prev_step_frame = nil
    local enter_finished = false
    for _ = 1, 240 do
        frame_with_input({})
        local mode = read_u16(CAVE_TRANSITION_MODE)
        local frame_counter = read_u16(FRAME_COUNTER)
        local y = read_u16(LINK_Y)
        if mode ~= 1 then
            enter_finished = true
            break
        end
        if enter_prev ~= nil then
            local dy = enter_prev - y
            if dy ~= 0 then
                enter_steps = enter_steps + 1
                if dy ~= 1 then
                    error(string.format("room67 enter step expected 1px, got %d", dy))
                end
                if enter_prev_step_frame ~= nil and frame_counter ~= (enter_prev_step_frame + 1) then
                    error(string.format("room67 enter cadence expected every frame, prev=%d current=%d", enter_prev_step_frame, frame_counter))
                end
                enter_prev_step_frame = frame_counter
            end
        end
        enter_prev = y
    end
    if not enter_finished then
        error("room67 enter transition never finished")
    end
    if enter_steps == 0 then
        error("room67 enter had zero walk samples")
    end

    local cave_settle_x = read_u16(LINK_X)
    local cave_settle_y = read_u16(LINK_Y)
    log(string.format("room67 cave settle x=%d y=%d", cave_settle_x, cave_settle_y))
    if cave_settle_x ~= CAVE_INTERIOR_X then
        error(string.format("expected room67 cave interior X=%d, got %d", CAVE_INTERIOR_X, cave_settle_x))
    end

    local exit_started = wait_for(function()
        return read_u16(CAVE_TRANSITION_MODE) == 2
    end, 320, { ["P1 Down"] = true })
    if exit_started == nil then
        error("room67 exit transition never started")
    end

    local exit_phase = nil
    local exit_steps = 0
    local prev_y = read_u16(LINK_Y)
    for _ = 1, 480 do
        frame_with_input({})
        local mode = read_u16(CAVE_TRANSITION_MODE)
        if mode ~= 2 then
            break
        end
        if read_u16(ROOM_CONTEXT_MODE) ~= 1 then
            error("room67 context switched before exit transition finished")
        end

        local frame_counter = read_u16(FRAME_COUNTER)
        local y = read_u16(LINK_Y)
        local dy = prev_y - y
        if dy ~= 0 then
            exit_steps = exit_steps + 1
            if dy ~= 1 then
                error(string.format("room67 exit step expected 1px, got %d", dy))
            end
            local phase = frame_counter & 0x0003
            if exit_phase == nil then
                exit_phase = phase
            elseif phase ~= exit_phase then
                error(string.format("room67 exit cadence drifted: expected phase %d got %d", exit_phase, phase))
            end
        end
        prev_y = y
    end
    if exit_steps == 0 then
        error("room67 exit had zero walk samples")
    end

    local exited = wait_for(function()
        return read_u16(ROOM_CONTEXT_MODE) == 0 and read_u16(CAVE_TRANSITION_MODE) == 0
    end, 120, {})
    if exited == nil then
        error("room67 never exited cave mode")
    end

    local end_room = read_u16(ROOM_ID)
    local end_x = read_u16(LINK_X)
    local end_y = read_u16(LINK_Y)
    log(string.format("room67 exit frame=%d room=%04X x=%d y=%d", exited, end_room, end_x, end_y))

    if end_room ~= TARGET_ROOM then
        error(string.format("expected return room 0067, got %04X", end_room))
    end
    if end_x ~= TARGET_EXIT_X or end_y ~= TARGET_EXIT_Y then
        error(string.format("expected return pos (%d,%d), got (%d,%d)", TARGET_EXIT_X, TARGET_EXIT_Y, end_x, end_y))
    end

    log("WHAT IF Phase 3 cave room67 probe: PASS")
end

local ok, err = pcall(main)
if not ok then
    log("WHAT IF Phase 3 cave room67 probe: FAIL - " .. tostring(err))
end

log_file:close()
client.exit()

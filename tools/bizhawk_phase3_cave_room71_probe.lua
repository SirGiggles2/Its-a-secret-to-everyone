local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_cave_room71_probe.txt"

local ROOM_CONTEXT_MODE = 0xFF0056
local CAVE_TRANSITION_MODE = 0xFF005E
local ROOM_ID = 0xFF003C
local LINK_X = 0xFF0048
local LINK_Y = 0xFF004A
local FRAME_COUNTER = 0xFF0002

local TARGET_ROOM = 0x0071
local TARGET_EXIT_X = 96
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

local function move_to_room_71()
    local settled = wait_for(function()
        return read_u16(ROOM_ID) == TARGET_ROOM and read_u16(0xFF004C) == 0
    end, 200, { ["P1 Left"] = true })
    if settled == nil then
        error("failed to settle into room 0071")
    end
    log(string.format("arrived room=%04X x=%d y=%d after %d frames", read_u16(ROOM_ID), read_u16(LINK_X), read_u16(LINK_Y), settled))
end

local function seek_room71_cave_entry()
    for _ = 1, 320 do
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

local function assert_enter_auto_walk()
    local enter_prev_y = nil
    local enter_prev_step_frame = nil
    local enter_steps = 0
    local enter_finished = false
    for _ = 1, 240 do
        frame_with_input({})
        local trans_mode = read_u16(CAVE_TRANSITION_MODE)
        local frame_counter = read_u16(FRAME_COUNTER)
        local y = read_u16(LINK_Y)
        if trans_mode ~= 1 then
            enter_finished = true
            break
        end
        if enter_prev_y == nil then
            enter_prev_y = y
        else
            local dy = enter_prev_y - y
            if dy ~= 0 then
                enter_steps = enter_steps + 1
                if dy ~= 1 then
                    error(string.format("enter auto-walk step expected 1px, got %d", dy))
                end
                if enter_prev_step_frame ~= nil and frame_counter ~= (enter_prev_step_frame + 1) then
                    error(string.format(
                        "enter auto-walk cadence expected every frame, prev=%d current=%d",
                        enter_prev_step_frame,
                        frame_counter
                    ))
                end
                enter_prev_step_frame = frame_counter
            end
        end
        enter_prev_y = y
    end
    if not enter_finished then
        error("enter transition did not finish")
    end
    if enter_steps < 20 then
        error(string.format("enter auto-walk too few steps: %d", enter_steps))
    end
    local x = read_u16(LINK_X)
    if x ~= CAVE_INTERIOR_X then
        error(string.format("cave interior X expected %d, got %d", CAVE_INTERIOR_X, x))
    end
    log(string.format("room71 cave settle x=%d y=%d", x, read_u16(LINK_Y)))
end

local function assert_exit_auto_walk()
    local exit_prev_y = nil
    local exit_prev_step_frame = nil
    local exit_steps = 0
    local exit_finished = false
    for _ = 1, 240 do
        frame_with_input({})
        local trans_mode = read_u16(CAVE_TRANSITION_MODE)
        local frame_counter = read_u16(FRAME_COUNTER)
        local y = read_u16(LINK_Y)
        if trans_mode == 0 then
            exit_finished = true
            break
        end
        if exit_prev_y == nil then
            exit_prev_y = y
        else
            local dy = exit_prev_y - y
            if dy ~= 0 then
                exit_steps = exit_steps + 1
                if dy ~= 1 then
                    error(string.format("exit auto-walk step expected 1px, got %d", dy))
                end
                if exit_prev_step_frame ~= nil and frame_counter ~= (exit_prev_step_frame + 4) then
                    error(string.format(
                        "exit auto-walk cadence expected every 4 frames, prev=%d current=%d",
                        exit_prev_step_frame,
                        frame_counter
                    ))
                end
                exit_prev_step_frame = frame_counter
            end
        end
        exit_prev_y = y
    end
    if not exit_finished then
        error("exit transition did not finish")
    end
    if exit_steps < 20 then
        error(string.format("exit auto-walk too few steps: %d", exit_steps))
    end
    local x = read_u16(LINK_X)
    local y = read_u16(LINK_Y)
    if x ~= TARGET_EXIT_X or y ~= TARGET_EXIT_Y then
        error(string.format("exit position expected (%d,%d), got (%d,%d)", TARGET_EXIT_X, TARGET_EXIT_Y, x, y))
    end
    log(string.format("room71 exit frame=1 room=%04X x=%d y=%d", read_u16(ROOM_ID), x, y))
end

local function assert_boundary_conditions()
    local start_room = read_u16(ROOM_ID)
    local start_x = read_u16(LINK_X)
    local start_y = read_u16(LINK_Y)
    log(string.format("start room=%04X x=%d y=%d", start_room, start_x, start_y))

    for _ = 1, 10 do
        frame_with_input({ ["P1 Up"] = true })
        if read_u16(ROOM_CONTEXT_MODE) == 1 then
            error("cave entry triggered before reaching doorway")
        end
    end

    local settled = wait_for(function()
        return read_u16(LINK_X) >= 200
    end, 200, { ["P1 Left"] = true })
    if settled == nil then
        error("failed to move left away from doorway")
    end

    for _ = 1, 10 do
        frame_with_input({ ["P1 Down"] = true })
        if read_u16(ROOM_CONTEXT_MODE) == 1 then
            error("cave entry triggered while misaligned left of doorway")
        end
    end

    for _ = 1, 10 do
        frame_with_input({ ["P1 Right"] = true })
        if read_u16(ROOM_CONTEXT_MODE) == 1 then
            error("cave entry triggered while misaligned below doorway")
        end
    end

    local settled = wait_for(function()
        return read_u16(LINK_X) <= 8
    end, 200, { ["P1 Left"] = true })
    if settled == nil then
        error("failed to return to doorway")
    end
end

local function run_probe()
    assert_boundary_conditions()
    move_to_room_71()
    local entered = seek_room71_cave_entry()
    if not entered then
        error("failed to enter cave")
    end
    log(string.format("entered cave room=%04X x=%d y=%d", read_u16(ROOM_ID), read_u16(LINK_X), read_u16(LINK_Y)))
    assert_enter_auto_walk()
    for _ = 1, 40 do
        frame_with_input({ ["P1 Down"] = true })
        if read_u16(CAVE_TRANSITION_MODE) == 2 then
            break
        end
    end
    local exit_triggered = false
    for _ = 1, 40 do
        frame_with_input({ ["P1 Down"] = true })
        if read_u16(CAVE_TRANSITION_MODE) == 2 then
            exit_triggered = true
            break
        end
    end
    if not exit_triggered then
        error("failed to trigger exit transition")
    end
    assert_exit_auto_walk()
    log("WHAT IF Phase 3 cave room71 probe: PASS")
end

run_probe()
log_file:close()

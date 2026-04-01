local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_cave_probe.txt"

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

local function main()
    for _ = 1, 20 do
        frame_with_input({})
    end

    local start_room = read_u16(0xFF003C)
    local start_x = read_u16(0xFF0048)
    local start_y = read_u16(0xFF004A)
    log(string.format("start room=%04X x=%d y=%d", start_room, start_x, start_y))

    if start_room ~= 0x0077 then
        error(string.format("unexpected start room %04X", start_room))
    end

    for _ = 1, 12 do
        frame_with_input({ ["P1 Right"] = true })
    end
    for _ = 1, 12 do
        frame_with_input({ ["P1 Up"] = true })
        if read_u16(0xFF0056) == 1 then
            error("entered cave while misaligned from doorway")
        end
    end
    for _ = 1, 12 do
        frame_with_input({ ["P1 Down"] = true })
    end
    for _ = 1, 12 do
        frame_with_input({ ["P1 Left"] = true })
    end

    local pre_entry_room = read_u16(0xFF003C)
    local pre_entry_x = read_u16(0xFF0048)
    local pre_entry_y = read_u16(0xFF004A)
    if pre_entry_room ~= start_room then
        error(string.format("misalignment precheck changed room unexpectedly: %04X", pre_entry_room))
    end
    if pre_entry_x ~= start_x or pre_entry_y ~= start_y then
        error(string.format(
            "misalignment precheck did not return to start pos (%d,%d), got (%d,%d)",
            start_x,
            start_y,
            pre_entry_x,
            pre_entry_y
        ))
    end

    local entered_frame = wait_for(function()
        return read_u16(0xFF0056) == 1
    end, 180, { ["P1 Up"] = true })

    if entered_frame == nil then
        error("never entered cave mode")
    end

    local cave_room = read_u16(0xFF003C)
    local cave_x = read_u16(0xFF0048)
    local cave_y = read_u16(0xFF004A)
    log(string.format("entered cave frame=%d room=%04X x=%d y=%d", entered_frame, cave_room, cave_x, cave_y))

    local enter_transition_started = wait_for(function()
        return read_u16(0xFF005E) == 1
    end, 120, {})
    if enter_transition_started == nil then
        error("cave enter transition mode never started")
    end

    local enter_prev_y = nil
    local enter_prev_step_frame = nil
    local enter_steps = 0
    local enter_finished = false
    for _ = 1, 240 do
        frame_with_input({})
        local trans_mode = read_u16(0xFF005E)
        local frame_counter = read_u16(0xFF0002)
        local y = read_u16(0xFF004A)
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
        error("cave enter transition mode never finished")
    end

    local cave_settled_x = read_u16(0xFF0048)
    local cave_settled_y = read_u16(0xFF004A)
    log(string.format("cave settle x=%d y=%d", cave_settled_x, cave_settled_y))

    if enter_steps == 0 then
        error("enter auto-walk recorded zero movement samples")
    end
    if cave_settled_x ~= 112 then
        error(string.format("expected cave interior X=112, got %d", cave_settled_x))
    end

    for _ = 1, 24 do
        frame_with_input({ ["P1 Left"] = true })
    end
    for _ = 1, 20 do
        frame_with_input({ ["P1 Down"] = true })
        if read_u16(0xFF005E) == 2 then
            error("started cave exit while misaligned from doorway")
        end
        if read_u16(0xFF0056) ~= 1 then
            error("left cave context during misaligned exit precheck")
        end
    end
    for _ = 1, 24 do
        frame_with_input({ ["P1 Right"] = true })
    end

    local exit_transition_started = wait_for(function()
        return read_u16(0xFF005E) == 2
    end, 300, { ["P1 Down"] = true })
    if exit_transition_started == nil then
        error("cave exit transition mode never started")
    end

    local cadence_anchor = nil
    local prev_y = read_u16(0xFF004A)
    local walk_samples = 0
    for _ = 1, 480 do
        frame_with_input({})
        local trans_mode = read_u16(0xFF005E)
        if trans_mode ~= 2 then
            break
        end
        if read_u16(0xFF0056) ~= 1 then
            error("context switched out of cave before exit transition completed")
        end

        local frame_counter = read_u16(0xFF0002)
        local y = read_u16(0xFF004A)
        local dy = prev_y - y
        if dy ~= 0 then
            walk_samples = walk_samples + 1
            if dy ~= 1 then
                error(string.format("exit auto-walk step expected 1px, got %d", dy))
            end
            if cadence_anchor == nil then
                cadence_anchor = frame_counter & 0x0003
            else
                local phase = frame_counter & 0x0003
                if phase ~= cadence_anchor then
                    error(string.format("exit auto-walk cadence drifted: expected phase %d got %d", cadence_anchor, phase))
                end
            end
        end
        prev_y = y
    end

    if walk_samples == 0 then
        error("exit auto-walk recorded zero movement samples")
    end

    local exited_frame = wait_for(function()
        return read_u16(0xFF0056) == 0 and read_u16(0xFF005E) == 0
    end, 120, {})

    if exited_frame == nil then
        error("never exited cave mode")
    end

    local end_room = read_u16(0xFF003C)
    local end_x = read_u16(0xFF0048)
    local end_y = read_u16(0xFF004A)
    log(string.format("exit cave frame=%d room=%04X x=%d y=%d", exited_frame, end_room, end_x, end_y))

    if end_room ~= start_room then
        error(string.format("expected return room %04X, got %04X", start_room, end_room))
    end

    if end_x ~= start_x or end_y ~= start_y then
        error(string.format("expected return pos (%d,%d), got (%d,%d)", start_x, start_y, end_x, end_y))
    end

    log("WHAT IF Phase 3 cave probe: PASS")
end

local ok, err = pcall(main)
if not ok then
    log("WHAT IF Phase 3 cave probe: FAIL - " .. tostring(err))
end

log_file:close()
client.exit()

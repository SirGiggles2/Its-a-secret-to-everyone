local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_dungeon_probe.txt"

local ROOM_CONTEXT_MODE = 0xFF0056
local ROOM_ID = 0xFF003C
local LEVEL_ID = 0xFF0062
local BOOT_STAGE = 0xFF0040
local BOOT_DETAIL = 0xFF0042
local FRAME_COUNTER = 0xFF0002

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

local function assert_dungeon_room_loaded(expected_level, expected_room)
    local settled = wait_for(function()
        local stage = read_u16(BOOT_STAGE)
        return stage >= 0x0300 and stage <= 0x0304
    end, 300, {})
    if settled == nil then
        error("dungeon room loading did not complete")
    end
    
    local level = read_u16(LEVEL_ID)
    local room = read_u16(ROOM_ID)
    local stage = read_u16(BOOT_STAGE)
    local detail = read_u16(BOOT_DETAIL)
    
    log(string.format("dungeon loaded level=%d room=%02X stage=%04X detail=%04X after %d frames", level, room, stage, detail, settled))
    
    if level ~= expected_level then
        error(string.format("expected level %d, got %d", expected_level, level))
    end
    if room ~= expected_room then
        error(string.format("expected room %02X, got %02X", expected_room, room))
    end
end

local function test_dungeon_room_loading()
    log("Testing dungeon room loading...")
    
    -- Wait for overworld boot (verify existing functionality works)
    local boot_settled = wait_for(function()
        return read_u16(BOOT_STAGE) == 0x010B
    end, 200, {})
    if boot_settled == nil then
        error("boot stage did not settle")
    end
    log(string.format("boot settled stage=%04X after %d frames", read_u16(BOOT_STAGE), boot_settled))
    
    -- Verify overworld room loaded correctly
    local room = read_u16(ROOM_ID)
    if room ~= 0x0077 then
        error(string.format("expected overworld room 0077, got %04X", room))
    end
    log(string.format("overworld room verification passed: room=%04X", room))
    
    -- Manually trigger dungeon room loading (test mode only)
    log("Setting up dungeon test...")
    memory.writebyte(0xFF0062, 0)  -- CURRENT_LEVEL_ID
    memory.writebyte(0xFF003C, 0)  -- CURRENT_ROOM_ID
    memory.writebyte(0xFF0054, 0)  -- ROOM_BUILD_ROOM_ID
    
    -- Trigger dungeon load by setting boot stage
    log("Triggering dungeon load with BOOT_STAGE=0300...")
    memory.writewordbe(0xFF0040, 0x0300)  -- BOOT_STAGE
    
    -- Add frame-by-frame debugging
    for frame = 1, 100 do
        frame_with_input({})
        local stage = read_u16(BOOT_STAGE)
        local detail = read_u16(BOOT_DETAIL)
        log(string.format("frame %d: stage=%04X detail=%04X", frame, stage, detail))
        if stage >= 0x0300 and stage <= 0x0304 then
            log("Dungeon boot stage detected!")
            break
        end
        if stage == 0x0304 then
            log("Dungeon loading complete!")
            break
        end
    end
    
    local level = read_u16(LEVEL_ID)
    local room = read_u16(ROOM_ID)
    local stage = read_u16(BOOT_STAGE)
    local detail = read_u16(BOOT_DETAIL)
    
    log(string.format("final state: level=%d room=%02X stage=%04X detail=%04X", level, room, stage, detail))
    
    if stage ~= 0x0304 then
        error(string.format("dungeon loading incomplete, final stage=%04X", stage))
    end
    
    log("WHAT IF Phase 3 dungeon probe: PASS")
end

local function run_probe()
    test_dungeon_room_loading()
end

run_probe()
log_file:close()

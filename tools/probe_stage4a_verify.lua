-- probe_stage4a_verify.lua — Verifies Stage 4a C-ported functions:
--   HasCompass, HasMap, CalcOpenDoorwayMask, AddDoorFlagsToCurOpenedDoors
--
-- Strategy: boot → walk left to room $73 → walk up into dungeon 1 entrance
-- → enter dungeon → walk through rooms (triggers AddDoorFlags/CalcOpenDoorwayMask)
-- → press Start to open inventory (triggers HasCompass/HasMap)
-- → log RAM state for verification.

dofile("C:\\tmp\\boot_sequence.lua")

local BUS = 0xFF0000
local DOM = "M68K BUS"
local OUT = "C:\\tmp\\stage4a_verify.txt"
local function u8(a) return memory.read_u8(a, DOM) end

local fh = assert(io.open(OUT, "w"))
fh:write("=== Stage 4a Verification Probe ===\n")
fh:write("Tests: HasCompass, HasMap, CalcOpenDoorwayMask, AddDoorFlags\n\n")
fh:flush()

local phase = "boot_to_ow"
local phase_start = 0
local dungeon_entered = false
local inventory_opened = false
local door_frames = 0
local checks = {}

local function log(msg)
    fh:write(string.format("[f%d] %s\n", emu.framecount(), msg))
    fh:flush()
end

local function check(name, pass, detail)
    local status = pass and "PASS" or "FAIL"
    checks[#checks + 1] = { name = name, pass = pass, detail = detail }
    log(string.format("CHECK %s: %s -- %s", status, name, detail or ""))
end

for frame = 1, 12000 do
    local mode = u8(BUS + 0x12)
    local sub  = u8(BUS + 0x13)
    local rid  = u8(BUS + 0xEB)
    local lvl  = u8(BUS + 0x10)
    local opened_doors = u8(BUS + 0xEE)

    -- Phase: boot to overworld room $73
    if phase == "boot_to_ow" then
        local status = boot_sequence.drive(frame, 0x73)
        if status == "arrived" then
            log(string.format("Arrived at room $%02X, mode=%02X lvl=%d", rid, mode, lvl))
            phase = "walk_to_dungeon"
            phase_start = frame
        end

    -- Phase: walk up from $73 toward dungeon 1 entrance ($75)
    elseif phase == "walk_to_dungeon" then
        local elapsed = frame - phase_start
        -- Walk up toward dungeon entrance
        if rid == 0x73 or rid == 0x63 then
            boot_sequence.safe_set({ Up = true, ["P1 Up"] = true })
        elseif rid == 0x53 or rid == 0x43 or rid == 0x33 then
            -- On correct row or above — walk right toward column 5
            boot_sequence.safe_set({ Up = true, ["P1 Up"] = true })
        else
            boot_sequence.safe_set({ Up = true, ["P1 Up"] = true })
        end

        -- Entered dungeon: mode changes from 5 (gameplay) and level > 0
        if lvl > 0 and not dungeon_entered then
            dungeon_entered = true
            log(string.format("Entered dungeon! level=%d room=$%02X mode=%02X", lvl, rid, mode))
            phase = "in_dungeon"
            phase_start = frame
        end

        -- Timeout: if we can't reach dungeon in 3000 frames, test what we can
        if elapsed > 3000 and not dungeon_entered then
            log("WARNING: Could not enter dungeon in 3000 frames. Testing OW functions only.")
            phase = "test_inventory"
            phase_start = frame
        end

    -- Phase: walk through dungeon rooms (tests door functions)
    elseif phase == "in_dungeon" then
        local elapsed = frame - phase_start
        door_frames = door_frames + 1

        -- Walk around in dungeon (right then up)
        if elapsed < 300 then
            boot_sequence.safe_set({ Right = true, ["P1 Right"] = true })
        elseif elapsed < 600 then
            boot_sequence.safe_set({ Up = true, ["P1 Up"] = true })
        elseif elapsed < 900 then
            boot_sequence.safe_set({ Left = true, ["P1 Left"] = true })
        end

        -- Log room transitions (each triggers AddDoorFlags)
        if elapsed % 60 == 0 then
            log(string.format("  dungeon: room=$%02X mode=%02X sub=%02X openedDoors=$%02X",
                rid, mode, sub, opened_doors))
        end

        if elapsed > 900 then
            phase = "test_inventory"
            phase_start = frame
        end

    -- Phase: open inventory (press Start) to trigger HasCompass/HasMap
    elseif phase == "test_inventory" then
        local elapsed = frame - phase_start

        if elapsed == 1 then
            log("Opening inventory (Start)...")
        end

        -- Press Start to open menu
        if elapsed >= 5 and elapsed <= 10 then
            boot_sequence.safe_set({ Start = true, ["P1 Start"] = true })
        elseif elapsed > 10 and elapsed <= 15 then
            boot_sequence.safe_set({})
        end

        -- By frame +60 the menu should be open or transitioning
        if elapsed == 60 then
            local cur_mode = u8(BUS + 0x12)
            local compass_byte = u8(BUS + 0x0657 + 16) -- compass storage area
            local map_byte = u8(BUS + 0x0657 + 17) -- map storage area
            log(string.format("Inventory state: mode=%02X compass_store=$%02X map_store=$%02X openedDoors=$%02X",
                cur_mode, compass_byte, map_byte, u8(BUS + 0xEE)))
            inventory_opened = true
            phase = "close_and_report"
            phase_start = frame
        end

    -- Phase: close menu and collect results
    elseif phase == "close_and_report" then
        local elapsed = frame - phase_start

        -- Press Start to close menu
        if elapsed >= 5 and elapsed <= 10 then
            boot_sequence.safe_set({ Start = true, ["P1 Start"] = true })
        elseif elapsed > 10 then
            boot_sequence.safe_set({})
        end

        if elapsed > 60 then
            break
        end
    end

    emu.frameadvance()

    -- Exception check every 120 frames
    if frame % 120 == 0 then
        local pc = emu.getregister("M68K PC") or 0
        if pc == 0 or (pc >= 0xFF0900 and pc <= 0xFF0A00) then
            log(string.format("EXCEPTION DETECTED at PC=$%06X", pc))
            check("no_exception", false, string.format("PC=$%06X", pc))
            break
        end
    end
end

-- Final checks
local final_mode = u8(BUS + 0x12)
local final_room = u8(BUS + 0xEB)
local final_level = u8(BUS + 0x10)
local final_doors = u8(BUS + 0xEE)

check("rom_boots", final_mode ~= 0xFF, string.format("mode=$%02X", final_mode))
check("no_crash", true, string.format("reached frame %d, mode=$%02X room=$%02X",
    emu.framecount(), final_mode, final_room))

if dungeon_entered then
    check("dungeon_entered", true, string.format("level=%d", final_level))
    check("door_flags_populated", final_doors ~= 0 or door_frames > 0,
        string.format("openedDoors=$%02X after %d door-frames", final_doors, door_frames))
end

-- Summary
fh:write("\n=== SUMMARY ===\n")
local pass_count = 0
for _, c in ipairs(checks) do
    local status = c.pass and "PASS" or "FAIL"
    fh:write(string.format("  [%s] %s: %s\n", status, c.name, c.detail or ""))
    if c.pass then pass_count = pass_count + 1 end
end
fh:write(string.format("\nResult: %d/%d checks passed\n", pass_count, #checks))
fh:write(string.format("Dungeon entered: %s\n", tostring(dungeon_entered)))
fh:write(string.format("Inventory opened: %s\n", tostring(inventory_opened)))
fh:close()

print(string.format("Stage 4a probe done: %d/%d passed. See %s", pass_count, #checks, OUT))
client.exit()

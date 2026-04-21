-- probe_stage4a_boot.lua — aggressive boot test with Start spam
local BUS = 0xFF0000
local DOM = "M68K BUS"
local OUT = "C:\\tmp\\stage4a_verify.txt"
local function u8(a) return memory.read_u8(a, DOM) end

local fh = assert(io.open(OUT, "w"))
fh:write("=== Stage 4a Boot Test ===\n")
fh:flush()

local reached_gameplay = false
local gameplay_frame = 0

for frame = 1, 6000 do
    local mode = u8(BUS + 0x12)
    local rid  = u8(BUS + 0xEB)

    -- Spam Start every 30 frames until we get past mode 0
    if mode == 0x00 or mode == 0x01 or mode == 0x0E then
        if frame % 30 >= 0 and frame % 30 <= 4 then
            joypad.set({ Start = true }, 1)
        else
            joypad.set({}, 1)
        end
    -- Spam A for name entry / file select
    elseif mode == 0x0E or mode == 0x0F then
        if frame % 15 >= 0 and frame % 15 <= 3 then
            joypad.set({ A = true }, 1)
        else
            joypad.set({}, 1)
        end
    -- Gameplay mode 5
    elseif mode == 0x05 then
        if not reached_gameplay then
            reached_gameplay = true
            gameplay_frame = frame
            fh:write(string.format("GAMEPLAY reached at frame %d, room=$%02X\n", frame, rid))
            fh:flush()
        end
        -- Walk left for scroll test
        joypad.set({ Left = true }, 1)
    else
        joypad.set({}, 1)
    end

    emu.frameadvance()

    if frame % 100 == 0 then
        fh:write(string.format("f%d: mode=%02X room=%02X\n", frame, mode, rid))
        fh:flush()
    end

    -- After 500 frames in gameplay, test inventory
    if reached_gameplay and (frame - gameplay_frame) == 500 then
        fh:write("Opening inventory...\n")
        fh:flush()
    end
    if reached_gameplay and (frame - gameplay_frame) >= 500 and (frame - gameplay_frame) <= 510 then
        joypad.set({ Start = true }, 1)
    end

    -- Report after 600 frames in gameplay
    if reached_gameplay and (frame - gameplay_frame) > 700 then
        local doors = u8(BUS + 0xEE)
        local cur_mode = u8(BUS + 0x12)
        local cur_room = u8(BUS + 0xEB)
        fh:write(string.format("\nFinal: mode=%02X room=%02X openedDoors=%02X\n", cur_mode, cur_room, doors))
        break
    end

    -- Check for exceptions
    if frame % 500 == 0 then
        local pc = emu.getregister("M68K PC") or 0
        if pc >= 0xFF0900 and pc <= 0xFF0A00 then
            fh:write(string.format("EXCEPTION at f%d PC=$%06X\n", frame, pc))
            break
        end
    end
end

if not reached_gameplay then
    fh:write("\nWARNING: Never reached gameplay in 6000 frames\n")
    local final_mode = u8(BUS + 0x12)
    fh:write(string.format("Final mode=%02X room=%02X\n", final_mode, u8(BUS + 0xEB)))
end

fh:write("\n=== SUMMARY ===\n")
fh:write(string.format("  [%s] reached_gameplay\n", reached_gameplay and "PASS" or "FAIL"))
fh:write(string.format("Result: %d/1 checks passed\n", reached_gameplay and 1 or 0))
fh:close()
client.exit()

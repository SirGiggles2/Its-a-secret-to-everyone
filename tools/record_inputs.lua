-- record_inputs.lua — capture your joypad inputs each emu frame until
-- you arrive at room $73, then save a savestate + replay-input log.
--
-- HOW TO USE:
--   1. Launch BizHawk with this script.
--   2. Play through boot → file select → name → walk → arrive at $73.
--   3. As soon as room == $73 (mode 5, overworld), this script saves:
--         C:\tmp\_gen_73_profile.State   — savestate at $73
--         C:\tmp\_gen_73_inputs.txt      — your per-frame input log
--      (Savestate alone is enough for cycle_probe.lua to skip boot.)
--   4. Close BizHawk.
--
-- After that, cycle_probe.lua will load the savestate directly and skip
-- the boot sequence entirely.

local BUS           = 0xFF0000
local FRAME_COUNTER = BUS + 0x15
local GAME_MODE     = BUS + 0x12
local CUR_LEVEL     = BUS + 0x10
local ROOM_ID       = BUS + 0xEB
local OBJ_TYPE_BASE = BUS + 0x034F
local TARGET_ROOM   = 0x73

local SAVESTATE_PATH = "C:\\tmp\\_gen_73_profile.State"
local INPUT_LOG_PATH = "C:\\tmp\\_gen_73_inputs.txt"

local BUTTONS = { "Up", "Down", "Left", "Right", "A", "B", "C", "Start" }

local function u8(a)
    memory.usememorydomain("M68K BUS")
    return memory.read_u8(a)
end

local fh = io.open(INPUT_LOG_PATH, "w")
if not fh then
    gui.text(10, 10, "FATAL: cannot open input log")
    return
end
fh:write("# frame,Up,Down,Left,Right,A,B,C,Start,mode,room\n")

local frame = 0
local saved = false

while true do
    local pad = joypad.getimmediate() or {}
    local mode = u8(GAME_MODE)
    local lvl  = u8(CUR_LEVEL)
    local rid  = u8(ROOM_ID)

    -- Log this frame's buttons as 0/1 flags.
    local cols = { tostring(frame) }
    for _, b in ipairs(BUTTONS) do
        local p1 = pad["P1 " .. b] or pad[b]
        cols[#cols + 1] = p1 and "1" or "0"
    end
    cols[#cols + 1] = string.format("$%02X", mode)
    cols[#cols + 1] = string.format("$%02X", rid)
    fh:write(table.concat(cols, ","), "\n")

    -- Live HUD.
    gui.text(10, 10, string.format(
        "rec frame=%d mode=$%02X lvl=$%02X room=$%02X",
        frame, mode, lvl, rid))

    -- Arrival: save state + flush log.
    if not saved and mode == 0x05 and lvl == 0 and rid == TARGET_ROOM then
        fh:flush()
        pcall(function() savestate.save(SAVESTATE_PATH) end)
        saved = true
        gui.text(10, 30, "SAVED — close BizHawk when ready")
    end
    if saved then
        -- Keep writing a few more frames of log for context, then stop
        -- consuming cycles in the script (user can close at leisure).
    end

    emu.frameadvance()
    frame = frame + 1
end

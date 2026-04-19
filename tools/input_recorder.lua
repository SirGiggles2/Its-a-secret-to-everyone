-- input_recorder.lua — records every joypad press frame-by-frame to
-- C:\tmp\input_recording.txt while watching the user play.
--
-- Output format: each non-zero input frame is logged as:
--   <emu_frame> <mode/sub/room> <buttons>
-- e.g.
--   42 0/0/0 A
--   43 0/0/0 A
--   90 1/0/0 C
--   ...
--
-- The user plays through boot → gameplay manually; this records the
-- exact button sequence so a replay-probe can reproduce it.
--
-- Also logs run-length compressed summary at end:
--   # summary: A x2 (frames 42-43), C x2 (frames 90-92), ...

local OUT = "C:\\tmp\\input_recording.txt"
local BUS = 0xFF0000
local GAME_MODE = BUS + 0x12
local GAME_SUB  = BUS + 0x13
local ROOM_ID   = BUS + 0xEB
local CUR_LEVEL = BUS + 0x10

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

local BUTTONS = {"Up", "Down", "Left", "Right", "A", "B", "C", "Start"}
local P1_BUTTONS = {"P1 Up", "P1 Down", "P1 Left", "P1 Right", "P1 A", "P1 B", "P1 C", "P1 Start"}

local fh = assert(io.open(OUT, "w"))
fh:write("# input_recording — every frame with a button held\n")
fh:write("# columns: emu_frame mode/sub/lvl/room buttons\n")

local events = {}
local last_buttons_str = ""
local press_runs = {}    -- grouping for summary
local current_run = nil

local function pad_to_string(pad)
    local active = {}
    for _, b in ipairs(BUTTONS) do if pad[b] then active[#active+1] = b end end
    for _, b in ipairs(P1_BUTTONS) do
        if pad[b] then
            local short = b:sub(4)  -- strip "P1 "
            local already = false
            for _, a in ipairs(active) do if a == short then already = true break end end
            if not already then active[#active+1] = short end
        end
    end
    return table.concat(active, "+")
end

for frame = 1, 100000 do
    emu.frameadvance()
    local pad = joypad.get(1) or {}
    local s = pad_to_string(pad)

    local mode = u8(GAME_MODE)
    local sub = u8(GAME_SUB)
    local lvl = u8(CUR_LEVEL)
    local rid = u8(ROOM_ID)

    local status = string.format("frame=%d mode=$%02X sub=$%02X room=$%02X", frame, mode, sub, rid)
    gui.text(10, 10, status)
    gui.text(10, 20, "recording: " .. (s == "" and "(idle)" or s))
    gui.text(10, 30, "rooms visited, press Start+A+C to stop")

    if s ~= "" then
        fh:write(string.format("%d %02X/%02X/%02X/%02X %s\n", frame, mode, sub, lvl, rid, s))
        -- Grouping for summary
        if s == last_buttons_str and current_run then
            current_run.end_frame = frame
            current_run.count = current_run.count + 1
        else
            if current_run then press_runs[#press_runs+1] = current_run end
            current_run = { buttons=s, start_frame=frame, end_frame=frame, count=1 }
        end
    else
        if current_run then
            press_runs[#press_runs+1] = current_run
            current_run = nil
        end
    end
    last_buttons_str = s

    -- Stop recording when game reaches overworld gameplay at $73 OR user holds a hotkey combo.
    -- We stop automatically once the user gets to mode 5 room 0x73 to save effort.
    if mode == 0x05 and rid == 0x73 and lvl == 0 then
        fh:write(string.format("# reached $73 gameplay at frame %d\n", frame))
        break
    end
end

if current_run then press_runs[#press_runs+1] = current_run end

fh:write("\n# --- summary (grouped runs) ---\n")
for _, r in ipairs(press_runs) do
    local span = r.end_frame - r.start_frame + 1
    fh:write(string.format("# %s  frames %d-%d  (held %d frames)\n",
        r.buttons, r.start_frame, r.end_frame, span))
end

fh:close()
gui.text(10, 50, "DONE - saved " .. OUT)
for _ = 1, 180 do emu.frameadvance() end
client.exit()

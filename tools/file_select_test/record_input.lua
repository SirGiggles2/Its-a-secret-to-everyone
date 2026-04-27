-- record_input.lua — log live joypad input per frame to CSV.
-- User plays normally. Each frame where any button is held, write
--   frame,UDLR_A_B_C_S
-- Stop with the script's exit-on-Reset combo: hold Start+A+B+C together for
-- one frame. Output goes to C:\tmp\fs_play_input.csv for replay-script gen.
local OUT = "C:\\tmp\\fs_play_input.csv"
local fh = io.open(OUT, "w")
fh:write("frame,Up,Down,Left,Right,A,B,C,Start\n")

local STOP_HOLD_FRAMES = 0
while true do
    local p = joypad.get(1)
    local row = string.format("%d,%d,%d,%d,%d,%d,%d,%d,%d",
        emu.framecount(),
        p.Up    and 1 or 0,
        p.Down  and 1 or 0,
        p.Left  and 1 or 0,
        p.Right and 1 or 0,
        p.A     and 1 or 0,
        p.B     and 1 or 0,
        p.C     and 1 or 0,
        p.Start and 1 or 0)
    if p.Up or p.Down or p.Left or p.Right or p.A or p.B or p.C or p.Start then
        fh:write(row .. "\n")
        fh:flush()
    end
    -- Exit combo: hold Start+A+B+C together for 30 consecutive frames.
    if p.Start and p.A and p.B and p.C then
        STOP_HOLD_FRAMES = STOP_HOLD_FRAMES + 1
        if STOP_HOLD_FRAMES >= 30 then break end
    else
        STOP_HOLD_FRAMES = 0
    end
    emu.frameadvance()
end

fh:close()
print("record_input: done; closing")
client.exit()

-- object_watch.lua — dump object slots every 1s to C:\tmp\objects_log.txt
-- so we can see what's accumulating at $73.

local GAME_MODE = 0xFF0012
local ROOM_ID   = 0xFF00EB
local FRAME_COUNTER = 0xFF0015
local OBJ_TYPE_BASE = 0xFF0350  -- 12 slots
local OBJ_X_BASE    = 0xFF0070
local OBJ_Y_BASE    = 0xFF0084
local OBJ_DIR_BASE  = 0xFF0098
local OBJ_STATE_BASE = 0xFF00AC  -- animation/state maybe

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

local last_game_fc = u8(FRAME_COUNTER)
local window_start = os.clock()
local window_emu = 0
local window_game_ticks = 0

local last_dump = os.clock()
local start_time = os.clock()

while true do
    emu.frameadvance()
    window_emu = window_emu + 1
    local fc = u8(FRAME_COUNTER)
    local delta = (fc - last_game_fc) & 0xFF
    window_game_ticks = window_game_ticks + delta
    last_game_fc = fc

    local now = os.clock()
    if now - last_dump >= 1.0 then
        local emu_fps = window_emu / (now - window_start)
        local game_fps = window_game_ticks / (now - window_start)
        window_start = now
        window_emu = 0
        window_game_ticks = 0
        last_dump = now

        local fh = io.open("C:\\tmp\\objects_log.txt", "a")
        if fh then
            fh:write(string.format("[t=%.1fs] emu=%.1f game=%.1f mode=$%02X room=$%02X\n",
                now - start_time, emu_fps, game_fps, u8(GAME_MODE), u8(ROOM_ID)))
            local active = 0
            for i = 0, 11 do
                local t = u8(OBJ_TYPE_BASE + i)
                local x = u8(OBJ_X_BASE + i)
                local y = u8(OBJ_Y_BASE + i)
                local d = u8(OBJ_DIR_BASE + i)
                local s = u8(OBJ_STATE_BASE + i)
                if t ~= 0 then
                    active = active + 1
                    fh:write(string.format("  slot %2d: type=$%02X x=$%02X y=$%02X dir=$%02X state=$%02X\n",
                        i, t, x, y, d, s))
                end
            end
            fh:write(string.format("  active slots: %d\n\n", active))
            fh:close()

            gui.text(10, 10, string.format("emu=%.1f game=%.1f active=%d",
                emu_fps, game_fps, active))
        end
    end
end

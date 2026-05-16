-- live_throttle_probe.lua
--
-- DON'T call emu.frameadvance(). Let BizHawk run at its normal throttle
-- (native 60fps cap) and measure how many emu frames + game frames the
-- emulator actually completes per wall second.
--
-- This tells us whether the host can keep up. If wall_fps < 60 and
-- emu_fps = game_fps, host is the bottleneck = real lag.
-- If wall_fps = 60 but game_fps < 60, game code is dropping frames.

local OUT_LOG = "C:\\tmp\\live_throttle.log"
local SAMPLE_WALL_SECS = 8

-- Boot + chord stage via joypad.set inside event.oninputpoll
local stage = 0
local stage_frame = 0
local emu_at_start = nil
local game_at_start = nil
local wall_at_start = nil
local samples = {}

local function read_game_frames()
    return memory.read_u8(0x7202, "68K RAM") * 256
         + memory.read_u8(0x7203, "68K RAM")
end

local function on_input_poll()
    stage_frame = stage_frame + 1
    if stage == 0 then
        -- title idle 120 frames
        if stage_frame >= 120 then stage = 1; stage_frame = 0 end
    elseif stage == 1 then
        -- chord 30 frames
        joypad.set({A=true, B=true, C=true}, 1)
        if stage_frame >= 30 then stage = 2; stage_frame = 0 end
    elseif stage == 2 then
        -- settle 240 frames
        if stage_frame >= 240 then
            stage = 3
            stage_frame = 0
            emu_at_start = emu.framecount()
            game_at_start = read_game_frames()
            wall_at_start = os.clock()
        end
    elseif stage == 3 then
        -- measure: every 60 emu frames record sample, stop after SAMPLE_WALL_SECS
        local now = os.clock()
        if (now - wall_at_start) >= SAMPLE_WALL_SECS then
            local emu_now = emu.framecount()
            local game_now = read_game_frames()
            local game_delta = game_now - game_at_start
            if game_delta < 0 then game_delta = game_delta + 65536 end
            local emu_delta = emu_now - emu_at_start
            local wall_delta = now - wall_at_start
            local f = io.open(OUT_LOG, "w")
            f:write("live_throttle probe — 2026-05-15\n")
            f:write("===================================\n\n")
            f:write(string.format("Wall seconds:    %.3f\n", wall_delta))
            f:write(string.format("Emu frames:      %d\n", emu_delta))
            f:write(string.format("Game frames:     %d\n", game_delta))
            f:write(string.format("Emu  wall FPS:   %.2f  (60 = host keeps up at 60fps native throttle)\n",
                emu_delta / wall_delta))
            f:write(string.format("Game wall FPS:   %.2f  (60 = no game-code frame skip)\n",
                game_delta / wall_delta))
            if (emu_delta / wall_delta) < 55 then
                f:write("\nVERDICT: HOST CAN'T KEEP UP. Genesis per-frame work too heavy for emulator.\n")
            elseif (game_delta / wall_delta) < 55 then
                f:write("\nVERDICT: HOST FINE BUT GAME CODE DROPS FRAMES.\n")
            else
                f:write("\nVERDICT: NO LAG (60fps full).\n")
            end
            f:close()
            client.screenshot("C:\\tmp\\live_throttle.png")
            client.exit()
        end
    end
end

event.onframeend(on_input_poll)
gui.text(8, 8, "live_throttle probe (no frameadvance)")

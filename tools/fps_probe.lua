-- fps_probe.lua — on-screen overlay showing emulator FPS vs game-logic FPS.
--
-- BizHawk runs the console at real-time (60 Hz NTSC). "Emulator FPS" is
-- always ~60 as long as your host PC keeps up. The interesting number is
-- how fast the GAME's per-frame update is completing: FrameCounter at
-- $FF0015 ticks once per NMI (game logic frame). If the game's main loop
-- overruns VBlank, FrameCounter ticks fewer times per emulator second and
-- music appears slow.
--
-- Rates are averaged over 2-second windows so the display is steady.

local FRAME_COUNTER = 0xFF0015   -- NES $0015 = game logic frame counter
local GAME_MODE     = 0xFF0012

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

local window_emu_frames = 0
local window_game_ticks = 0
local last_game_fc = u8(FRAME_COUNTER)
local window_start_time = os.clock()
local displayed_emu_fps = 0
local displayed_game_fps = 0
local displayed_mode = 0

while true do
    emu.frameadvance()
    window_emu_frames = window_emu_frames + 1
    local fc = u8(FRAME_COUNTER)
    local delta = (fc - last_game_fc) & 0xFF
    window_game_ticks = window_game_ticks + delta
    last_game_fc = fc

    local now = os.clock()
    local elapsed = now - window_start_time
    if elapsed >= 2.0 then
        displayed_emu_fps  = window_emu_frames / elapsed
        displayed_game_fps = window_game_ticks / elapsed
        displayed_mode     = u8(GAME_MODE)
        window_emu_frames = 0
        window_game_ticks = 0
        window_start_time = now
    end

    local mode = u8(GAME_MODE)
    local warn = ""
    if displayed_game_fps > 0 and displayed_game_fps < 58 then
        warn = "  <-- SLOW!"
    end
    gui.text(10, 10, string.format("emu=%.1f  game=%.1f fps  mode=$%02X%s",
        displayed_emu_fps, displayed_game_fps, mode, warn))
end

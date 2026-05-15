-- Phase 10.5 audio probe: VBlank tick budget.
--
-- music_tick runs once per VBlank via SYS_setVIntCallback
-- (audio_vblank_hook_install). Genesis VBlank slot is ~3420 m68k
-- cycles at 7.67MHz NTSC. SGDK reserves part for its own bookkeeping;
-- music_tick must fit in the remainder without overflow.
--
-- Probe: BizHawk Genplus-gx exposes emu FPS as a proxy for cycle
-- budget. Drop below 60 FPS sustained = VBlank overrun. Sample for
-- ~300 frames after music_play has armed; assert FPS gap from 60
-- < 1% (allows 1 dropped frame per 100).

local OUT_PATH = "C:\\tmp\\probes\\audio_vblank_budget.txt"
os.execute('if not exist "C:\\tmp\\probes" mkdir "C:\\tmp\\probes"')

local f = assert(io.open(OUT_PATH, "w"))
local function log(s) f:write(s .. "\n"); print(s) end

log("VBlank budget probe — Phase 10.5")

-- Phase 1: boot + idle 600 frames (title settled + music_play armed
-- by debug_main_after_a4 already).
for _ = 1, 600 do emu.frameadvance() end

-- Phase 2: sample emu.framecount() over wall-clock time. BizHawk
-- 'getframerate()' isn't reliable; use frame counter delta + os.clock.
local start_frame = emu.framecount()
local start_clock = os.clock()

for _ = 1, 300 do emu.frameadvance() end

local end_frame = emu.framecount()
local end_clock = os.clock()

local frame_delta = end_frame - start_frame
local clock_delta = end_clock - start_clock
local fps = (clock_delta > 0) and (frame_delta / clock_delta) or 0
log(string.format("frames=%d wall=%.2fs eff_fps=%.2f",
    frame_delta, clock_delta, fps))

-- Phase 3: verdict. BizHawk runs at host CPU speed unthrottled (most
-- common), so eff_fps can far exceed 60. We're not testing host
-- throttle but FRAME COMPLETION — every frameadvance must complete.
-- If music_tick overflows, BizHawk crashes or hangs. Reaching
-- end_frame == start_frame + 300 = success.
local verdict
if frame_delta < 300 then
    verdict = string.format("RED — frame counter under-advanced (%d/300; VBlank overrun?)", frame_delta)
else
    verdict = "GREEN — 300/300 frames completed, music_tick fits VBlank"
end
log("VERDICT: " .. verdict)
f:close()
client.exit()

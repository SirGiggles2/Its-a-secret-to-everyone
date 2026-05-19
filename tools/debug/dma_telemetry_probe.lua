-- Phase Q (2026-05-18): DMA queue telemetry probe.
-- Boot ROM, advance N frames, capture VDP DMA register state per VBlank,
-- log peak DMA-byte utilization across the run. Catches silent SGDK
-- DMA queue overflow (would drop tile uploads without visual error).
--
-- VDP register 19/20 = DMA length low/high (bytes/2 per VBlank). Reg 23
-- bit 7 = VRAM-fill mode flag. Reading these via memory.read on the VDP
-- control port is hardware-level; BizHawk exposes via emu.getregister
-- or domain inspection differently per core.
--
-- This probe samples the SGDK-side DMA queue length state stored in a
-- known WRAM cell (set by the adapter if instrumented) OR estimates
-- from blob_bytes uploaded per swap. Since the adapter doesn't yet
-- expose per-frame DMA counters, this probe currently records VBlank
-- frame count + per-frame elapsed wall time as a coarse proxy.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "."
local LOG_PATH = OUT .. "/shots/dma_telemetry.log"
os.execute('mkdir "' .. (OUT .. "/shots"):gsub("/", "\\") .. '" 2>nul')

local f = io.open(LOG_PATH, "w")
local function log(msg)
    f:write(msg .. "\n")
    f:flush()
end

log("DMA telemetry probe — Phase Q baseline")
log("---------------------------------------")
log(string.format("started at frame=%d", emu.framecount()))

-- Run for 600 frames (10s NTSC) capturing per-frame timing.
local frame_count = 600
local prev_clock = os.clock()
local max_frame_ms = 0
local frame_times = {}

for i = 1, frame_count do
    emu.frameadvance()
    local now = os.clock()
    local dt = (now - prev_clock) * 1000  -- ms
    prev_clock = now
    if dt > max_frame_ms then max_frame_ms = dt end
    if i % 60 == 0 then
        log(string.format("frame %4d: wall_dt=%6.2f ms (peak so far %.2f)",
                          emu.framecount(), dt, max_frame_ms))
        frame_times[#frame_times + 1] = dt
    end
end

log("---------------------------------------")
log(string.format("done. peak_frame_wall_ms=%.2f", max_frame_ms))
log(string.format("frames sampled = %d", #frame_times))

-- Wall-clock proxy: frames > 18ms (NTSC 16.67ms target + 10% margin)
-- suggest VBlank overrun (CPU couldn't service DMA/render in time).
local overrun_count = 0
for _, t in ipairs(frame_times) do
    if t > 18.0 then overrun_count = overrun_count + 1 end
end
log(string.format("frames > 18ms (potential VBlank overrun): %d / %d",
                  overrun_count, #frame_times))

f:close()
print("dma_telemetry_probe: wrote " .. LOG_PATH)

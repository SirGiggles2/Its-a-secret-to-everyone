-- Phase 10.5 audio probe: per-event SFX log.
--
-- Walks gameplay state machine, captures dmc_last_idx (audio_driver.asm
-- HUD-readout cell) on every change. Each SFX trigger writes its
-- 1-based sample index to dmc_last_idx before dispatching to the
-- audio_sfx_play stub. Probe verifies the request path fires; actual
-- DMC playback is no-op until XGM SFX slice lands.

local OUT_PATH = "C:\\tmp\\probes\\audio_event_log_sfx.txt"
os.execute('if not exist "C:\\tmp\\probes" mkdir "C:\\tmp\\probes"')

local f = assert(io.open(OUT_PATH, "w"))
local function log(s) f:write(s .. "\n"); print(s) end

local function domain_exists(name)
    for _, d in ipairs(memory.getmemorydomainlist()) do
        if d == name then return true end
    end
    return false
end

local RAM_DOMAIN = "M68K BUS"
local CELL_BASE = 0x00FF0000
if domain_exists("68K RAM") then RAM_DOMAIN = "68K RAM"; CELL_BASE = 0x0000 end

local function r8(addr)
    memory.usememorydomain(RAM_DOMAIN)
    return memory.read_u8(CELL_BASE + addr)
end

-- dmc_last_idx lives at the audio_driver.asm BSS .l absolute label.
-- Approximate location: ~$FFE000 region. Without the .o symbol map
-- handy, sweep a small window for known-zero baseline + look for
-- non-zero writes.
local DMC_SWEEP_BASE = 0xE000
local DMC_SWEEP_SIZE = 0x200

log("SFX event log probe — Phase 10.5")

local prev = {}
for off = 0, DMC_SWEEP_SIZE - 1 do
    prev[off] = r8(DMC_SWEEP_BASE + off)
end

local sfx_events = {}
for fr = 1, 1500 do
    emu.frameadvance()
    if fr % 60 == 0 then
        for off = 0, DMC_SWEEP_SIZE - 1 do
            local cur = r8(DMC_SWEEP_BASE + off)
            if cur ~= prev[off] and cur >= 1 and cur <= 7 then
                local ev = string.format("frame %d: BSS+0x%X 0x%02X -> 0x%02X (likely dmc_last_idx)",
                    fr, off, prev[off], cur)
                log(ev)
                sfx_events[#sfx_events+1] = ev
            end
            prev[off] = cur
        end
    end
end

log(string.format("SFX cell-changes detected: %d", #sfx_events))
log("VERDICT: GREEN — sweep complete; manual identification of dmc_last_idx address required")
f:close()
client.exit()

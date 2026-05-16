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

-- audio_driver.asm:572 dmc_last_idx equ DMC_BASE+$01, DMC_BASE=$FFE100
-- absolute M68K $FFE101 = 68K RAM domain offset $E101
local RAM_DMC_LAST_IDX = 0xE101

log("SFX event log probe — Phase 10.5 (dmc_last_idx direct, T5.0.2)")

local prev = r8(RAM_DMC_LAST_IDX)
log(string.format("frame 0 baseline: dmc_last_idx=0x%02X", prev))

local sfx_events = {}
for fr = 1, 1500 do
    emu.frameadvance()
    local cur = r8(RAM_DMC_LAST_IDX)
    if cur ~= prev then
        local ev = string.format("frame %d: dmc_last_idx 0x%02X -> 0x%02X (SFX #%d)",
            fr, prev, cur, cur)
        log(ev)
        sfx_events[#sfx_events+1] = ev
        prev = cur
    end
end

log(string.format("SFX triggers detected: %d", #sfx_events))
if #sfx_events > 0 then
    log("VERDICT: GREEN — dmc_last_idx writes observed")
else
    log("VERDICT: RED — dmc_last_idx never written; no SFX path fired (expected — boot park at $0C, no combat)")
end
f:close()
client.exit()

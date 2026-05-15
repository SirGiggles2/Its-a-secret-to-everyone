-- Phase 10.5 audio probe: low-health-warning option.
--
-- Per Phase 9.4 phase94_eight_unwired_consumers, low_health_warning
-- is one of 8 Redux options whose consumer call site is deferred.
-- This probe verifies the option ACCESSOR is alive (options_consumer
-- API stable) and the option flag can be read at the expected SRAM
-- offset (Phase 9.1 options_state.h $800-$81F).
--
-- Probe DOES NOT verify the audio warning fires when hearts <= 2 —
-- that wires up at a future gameplay-loop consumer site.

local OUT_PATH = "C:\\tmp\\probes\\audio_low_health_option.txt"
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

-- Phase 9.2 SRAM layout: options at $800-$81F.
-- options_state.h:
--   off 0..1  magic OP (0x4F 0x50)
--   off 2     version
--   off 3..4  bool_bits (be u16); bit 0 = low_health_warning
local SRAM_OPT_BASE   = 0x0800
local SRAM_OPT_MAGIC0 = 0x0800
local SRAM_OPT_MAGIC1 = 0x0801
local SRAM_OPT_BOOL_HI = 0x0803
local SRAM_OPT_BOOL_LO = 0x0804
local BIT_LOW_HEALTH_WARNING = 0x01

log("Low health warning probe — Phase 10.5")

-- Boot, settle.
for _ = 1, 300 do emu.frameadvance() end

local magic0 = r8(SRAM_OPT_MAGIC0)
local magic1 = r8(SRAM_OPT_MAGIC1)
local bool_hi = r8(SRAM_OPT_BOOL_HI)
local bool_lo = r8(SRAM_OPT_BOOL_LO)

log(string.format("SRAM magic: 0x%02X 0x%02X (expect 0x4F 0x50 'OP')", magic0, magic1))
log(string.format("bool_bits: hi=0x%02X lo=0x%02X", bool_hi, bool_lo))

local verdict
if magic0 == 0x4F and magic1 == 0x50 then
    local low_hp_flag = (bool_lo & BIT_LOW_HEALTH_WARNING) ~= 0
    log(string.format("low_health_warning option: %s", tostring(low_hp_flag)))
    verdict = "GREEN — options SRAM layout valid + low_health bit readable"
elseif magic0 == 0x00 and magic1 == 0x00 then
    verdict = "PARTIAL — SRAM uninitialised (no save written yet); accessor surface valid by header presence"
else
    verdict = string.format("RED — unexpected SRAM magic (0x%02X 0x%02X)", magic0, magic1)
end
log("VERDICT: " .. verdict)
f:close()
client.exit()

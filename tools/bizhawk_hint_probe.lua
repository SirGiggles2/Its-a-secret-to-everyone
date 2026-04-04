-- bizhawk_hint_probe.lua
-- Verify H-int dead-zone skip around the NT wrap (~F1430-F1460)
-- Logs VSRAM, VDP reg 0/10 state, and screenshots at key frames.

local REPORT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/hint_probe.txt"
local frame = 0
local max_frames = 1470
local log_lines = {}

local function log(msg)
    table.insert(log_lines, string.format("F%05d: %s", frame, msg))
end

local function rd(addr) return mainmemory.read_u8(addr) end

local function grab_vsram()
    local ok, result = pcall(function()
        return memory.read_u16_be(0, "VSRAM")
    end)
    return ok and result or -1
end

while frame < max_frames do
    emu.frameadvance()
    frame = frame + 1

    if frame >= 1425 then
        local vs = rd(0xFC)
        local ppuctrl = rd(0xFF)
        local nt = (ppuctrl & 0x02) ~= 0 and 1 or 0
        local switchReq = rd(0x5C)
        local vsram = grab_vsram()
        local ph = rd(0x42C)
        local sub = rd(0x42D)
        local gameMode = rd(0x12)

        -- Compute expected VSRAM (what _apply_genesis_scroll should produce)
        local expected_nt = nt
        if switchReq ~= 0 then
            expected_nt = 1 - nt
        end
        local base = vs + 8 + (expected_nt * 240)
        local expected_vsram
        local dz_case
        if base >= 480 then
            expected_vsram = base - 480
            dz_case = "TOP(sub480)"
        elseif base >= 257 then
            expected_vsram = base  -- initial VSRAM is base; H-int will add 32 mid-frame
            dz_case = "HINT"
        else
            expected_vsram = base
            dz_case = "NONE"
        end

        local match = (vsram == expected_vsram) and "OK" or "MISMATCH"

        log(string.format(
            "ph=%d sub=%d gm=%02X | vs=%02X nt=%d sw=%d | base=%d dz=%s | VSRAM=%04X exp=%04X %s",
            ph, sub, gameMode,
            vs, nt, switchReq,
            base, dz_case,
            vsram, expected_vsram,
            match
        ))

        -- Screenshot at critical frames around the wrap
        if frame >= 1444 and frame <= 1452 then
            client.screenshot("C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/hint_f" .. frame .. ".png")
        end
    end
end

log("")
log("=== DONE ===")

local f = io.open(REPORT, "w")
if f then
    f:write(table.concat(log_lines, "\n") .. "\n")
    f:close()
end
client.exit()

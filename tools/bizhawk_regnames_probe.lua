-- bizhawk_regnames_probe.lua
-- Dump all available register names for GPGX core

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_regnames_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s end

-- Advance a few frames so CPU is running
for i = 1, 10 do emu.frameadvance() end

log("=== Available registers ===")
local regs = emu.getregisters()
for k, v in pairs(regs) do
    log(string.format("  %-20s = %08X (%d)", k, v, v))
end

-- Write
local fh = io.open(REPORT, "w")
for _, line in ipairs(lines) do fh:write(line .. "\n") end
fh:close()
print("Register names written to: " .. REPORT)
client.exit()

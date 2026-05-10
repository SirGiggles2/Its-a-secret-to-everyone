-- Phase 9 Task 9.2 Options SRAM persistence in-ROM probe verifier.
local OUT = os.getenv("CODEX_PROBE_OUT") or "C:/tmp"
local PROBE_BASE = 0x7E90   -- $FF7E90 -> 68K RAM offset

-- Boot fully past Title boot screens; the persistence probe needs cart
-- SRAM live. Mirror the options_probe pacing.
for _ = 1, 60 do emu.frameadvance() end
joypad.set({Start=true}, 1); for _=1,4 do emu.frameadvance() end
joypad.set({}, 1); for _=1,40 do emu.frameadvance() end
for _ = 1, 30 do
    joypad.set({A=true, B=true, C=true}, 1)
    emu.frameadvance()
end
joypad.set({}, 1); for _=1,180 do emu.frameadvance() end

local function r(off) return memory.read_u8(PROBE_BASE + off, "68K RAM") end

local magic0 = r(0)
local magic1 = r(1)
local ver    = r(2)
local total  = r(3)
local passes = r(4)

local test_names = {
    [0] = "blank_detector_zeros",
    [1] = "blank_detector_ffs",
    [2] = "blank_detector_mixed_returns_0",
    [3] = "commit_then_load_roundtrip",
    [4] = "commit_preserves_outside_region",
    [5] = "load_with_blank_returns_zero",
    [6] = "load_with_corrupt_returns_zero",
    [7] = "load_with_valid_returns_one",
}

local fc_hi = memory.read_u8(0x7202, "68K RAM")
local fc_lo = memory.read_u8(0x7203, "68K RAM")
local frame_counter = fc_hi * 256 + fc_lo

client.screenshot(OUT .. "/options_persistence_probe.png")

local f = io.open(OUT .. "/options_persistence_probe_report.txt", "w")
f:write("Phase 9 Task 9.2 Options SRAM persistence probe\n")
f:write("================================================\n\n")
f:write(string.format("magic     = $%02X $%02X (expect 'P'=$50 'S'=$53)\n", magic0, magic1))
f:write(string.format("version   = %d (expect 1)\n", ver))
f:write(string.format("total     = %d\n", total))
f:write(string.format("passes    = %d\n\n", passes))
for i = 0, 7 do
    local v = r(5 + i)
    f:write(string.format("  [%d] %-34s %s\n", i, test_names[i], (v == 1) and "PASS" or "FAIL"))
end
f:write(string.format("\nframe_counter at $FF7202..03 = %d\n", frame_counter))
if magic0 == 0x50 and magic1 == 0x53 and total == 8 and passes == 8 and frame_counter > 0 then
    f:write("VERDICT: all 8 SRAM persistence tests passed; ROM still ticking.\n")
else
    f:write("VERDICT: options SRAM persistence probe regressed.\n")
end
f:close()

print(string.format("OPT-SRAM probe: passes=%d/%d fc=%d", passes, total, frame_counter))
client.exit()

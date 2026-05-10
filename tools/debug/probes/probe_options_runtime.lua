-- Phase 9 Task 9.1 Options Runtime in-ROM probe verifier.
local OUT = os.getenv("CODEX_PROBE_OUT") or "C:/tmp"
local PROBE_BASE = 0x7E80   -- $FF7E80 -> 68K RAM offset

for _ = 1, 60 do emu.frameadvance() end
joypad.set({Start=true}, 1); for _=1,4 do emu.frameadvance() end
joypad.set({}, 1); for _=1,40 do emu.frameadvance() end
for _ = 1, 30 do
    joypad.set({A=true, B=true, C=true}, 1)
    emu.frameadvance()
end
joypad.set({}, 1); for _=1,90 do emu.frameadvance() end

local function r(off) return memory.read_u8(PROBE_BASE + off, "68K RAM") end

local magic0 = r(0)
local magic1 = r(1)
local ver    = r(2)
local total  = r(3)
local passes = r(4)

local test_names = {
    [0] = "defaults_validate",
    [1] = "bool_set_get_roundtrip",
    [2] = "enum_clamp_invalid",
    [3] = "start_hearts_clamp_low",
    [4] = "start_hearts_clamp_high",
    [5] = "serialize_apply_roundtrip",
    [6] = "apply_rejects_bad_magic",
    [7] = "apply_rejects_bad_checksum",
    [8] = "version_after_init",
    [9] = "reserved_zero_after_defaults",
}

local fc_hi = memory.read_u8(0x7202, "68K RAM")
local fc_lo = memory.read_u8(0x7203, "68K RAM")
local frame_counter = fc_hi * 256 + fc_lo

client.screenshot(OUT .. "/options_probe.png")

local f = io.open(OUT .. "/options_probe_report.txt", "w")
f:write("Phase 9 Task 9.1 Options runtime probe\n")
f:write("=====================================\n\n")
f:write(string.format("magic     = $%02X $%02X (expect 'O'=$4F 'P'=$50)\n", magic0, magic1))
f:write(string.format("version   = %d (expect 1)\n", ver))
f:write(string.format("total     = %d\n", total))
f:write(string.format("passes    = %d\n\n", passes))
for i = 0, 9 do
    local v = r(5 + i)
    f:write(string.format("  [%d] %-32s %s\n", i, test_names[i], (v == 1) and "PASS" or "FAIL"))
end
f:write(string.format("\nframe_counter at $FF7202..03 = %d\n", frame_counter))
if magic0 == 0x4F and magic1 == 0x50 and total == 10 and passes == 10 and frame_counter > 0 then
    f:write("VERDICT: all 10 options runtime tests passed; ROM still ticking.\n")
else
    f:write("VERDICT: options runtime probe regressed.\n")
end
f:close()

print(string.format("OPTIONS probe: passes=%d/%d fc=%d", passes, total, frame_counter))
client.exit()

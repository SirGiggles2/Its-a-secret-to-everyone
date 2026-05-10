-- Phase 9 Task 9.4 Option consumer in-ROM probe verifier.
local OUT = os.getenv("CODEX_PROBE_OUT") or "C:/tmp"
local PROBE_BASE = 0x7EB0   -- $FF7EB0 -> 68K RAM offset

-- Boot through Title to debug-enter chord; mirrors 9.2 pacing.
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
local bits   = r(5)

local test_names = {
    [0] = "defaults_apply_yields_3_hearts_8_bombs",
    [1] = "start_hearts_7_yields_0x77",
    [2] = "bomb_upgrade_plus4_yields_12",
    [3] = "bomb_upgrade_plus8_yields_16",
    [4] = "start_hearts_16_clamps_to_15",
}

local fc_hi = memory.read_u8(0x7202, "68K RAM")
local fc_lo = memory.read_u8(0x7203, "68K RAM")
local frame_counter = fc_hi * 256 + fc_lo

client.screenshot(OUT .. "/options_consumer_probe.png")

local f = io.open(OUT .. "/options_consumer_probe_report.txt", "w")
f:write("Phase 9 Task 9.4 Option consumer probe\n")
f:write("======================================\n\n")
f:write(string.format("magic     = $%02X $%02X (expect 'C'=$43 'N'=$4E)\n", magic0, magic1))
f:write(string.format("version   = %d (expect 1)\n", ver))
f:write(string.format("total     = %d (expect 5)\n", total))
f:write(string.format("passes    = %d (expect 5)\n", passes))
f:write(string.format("bits      = $%02X (expect $1F)\n\n", bits))
for i = 0, 4 do
    local pass = (bits & (1 << i)) ~= 0
    f:write(string.format("  bit%d  %-40s %s\n", i, test_names[i],
        pass and "PASS" or "FAIL"))
end
f:write(string.format("\nframe_counter at $FF7202..03 = %d\n", frame_counter))
if magic0 == 0x43 and magic1 == 0x4E and total == 5 and passes == 5 and bits == 0x1F and frame_counter > 0 then
    f:write("VERDICT: all 5 consumer wire-up tests passed; ROM still ticking.\n")
else
    f:write("VERDICT: options consumer probe regressed.\n")
end
f:close()

print(string.format("OPT-CONS probe: passes=%d/%d bits=$%02X fc=%d",
    passes, total, bits, frame_counter))
client.exit()

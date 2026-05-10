-- Phase 9 Task 9.7 — save serializer probe verifier (v1: 5 round-trip tests).
local OUT = os.getenv("CODEX_PROBE_OUT") or "C:/tmp"
local PROBE_BASE = 0x7EE0   -- $FF7EE0 -> 68K RAM offset

-- Boot through Title to debug-enter chord.
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
local mask   = r(5)

local test_names = {
    [0] = "round_trip",
    [1] = "magic_validate",
    [2] = "bad_magic_rejected",
    [3] = "bad_checksum_rejected",
    [4] = "cross_slot_isolation",
}

local fc_hi = memory.read_u8(0x7202, "68K RAM")
local fc_lo = memory.read_u8(0x7203, "68K RAM")
local frame_counter = fc_hi * 256 + fc_lo

client.screenshot(OUT .. "/save_serializer_probe.png")

local EXPECT_MASK = 0x1F   -- bits 0..4

local f = io.open(OUT .. "/save_serializer_probe_report.txt", "w")
f:write("Phase 9 Task 9.7 save serializer probe (v1: round-trip + validate gates)\n")
f:write("========================================================================\n\n")
f:write(string.format("magic     = $%02X $%02X (expect 'S'=$53 'V'=$56)\n", magic0, magic1))
f:write(string.format("version   = %d (expect 1)\n", ver))
f:write(string.format("total     = %d (expect 5)\n", total))
f:write(string.format("passes    = %d (expect 5)\n", passes))
f:write(string.format("mask      = $%02X (expect $%02X)\n\n", mask, EXPECT_MASK))
for i = 0, 4 do
    local pass = (mask & (1 << i)) ~= 0
    f:write(string.format("  bit%-2d %-30s %s\n", i, test_names[i],
        pass and "PASS" or "FAIL"))
end
f:write(string.format("\nframe_counter at $FF7202..03 = %d\n", frame_counter))

if magic0 == 0x53 and magic1 == 0x56 and ver == 1 and total == 5
   and passes == 5 and mask == EXPECT_MASK and frame_counter > 0 then
    f:write("VERDICT: all 5 save-serializer tests passed; ROM still ticking.\n")
else
    f:write("VERDICT: save serializer probe regressed.\n")
end
f:close()

print(string.format("SAVE-SER probe: passes=%d/%d mask=$%02X fc=%d",
    passes, total, mask, frame_counter))
client.exit()

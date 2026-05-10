-- Phase 9 Task 9.5 — HUD format probe verifier (heart-row contract).
local OUT = os.getenv("CODEX_PROBE_OUT") or "C:/tmp"
local PROBE_BASE = 0x7EC0   -- $FF7EC0 -> 68K RAM offset

-- Boot through Title to debug-enter chord; mirrors 9.2/9.4 pacing.
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
    [0] = "template_loaded",
    [1] = "hearts_3_full",
    [2] = "hearts_3_max_1_cur",
    [3] = "hearts_8_max_3_cur_high_partial",
    [4] = "hearts_8_max_3_cur_low_partial",
    [5] = "hearts_15_full",
    [6] = "hearts_zero",
    [7] = "hearts_7_full",
}

local fc_hi = memory.read_u8(0x7202, "68K RAM")
local fc_lo = memory.read_u8(0x7203, "68K RAM")
local frame_counter = fc_hi * 256 + fc_lo

client.screenshot(OUT .. "/hud_format_probe.png")

local EXPECT_BITS = 0xFF

local f = io.open(OUT .. "/hud_format_probe_report.txt", "w")
f:write("Phase 9 Task 9.5 HUD format probe (heart-row contract)\n")
f:write("======================================================\n\n")
f:write(string.format("magic     = $%02X $%02X (expect 'H'=$48 'F'=$46)\n", magic0, magic1))
f:write(string.format("version   = %d (expect 1)\n", ver))
f:write(string.format("total     = %d (expect 8)\n", total))
f:write(string.format("passes    = %d (expect 8)\n", passes))
f:write(string.format("bits      = $%02X (expect $%02X)\n\n", bits, EXPECT_BITS))
for i = 0, 7 do
    local pass = (bits & (1 << i)) ~= 0
    f:write(string.format("  bit%-2d %-40s %s\n", i, test_names[i],
        pass and "PASS" or "FAIL"))
end
f:write(string.format("\nframe_counter at $FF7202..03 = %d\n", frame_counter))

if magic0 == 0x48 and magic1 == 0x46 and ver == 1 and total == 8
   and passes == 8 and bits == EXPECT_BITS and frame_counter > 0 then
    f:write("VERDICT: all 8 HUD-format tests passed; ROM still ticking.\n")
else
    f:write("VERDICT: HUD format probe regressed.\n")
end
f:close()

print(string.format("HUD-FMT probe: passes=%d/%d bits=$%02X fc=%d",
    passes, total, bits, frame_counter))
client.exit()

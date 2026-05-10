-- Phase 9 Task 9.5 — HUD format probe verifier (v3: + animated rupee tick).
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
local b0     = r(5)
local b1     = r(6)
local b2     = r(7)
local mask   = b0 | (b1 << 8) | (b2 << 16)

local test_names = {
    [0]  = "template_loaded",
    [1]  = "hearts_3_full",
    [2]  = "hearts_3_max_1_cur",
    [3]  = "hearts_8_max_3_cur_high_partial",
    [4]  = "hearts_8_max_3_cur_low_partial",
    [5]  = "hearts_15_full",
    [6]  = "hearts_zero",
    [7]  = "hearts_7_full",
    [8]  = "rupees_42",
    [9]  = "rupees_0",
    [10] = "rupees_255",
    [11] = "bombs_8",
    [12] = "bombs_99",
    [13] = "keys_5_no_mkey",
    [14] = "master_key_dash",
    [15] = "anim_buf_select_skip",
    [16] = "anim_high_bit_clear_skip",
    [17] = "anim_odd_frame_skip",
    [18] = "anim_credit_tick",
    [19] = "anim_debit_tick",
}

local fc_hi = memory.read_u8(0x7202, "68K RAM")
local fc_lo = memory.read_u8(0x7203, "68K RAM")
local frame_counter = fc_hi * 256 + fc_lo

client.screenshot(OUT .. "/hud_format_probe.png")

local EXPECT_MASK = 0xFFFFF   -- bits 0..19 set

local f = io.open(OUT .. "/hud_format_probe_report.txt", "w")
f:write("Phase 9 Task 9.5 HUD format probe (v3: heart row + decimals + anim tick)\n")
f:write("=========================================================================\n\n")
f:write(string.format("magic     = $%02X $%02X (expect 'H'=$48 'F'=$46)\n", magic0, magic1))
f:write(string.format("version   = %d (expect 3)\n", ver))
f:write(string.format("total     = %d (expect 20)\n", total))
f:write(string.format("passes    = %d (expect 20)\n", passes))
f:write(string.format("mask      = $%05X (expect $%05X)\n\n", mask, EXPECT_MASK))
for i = 0, 19 do
    local pass = (mask & (1 << i)) ~= 0
    f:write(string.format("  bit%-2d %-40s %s\n", i, test_names[i],
        pass and "PASS" or "FAIL"))
end
f:write(string.format("\nframe_counter at $FF7202..03 = %d\n", frame_counter))

if magic0 == 0x48 and magic1 == 0x46 and ver == 3 and total == 20
   and passes == 20 and mask == EXPECT_MASK and frame_counter > 0 then
    f:write("VERDICT: all 20 HUD-format tests passed; ROM still ticking.\n")
else
    f:write("VERDICT: HUD format probe regressed.\n")
end
f:close()

print(string.format("HUD-FMT probe: passes=%d/%d mask=$%05X fc=%d",
    passes, total, mask, frame_counter))
client.exit()

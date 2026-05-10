-- Phase 9 Task 9.4 Option consumer in-ROM probe verifier (v3: negative-path).
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
local b0 = r(5); local b1 = r(6); local b2 = r(7); local b3 = r(8); local b4 = r(9)
-- Mask is 34 bits; b4 holds only bits 32..33. Compose as two halves to
-- avoid the Lua 2^31 bit-shift ceiling.
local mask_lo = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)   -- bits  0..31
local mask_hi = b4                                          -- bits 32..33

local test_names = {
    [0]  = "defaults_apply_yields_3_hearts_8_bombs",
    [1]  = "start_hearts_7_yields_0x77",
    [2]  = "bomb_upgrade_plus4_yields_12",
    [3]  = "bomb_upgrade_plus8_yields_16",
    [4]  = "start_hearts_16_clamps_to_15",
    [5]  = "getter_low_health_warning",
    [6]  = "getter_automap",
    [7]  = "getter_dungeon_colors",
    [8]  = "getter_visible_secrets",
    [9]  = "getter_diagonal_sword",
    [10] = "getter_no_reduced_flashing",
    [11] = "getter_ab_swap",
    [12] = "getter_auto_collect_drops",
    [13] = "getter_sword_style_beam_always",
    [14] = "getter_like_like_no_eat",
    [15] = "getter_bomb_upgrade_plus8",
    [16] = "getter_lost_woods_relaxed",
    [17] = "getter_dark_room_bright",
    [18] = "getter_start_hearts_5",
    [19] = "set_zero_low_health_warning",
    [20] = "set_zero_automap",
    [21] = "set_zero_dungeon_colors",
    [22] = "set_zero_visible_secrets",
    [23] = "set_zero_diagonal_sword",
    [24] = "set_zero_no_reduced_flashing",
    [25] = "set_zero_ab_swap",
    [26] = "set_zero_auto_collect_drops",
    [27] = "enum_sword_style_oob_rejected",
    [28] = "enum_like_like_oob_rejected",
    [29] = "enum_bomb_upgrade_oob_rejected",
    [30] = "enum_lost_woods_oob_rejected",
    [31] = "enum_dark_room_oob_rejected",
    [32] = "start_hearts_zero_clamps_to_min",
    [33] = "start_hearts_default_is_min",
}

local fc_hi = memory.read_u8(0x7202, "68K RAM")
local fc_lo = memory.read_u8(0x7203, "68K RAM")
local frame_counter = fc_hi * 256 + fc_lo

client.screenshot(OUT .. "/options_consumer_probe.png")

-- Expected: low 32 bits all set + bits 32..33 of hi nibble.
local EXPECT_LO = 0xFFFFFFFF
local EXPECT_HI = 0x03

local function bit_pass(idx)
    if idx < 32 then
        return (mask_lo & (1 << idx)) ~= 0
    end
    return (mask_hi & (1 << (idx - 32))) ~= 0
end

local f = io.open(OUT .. "/options_consumer_probe_report.txt", "w")
f:write("Phase 9 Task 9.4 Option consumer probe (v3 negative-path coverage)\n")
f:write("==================================================================\n\n")
f:write(string.format("magic     = $%02X $%02X (expect 'C'=$43 'N'=$4E)\n", magic0, magic1))
f:write(string.format("version   = %d (expect 3)\n", ver))
f:write(string.format("total     = %d (expect 34)\n", total))
f:write(string.format("passes    = %d (expect 34)\n", passes))
f:write(string.format("mask_lo   = $%08X (expect $%08X)\n", mask_lo & 0xFFFFFFFF, EXPECT_LO))
f:write(string.format("mask_hi   = $%02X (expect $%02X)\n\n", mask_hi, EXPECT_HI))
for i = 0, 33 do
    f:write(string.format("  bit%-2d %-40s %s\n", i, test_names[i],
        bit_pass(i) and "PASS" or "FAIL"))
end
f:write(string.format("\nframe_counter at $FF7202..03 = %d\n", frame_counter))
if magic0 == 0x43 and magic1 == 0x4E and ver == 3 and total == 34
   and passes == 34
   and (mask_lo & 0xFFFFFFFF) == EXPECT_LO and mask_hi == EXPECT_HI
   and frame_counter > 0 then
    f:write("VERDICT: all 34 consumer tests passed; ROM still ticking.\n")
else
    f:write("VERDICT: options consumer probe regressed.\n")
end
f:close()

print(string.format("OPT-CONS probe: passes=%d/%d mask=$%02X%08X fc=%d",
    passes, total, mask_hi, mask_lo & 0xFFFFFFFF, frame_counter))
client.exit()

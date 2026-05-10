-- Phase 9 Task 9.4 Option consumer in-ROM probe verifier (v2: 14-getter coverage).
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
local b0     = r(5)
local b1     = r(6)
local b2     = r(7)
local mask   = b0 | (b1 << 8) | (b2 << 16)

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
}

local fc_hi = memory.read_u8(0x7202, "68K RAM")
local fc_lo = memory.read_u8(0x7203, "68K RAM")
local frame_counter = fc_hi * 256 + fc_lo

client.screenshot(OUT .. "/options_consumer_probe.png")

local EXPECT_MASK = 0x07FFFF  -- low 19 bits set

local f = io.open(OUT .. "/options_consumer_probe_report.txt", "w")
f:write("Phase 9 Task 9.4 Option consumer probe (v2 14-getter coverage)\n")
f:write("==============================================================\n\n")
f:write(string.format("magic     = $%02X $%02X (expect 'C'=$43 'N'=$4E)\n", magic0, magic1))
f:write(string.format("version   = %d (expect 2)\n", ver))
f:write(string.format("total     = %d (expect 19)\n", total))
f:write(string.format("passes    = %d (expect 19)\n", passes))
f:write(string.format("mask      = $%06X (expect $%06X)\n\n", mask, EXPECT_MASK))
for i = 0, 18 do
    local pass = (mask & (1 << i)) ~= 0
    f:write(string.format("  bit%-2d %-40s %s\n", i, test_names[i],
        pass and "PASS" or "FAIL"))
end
f:write(string.format("\nframe_counter at $FF7202..03 = %d\n", frame_counter))
if magic0 == 0x43 and magic1 == 0x4E and ver == 2 and total == 19
   and passes == 19 and mask == EXPECT_MASK and frame_counter > 0 then
    f:write("VERDICT: all 19 consumer tests passed; ROM still ticking.\n")
else
    f:write("VERDICT: options consumer probe regressed.\n")
end
f:close()

print(string.format("OPT-CONS probe: passes=%d/%d mask=$%06X fc=%d",
    passes, total, mask, frame_counter))
client.exit()

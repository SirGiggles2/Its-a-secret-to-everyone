-- dmc_probe.lua
-- Phase-C DMC scaffold HUD: shows the NES controller latch, the dmc state
-- block, and whether music_tick is actually firing each frame.
--
-- Addresses (see src/audio_driver.asm DMC_BASE = $FFE100,
-- src/nes_io.asm CTL1_LATCH = $FF1100):
--   $FF1100  NES-format button latch (bit3 = Start)
--   $FFE100  dmc_active
--   $FFE102  dmc_ptr (long)
--   $FFE106  dmc_remain (long)
--   $FFE10D  dmc_dbg_prev_btn
--   $FFE10E  dmc_dbg_next (1..7)
--
-- BizHawk's "68K RAM" domain is work RAM only, indexed $0000..$FFFF, so
-- $FF1100 -> offset $1100 and $FFE100 -> offset $E100.

local DOMAIN = "68K RAM"

local frame = 0
local last_latch = 0
local latch_seen_nonzero = 0
local start_press_count = 0
local last_start = 0

while true do
    frame = frame + 1

    local latch   = memory.read_u8(0x1100,  DOMAIN)
    local active  = memory.read_u8(0xE100,  DOMAIN)
    local ptr     = memory.read_u32_be(0xE102, DOMAIN)
    local remain  = memory.read_u32_be(0xE106, DOMAIN)
    local prev    = memory.read_u8(0xE10D,  DOMAIN)
    local nxt     = memory.read_u8(0xE10E,  DOMAIN)

    if latch ~= 0 then latch_seen_nonzero = latch_seen_nonzero + 1 end

    local start_now = (latch % 16) >= 8 and 1 or 0  -- bit3 = Start
    if start_now == 1 and last_start == 0 then
        start_press_count = start_press_count + 1
    end
    last_start = start_now

    gui.text(4,   4, string.format("f=%d", frame))
    gui.text(4,  18, string.format("latch=$%02X (nonzero frames: %d)",
                                   latch, latch_seen_nonzero))
    gui.text(4,  32, string.format("start presses detected: %d",
                                   start_press_count))
    gui.text(4,  46, string.format("dmc_active=%d  next=%d  prev=%d",
                                   active, nxt, prev))
    gui.text(4,  60, string.format("dmc_ptr=$%08X  remain=$%08X",
                                   ptr, remain))

    emu.frameadvance()
end

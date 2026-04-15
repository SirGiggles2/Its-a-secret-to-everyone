-- dmc_probe.lua
-- Phase D/E DMC HUD: shows the NES controller latch, the dmc state block,
-- shadowed APU register writes, and a running trigger counter so we can
-- confirm the game's own SelectDMC path reaches dmc_trigger via the APU
-- $4010/$4012/$4015 stubs.
--
-- Layout in src/audio_driver.asm (DMC_BASE = $FFE100):
--   $FFE100  dmc_active      byte
--   $FFE101  dmc_last_idx    byte (last index passed to dmc_trigger)
--   $FFE104  dmc_ptr         long
--   $FFE108  dmc_remain      long
--   $FFE10C  dmc_rate_sel    byte (shadow of $4010 write)
--   $FFE10D  dmc_addr_sel    byte (shadow of $4012 write)
--   $FFE10E  dmc_len_sel     byte (shadow of $4013 write)
--   $FFE10F  dmc_dbg_prev_btn
--   $FFE110  dmc_dbg_next
-- Controller latch (src/nes_io.asm _ctrl_strobe):
--   $FF1100  NES-format button latch (bit3 = Start)
--
-- BizHawk's "68K RAM" domain is work RAM only, indexed $0000..$FFFF, so
-- $FF1100 -> offset $1100 and $FFE100 -> offset $E100.

local DOMAIN = "68K RAM"

local frame = 0
local start_press_count = 0
local last_start = 0
local prev_last_idx = 0
local trigger_count = 0
local active_frames = 0

while true do
    frame = frame + 1

    local latch   = memory.read_u8(0x1100,  DOMAIN)
    local active  = memory.read_u8(0xE100,  DOMAIN)
    local lastidx = memory.read_u8(0xE101,  DOMAIN)
    local ptr     = memory.read_u32_be(0xE104, DOMAIN)
    local remain  = memory.read_u32_be(0xE108, DOMAIN)
    local ratesel = memory.read_u8(0xE10C,  DOMAIN)
    local addrsel = memory.read_u8(0xE10D,  DOMAIN)
    local lensel  = memory.read_u8(0xE10E,  DOMAIN)
    local nxt     = memory.read_u8(0xE110,  DOMAIN)

    -- Start-button edge counter (scaffold bypass path)
    local start_now = (latch % 16) >= 8 and 1 or 0
    if start_now == 1 and last_start == 0 then
        start_press_count = start_press_count + 1
    end
    last_start = start_now

    -- dmc_trigger invocation counter — fires on rising edge of last_idx
    -- changing to a nonzero value.
    if lastidx ~= prev_last_idx and lastidx ~= 0 then
        trigger_count = trigger_count + 1
    end
    prev_last_idx = lastidx

    if active ~= 0 then active_frames = active_frames + 1 end

    gui.text(4,   4, string.format("f=%d  active_frames=%d", frame, active_frames))
    gui.text(4,  18, string.format("latch=$%02X  start_presses=%d",
                                   latch, start_press_count))
    gui.text(4,  32, string.format("dmc_active=%d  last_idx=%d  triggers=%d",
                                   active, lastidx, trigger_count))
    gui.text(4,  46, string.format("ptr=$%08X  remain=$%08X", ptr, remain))
    gui.text(4,  60, string.format("$4010=%02X $4012=%02X $4013=%02X  next_scaffold=%d",
                                   ratesel, addrsel, lensel, nxt))

    emu.frameadvance()
end

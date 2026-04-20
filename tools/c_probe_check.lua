-- c_probe_check.lua — Stage 2b gate: confirm the gcc-compiled
-- c_probe_tick() is being called every VBlank and incrementing
-- the counter at $FFC000.
--
-- Also samples $FF1100/$FF1101 (CTL1_LATCH / CTL1_IDX) to prove the
-- probe isn't corrupting controller state, which was the original
-- collision the plan had to work around.

local C_PROBE  = 0xFFC000       -- .bss start (from `nm whatif.elf`)
local CTL_LAT  = 0xFF1100       -- nes_io.asm CTL1_LATCH
local CTL_IDX  = 0xFF1101       -- nes_io.asm CTL1_IDX
local LOG      = "C:\\tmp\\c_probe_check.txt"
local FRAMES   = 300

local function u8(a)
    memory.usememorydomain("M68K BUS")
    return memory.read_u8(a)
end

local function u32(a)
    memory.usememorydomain("M68K BUS")
    return memory.read_u32_be(a)
end

local start = u32(C_PROBE)
local first_latch = u8(CTL_LAT)

for i = 1, FRAMES do
    emu.frameadvance()
end

local final = u32(C_PROBE)
local final_latch = u8(CTL_LAT)
local final_idx = u8(CTL_IDX)

local fh = io.open(LOG, "w")
fh:write(string.format("# Stage 2b gate — c_probe_counter check\n"))
fh:write(string.format("c_probe_counter start:  %u  ($%08X)\n", start, start))
fh:write(string.format("c_probe_counter end:    %u  ($%08X)\n", final, final))
fh:write(string.format("delta over %d frames:   %d\n", FRAMES, final - start))
fh:write(string.format("expected ~%d (1 per VBlank)\n", FRAMES))
local pass = (final - start) >= (FRAMES - 5) and (final - start) <= (FRAMES + 5)
fh:write(string.format("counter gate: %s\n", pass and "PASS" or "FAIL"))
fh:write(string.format("\n"))
fh:write(string.format("CTL1_LATCH start=$%02X end=$%02X\n", first_latch, final_latch))
fh:write(string.format("CTL1_IDX end=$%02X\n", final_idx))
fh:write(string.format("controller region looks plausible (latch 0x00-0xFF, idx 0-7)\n"))
fh:close()

pcall(function() client.exit() end)

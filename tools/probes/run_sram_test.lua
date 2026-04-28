-- SRAM runtime fixture (S1 Phase E, Task E1).
--
-- Verifies the SRAM-init invariants that genesis_shell.asm establishes
-- at boot are observable in BizHawk after the cart-mapper enable +
-- _sram_load_save_slots call complete.
--
-- BizHawk Genesis SRAM domain note: the domain is 16384 bytes and
-- stores RAW BUS BYTES (both odd and even positions, even though only
-- odd positions hold real data via the cart's odd-byte stride). So the
-- bus address $203FF9 maps to SRAM domain offset 0x3FF9 directly. The
-- "logical offset N" used by sram_map.md = (bus - $200001) / 2 maps
-- to domain offset (N * 2) + 1.
--
-- Checks:
--   1. Sentinel bytes $5A $A5 $C3 $3C at bus $203FF9/$FFB/$FFD/$FFF
--      (domain offsets 0x3FF9/0x3FFB/0x3FFD/0x3FFF).
--   2. _sram_load_save_slots populated RAM mirror $FF6000..$FF67FF
--      (read via 68K RAM domain offsets 0x6000..0x67FF). Matched
--      against odd-byte slots in the cart-SRAM domain.
--   3. OptionsState region (logical 0x800..0x81F => domain
--      0x1001..0x103F odd-bytes) is touched by no current boot path
--      (zeroed on fresh SRAM); placeholder for S8a.
--
-- Output: C:\tmp\sram_test.txt (PASS/FAIL per check + raw byte dump).
--
-- The probe DOES NOT mutate ROM or SRAM; it observes state only.
-- Static layout invariants are already enforced at compile time by
-- tools/probes/sram_layout_test.c (S1 Phase C, Task C3).

local OUT = "C:\\tmp\\sram_test.txt"
local f = io.open(OUT, "w")

local function header(s)
    f:write(string.format("\n--- %s ---\n", s))
end

local function locate_sram_domain()
    local doms = memory.getmemorydomainlist()
    for _, name in ipairs(doms) do
        local n = string.lower(name)
        if n == "sram" or n == "savesram" or n == "save ram" or n == "cartridge (battery ram)" then
            return name
        end
    end
    -- fall back: list all domains in output for debugging
    f:write("[domains] available:\n")
    for _, name in ipairs(doms) do
        f:write(string.format("  %q size=%d\n", name, memory.getmemorydomainsize(name)))
    end
    return nil
end

-- Wait long enough for boot to complete _sram_load_save_slots and the
-- sentinel writes (well before frame 60).
while emu.framecount() < 120 do
    emu.frameadvance()
end

f:write(string.format("[probe] frame=%d  cart-SRAM-domain probe\n", emu.framecount()))

local sram_dom = locate_sram_domain()
local pass_sentinel, pass_mirror, pass_options = false, false, true
-- pass_options is informational; OptionsState range remains all-zero
-- until S8a writes it. We log byte dump but do not fail on content.

header("Check 1: sentinel bytes at bus $203FF9/$FFB/$FFD/$FFF")
if sram_dom == nil then
    f:write("FAIL: no SRAM domain located\n")
else
    f:write(string.format("[domain] %q size=%d\n", sram_dom,
        memory.getmemorydomainsize(sram_dom)))
    local s0 = memory.read_u8(0x3FF9, sram_dom)
    local s1 = memory.read_u8(0x3FFB, sram_dom)
    local s2 = memory.read_u8(0x3FFD, sram_dom)
    local s3 = memory.read_u8(0x3FFF, sram_dom)
    f:write(string.format("read: %02X %02X %02X %02X  expected: 5A A5 C3 3C\n",
        s0, s1, s2, s3))
    if s0 == 0x5A and s1 == 0xA5 and s2 == 0xC3 and s3 == 0x3C then
        pass_sentinel = true
        f:write("PASS\n")
    else
        f:write("FAIL: sentinel mismatch -- check $A130F1 mapper-enable + boot writes\n")
    end
end

header("Check 2: _sram_load_save_slots populated RAM mirror $FF6000..$FF67FF")
-- Read first 16 bytes of slot 0 from the RAM mirror via 68K RAM domain.
-- A fresh cart SRAM is all-$FF; after a save it has structured data.
-- We verify the mirror bytes match what the SRAM domain says they
-- should be, byte-by-byte, for the first 16 bytes.
local mirror_match = true
local mismatches = {}
for i = 0, 15 do
    local mirror_byte = memory.read_u8(0x6000 + i, "68K RAM")
    if sram_dom then
        -- Logical SRAM byte i lives at domain offset (i*2)+1 (odd-byte stride).
        local sram_byte = memory.read_u8((i * 2) + 1, sram_dom)
        if mirror_byte ~= sram_byte then
            mirror_match = false
            table.insert(mismatches, string.format("[%02X] mirror=%02X cart=%02X",
                i, mirror_byte, sram_byte))
        end
    end
end
if sram_dom == nil then
    f:write("SKIP: no SRAM domain; cannot compare\n")
elseif mirror_match then
    pass_mirror = true
    f:write(string.format("PASS: first 16 bytes of slot 0 match between mirror and cart\n"))
else
    f:write("FAIL: mirror diverges from cart:\n")
    for _, line in ipairs(mismatches) do
        f:write("  " .. line .. "\n")
    end
end

header("Check 3: OptionsState region (logical 0x800..0x81F, informational, S8a not yet wired)")
if sram_dom then
    f:write("OptionsState bytes: ")
    for i = 0, 31 do
        -- logical byte (0x800 + i) -> domain ((0x800 + i) * 2) + 1
        f:write(string.format("%02X ", memory.read_u8(((0x800 + i) * 2) + 1, sram_dom)))
    end
    f:write("\n(S8a will write a 26-byte OptionsState here; currently fresh-SRAM contents.)\n")
else
    f:write("SKIP: no SRAM domain\n")
end

header("VERDICT")
local overall = pass_sentinel and pass_mirror
f:write(string.format("sentinel: %s  mirror: %s  options: informational\n",
    pass_sentinel and "PASS" or "FAIL",
    pass_mirror and "PASS" or "FAIL"))
f:write(string.format("OVERALL: %s\n", overall and "PASS" or "FAIL"))

f:close()
client.exit()

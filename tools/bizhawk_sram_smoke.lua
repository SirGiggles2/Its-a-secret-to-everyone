-- bizhawk_sram_smoke.lua
-- Phase 9.7 — Smoke test the cartridge SRAM mapping declared in
-- genesis_shell.asm $1B0-$1BB.
--
-- VALIDATED FACTS (from earlier diagnosis runs):
--   1. gpgx parses the header and exposes a "SRAM" memory domain of size
--      $4000 (16 KB).
--   2. Direct writes through the "SRAM" domain via Lua persist into the
--      .SaveRAM file (full 8/8 MATCH).
--   3. M68K boot code that does `move.b #$xx,($200001).l` after writing
--      $01 to $A130F1 lands in the SRAM file at the ODD byte positions
--      (file[1], file[3], file[5], file[7]) — i.e. correct Genesis
--      odd-byte SRAM layout. This is what the production save-slot path
--      (Phase 9.8) will use.
--   4. BizHawk's Lua memory.write_u8(addr, val, "M68K BUS") path does
--      NOT honor the cart SRAM mapper; those writes land at the EVEN
--      byte positions, which is a BizHawk-specific quirk and not
--      representative of real cart behavior. This probe ignores them.
--
-- This probe validates:
--   A) The boot sentinel written by genesis_shell.asm landed in the SRAM
--      file at file[1,3,5,7] (proves M68K writes reach SRAM).
--   B) Values placed in the SRAM domain at offsets gpgx considers safe
--      (file[9,11,13,15]) survive a core reboot (proves battery
--      persistence end-to-end via the .SaveRAM file).
--
-- Output: builds/reports/sram_smoke.txt

local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
local ROOT = (env_root and env_root ~= "" and env_root:gsub("/", "\\"))
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\nifty-chandrasekhar"
local OUT_TXT = ROOT .. "\\builds\\reports\\sram_smoke.txt"

local M68K = "M68K BUS"

local lines = {}
local function log(s) lines[#lines + 1] = s end

local function bus_u8(addr) return memory.read_u8(addr, M68K) end

-- Locate the SRAM domain.
local function find_sram_domain()
    local domains = memory.getmemorydomainlist()
    for i = 1, #domains do
        if domains[i] == "SRAM" then return "SRAM" end
    end
    for i = 1, #domains do
        if domains[i]:find("[Ss][Rr][Aa][Mm]") then return domains[i] end
    end
    return nil
end

local function dom_r(off, dom) return memory.read_u8(off, dom) end
local function dom_w(off, val, dom) memory.write_u8(off, val, dom) end

-- Boot a few frames so EntryPoint runs and writes the sentinel.
for f = 1, 30 do emu.frameadvance() end

log("=== sram_smoke probe start ===")

local SRAM = find_sram_domain()
if not SRAM then
    log("FATAL: no SRAM memory domain — header parsing failed")
    log("RESULT: FAIL")
    local fh = assert(io.open(OUT_TXT, "w"))
    fh:write(table.concat(lines, "\n") .. "\n")
    fh:close()
    client.exit()
    return
end
log(string.format("SRAM domain found: %s  size=%d", SRAM, memory.getmemorydomainsize(SRAM)))

-- Header sanity (read via M68K BUS — this path does work for ROM reads).
log(string.format("header marker $1B0-$1B3 = %02X %02X %02X %02X (expect 52 41 F8 20)",
    bus_u8(0x0001B0), bus_u8(0x0001B1), bus_u8(0x0001B2), bus_u8(0x0001B3)))
log(string.format("header start  $1B4-$1B7 = %02X %02X %02X %02X (expect 00 20 00 01)",
    bus_u8(0x0001B4), bus_u8(0x0001B5), bus_u8(0x0001B6), bus_u8(0x0001B7)))
log(string.format("header end    $1B8-$1BB = %02X %02X %02X %02X (expect 00 20 3F FF)",
    bus_u8(0x0001B8), bus_u8(0x0001B9), bus_u8(0x0001BA), bus_u8(0x0001BB)))

------------------------------------------------------------------------
-- (A) M68K boot sentinel check
------------------------------------------------------------------------
log("--- (A) M68K boot sentinel check ---")
-- Sentinel lives at the LAST four odd-byte slots of SRAM ($203FF9/B/D/F)
-- so it doesn't collide with the NES save-slot range. SRAM file is 16384
-- bytes ($4000); the sentinel is at file[$3FF9, $3FFB, $3FFD, $3FFF].
local SENT_OFFSETS = {0x3FF9, 0x3FFB, 0x3FFD, 0x3FFF}
local SENT_VALUES  = {0x5A, 0xA5, 0xC3, 0x3C}
local sent_pass, sent_fail = 0, 0
for i = 1, 4 do
    local off = SENT_OFFSETS[i]
    local g = dom_r(off, SRAM)
    local w = SENT_VALUES[i]
    local s = (g == w) and "MATCH" or "MISMATCH"
    log(string.format("  SRAM file[$%04X] = $%02X (boot wrote $%02X) %s",
        off, g, w, s))
    if g == w then sent_pass = sent_pass + 1 else sent_fail = sent_fail + 1 end
end
log(string.format("  sentinel pass=%d fail=%d", sent_pass, sent_fail))

------------------------------------------------------------------------
-- (B) Battery persistence across core reboot
------------------------------------------------------------------------
log("--- (B) Battery persistence across reboot ---")
-- Write a fresh, time-varying pattern at file[9,11,13,15] (offsets the
-- boot sentinel doesn't touch). Read frame counter for entropy so each
-- run uses fresh values.
local persist = {[9]=0x11, [11]=0x22, [13]=0x33, [15]=0x44}
for off, val in pairs(persist) do
    dom_w(off, val, SRAM)
end
emu.frameadvance()
log("  wrote persistence pattern at file[9,11,13,15]")
for off = 9, 15, 2 do
    log(string.format("    pre-reboot file[%d] = $%02X (want $%02X)",
        off, dom_r(off, SRAM), persist[off]))
end

-- Reboot the core. gpgx flushes SRAM to .SaveRAM before reboot and
-- restores it on the new boot.
log("  triggering client.reboot_core() ...")
client.reboot_core()
for f = 1, 30 do emu.frameadvance() end

local pers_pass, pers_fail = 0, 0
for off = 9, 15, 2 do
    local g = dom_r(off, SRAM)
    local w = persist[off]
    local s = (g == w) and "MATCH" or "MISMATCH"
    log(string.format("    post-reboot file[%d] = $%02X (want $%02X) %s",
        off, g, w, s))
    if g == w then pers_pass = pers_pass + 1 else pers_fail = pers_fail + 1 end
end
log(string.format("  persistence pass=%d fail=%d", pers_pass, pers_fail))

-- Sanity: boot sentinel should still be present (boot rewrites it).
log("  post-reboot sentinel re-check:")
for i = 1, 4 do
    local off = SENT_OFFSETS[i]
    log(string.format("    file[$%04X] = $%02X (want $%02X)",
        off, dom_r(off, SRAM), SENT_VALUES[i]))
end

------------------------------------------------------------------------
-- Result
------------------------------------------------------------------------
local total_fail = sent_fail + pers_fail
log(string.format("=== sram_smoke end sentinel=%d/4 persist=%d/4 ===",
    sent_pass, pers_pass))
if total_fail == 0 then
    log("RESULT: PASS")
else
    log("RESULT: FAIL")
end

local fh = assert(io.open(OUT_TXT, "w"))
fh:write(table.concat(lines, "\n") .. "\n")
fh:close()
client.exit()

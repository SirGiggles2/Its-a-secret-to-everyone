-- bizhawk_sram_save.lua
-- Phase 9.8 — End-to-end save-slot persistence test.
--
-- This probe validates the full SRAM commit path added in P21:
--    NES save-slot writes -> work-RAM mirror at $FF6000 -> cart SRAM at
--    $200001 (via _sram_commit_save_slots) -> .SaveRAM file -> survive
--    reboot -> _sram_load_save_slots restores mirror -> game resumes
--    seeing the persisted slot data.
--
-- Strategy: instead of driving the FS2 keyboard (which works but is
-- slow and brittle), we directly seed a known pattern into the work-RAM
-- mirror at $FF6000+ via Lua, then force GameMode=$0D / GameSubmode=$02
-- so the next dispatcher tick runs UpdateModeDSave_Sub2 — which now
-- starts with `jsr _sram_commit_save_slots`. After the commit fires, we
-- read the SRAM memory domain at the odd-byte positions and confirm the
-- pattern landed.
--
-- Then we reboot the core. _sram_load_save_slots in EntryPoint should
-- copy the pattern back into the work-RAM mirror BEFORE Zelda runs, so
-- a fresh boot sees the persisted slot bytes.
--
-- Output: builds/reports/sram_save.txt

local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
local ROOT = (env_root and env_root ~= "" and env_root:gsub("/", "\\"))
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\nifty-chandrasekhar"
local OUT_TXT = ROOT .. "\\builds\\reports\\sram_save.txt"

local M68K  = "M68K BUS"
local RAM68 = "68K RAM"

local lines = {}
local function log(s) lines[#lines + 1] = s end

local function ram_r(bus_addr) return memory.read_u8(bus_addr - 0xFF0000, RAM68) end
local function ram_w(bus_addr, val) memory.write_u8(bus_addr - 0xFF0000, val, RAM68) end

local function find_sram_domain()
    local doms = memory.getmemorydomainlist()
    for i = 1, #doms do
        if doms[i] == "SRAM" then return "SRAM" end
    end
    return nil
end

local SRAM = find_sram_domain()
if not SRAM then
    log("FATAL: no SRAM domain — header parsing failed")
    log("RESULT: FAIL")
    local fh = assert(io.open(OUT_TXT, "w"))
    fh:write(table.concat(lines, "\n") .. "\n")
    fh:close()
    client.exit()
    return
end
local function sram_r(off) return memory.read_u8(off, SRAM) end

-- Boot the game so EntryPoint runs (_sram_enable + sentinel + _sram_load_save_slots)
local frame_no = 0
local function adv(n)
    n = n or 1
    for i = 1, n do
        frame_no = frame_no + 1
        emu.frameadvance()
    end
end
adv(120)

log("=== sram_save probe start ===")
log(string.format("after boot: GameMode=$%02X Sub=$%02X SRAM file[1..F]=",
    ram_r(0xFF0012), ram_r(0xFF0013)))
local sb = {}
for i = 1, 0xF do sb[#sb+1] = string.format("%02X", sram_r(i)) end
log("  " .. table.concat(sb, " "))
log("  mirror $FF6001..$FF6010:")
local mb = {}
for i = 1, 0x10 do mb[#mb+1] = string.format("%02X", ram_r(0xFF6000 + i)) end
log("  " .. table.concat(mb, " "))

------------------------------------------------------------------------
-- (1) Seed a known pattern into the work-RAM mirror
------------------------------------------------------------------------
-- Use a pattern that won't appear naturally so we can be sure the bytes
-- came from us. Place it at NES SRAM offsets $20..$27 — well past any
-- "is initialized" meta bytes Zelda writes at $6001 / $6002 on cold boot.
-- These offsets are inside actual save-slot data territory.
local PATTERN = {
    [0x20] = 0x54,  -- 'T'
    [0x21] = 0x45,  -- 'E'
    [0x22] = 0x53,  -- 'S'
    [0x23] = 0x54,  -- 'T'
    [0x24] = 0x9C,  -- nonce
    [0x25] = 0x77,  -- nonce
    [0x26] = 0x33,
    [0x27] = 0xCC,
}
log("--- (1) seeding mirror $FF6020..$FF6027 ---")
for off, val in pairs(PATTERN) do
    ram_w(0xFF6000 + off, val)
end
adv(1)
log("  mirror after seed:")
local seeded = {}
for i = 1, 8 do seeded[#seeded+1] = string.format("%02X", ram_r(0xFF6000 + i)) end
log("    " .. table.concat(seeded, " "))

------------------------------------------------------------------------
-- (2) Force the dispatcher into UpdateModeDSave_Sub2
------------------------------------------------------------------------
-- GameMode ($FF0012) = $0D (Save mode), GameSubmode ($FF0013) = $02.
-- Next frame dispatcher will look up the Save mode jump table and call
-- UpdateModeDSave_Sub2, which (post-P21) starts with
-- `jsr _sram_commit_save_slots` and then resets the mode.
log("--- (2) forcing GameMode=$0D Sub=$02 ---")
ram_w(0xFF0012, 0x0D)
ram_w(0xFF0013, 0x02)
adv(1)
log(string.format("  after 1 frame: GameMode=$%02X Sub=$%02X",
    ram_r(0xFF0012), ram_r(0xFF0013)))
adv(5)
log(string.format("  after 6 frames: GameMode=$%02X Sub=$%02X",
    ram_r(0xFF0012), ram_r(0xFF0013)))

------------------------------------------------------------------------
-- (3) Read SRAM file at the odd-byte positions for the pattern
------------------------------------------------------------------------
-- _sram_commit_save_slots writes:
--   mirror $FF6000+N -> bus $200001 + N*2 -> file offset 1 + N*2
-- So pattern at mirror offset $01 lands at file[1 + 1*2 - 2 + 1]... wait,
-- the mirror loop is:
--   A0 = $FF6000 (mirror), A1 = $200001 (cart base)
--   for N=0..$7FF:
--      D0 = (A0)+      ; reads mirror[N]
--      D0 -> (A1)      ; writes cart bus, A1 stride 2
--      A1 += 2
-- Mapping: mirror $FF6000+N -> bus $200001 + N*2 -> SRAM file offset
-- 1 + N*2 (since file index = bus_addr - $200000).
-- mirror[$01] -> file[1 + 1*2] = file[3]
-- mirror[$02] -> file[5]
-- mirror[$03] -> file[7]
-- mirror[$04] -> file[9]
-- mirror[$05] -> file[B]
-- mirror[$06] -> file[D]
-- mirror[$07] -> file[F]
-- mirror[$08] -> file[11]
local function mirror_to_file(N) return 1 + N * 2 end

log("--- (3) verifying pattern landed in SRAM file ---")
local pre_pass, pre_fail = 0, 0
for off, want in pairs(PATTERN) do
    local fo = mirror_to_file(off)
    local got = sram_r(fo)
    local s = (got == want) and "MATCH" or "MISMATCH"
    log(string.format("  mirror[$%02X] -> file[$%X] = $%02X (want $%02X) %s",
        off, fo, got, want, s))
    if got == want then pre_pass = pre_pass + 1 else pre_fail = pre_fail + 1 end
end
log(string.format("  pre-reboot pass=%d fail=%d", pre_pass, pre_fail))

------------------------------------------------------------------------
-- (4) Reboot core; verify pattern survives AND mirror is restored
------------------------------------------------------------------------
log("--- (4) client.reboot_core() ---")
client.reboot_core()
adv(120)

log("  post-reboot SRAM file:")
local pb = {}
for i = 1, 0x11 do pb[#pb+1] = string.format("%02X", sram_r(i)) end
log("    " .. table.concat(pb, " "))
log("  post-reboot mirror $FF6001..$FF6008:")
local mb2 = {}
for i = 1, 8 do mb2[#mb2+1] = string.format("%02X", ram_r(0xFF6000 + i)) end
log("    " .. table.concat(mb2, " "))

local post_pass, post_fail = 0, 0
for off, want in pairs(PATTERN) do
    local fo = mirror_to_file(off)
    local got = sram_r(fo)
    local s = (got == want) and "MATCH" or "MISMATCH"
    log(string.format("  post file[$%X] = $%02X (want $%02X) %s",
        fo, got, want, s))
    if got == want then post_pass = post_pass + 1 else post_fail = post_fail + 1 end
end
log(string.format("  post-reboot SRAM pass=%d fail=%d", post_pass, post_fail))

-- Also check that the boot _sram_load_save_slots actually restored the
-- mirror (this is the read-back path Zelda will see at runtime).
local mir_pass, mir_fail = 0, 0
for off, want in pairs(PATTERN) do
    local got = ram_r(0xFF6000 + off)
    local s = (got == want) and "MATCH" or "MISMATCH"
    log(string.format("  mirror[$%02X] = $%02X (want $%02X) %s",
        off, got, want, s))
    if got == want then mir_pass = mir_pass + 1 else mir_fail = mir_fail + 1 end
end
log(string.format("  mirror restore pass=%d fail=%d", mir_pass, mir_fail))

------------------------------------------------------------------------
-- Result
------------------------------------------------------------------------
local total_fail = pre_fail + post_fail + mir_fail
log(string.format("=== sram_save end pre=%d/8 post=%d/8 mirror=%d/8 ===",
    pre_pass, post_pass, mir_pass))
if total_fail == 0 then
    log("RESULT: PASS")
else
    log("RESULT: FAIL")
end

local fh = assert(io.open(OUT_TXT, "w"))
fh:write(table.concat(lines, "\n") .. "\n")
fh:close()
client.exit()

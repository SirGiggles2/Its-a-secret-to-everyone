-- probe_levelinfo_install.lua — verify LevelInfo lands at the right SRAM
-- offsets after level_info_install_uw().
--
-- WHY: tools/extract_rooms.py used LEVEL_INFO_SIZE 0x100 when the real ROM
-- record is 252 bytes, so LevelInfoUW<n> was read 4*(n-1) bytes late and every
-- field landed 4 bytes early in the installed SRAM image. This probe is the
-- runtime half of that fix (RULE V1: a byte-diff of the blob is not evidence
-- that the runtime installs it correctly).
--
-- Debug.md boots into SCENE_OW room $77 and the A+B+C chord enters gameplay.
-- roomrom_debug_enter -> level_info_install_uw(1, 1), so the L1Q1 LevelInfo
-- image is what lands in the NES RAM mirror.
--
-- EXPECTED (live NES SRAM, src/game/dungeon/uw_map_data.c, captured by
-- tools/parity/pause_golden/uw_capture_all_levels.lua):
--   $6BAD StartRoomId    = $73
--   $6BAE TriforceRoomId = $36
--   $6BB1 LevelNumber    = $01
--   $6BBC BossRoomId     = $35
--   $6BAB SubmenuMapRot  = $04
--
-- RULE V3: enumerate domains live, never assume a name. The Genesis core here
-- is Waterbox genplus, which exposes "M68K BUS" and NOT "68K RAM"; the NES RAM
-- mirror sits at 68K $FF0000 + $8000 + nes_addr.

local OUT = "C:\\tmp\\levelinfo_install_report.txt"

------------------------------------------------------------------ domains ---
local function domain_list()
    local ok, list = pcall(memory.getmemorydomainlist)
    if not ok or type(list) ~= "table" then return {} end
    return list
end

local function pick_domain()
    local names = {}
    for _, d in ipairs(domain_list()) do names[tostring(d)] = true end
    -- Preference order: current genplus core first, then legacy cores.
    for _, cand in ipairs({ "M68K BUS", "68K RAM", "Main RAM" }) do
        if names[cand] then return cand, names end
    end
    return nil, names
end

local DOMAIN, DOMAIN_NAMES = pick_domain()
if DOMAIN == nil then
    local f = io.open(OUT, "w")
    f:write("FAIL: no usable 68K memory domain found. Domains seen:\n")
    for n, _ in pairs(DOMAIN_NAMES) do f:write("  " .. n .. "\n") end
    f:close()
    print("FAIL: no usable memory domain — see " .. OUT)
    client.exit()
    return
end

-- "M68K BUS" is bus-addressed ($FF0000 = work RAM); the RAM-only domains are
-- zero-based. Resolve the base once so a domain change cannot silently shift
-- every read.
local BUS_BASE = (DOMAIN == "M68K BUS") and 0xFF0000 or 0x000000
local NES_MIRROR = 0x8000

-- Returns (value, err). A failed read yields nil rather than a number, and
-- feeding nil to string.format("%02X") aborts the probe mid-run — which would
-- look like a crash rather than a diagnosable domain problem.
local read_errors = {}
local function nesram(nes_addr)
    local ok, v = pcall(memory.read_u8, BUS_BASE + NES_MIRROR + nes_addr, DOMAIN)
    if not ok or type(v) ~= "number" then
        read_errors[#read_errors + 1] = string.format(
            "$%04X (domain %s): %s", nes_addr, DOMAIN,
            ok and "non-numeric result" or tostring(v))
        return nil
    end
    return v
end

local function hex8(v) return v and string.format("$%02X", v) or "<read failed>" end

-------------------------------------------------------------------- drive ---
local function press(btns, frames)
    for _ = 1, frames do
        joypad.set(btns, 1)
        emu.frameadvance()
    end
end

local function idle(frames)
    for _ = 1, frames do emu.frameadvance() end
end

idle(150)                                   -- title settle
press({ A = true, B = true, C = true }, 8)  -- debug-enter chord
idle(240)                                   -- let install + first frames run

------------------------------------------------------------------- verify ---
-- Per-level expected values, read from the ROM at the corrected layout
-- (PRG $193FC, 252-byte records) and cross-checked against live NES SRAM in
-- src/game/dungeon/uw_map_data.c for StartRoomId / TriforceRoomId / MapRot.
--                 start  tri   boss  rot
local EXPECTED = {
    [1] = { 0x73, 0x36, 0x35, 0x04 },
    [2] = { 0x7D, 0x0D, 0x0E, 0x0A },
    [3] = { 0x7C, 0x3D, 0x4D, 0x0C },
    [4] = { 0x71, 0x03, 0x13, 0x06 },
    [5] = { 0x76, 0x14, 0x24, 0x02 },
    [6] = { 0x79, 0x0C, 0x1C, 0x0D },
    [7] = { 0x79, 0x2B, 0x2A, 0x0D },
    [8] = { 0x7E, 0x2C, 0x3C, 0x0A },
    [9] = { 0x76, 0x32, 0x42, 0x04 },
}

-- Self-validating: trust nothing about WHICH level is loaded. Read
-- LevelNumber ($6BB1) from the installed image, then check the other four
-- fields against that level's row. This is the alignment test — under the old
-- 4-byte-early layout LevelNumber read garbage (0/$FF/$C0/...), so a clean
-- 1..9 that agrees with four independent sibling fields can only happen if the
-- record is aligned correctly.
local level_number = nesram(0x6BB1)
local row = (level_number ~= nil) and EXPECTED[level_number] or nil

local CHECKS = {}
if row then
    CHECKS = {
        { name = "StartRoomId",    addr = 0x6BAD, want = row[1] },
        { name = "TriforceRoomId", addr = 0x6BAE, want = row[2] },
        { name = "BossRoomId",     addr = 0x6BBC, want = row[3] },
        { name = "SubmenuMapRot",  addr = 0x6BAB, want = row[4] },
    }
end

local pass, fail = 0, 0
local lines = {}
for _, c in ipairs(CHECKS) do
    local got = nesram(c.addr)
    local ok = (got ~= nil) and (got == c.want)
    if ok then pass = pass + 1 else fail = fail + 1 end
    lines[#lines + 1] = string.format(
        "  %-15s $%04X  got %-12s want $%02X  %s",
        c.name, c.addr, hex8(got), c.want,
        got == nil and "READ FAILED" or (ok and "OK" or "MISMATCH"))
end

-- Liveness. GameMode must be Play, and the installed image must self-report a
-- valid LevelNumber (1..9) so we know a UW LevelInfo was actually installed.
-- CurLevel is reported but NOT gated on: Debug.md boots into SCENE_OW with
-- CurLevel $00 while a UW LevelInfo is already resident, so requiring it would
-- reject a perfectly valid observation.
local game_mode = nesram(0x0012)
local cur_level = nesram(0x0010)
local alive = (game_mode == 0x05) and (row ~= nil)

os.execute('mkdir "C:\\tmp" 2>NUL')
local f, ferr = io.open(OUT, "w")
if f == nil then
    print("probe_levelinfo_install: cannot write " .. OUT .. ": " ..
          tostring(ferr))
    client.exit()
    return
end
f:write("probe_levelinfo_install — " .. os.date() .. "\n")
f:write("domain: " .. DOMAIN .. "  bus_base: $" ..
        string.format("%06X", BUS_BASE) .. "\n")
f:write(string.format("GameMode $0012 = %s   CurLevel $0010 = %s\n",
                      hex8(game_mode), hex8(cur_level)))
f:write(string.format("LevelNumber $6BB1 = %s  -> validating against L%s row\n",
                      hex8(level_number),
                      row and tostring(level_number) or "?"))
f:write("usable_observation: " .. tostring(alive) ..
        "  (requires GameMode $05 AND LevelNumber in 1..9)\n\n")
f:write("LevelInfo fields installed at NES SRAM:\n")
for _, l in ipairs(lines) do f:write(l .. "\n") end
f:write("\n")

if #read_errors > 0 then
    f:write("READ ERRORS (" .. #read_errors .. "):\n")
    for _, e in ipairs(read_errors) do f:write("  " .. e .. "\n") end
    f:write("\n")
end

local verdict
if not alive then
    verdict = "UNVERIFIED — GameMode not Play, or LevelNumber outside 1..9 " ..
              "(no UW LevelInfo resident). Field reads say nothing either " ..
              "way. This is NOT a pass and NOT a failure."
elseif #read_errors > 0 then
    verdict = "UNVERIFIED — one or more memory reads failed."
elseif fail == 0 then
    verdict = string.format("PASS — %d/%d fields match live-NES-SRAM values",
                            pass, pass + fail)
else
    verdict = string.format("FAIL — %d/%d fields match, %d mismatched",
                            pass, pass + fail, fail)
end
f:write("VERDICT: " .. verdict .. "\n")
f:close()

print("probe_levelinfo_install: " .. verdict .. "  (domain=" .. DOMAIN ..
      ") -> " .. OUT)
client.exit()

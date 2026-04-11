-- bizhawk_phase10_fs2_probe.lua
-- Phase 10.1 — File Select 2 / REGISTER YOUR NAME (GameMode=$0E) diagnostic probe.
--
-- Answers:
--   FS2-A: Mode $0E Link ladder Y vs. BG slot row Y (plus X/Y swap check
--          in _anon_z02_5 vs Mode1_WriteLinkSprites expectations)
--   FS2-B: P13 ModeE_SyncCharBoardCursorToIndex output X/Y vs BG char cell
--   FS2-E/F/G: D-pad walk of the 4x11 grid, logging $041F/$0071/$0085 at
--          each step; A-press and B-press sequences to test the A/B path.
--
-- Template: fs1_vram_snap.lua + fs2_keyboard.lua navigation.
-- Output: builds/reports/fs2_p10_diag.txt

local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
local ROOT = (env_root and env_root ~= "" and env_root:gsub("/", "\\"))
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\nifty-chandrasekhar"
local OUT_TXT = ROOT .. "\\builds\\reports\\fs2_p10_diag.txt"

local M68K   = "M68K BUS"
local RAM68K = "68K RAM"

local lines = {}
local function log(s) lines[#lines + 1] = s end

local function ram_u8(bus_addr) return memory.read_u8(bus_addr - 0xFF0000, RAM68K) end
local function ram_w8(bus_addr, value) memory.write_u8(bus_addr - 0xFF0000, value, RAM68K) end
local function vram_u16(off) return memory.read_u16_be(off, "VRAM") end
local function cram_u16(off) return memory.read_u16_be(off, "CRAM") end
local function bus_u8(addr) return memory.read_u8(addr, M68K) end

local frame_no = 0
local function adv(n)
    n = n or 1
    for i = 1, n do
        frame_no = frame_no + 1
        emu.frameadvance()
    end
end
local function press(buttons, frames)
    frames = frames or 1
    for i = 1, frames do
        joypad.set(buttons)
        frame_no = frame_no + 1
        emu.frameadvance()
    end
end
local function tap(btn, gap)
    press({[btn] = true}, 1)
    adv(gap or 8)
end

local function snap()
    return string.format("mode=%02X sub=%02X idx=%02X off=%02X x=%02X y=%02X $0423=%02X",
        ram_u8(0xFF0012), ram_u8(0xFF0013),
        ram_u8(0xFF041F), ram_u8(0xFF0421),
        ram_u8(0xFF0071), ram_u8(0xFF0085),
        ram_u8(0xFF0423))
end

local function namebuf_str()
    local b = {}
    for i = 0, 7 do b[#b+1] = string.format("%02X", ram_u8(0xFF0638 + i)) end
    return table.concat(b, " ")
end

------------------------------------------------------------------------
-- (0) Boot title → FS1 → nav to REGISTER → Start into Mode $0E
------------------------------------------------------------------------
log("=== fs2_p10_diag probe start ===")

-- Boot ~80 frames
adv(80)
log(string.format("f=%4d after boot mode=%02X", frame_no, ram_u8(0xFF0012)))

-- Start tap to leave title -> FS1
press({["P1 Start"] = true}, 18)
adv(20)
log(string.format("f=%4d post-Start mode=%02X slot=%02X", frame_no,
    ram_u8(0xFF0012), ram_u8(0xFF0016)))

-- Tap Genesis C (NES Select) up to 5 times to land on CurSaveSlot=3
-- (REGISTER YOUR NAME)
for i = 1, 5 do
    if ram_u8(0xFF0016) == 0x03 then break end
    tap("P1 C", 12)
    log(string.format("f=%4d after-C#%d slot=%02X", frame_no, i,
        ram_u8(0xFF0016)))
end
log(string.format("f=%4d pre-Start slot=%02X", frame_no, ram_u8(0xFF0016)))

-- Start to enter Mode $0E
press({["P1 Start"] = true}, 4)
adv(18)
log(string.format("f=%4d post-Start1 %s", frame_no, snap()))
if ram_u8(0xFF0012) ~= 0x0E then
    for i = 1, 4 do
        press({["P1 Start"] = true}, 4)
        adv(12)
        log(string.format("f=%4d post-Start%d %s", frame_no, i+1, snap()))
        if ram_u8(0xFF0012) == 0x0E then break end
    end
end

if ram_u8(0xFF0012) ~= 0x0E then
    log(string.format("ABORT: failed to reach Mode $0E (mode=%02X)", ram_u8(0xFF0012)))
    local fh = assert(io.open(OUT_TXT, "w"))
    fh:write(table.concat(lines, "\n") .. "\n")
    fh:close()
    client.exit()
    return
end

------------------------------------------------------------------------
-- (1) Work-RAM state at Mode $0E idle — check the X/Y seed swap
------------------------------------------------------------------------
log("--- (1) Work-RAM seeds $FF0000/$FF0001 after _anon_z02_5 ---")
log(string.format("  $FF0000 = $%02X (%d)  $FF0001 = $%02X (%d)",
    ram_u8(0xFF0000), ram_u8(0xFF0000), ram_u8(0xFF0001), ram_u8(0xFF0001)))
log("  NOTE: Mode1_WriteLinkSprites reads $0001 as Y, $0000 as X.")
log("  _L_z02_UpdateMode1Menu_Sub0_WriteCursorSprite seeds $0001=$58 (Y), $0000=$30 (X).")
log("  _anon_z02_5 (Mode $0E) seeds $0000=80 first, then $0001=48 — X/Y MAY be swapped.")

------------------------------------------------------------------------
-- (2) NES OAM shadow $FF0200..$FF0243 (17 sprites)
------------------------------------------------------------------------
log("--- (2) NES OAM shadow $FF0200..$FF0243 ---")
for spr = 0, 16 do
    local base = 0xFF0200 + spr * 4
    log(string.format("  spr%02d: Y=$%02X Tile=$%02X Attr=$%02X X=$%02X",
        spr, ram_u8(base + 0), ram_u8(base + 1),
        ram_u8(base + 2), ram_u8(base + 3)))
end

------------------------------------------------------------------------
-- (3) VDP SAT at $F800 (non-zero slots)
------------------------------------------------------------------------
log("--- (3) VDP SAT $F800..$F9C0 (non-empty) ---")
for i = 0, 55 do
    local base = 0xF800 + i * 8
    local y = vram_u16(base + 0)
    local l = vram_u16(base + 2)
    local a = vram_u16(base + 4)
    local x = vram_u16(base + 6)
    if y ~= 0 or a ~= 0 or x ~= 0 then
        local pal = (a >> 13) & 0x3
        log(string.format("  sat%02d: Y=%04X SL=%04X AT=%04X(pal=%d) X=%04X",
            i, y, l, a, pal, x))
    end
end

------------------------------------------------------------------------
-- (4) CRAM dump
------------------------------------------------------------------------
log("--- (4) CRAM (PAL0..PAL3) ---")
for pal = 0, 3 do
    local row = {string.format("  PAL%d:", pal)}
    for i = 0, 15 do
        row[#row + 1] = string.format("%04X", cram_u16(pal * 32 + i * 2))
    end
    log(table.concat(row, " "))
end

------------------------------------------------------------------------
-- (5) Plane A NT slice (rows 8..26, cols 0..31)
------------------------------------------------------------------------
log("--- (5) Plane A NT rows 8..26 cols 0..31 ---")
local PLANE_A_BASE = 0xC000
local STRIDE = 0x80
for row = 8, 26 do
    local parts = {string.format("  row %02d:", row)}
    for col = 0, 31 do
        parts[#parts + 1] = string.format("%04X",
            vram_u16(PLANE_A_BASE + row * STRIDE + col * 2))
    end
    log(table.concat(parts, " "))
end

------------------------------------------------------------------------
-- (6) P13 output at canonical grid indices
------------------------------------------------------------------------
-- For each idx in {0, 1, 5, 10, 11, 22, 33, 42}, force $041F = idx,
-- advance 2 frames so the dispatcher tick + P13 sync runs, then read
-- the resulting $0071 (CharBoardCursorX) and $0085 (CharBoardCursorY)
-- AND the corresponding sprite in OAM.
log("--- (6) P13 sync output vs CharBoardIndex ---")
local function test_idx(idx)
    ram_w8(0xFF041F, idx)
    adv(2)
    local x = ram_u8(0xFF0071)
    local y = ram_u8(0xFF0085)
    log(string.format("  idx=%02d: $0071 X=$%02X (%d)  $0085 Y=$%02X (%d)",
        idx, x, x, y, y))
end
for _, idx in ipairs({0, 1, 5, 10, 11, 21, 22, 32, 33, 42}) do
    test_idx(idx)
end

------------------------------------------------------------------------
-- (7) A-press path sanity (confirm A writes the right char)
------------------------------------------------------------------------
log("--- (7) A-press char-write test ---")
log("  initial namebuf: " .. namebuf_str())
ram_w8(0xFF041F, 0)   -- idx=0 => 'A' in NES charmap
ram_w8(0xFF0421, 0)   -- NameCharOffset=0
adv(2)
log(string.format("  pre-A idx=%02X off=%02X", ram_u8(0xFF041F), ram_u8(0xFF0421)))
press({["P1 B"] = true}, 1)   -- Genesis B = NES A
adv(6)
log(string.format("  post-A idx=%02X off=%02X", ram_u8(0xFF041F), ram_u8(0xFF0421)))
log("  post-A namebuf: " .. namebuf_str())

------------------------------------------------------------------------
-- (8) B-press backspace test (should NOT erase currently — FS2-E)
------------------------------------------------------------------------
log("--- (8) B-press (backspace) test ---")
-- First write an A so there's something to erase
ram_w8(0xFF041F, 0)
ram_w8(0xFF0421, 0)
adv(2)
press({["P1 B"] = true}, 1)
adv(6)
log("  after A#1 namebuf: " .. namebuf_str() .. " off=" .. string.format("%02X", ram_u8(0xFF0421)))
-- Then write another A
ram_w8(0xFF041F, 0)
adv(2)
press({["P1 B"] = true}, 1)
adv(6)
log("  after A#2 namebuf: " .. namebuf_str() .. " off=" .. string.format("%02X", ram_u8(0xFF0421)))
-- Now B (Genesis A = NES B)
press({["P1 A"] = true}, 1)
adv(6)
log("  after B#1 namebuf: " .. namebuf_str() .. " off=" .. string.format("%02X", ram_u8(0xFF0421)))
press({["P1 A"] = true}, 1)
adv(6)
log("  after B#2 namebuf: " .. namebuf_str() .. " off=" .. string.format("%02X", ram_u8(0xFF0421)))

------------------------------------------------------------------------
-- (9) D-pad walk across the 4x11 grid
------------------------------------------------------------------------
-- This is FS2-F/FS2-G territory. BizHawk can't catch a hardware freeze,
-- but it can at least confirm whether $041F is advancing correctly.
log("--- (9) D-pad grid walk ---")
ram_w8(0xFF041F, 0)
adv(2)
log(string.format("  start %s", snap()))

local function nav(btn, n, label)
    for k = 1, n do
        press({[btn] = true}, 1)
        adv(6)
        log(string.format("  %s#%d %s", label, k, snap()))
    end
end

-- Row 0: right 11 times
nav("P1 Right", 11, "R")
-- Down to row 1
nav("P1 Down", 1, "D")
-- Row 1: right 11 times
nav("P1 Right", 11, "R")
-- Down to row 2
nav("P1 Down", 1, "D")
-- Row 2: left 11 times
nav("P1 Left", 11, "L")
-- Down to row 3 (hidden/final)
nav("P1 Down", 1, "D")
-- Row 3 probes
nav("P1 Right", 11, "R")
-- Up back through rows
nav("P1 Up", 3, "U")

------------------------------------------------------------------------
-- (10) Mode $0E Link pair OAM + work-RAM state dump
------------------------------------------------------------------------
log("--- (10) Post-walk OAM + work-RAM state ---")
for spr = 0, 12 do
    local base = 0xFF0200 + spr * 4
    log(string.format("  spr%02d: Y=$%02X Tile=$%02X Attr=$%02X X=$%02X",
        spr, ram_u8(base + 0), ram_u8(base + 1),
        ram_u8(base + 2), ram_u8(base + 3)))
end
log(string.format("  $FF0000=$%02X $FF0001=$%02X $FF0004=$%02X $FF0005=$%02X",
    ram_u8(0xFF0000), ram_u8(0xFF0001), ram_u8(0xFF0004), ram_u8(0xFF0005)))
log(string.format("  $FF0343=$%02X $FF0344=$%02X", ram_u8(0xFF0343), ram_u8(0xFF0344)))
log(string.format("  namebuf $FF0638..$FF063F: %s", namebuf_str()))

log("=== fs2_p10_diag end ===")

local fh = assert(io.open(OUT_TXT, "w"))
fh:write(table.concat(lines, "\n") .. "\n")
fh:close()
client.exit()

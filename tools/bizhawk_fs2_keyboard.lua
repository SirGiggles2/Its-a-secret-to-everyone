-- bizhawk_fs2_keyboard.lua
-- Phase 9.5 — diagnose FS2 (Mode E) letter-typing.
--
-- Approach:
--   1. Walk title -> FS1 with Start tap.
--   2. From FS1, move cursor down to REGISTER YOUR NAME, press A to enter
--      Mode E (the char board / keyboard).
--   3. Once in mode E (GameMode=$0E), the test loop pokes CharBoardIndex
--      ($FF041F) to known positions, presses A for one frame, and logs:
--        - $041F before
--        - ModeE_CharMap[$041F] expected char
--        - $0421 NameCharOffset before
--        - $0638..$063F name buffer before
--        - $0421 NameCharOffset after
--        - $0638..$063F name buffer after
--        - whether the expected char actually landed at $0638+($0421 before)
--
-- We also hook execute on:
--   $00009C8C = ModeE_HandleAOrB entry
--   $00009D1C = read of ModeE_CharMap[D3]
--   $00009D28 = write D0 -> ($0638,A4,D2.W)
-- to confirm the path is reached and which char is being written.

local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
local ROOT = (env_root and env_root ~= "" and env_root:gsub("/", "\\"))
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\nifty-chandrasekhar"
local OUT_TXT = ROOT .. "\\builds\\reports\\fs2_keyboard.txt"

local M68K = "M68K BUS"
local RAM68K = "68K RAM"

local A_HANDLE_AB     = 0x00009C8C
local A_READ_CHARMAP  = 0x00009D1C
local A_WRITE_NAME    = 0x00009D28
local A_CHARMAP       = 0x0000960C  -- ModeE_CharMap base in ROM

local lines = {}
local function log(s) lines[#lines + 1] = s end

local function bus_u8(addr) return memory.read_u8(addr, M68K) end
local function ram_u8(bus_addr) return memory.read_u8(bus_addr - 0xFF0000, RAM68K) end
local function ram_w8(bus_addr, value) memory.write_u8(bus_addr - 0xFF0000, value, RAM68K) end

local function snap_state()
    return string.format("mode=%02X sub=%02X idx=%02X off=%02X x=%02X y=%02X",
        ram_u8(0xFF0012), ram_u8(0xFF0013),
        ram_u8(0xFF041F), ram_u8(0xFF0421),
        ram_u8(0xFF0071), ram_u8(0xFF0085))
end

local function dump_namebuf(prefix)
    local b = {}
    for i = 0, 7 do b[#b+1] = string.format("%02X", ram_u8(0xFF0638 + i)) end
    return prefix .. " " .. table.concat(b, " ")
end

local frame_no = 0
local hits = {ab=0, read=0, write=0}

event.onmemoryexecute(function()
    hits.ab = hits.ab + 1
    if hits.ab <= 60 then
        log(string.format("f=%4d HANDLE_AB#%d %s", frame_no, hits.ab, snap_state()))
    end
end, A_HANDLE_AB, "p9_ab", M68K)

event.onmemoryexecute(function()
    hits.read = hits.read + 1
    local d3 = emu.getregister("M68K D3") or 0
    if hits.read <= 30 then
        log(string.format("f=%4d READ_CHARMAP#%d D3=%08X charmap[%02X]=%02X %s",
            frame_no, hits.read, d3, d3 % 0x100,
            bus_u8(A_CHARMAP + (d3 % 0x100)), snap_state()))
    end
end, A_READ_CHARMAP, "p9_read", M68K)

event.onmemoryexecute(function()
    hits.write = hits.write + 1
    local d0 = emu.getregister("M68K D0") or 0
    local d2 = emu.getregister("M68K D2") or 0
    if hits.write <= 30 then
        log(string.format("f=%4d WRITE_NAME#%d D0=%02X -> $0638+%02X %s",
            frame_no, hits.write, d0 % 0x100, d2 % 0x100, snap_state()))
    end
end, A_WRITE_NAME, "p9_write", M68K)

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

log("=== fs2_keyboard probe start ===")

-- Boot to ~frame 80
adv(80)
log(string.format("f=%4d after boot %s", frame_no, snap_state()))

-- Press Start to leave title -> FS1 (mode 1)
press({["P1 Start"]=true}, 18)
adv(20)
log(string.format("f=%4d post-start %s", frame_no, snap_state()))

-- Helper: press a button for 1 frame, then release for `gap` frames so the
-- repeat-delay logic accepts the next press.
local function tap(btn, gap)
    press({[btn]=true}, 1)
    adv(gap or 8)
end

-- FS1 cursor navigation: NES Select bit ($00F8 & $20) is mapped from
-- Genesis pad C (nes_io.asm line 1602: "Genesis C → NES Select remap").
-- UpdateMode1Menu_Sub0 at $A7FA: andi.b #$20,D0; beq skip; ChangeSelection.
-- ChangeSelection at $A800 increments ($0016,A4) (CurSaveSlot) and skips
-- inactive slots via $0633+D3.  At fresh boot, slots 0/1/2 are inactive,
-- so $0016 should be 3 (REGISTER YOUR NAME) once init completes (or after
-- one C tap that runs ChangeSelection's skip loop).
--
-- Mode advance to Mode E uses START, not A: UpdateMode1Menu_Sub0 sees
-- $00F8 & $10 (Start), branches to Exit which addq.b #1,($0013,A4).  Next
-- frame, UpdateMode1Menu_Sub1 reads $0016=3, computes mode=3+$0B=$0E,
-- writes ($0012,A4) and jmp EndGameMode.
log(string.format("f=%4d before-nav %s slot=%02X", frame_no, snap_state(), ram_u8(0xFF0016)))

-- Tap C up to 5 times until $0016 == 3 (REGISTER YOUR NAME). If $0016 is
-- already 3 (likely on fresh boot since slots 0/1/2 are empty), this is a
-- no-op other than confirming via the log.
for i = 1, 5 do
    if ram_u8(0xFF0016) == 0x03 then break end
    tap("P1 C", 12)
    local slot = ram_u8(0xFF0016)
    log(string.format("f=%4d after-C#%d slot=%02X %s", frame_no, i, slot, snap_state()))
end
log(string.format("f=%4d pre-start slot=%02X %s", frame_no, ram_u8(0xFF0016), snap_state()))

-- Press Start to enter Mode E (Sub0 → Sub1 → mode=$0E)
press({["P1 Start"]=true}, 4)
adv(8)
log(string.format("f=%4d post-Start1 %s", frame_no, snap_state()))

if ram_u8(0xFF0012) ~= 0x0E then
    -- Try a couple more Start presses with gaps
    for i = 1, 4 do
        press({["P1 Start"]=true}, 4)
        adv(12)
        log(string.format("f=%4d post-Start%d %s", frame_no, i+1, snap_state()))
        if ram_u8(0xFF0012) == 0x0E then break end
    end
end

-- Probe the char map directly from ROM (sanity)
log("--- ModeE_CharMap[0..43] from ROM ---")
local row = {}
for i = 0, 43 do
    row[#row+1] = string.format("%02X", bus_u8(A_CHARMAP + i))
end
log("  " .. table.concat(row, " "))

-- Test loop: poke CharBoardIndex, press NES-A (= Genesis B per nes_io.asm
-- line 1589: "NES B = Genesis A, NES A = Genesis B"), capture result.
local function test_index(idx)
    log(string.format("--- TEST idx=%02d expected=charmap[%02X]=%02X ---",
        idx, idx, bus_u8(A_CHARMAP + idx)))
    log(dump_namebuf("  before"))
    local off_before = ram_u8(0xFF0421)
    log(string.format("  before %s", snap_state()))
    -- Force CharBoardIndex
    ram_w8(0xFF041F, idx)
    -- Press Genesis B (= NES A) for 1 frame, then release several to dispatch
    press({["P1 B"]=true}, 1)
    adv(3)
    log(dump_namebuf("  after "))
    log(string.format("  after  %s", snap_state()))
    local landed = ram_u8(0xFF0638 + off_before)
    log(string.format("  expected $%02X at $0638+%02X actual=$%02X %s",
        bus_u8(A_CHARMAP + idx), off_before, landed,
        (landed == bus_u8(A_CHARMAP + idx)) and "MATCH" or "MISMATCH"))
    -- Release for several frames so D-pad/A repeat counter resets
    adv(8)
end

if ram_u8(0xFF0012) == 0x0E then
    test_index(0)
    test_index(5)
    test_index(10)
    test_index(15)
    test_index(22)
    test_index(30)
    test_index(42)

    -- ----------------------------------------------------------------
    -- Cursor-navigation test (Phase 9.6 verification): from a known
    -- starting position, send D-pad presses and log (idx, x, y) at each
    -- step. The board is 4 rows x 11 cols = 44 cells. CharBoardIndex
    -- ($041F) is the source of truth post-P13. Expected: each Right
    -- step increments idx mod 11 within a row, Down/Up moves +/-11 (mod
    -- 44 with hidden-slot snap), Left mirrors Right.
    -- ----------------------------------------------------------------
    log("--- CURSOR NAV TEST ---")
    -- Snap idx back to 0 to start clean
    ram_w8(0xFF041F, 0)
    adv(2)
    log(string.format("  start %s", snap_state()))

    local function nav(btn, n)
        for k = 1, n do
            press({[btn]=true}, 1)
            adv(6)
            log(string.format("  %s#%d %s", btn, k, snap_state()))
        end
    end

    -- Walk right across row 0 (11 cells expected: idx 0..10)
    nav("P1 Right", 11)
    -- Down should jump to row 1 (idx 11..)
    nav("P1 Down", 1)
    -- Walk right across row 1
    nav("P1 Right", 11)
    -- Down to row 2
    nav("P1 Down", 1)
    -- Down to row 3
    nav("P1 Down", 1)
    -- Walk left across row 3
    nav("P1 Left", 11)
    -- Up back through rows
    nav("P1 Up", 3)
else
    log(string.format("ABORT: failed to reach mode 0E (mode=%02X)", ram_u8(0xFF0012)))
end

log(string.format("=== fs2_keyboard end frame=%d totals ab=%d read=%d write=%d ===",
    frame_no, hits.ab, hits.read, hits.write))

local fh = assert(io.open(OUT_TXT, "w"))
fh:write(table.concat(lines, "\n") .. "\n")
fh:close()
client.exit()

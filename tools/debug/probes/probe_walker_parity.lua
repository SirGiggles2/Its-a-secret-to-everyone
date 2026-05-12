-- Phase 7 Task 7.2 step 3 — enemy slot iterator + INIT dispatch verifier.
--
-- Step 3 wires enemy_init_fns[$07] = enrt_init_slow_octorock_or_ghini
-- + a z07_reset_obj_state forwarder. Probe pre-pins LINK position so
-- enrt_init_walker DIR computation is deterministic, then verifies all
-- post-init cells (WALK_SPEED, MOVE_TIMER, ANIM_TIMER, OBJ_STATE) plus
-- the original step-2 cell-write checks.
--
-- Reads ENEMY_LOOP_PROBE_BASE = $FF7E00 = 68K RAM offset 0x7E00 and
-- prints (actual, expected) for each of the 14 checks. Saves a screenshot
-- after the verifier writes results so the screen state at probe-time is
-- captured.
--
-- Block layout (must match src/game/enemies/probes/enemy_loop_probe.h):
--   [0..1] = 'E','L'
--   [2]    = check_count (14)
--   [3]    = reserved
--   [4..]  = check_count * 4 bytes (actual_be_u16 || expected_be_u16)

local BASE = 0x7E00  -- 68K RAM domain offset for $FF7E00
local DOMAIN = "68K RAM"

local function read_u8(off)
    return memory.read_u8(BASE + off, DOMAIN)
end

local function read_u16_be(off)
    local hi = memory.read_u8(BASE + off, DOMAIN)
    local lo = memory.read_u8(BASE + off + 1, DOMAIN)
    return (hi * 256) + lo
end

local CHECK_NAMES = {
    [0]  = "alive_before_spawn (=0)",
    [1]  = "alive_after_spawn (=1)",
    [2]  = "ENEMY_TYPE(1) (=$07)",
    [3]  = "ENEMY_X(1) (=$80)",
    [4]  = "ENEMY_Y(1) (=$80)",
    [5]  = "ENEMY_DIR(1) (=$02 post-init)",
    [6]  = "ENEMY_STATE_TIMER(1) (=$00 — same cell as OBJ_STATE, zeroed by z07_reset_obj_state)",
    [7]  = "ENEMY_ALIVE_FLAG(1) (=1)",
    [8]  = "enemy_loop_get_type(1) (=$07)",
    [9]  = "enemy_loop_get_type(2) (=0)",
    [10] = "ENEMY_WALK_SPEED(1) (=$20)",
    [11] = "ENEMY_MOVE_TIMER(1) (=$20)",
    [12] = "ENEMY_ANIM_TIMER(1) (=$06)",
    [13] = "OBJ_STATE(1) (=0 via z07_reset_obj_state forwarder)",
}

local function format_u16(v)
    return string.format("$%04X (%d)", v, v)
end

local OUT_PATH = "C:\\tmp\\probe_walker_parity.txt"

local function probe_once()
    local f = io.open(OUT_PATH, "w")
    local function w(s)
        print(s)
        if f then f:write(s .. "\n") end
    end

    local magic_e = read_u8(0)
    local magic_l = read_u8(1)
    local count   = read_u8(2)

    w(string.rep("=", 60))
    w(string.format("ENEMY_LOOP probe @ $FF%04X", 0x7E00))
    w(string.format("  magic = '%c%c' (expect 'EL') raw=0x%02X 0x%02X",
                    magic_e, magic_l, magic_e, magic_l))
    w(string.format("  count = %d (expect 14)", count))
    w(string.rep("-", 60))

    if magic_e ~= 0x45 or magic_l ~= 0x4C then
        w("FAIL: magic mismatch — probe never ran or block clobbered.")
        if f then f:close() end
        return false, 0, 0
    end

    if count ~= 14 then
        w("FAIL: check count mismatch.")
        if f then f:close() end
        return false, 0, 0
    end

    local pass = 0
    local fail = 0

    for i = 0, count - 1 do
        local off = 4 + (i * 4)
        local actual   = read_u16_be(off)
        local expected = read_u16_be(off + 2)
        local ok = (actual == expected)
        local status = ok and "PASS" or "FAIL"
        local name = CHECK_NAMES[i] or ("check[" .. tostring(i) .. "]")
        w(string.format("  %s [%d] %s  actual=%s  expected=%s",
                        status, i, name,
                        format_u16(actual), format_u16(expected)))
        if ok then pass = pass + 1 else fail = fail + 1 end
    end

    w(string.rep("-", 60))
    w(string.format("RESULT: %d/%d passed", pass, count))
    w(string.rep("=", 60))

    if f then f:close() end
    return fail == 0, pass, fail
end

-- Boot path: title screen polls JOY_1 for the A+B+C debug chord
-- (src/debug/a4_probe_main.c:15 CHORD_DEBUG). Rising edge fires
-- roomrom_debug_enter() which clears slots and runs enemy_loop_probe_run()
-- only when this script arms the heavy probe with "RP" at $FF73F8.
--
-- Sequence: advance idle to settle title, then hold A+B+C for several
-- frames so the rising-edge detector triggers, then advance to let
-- the boot path complete.

-- 1) Idle frames to settle title.
for _ = 1, 180 do
    emu.frameadvance()
end

-- 2) Arm the heavy enemy-loop stress probe, then hold A+B+C.
memory.write_u8(0x73F8, 0x52, "68K RAM") -- 'R'
memory.write_u8(0x73F9, 0x50, "68K RAM") -- 'P'
memory.write_u8(0x73FA, 0x03, "68K RAM") -- heavy mirror + enemy stress
local chord = {["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true}
for _ = 1, 30 do
    joypad.set(chord)
    emu.frameadvance()
end

-- 3) Release and let roomrom_debug_enter run end-to-end.
for _ = 1, 60 do
    emu.frameadvance()
end

-- Take screenshot.
local shot = "C:\\tmp\\probe_walker_parity.png"
client.screenshot(shot)
print("Screenshot: " .. shot)

local all_pass = probe_once()

if all_pass then
    print(">>> WALKER PARITY PROBE: ALL CHECKS PASS <<<")
else
    print(">>> WALKER PARITY PROBE: FAIL <<<")
end

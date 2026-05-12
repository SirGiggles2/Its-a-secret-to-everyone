-- Phase 7 Task 7.3 step 8 -- family-73 multi-slot dispatch verify.
--
-- Reads $FF7E40 (ENEMY_LOOP_FAMILY73_BASE) family-73 block published by
-- publish_family73() at end of enemy_loop_tick() each frame. Verifies
-- that the 6 dispatch UPDATE rows wired in steps 3..7 tick without
-- crashing and (for movement-active types) advance per-frame state.
--
-- Slot mapping (entry index -> slot -> NES type):
--   0 -> 6  -> $13 Zol
--   1 -> 7  -> $15 Gel
--   2 -> 8  -> $1A Peahat
--   3 -> 9  -> $1B BlueKeese
--   4 -> 10 -> $28 Rope
--   5 -> 11 -> $12 Vire
--
-- Per-entry layout (8 bytes):
--   [0] ALIVE_FLAG  [1] TYPE        [2] X       [3] Y
--   [4] DIR         [5] ANIM_TIMER  [6] MOVE_TIMER  [7] FLAP_PHASE
--
-- PASS gates:
--   G1 magic 'FM' present (publisher fired)
--   G2-G7  per-slot alive+type held (zol, gel, peahat, keese, rope, vire)
--   G8     at least one family-73 slot advanced X/Y/anim/flap (proves
--          UPDATE bodies tick, not just init)

local FAM73_BASE = 0x7E40
local DOMAIN = "68K RAM"

local SLOTS = {
    { idx = 0, slot =  6, ntype = 0x13, name = "zol"    },
    { idx = 1, slot =  7, ntype = 0x15, name = "gel"    },
    { idx = 2, slot =  8, ntype = 0x1A, name = "peahat" },
    { idx = 3, slot =  9, ntype = 0x1B, name = "keese"  },
    { idx = 4, slot = 10, ntype = 0x28, name = "rope"   },
    { idx = 5, slot = 11, ntype = 0x12, name = "vire"   },
}

local function read_u8(off)
    return memory.read_u8(FAM73_BASE + off, DOMAIN)
end

local function snapshot_entry(entry_idx)
    local off = 4 + entry_idx * 8
    return {
        alive  = read_u8(off + 0),
        type_  = read_u8(off + 1),
        x      = read_u8(off + 2),
        y      = read_u8(off + 3),
        dir    = read_u8(off + 4),
        anim_t = read_u8(off + 5),
        move_t = read_u8(off + 6),
        flap   = read_u8(off + 7),
    }
end

local OUT_PATH = "C:\\tmp\\probe_family73_dispatch.txt"
local f = io.open(OUT_PATH, "w")
local function w(s)
    print(s)
    if f then f:write(s .. "\n") end
end

-- 1) Idle to settle title.
for _ = 1, 180 do emu.frameadvance() end

-- 2) Arm the heavy enemy-loop stress probe, then A+B+C enters
-- roomrom_debug_enter (force_spawn slots 1..11).
memory.write_u8(0x73F8, 0x52, "68K RAM") -- 'R'
memory.write_u8(0x73F9, 0x50, "68K RAM") -- 'P'
memory.write_u8(0x73FA, 0x03, "68K RAM") -- heavy mirror + enemy stress
local chord = {["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true}
for _ = 1, 30 do
    joypad.set(chord)
    emu.frameadvance()
end

-- 3) Boot path completes.
for _ = 1, 60 do emu.frameadvance() end

w(string.rep("=", 64))
w("FAMILY-73 DISPATCH TRACE -- $FF7E40 (slots 6..11, types $13/$15/$1A/$1B/$28/$12)")
w(string.rep("-", 64))

local magic_f = read_u8(0)
local magic_m = read_u8(1)
w(string.format("magic = '%c%c' (expect 'FM')", magic_f, magic_m))

-- 4) Sample 31 snapshots over 600 frames (20 frames between samples).
local per_slot_samples = {}
for i = 1, 6 do per_slot_samples[i] = {} end

for sample_n = 1, 31 do
    local line = string.format("[t+%3d]", (sample_n - 1) * 20)
    for i, sd in ipairs(SLOTS) do
        local s = snapshot_entry(sd.idx)
        table.insert(per_slot_samples[i], s)
        line = line .. string.format(
            " | %-6s al=%d t=$%02X xy=(%3d,%3d) dir=$%02X anim=%3d move=$%02X flap=$%02X",
            sd.name, s.alive, s.type_, s.x, s.y,
            s.dir, s.anim_t, s.move_t, s.flap)
    end
    w(line)
    if sample_n < 31 then
        for _ = 1, 20 do emu.frameadvance() end
    end
end

-- 5) Per-slot summary.
w(string.rep("-", 64))
w("PER-SLOT SUMMARY")
for i, sd in ipairs(SLOTS) do
    local sl = per_slot_samples[i]
    local first = sl[1]
    local last  = sl[#sl]
    w(string.format(
        "  %-6s slot %2d type=$%02X alive %d->%d xy=(%d,%d)->(%d,%d) anim=%d->%d move=$%02X->$%02X flap=$%02X->$%02X",
        sd.name, sd.slot, sd.ntype,
        first.alive, last.alive,
        first.x, first.y, last.x, last.y,
        first.anim_t, last.anim_t,
        first.move_t, last.move_t,
        first.flap,   last.flap))
end

-- 6) Gate evaluation.
w(string.rep("-", 64))
local pass = true
local function gate(ok, name)
    w(string.format("  %s  %s", ok and "PASS" or "FAIL", name))
    if not ok then pass = false end
end

gate(magic_f == 0x46 and magic_m == 0x4D, "G1 magic 'FM' present")

local function alive_and_type_held(entry_idx, expected_type)
    local sl = per_slot_samples[entry_idx + 1]
    for _, s in ipairs(sl) do
        if s.alive ~= 1 then return false end
        if s.type_ ~= expected_type then return false end
    end
    return true
end

for i, sd in ipairs(SLOTS) do
    local gname = string.format("G%d slot %2d %-6s ($%02X) alive+type held",
                                 i + 1, sd.slot, sd.name, sd.ntype)
    gate(alive_and_type_held(sd.idx, sd.ntype), gname)
end

-- G8: at least one family-73 slot advanced any of X/Y/anim/flap across
-- the trace (proves the UPDATE chain ran a body, not just init).
local any_advanced = false
local advanced_msg = ""
for i, sd in ipairs(SLOTS) do
    local sl = per_slot_samples[i]
    for j = 2, #sl do
        if sl[j].x      ~= sl[j-1].x      or
           sl[j].y      ~= sl[j-1].y      or
           sl[j].anim_t ~= sl[j-1].anim_t or
           sl[j].move_t ~= sl[j-1].move_t or
           sl[j].flap   ~= sl[j-1].flap   then
            any_advanced = true
            advanced_msg = sd.name
            break
        end
    end
    if any_advanced then break end
end
gate(any_advanced,
     string.format("G8 at least one family-73 slot advanced motion/anim (witness: %s)",
                   advanced_msg == "" and "none" or advanced_msg))

w(string.rep("-", 64))
w(pass and ">>> FAMILY-73 DISPATCH: PASS <<<"
        or ">>> FAMILY-73 DISPATCH: FAIL <<<")
w(string.rep("=", 64))

local shot = "C:\\tmp\\probe_family73_dispatch.png"
client.screenshot(shot)
print("Screenshot: " .. shot)

if f then f:close() end

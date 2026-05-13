-- ph5_uw_t52_special_cases.lua
--
-- Phase 5 Task 5.2 parity probe — UW collision grid + wall-stop verification.
--
-- Targets 8 L1 rooms selected for collision diversity:
--   L1 $29 (uid 07, water=15)      L1 $35 (uid 23, water=26)
--   L1 $36 (uid 10, WALL-only)     L1 $53 (uid 36, water=20)
--   L1 $63 (uid 03, water+hazard)  L1 $72 (uid 13, water=4)
--   L1 $73 (uid 30, water=36)      L1 $74 (uid 00, water=6)
--
-- Also captures 4-direction wall-stop in room $73 (the canonical test room).
--
-- Symbol offsets are passed by tools/probes/run_ph5_uw_t52_special_cases.py.
-- The launcher resolves build/debug_project/out/Debug.out and boots this Lua
-- together with builds/Debug.md.
--
-- Output: build/probes/ph5/t52/special_cases.json
-- Compared by: python tools/parity/verify_uw_collision.py --probe build/probes/ph5/t52/special_cases.json
--
-- Wall-stop: build/probes/ph5/t52/wall_stop.json
-- Pass criterion: stable_x=true, stable_y=true in all 4 directions.

local OUT_CASES = os.getenv("CODEX_T52_OUT_CASES") or "build/probes/ph5/t52/special_cases.json"
local OUT_WSTOP = os.getenv("CODEX_T52_OUT_WSTOP") or "build/probes/ph5/t52/wall_stop.json"

local function parse_env_hex(name, value)
    if value == nil or value == "" then
        error("[ph5_t52] missing environment variable " .. name)
    end
    local n = tonumber(value) or tonumber((value:gsub("^0x", "")), 16)
    if n == nil then
        error("[ph5_t52] invalid environment variable " .. name .. "=" .. tostring(value))
    end
    return n
end

local function domain_exists(name)
    for _, domain in ipairs(memory.getmemorydomainlist()) do
        if domain == name then return true end
    end
    return false
end

local RAM = "M68K BUS"
local RAM_OFFSET = 0x00FF0000
local PROBE_BASE = 0x00FF7000
local TITLE_PHASE_ADDR = 0x00FF8000 + 0x07F0
if domain_exists("68K RAM") then
    RAM = "68K RAM"
    RAM_OFFSET = 0
    PROBE_BASE = 0x7000
    TITLE_PHASE_ADDR = 0x8000 + 0x07F0
elseif domain_exists("M68K RAM") then
    RAM = "M68K RAM"
    RAM_OFFSET = 0
    PROBE_BASE = 0x7000
    TITLE_PHASE_ADDR = 0x8000 + 0x07F0
end

local function addr(off)
    return RAM_OFFSET + off
end
local function r8(off)
    local v = memory.read_u8(addr(off), RAM)
    return v or 0
end
local function r16s(off)
    local v = memory.read_s16_be(addr(off), RAM)
    return v or 0
end
local function r32(off)
    local v = memory.read_u32_be(addr(off), RAM)
    return v or 0
end
local function w16(off, val)
    memory.write_u16_be(addr(off), val, RAM)
end
local function w32(off, val)
    memory.write_u32_be(addr(off), val, RAM)
end

local SYM_LINK_X   = parse_env_hex("CODEX_T52_LINK_X", os.getenv("CODEX_T52_LINK_X"))
local SYM_LINK_Y   = parse_env_hex("CODEX_T52_LINK_Y", os.getenv("CODEX_T52_LINK_Y"))
local SYM_ROOM_ID  = parse_env_hex("CODEX_T52_ROOM_ID", os.getenv("CODEX_T52_ROOM_ID"))
local SYM_SCENE    = parse_env_hex("CODEX_T52_SCENE", os.getenv("CODEX_T52_SCENE"))
local SYM_UW_LEVEL = parse_env_hex("CODEX_T52_UW_LEVEL", os.getenv("CODEX_T52_UW_LEVEL"))
local SYM_LINK_DIR = parse_env_hex("CODEX_T52_LINK_DIR", os.getenv("CODEX_T52_LINK_DIR"))
local SYM_WALKABLE = parse_env_hex("CODEX_T52_WALKABLE", os.getenv("CODEX_T52_WALKABLE"))

local LINK_SPAWN_X   = 124
local LINK_SPAWN_Y   = 144

-- Joypad helper: set button for n frames then release for n frames.
local function adv(n, pad)
    for _ = 1, n do
        if pad then joypad.set(pad) end
        emu.frameadvance()
    end
end

local function tap(btn)
    local p = { [btn] = true, ["P1 " .. btn] = true }
    adv(4, p)
    adv(4, {})
end

local function hold(btn, n)
    local p = { [btn] = true, ["P1 " .. btn] = true }
    adv(n, p)
    adv(4, {})
end

local function probe_r8(off)
    local v = memory.read_u8(PROBE_BASE + off, RAM)
    return v or 0
end

local function title_phase()
    local v = memory.read_u8(TITLE_PHASE_ADDR, RAM)
    return v or 0
end

local function enter_debug_room()
    if probe_r8(13) == 1 then return true end
    local magic = false
    for _ = 1, 120 do
        emu.frameadvance()
        if probe_r8(0) == 0xA4 and probe_r8(1) == 0x4A then
            magic = true
            break
        end
    end
    if not magic then return false, "probe_magic_failed" end
    for _ = 1, 60 do
        if title_phase() == 1 then break end
        emu.frameadvance()
    end
    if title_phase() ~= 1 then return false, "title_phase_failed" end
    for _ = 1, 8 do
        joypad.set({ ["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true }, 1)
        emu.frameadvance()
    end
    joypad.set({}, 1)
    for _ = 1, 180 do
        emu.frameadvance()
        if probe_r8(13) == 1 then return true, "ok" end
    end
    return false, "debug_entry_failed"
end

-- Read s_uw_walkable grid as flat 176-byte array (col-major: index = col*11+row).
local function read_walkable()
    local out = {}
    for i = 0, 175 do
        out[i + 1] = r8(SYM_WALKABLE + i)
    end
    return out
end

-- Read all grid cells at (col, row) → flat [1..176].
local function walkable_at(grid, col, row)
    return grid[col * 11 + row + 1]
end

-- Snapshot current RAM state for one room.
local function snap_room(name)
    adv(8, {})    -- let room load settle
    return {
        name      = name,
        frame     = emu.framecount(),
        room_id   = r8(SYM_ROOM_ID),
        uw_level  = r8(SYM_UW_LEVEL),
        scene     = r32(SYM_SCENE),
        walkable  = read_walkable(),
    }
end

-- Navigate from current room_id to target room via D-pad presses in TELEPORT mode.
-- Room grid: room_id = (row << 4) | col. One press = one cell.
local function teleport_to(target_id)
    local function cur_col() return r8(SYM_ROOM_ID) % 16 end
    local function cur_row() return math.floor(r8(SYM_ROOM_ID) / 16) end
    local want_col = target_id % 16
    local want_row = math.floor(target_id / 16)
    -- Move columns first, then rows (arbitrary order).
    while cur_col() ~= want_col do
        if cur_col() < want_col then
            tap("Right")
        else
            tap("Left")
        end
        adv(4, {})
    end
    while cur_row() ~= want_row do
        if cur_row() < want_row then
            tap("Down")
        else
            tap("Up")
        end
        adv(4, {})
    end
end

-- Reset Link to spawn position via direct WRAM write.
local function reset_link_pos()
    w16(SYM_LINK_X, LINK_SPAWN_X)
    w16(SYM_LINK_Y, LINK_SPAWN_Y)
    w32(SYM_LINK_DIR, 0)
    adv(4, {})
end

-- Wall-stop test: drive in one direction for DRIVE_FRAMES, sample final SAMPLE_FRAMES.
-- Returns { direction, start_x, start_y, samples_x, samples_y, stable_x, stable_y }
local DRIVE_FRAMES  = 90
local SAMPLE_FRAMES = 10

local function wall_stop_test(dir_name, btn)
    reset_link_pos()
    adv(4, {})    -- settle
    local sx = r16s(SYM_LINK_X)
    local sy = r16s(SYM_LINK_Y)
    -- Drive into wall.
    hold(btn, DRIVE_FRAMES)
    -- Sample final position across SAMPLE_FRAMES.
    local xs, ys = {}, {}
    for _ = 1, SAMPLE_FRAMES do
        local p = { [btn] = true, ["P1 " .. btn] = true }
        joypad.set(p)
        emu.frameadvance()
        xs[#xs + 1] = r16s(SYM_LINK_X)
        ys[#ys + 1] = r16s(SYM_LINK_Y)
    end
    adv(4, {})
    -- Check stability: all sample values identical.
    local stable_x = true
    local stable_y = true
    for i = 2, SAMPLE_FRAMES do
        if xs[i] ~= xs[1] then stable_x = false end
        if ys[i] ~= ys[1] then stable_y = false end
    end
    return {
        direction = dir_name,
        start_x   = sx,
        start_y   = sy,
        final_x   = xs[SAMPLE_FRAMES],
        final_y   = ys[SAMPLE_FRAMES],
        stable_x  = stable_x,
        stable_y  = stable_y,
    }
end

-- JSON serialiser.
local function to_json(v, _depth)
    _depth = _depth or 0
    local t = type(v)
    if t == "number" then
        return tostring(v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        local is_array = true
        for k in pairs(v) do
            if type(k) ~= "number" then is_array = false; break end
        end
        if is_array and n > 0 then
            local parts = {}
            for i = 1, n do parts[#parts + 1] = to_json(v[i], _depth + 1) end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, val in pairs(v) do
                parts[#parts + 1] = string.format("%q:%s", tostring(k), to_json(val, _depth + 1))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

local function write_json(path, payload)
    local f = io.open(path, "w")
    if f then
        f:write(to_json(payload))
        f:close()
        print("[ph5_t52] wrote " .. path)
    else
        print("[ph5_t52] FAIL: could not write " .. path)
    end
end

-- ===========================================================================
-- Main sequence
-- ===========================================================================

-- 1. Enter Debug gameplay from the title with A+B+C.
local entered, entry_reason = enter_debug_room()
if not entered then
    print("[ph5_t52] ERROR: " .. tostring(entry_reason))
    client.exit()
end
adv(16, {})

-- Verify we are in UW scene.
if r32(SYM_SCENE) ~= 1 then
    print("[ph5_t52] ERROR: not in UW scene at boot!")
    client.exit()
end

-- 2. Enter TELEPORT mode (X button).
tap("X")
adv(8, {})    -- let mode change settle

-- ===========================================================================
-- Capture 8 rooms.
-- ===========================================================================
local rooms = {}

-- Rooms in teleport-navigation order (minimises D-pad presses):
-- $73 (already loaded) → $29 → $35 → $36 → $53 → $63 → $72 → $73 → $74
-- Start room $73 is already loaded; navigate to each target.

-- Room $29 (row=2, col=9)
teleport_to(0x29)
rooms[#rooms + 1] = snap_room("L1_0x29_uid07_water15")

-- Room $35 (row=3, col=5)
teleport_to(0x35)
rooms[#rooms + 1] = snap_room("L1_0x35_uid23_water26")

-- Room $36 (row=3, col=6)
teleport_to(0x36)
rooms[#rooms + 1] = snap_room("L1_0x36_uid10_wallonly")

-- Room $53 (row=5, col=3)
teleport_to(0x53)
rooms[#rooms + 1] = snap_room("L1_0x53_uid36_water20")

-- Room $63 (row=6, col=3)
teleport_to(0x63)
rooms[#rooms + 1] = snap_room("L1_0x63_uid03_hazard")

-- Room $72 (row=7, col=2)
teleport_to(0x72)
rooms[#rooms + 1] = snap_room("L1_0x72_uid13_water4")

-- Room $73 (row=7, col=3) — canonical entrance
teleport_to(0x73)
rooms[#rooms + 1] = snap_room("L1_0x73_uid30_water36")

-- Room $74 (row=7, col=4)
teleport_to(0x74)
rooms[#rooms + 1] = snap_room("L1_0x74_uid00_water6")

write_json(OUT_CASES, {
    schema  = "ph5_t52_special_cases_v1",
    rom     = "Debug.md",
    level   = 1,
    quest   = 1,
    rooms   = rooms,
})

-- ===========================================================================
-- Wall-stop test in room $73.
-- ===========================================================================

-- Navigate back to $73 and switch to WALK mode.
teleport_to(0x73)
tap("X")     -- exit TELEPORT → WALK mode
adv(8, {})

local wall_stops = {}
wall_stops[#wall_stops + 1] = wall_stop_test("DOWN",  "Down")
wall_stops[#wall_stops + 1] = wall_stop_test("UP",    "Up")
wall_stops[#wall_stops + 1] = wall_stop_test("RIGHT", "Right")
wall_stops[#wall_stops + 1] = wall_stop_test("LEFT",  "Left")

write_json(OUT_WSTOP, {
    schema     = "ph5_t52_wall_stop_v1",
    rom        = "Debug.md",
    room_id    = 0x73,
    level      = 1,
    quest      = 1,
    spawn_x    = LINK_SPAWN_X,
    spawn_y    = LINK_SPAWN_Y,
    drive_frames  = DRIVE_FRAMES,
    sample_frames = SAMPLE_FRAMES,
    results    = wall_stops,
})

-- All done.
print("[ph5_t52] probe complete — both JSON files written")
client.exit()

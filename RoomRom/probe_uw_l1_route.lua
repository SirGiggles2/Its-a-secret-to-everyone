-- probe_uw_l1_route.lua
--
-- Task 5.5 — passive UW door-state recorder for L1Q1 traversal.
-- User drives Link through every reachable=1 room in
-- RoomRom/data/uw_l1q1_expected_doors.{c,h}; this script reads the
-- 72-byte state mirror at 0xFF7200 + 256-byte persistence block at
-- 0xFF76D0 every frame and emits JSONL door-state observations for
-- the diff harness (tools/gate_5_5_door_route.py).
--
-- Outputs:
--   C:\tmp\uw_route_progress.json     — live visited/remaining sets
--   C:\tmp\uw_door_observations.jsonl — append per room entry / touch
--   C:\tmp\uw_door_state.json         — single-line current snapshot

local MIRROR_BASE = 0xFF7200
local MIRROR_OFFSET = 0x7200   -- domain offset in "68K RAM" (which is $FF0000-based)
local PERSIST_OFFSET = 0x76D0
local MAGIC_W, MAGIC_P = 0x57, 0x50

local L1Q1_REACHABLE = {
    [0x22]=true, [0x23]=true, [0x33]=true,
    [0x41]=true, [0x42]=true, [0x43]=true, [0x44]=true, [0x45]=true,
    [0x52]=true, [0x53]=true, [0x54]=true,
    [0x63]=true, [0x72]=true, [0x73]=true, [0x74]=true,
}
-- $35 boss + $36 triforce = combat-locked, excluded.
local TOTAL_REACHABLE = 0
for _ in pairs(L1Q1_REACHABLE) do TOTAL_REACHABLE = TOTAL_REACHABLE + 1 end

-- Domain selection (try common names).
local DOMAIN
do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if ok then DOMAIN = "68K RAM"
    else
        ok = pcall(function() memory.usememorydomain("Main RAM") end)
        if ok then DOMAIN = "Main RAM" else DOMAIN = "MD RAM" end
    end
end
print("[probe_uw_l1_route] memory domain: " .. tostring(DOMAIN))

local function rb(off) return memory.read_u8(MIRROR_OFFSET + off) end
local function rs8(off)
    local v = memory.read_u8(MIRROR_OFFSET + off)
    if v >= 0x80 then v = v - 0x100 end
    return v
end
local function rs16be(off)
    local hi = memory.read_u8(MIRROR_OFFSET + off)
    local lo = memory.read_u8(MIRROR_OFFSET + off + 1)
    local v = hi * 256 + lo
    if v >= 0x8000 then v = v - 0x10000 end
    return v
end
local function ru16be(off)
    return memory.read_u8(MIRROR_OFFSET + off) * 256
         + memory.read_u8(MIRROR_OFFSET + off + 1)
end

local function read_persist(room_id)
    return memory.read_u8(PERSIST_OFFSET + (room_id & 0xFF))
end

local function read_mirror()
    if rb(0) ~= MAGIC_W or rb(1) ~= MAGIC_P then return nil end
    return {
        frame      = ru16be(2),
        scene      = rb(4),
        room_id    = rb(5),
        link_x     = rs16be(6),
        link_y     = rs16be(8),
        link_face  = rb(10),
        link_dir   = rb(11),
        link_grid  = rs8(12),
        doorway    = rb(13),
        uw_level   = rb(16),
        uw_quest   = rb(17),
        door_E = rb(40), door_W = rb(41), door_S = rb(42), door_N = rb(43),
        opened_mask = rb(44),
        false_timer = rb(45),
        has_shutters = rb(46),
        shutter_trigger_count = rb(47),
        keys = rb(48),
        keys_pre = rb(49),
        keys_post = rb(50),
        last_touch_dir = rb(51),
        last_touch_result = rb(52),
        last_touch_door_type = rb(53),
    }
end

-- JSON encoder (flat objects).
local function jval(v)
    local t = type(v)
    if t == "string" then return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
    elseif t == "number" then return tostring(v)
    elseif t == "boolean" then return v and "true" or "false"
    else return "null" end
end
local function jobj(o)
    local keys = {}
    for k in pairs(o) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = '"' .. k .. '":' .. jval(o[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local jsonl_path = "C:\\tmp\\uw_door_observations.jsonl"
local progress_path = "C:\\tmp\\uw_route_progress.json"
local state_path = "C:\\tmp\\uw_door_state.json"
local walk_path = "C:\\tmp\\uw_walk_dump.json"

-- Read 32x22 BG-tile walkability cache at $FF7800 (Task 5.5 publish).
local UW_WALK_BASE = 0x7800
local function dump_walkability_around(lcol, lrow)
    if memory.read_u8(UW_WALK_BASE) ~= 0x55 or
       memory.read_u8(UW_WALK_BASE + 1) ~= 0x57 then
        return nil
    end
    local cells = {}
    for c = 0, 31 do
        cells[c] = {}
        for r = 0, 21 do
            cells[c][r] = memory.read_u8(UW_WALK_BASE + 4 + c * 22 + r)
        end
    end
    return cells
end

local function write_walk_dump(lcol, lrow, cells)
    local f = io.open(walk_path, "w")
    if not f then return end
    f:write('{"link_col":' .. lcol .. ',"link_row":' .. lrow .. ',"cells":[\n')
    for r = 0, 21 do
        f:write("  [")
        for c = 0, 31 do
            f:write(tostring(cells[c][r]))
            if c < 31 then f:write(",") end
        end
        f:write("]")
        if r < 21 then f:write(",") end
        f:write("\n")
    end
    f:write("]}\n")
    f:close()
end

-- Append mode so re-launches don't wipe prior session evidence.
local jsonl = io.open(jsonl_path, "a")
if not jsonl then
    print("ERROR: cannot open " .. jsonl_path); return
end
jsonl:write(jobj({event="probe_open", ts=os.time(),
    note="Task 5.5 UW L1Q1 door-state probe; mirror $FF7200 / persist $FF76D0"}) .. "\n")
jsonl:flush()

local function jappend(obj)
    jsonl:write(jobj(obj) .. "\n")
    jsonl:flush()
end

local function write_progress(visited)
    local v_arr, r_arr = {}, {}
    for room in pairs(L1Q1_REACHABLE) do
        if visited[room] then v_arr[#v_arr + 1] = room
        else r_arr[#r_arr + 1] = room end
    end
    table.sort(v_arr); table.sort(r_arr)
    local h = io.open(progress_path, "w")
    if h then
        h:write(jobj({
            visited_count = #v_arr,
            remaining_count = #r_arr,
            total_reachable = TOTAL_REACHABLE,
            visited = "[" .. table.concat(map_format(v_arr), ",") .. "]",
            remaining = "[" .. table.concat(map_format(r_arr), ",") .. "]",
        }) .. "\n")
        h:close()
    end
end

function map_format(arr)
    local out = {}
    for i, v in ipairs(arr) do out[i] = string.format("\"$%02X\"", v) end
    return out
end

local visited = {}
local prev = nil
local state_counter = 0

while true do
    local m = read_mirror()
    if m ~= nil then
        -- Live snapshot every 6 frames.
        state_counter = state_counter + 1
        if state_counter >= 6 then
            local h = io.open(state_path, "w")
            if h then
                h:write(jobj({
                    frame = m.frame, scene = m.scene, room_id = m.room_id,
                    link_x = m.link_x, link_y = m.link_y,
                    link_face = m.link_face, link_dir = m.link_dir,
                    link_grid = m.link_grid, doorway = m.doorway,
                    uw_level = m.uw_level, uw_quest = m.uw_quest,
                    door_E = m.door_E, door_W = m.door_W,
                    door_S = m.door_S, door_N = m.door_N,
                    opened_mask = m.opened_mask, false_timer = m.false_timer,
                    has_shutters = m.has_shutters,
                    shutter_trigger_count = m.shutter_trigger_count,
                    keys = m.keys, keys_pre = m.keys_pre, keys_post = m.keys_post,
                    last_touch_dir = m.last_touch_dir,
                    last_touch_result = m.last_touch_result,
                    last_touch_door_type = m.last_touch_door_type,
                    persisted_mask_this_room = read_persist(m.room_id),
                }) .. "\n")
                h:close()
            end
            -- Also dump UW walkability cache to /c/tmp/uw_walk_dump.json
            -- once per state cycle. Only meaningful when in UW.
            if m.scene == 1 then
                local foot_y = m.link_y + 0x0B
                local lcol = math.floor(m.link_x / 8)
                local lrow = math.floor((foot_y - 56) / 8)
                local cells = dump_walkability_around(lcol, lrow)
                if cells then write_walk_dump(lcol, lrow, cells) end
            end
            state_counter = 0
        end

        -- Track room transitions in UW only.
        if m.scene == 1 then
            local room_changed = (prev == nil) or (prev.room_id ~= m.room_id) or (prev.scene ~= 1)
            if room_changed then
                local persist_before = read_persist(m.room_id)
                jappend({
                    event = "room_entry",
                    frame = m.frame,
                    room_id = m.room_id,
                    door_E = m.door_E, door_W = m.door_W,
                    door_S = m.door_S, door_N = m.door_N,
                    opened_mask = m.opened_mask,
                    has_shutters = m.has_shutters,
                    persisted_mask = persist_before,
                    uw_level = m.uw_level, uw_quest = m.uw_quest,
                    keys_at_entry = m.keys,
                })
                if L1Q1_REACHABLE[m.room_id] and not visited[m.room_id] then
                    visited[m.room_id] = true
                    write_progress(visited)
                end
            end
            -- Record touch events: log on every change of (last_touch_dir,
            -- last_touch_result) tuple.
            if prev and (prev.last_touch_dir ~= m.last_touch_dir or
                         prev.last_touch_result ~= m.last_touch_result) then
                jappend({
                    event = "touch",
                    frame = m.frame,
                    room_id = m.room_id,
                    dir = m.last_touch_dir,
                    door_type = m.last_touch_door_type,
                    result = m.last_touch_result,
                    keys_pre = m.keys_pre,
                    keys_post = m.keys_post,
                    opened_mask_after = m.opened_mask,
                })
            end
            -- Record shutter trigger fires.
            if prev and prev.shutter_trigger_count ~= m.shutter_trigger_count then
                jappend({
                    event = "shutter_trigger",
                    frame = m.frame,
                    room_id = m.room_id,
                    count = m.shutter_trigger_count,
                    opened_mask_after = m.opened_mask,
                })
            end
        end

        prev = m
    end
    emu.frameadvance()
end

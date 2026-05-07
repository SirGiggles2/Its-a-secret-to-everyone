-- probe_uw_inventory_auto.lua
-- Task 5.9 auto-verification probe.
-- Boot drops Link in $36 at triforce position; pickup fires tick 0.
-- Reads mirror $FF7200 + persistence $FF7D00.

local MIRROR_OFFSET = 0x7200
local PERSIST_OFFSET = 0x7D00
local MAGIC_W, MAGIC_P = 0x57, 0x50

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then
        ok = pcall(function() memory.usememorydomain("Main RAM") end)
        if not ok then memory.usememorydomain("MD RAM") end
    end
end
print("[probe_uw_inventory_auto] mirror $FF7200 / item-taken $FF7D00")

local function rb(off) return memory.read_u8(MIRROR_OFFSET + off) end
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
        uw_level   = rb(16),
        uw_quest   = rb(17),
        keys       = rb(48),
        compass    = rb(105),
        map        = rb(106),
        triforce_inv = rb(107),
        item_id_for_room = rb(108),
        item_taken = rb(109),
        triforce_active = rb(111),
    }
end

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

local jsonl_path = "C:\\tmp\\uw_inventory_observations.jsonl"
local state_path = "C:\\tmp\\uw_inventory_state.json"
local jsonl = io.open(jsonl_path, "a")
if not jsonl then print("ERROR: cannot open " .. jsonl_path); return end
jsonl:write(jobj({event="probe_open", ts=os.time(),
    note="Task 5.9 auto-probe; boot at triforce"}) .. "\n")
jsonl:flush()
local function jappend(o) jsonl:write(jobj(o) .. "\n"); jsonl:flush() end

local prev = nil
local fcount = 0

while true do
    local m = read_mirror()
    if m ~= nil then
        m.persist_this_room = read_persist(m.room_id)
        if fcount % 6 == 0 then
            local h = io.open(state_path, "w")
            if h then h:write(jobj(m) .. "\n"); h:close() end
        end

        local effective_prev = prev or {
            item_taken = 0, triforce_active = 0,
            compass = 0, map = 0,
        }
        if true then
            if effective_prev.item_taken == 0 and m.item_taken == 1 then
                jappend({
                    event = "item_pickup",
                    frame = m.frame, room_id = m.room_id,
                    item_id = m.item_id_for_room,
                    compass = m.compass, map = m.map,
                    triforce_active = m.triforce_active,
                })
            end
            if effective_prev.triforce_active == 0 and m.triforce_active == 1 then
                jappend({
                    event = "triforce_pickup",
                    frame = m.frame, room_id = m.room_id,
                })
            end
            if (effective_prev.compass == 0 and m.compass ~= 0) then
                jappend({
                    event = "compass_set",
                    frame = m.frame, byte = m.compass,
                })
            end
            if (effective_prev.map == 0 and m.map ~= 0) then
                jappend({
                    event = "map_set",
                    frame = m.frame, byte = m.map,
                })
            end
        end
        prev = m
    end

    fcount = fcount + 1
    emu.frameadvance()
end

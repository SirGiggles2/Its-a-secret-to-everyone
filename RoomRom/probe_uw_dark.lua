-- probe_uw_dark.lua
--
-- Task 5.8 — passive UW dark-room recorder.
-- Reads 104-byte state mirror at $FF7200 every frame, emits JSONL
-- events on dark room enter, candle reveal, and persistence on
-- room re-entry.

local MIRROR_OFFSET = 0x7200
local PERSIST_OFFSET = 0x7C00
local MAGIC_W, MAGIC_P = 0x57, 0x50

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then
        ok = pcall(function() memory.usememorydomain("Main RAM") end)
        if not ok then memory.usememorydomain("MD RAM") end
    end
end
print("[probe_uw_dark] mirror $FF7200 / persist $FF7C00")

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
        is_dark    = rb(96),
        is_lit     = rb(97),
        candle_used_count = rb(98),
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

local jsonl_path = "C:\\tmp\\uw_dark_observations.jsonl"
local state_path = "C:\\tmp\\uw_dark_state.json"
local jsonl = io.open(jsonl_path, "a")
if not jsonl then print("ERROR: cannot open " .. jsonl_path); return end
jsonl:write(jobj({event="probe_open", ts=os.time(),
    note="Task 5.8 UW dark-room probe; mirror $FF7200 (104 B)"}) .. "\n")
jsonl:flush()
local function jappend(o) jsonl:write(jobj(o) .. "\n"); jsonl:flush() end

local prev = nil
local state_ctr = 0

while true do
    local m = read_mirror()
    if m ~= nil then
        m.persist_this_room = read_persist(m.room_id)
        state_ctr = state_ctr + 1
        if state_ctr >= 6 then
            local h = io.open(state_path, "w")
            if h then h:write(jobj(m) .. "\n"); h:close() end
            state_ctr = 0
        end

        if prev and m.scene == 1 then
            -- Dark room enter: room transition into a dark room.
            if (prev.scene ~= 1 or prev.room_id ~= m.room_id) and m.is_dark == 1 then
                jappend({
                    event = "room_dark_enter",
                    frame = m.frame, room_id = m.room_id,
                    level = m.uw_level, quest = m.uw_quest,
                    is_lit = m.is_lit,
                    persist_this_room = m.persist_this_room,
                })
            end
            -- Candle lit transition.
            if prev.is_lit == 0 and m.is_lit == 1 and m.is_dark == 1 then
                jappend({
                    event = "candle_lit",
                    frame = m.frame, room_id = m.room_id,
                    level = m.uw_level, quest = m.uw_quest,
                    candle_used_count = m.candle_used_count,
                })
            end
            -- Persistence verified on room re-entry.
            if prev.room_id ~= m.room_id and m.is_dark == 1
                and m.persist_this_room == 1 then
                jappend({
                    event = "dark_room_persist_reentry",
                    frame = m.frame, room_id = m.room_id,
                    is_lit_at_reentry = m.is_lit,
                })
            end
        end
        prev = m
    end
    emu.frameadvance()
end

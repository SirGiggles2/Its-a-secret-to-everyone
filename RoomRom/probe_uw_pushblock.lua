-- probe_uw_pushblock.lua
--
-- Task 5.7 — passive UW push-block recorder.
-- Reads 96-byte state mirror at $FF7200 every frame, emits JSONL
-- events on push state transitions + room change persistence.

local MIRROR_OFFSET = 0x7200
local PERSIST_OFFSET = 0x7B00
local MAGIC_W, MAGIC_P = 0x57, 0x50

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then
        ok = pcall(function() memory.usememorydomain("Main RAM") end)
        if not ok then memory.usememorydomain("MD RAM") end
    end
end
print("[probe_uw_pushblock] mirror $FF7200 / persist $FF7B00")

local function rb(off) return memory.read_u8(MIRROR_OFFSET + off) end
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
        uw_level   = rb(16),
        uw_quest   = rb(17),
        cellar_state = rb(72),
        pb_state_room = rb(80),
        pb_dir     = rb(81),
        pb_timer   = rb(82),
        pb_offset  = rb(83),
        pb_col     = rb(84),
        pb_row     = rb(85),
        pb_complete_count = rb(86),
        pb_all_dead = rb(87),
        pb_internal = rb(88),
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

local jsonl_path = "C:\\tmp\\uw_pushblock_observations.jsonl"
local state_path = "C:\\tmp\\uw_pushblock_state.json"

local jsonl = io.open(jsonl_path, "a")
if not jsonl then print("ERROR: cannot open " .. jsonl_path); return end
jsonl:write(jobj({event="probe_open", ts=os.time(),
    note="Task 5.7 UW push-block probe; mirror $FF7200 (96 B)"}) .. "\n")
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
            -- Internal state transitions.
            if prev.pb_internal ~= m.pb_internal then
                if m.pb_internal == 1 then
                    jappend({
                        event = "push_timing_start",
                        frame = m.frame, room_id = m.room_id,
                        block_col = m.pb_col, block_row = m.pb_row,
                        dir = m.pb_dir,
                    })
                elseif m.pb_internal == 2 then
                    jappend({
                        event = "push_movement_start",
                        frame = m.frame, room_id = m.room_id,
                        block_col = m.pb_col, block_row = m.pb_row,
                        dir = m.pb_dir, timer = prev.pb_timer,
                    })
                elseif m.pb_internal == 3 then
                    jappend({
                        event = "push_done",
                        frame = m.frame, room_id = m.room_id,
                        block_col = m.pb_col, block_row = m.pb_row,
                        dir = m.pb_dir, offset = prev.pb_offset,
                        complete_count = m.pb_complete_count,
                    })
                end
            end
            -- Persistence on room re-entry.
            if prev.room_id ~= m.room_id and m.persist_this_room ~= 0 then
                jappend({
                    event = "push_state_persist",
                    frame = m.frame, room_id = m.room_id,
                    push_state = m.persist_this_room,
                })
            end
        end
        prev = m
    end
    emu.frameadvance()
end

-- probe_uw_stair.lua
--
-- Task 5.6 — passive UW stair / cellar recorder for L1Q1.
-- Reads 80-byte state mirror at $FF7200 every frame, emits JSONL
-- events on cellar entry/exit and room changes inside UW.
--
-- Outputs:
--   C:\tmp\uw_stair_observations.jsonl  -- append per event
--   C:\tmp\uw_stair_state.json          -- single-line snapshot

local MIRROR_OFFSET = 0x7200
local MAGIC_W, MAGIC_P = 0x57, 0x50

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then
        ok = pcall(function() memory.usememorydomain("Main RAM") end)
        if not ok then memory.usememorydomain("MD RAM") end
    end
end
print("[probe_uw_stair] mirror domain set")

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

local function read_mirror()
    if rb(0) ~= MAGIC_W or rb(1) ~= MAGIC_P then return nil end
    return {
        frame      = ru16be(2),
        scene      = rb(4),
        room_id    = rb(5),
        link_x     = rs16be(6),
        link_y     = rs16be(8),
        link_face  = rb(10),
        warp_active = rb(14),
        uw_level   = rb(16),
        uw_quest   = rb(17),
        foot_tile  = rb(21),
        save_source_room = rb(23),
        save_dest_level  = rb(31),
        save_dest_quest  = rb(32),
        save_dest_room   = rb(33),
        cellar_state     = rb(72),
        cellar_entry_ct  = rb(73),
        cellar_exit_ct   = rb(74),
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

local jsonl_path = "C:\\tmp\\uw_stair_observations.jsonl"
local state_path = "C:\\tmp\\uw_stair_state.json"

local jsonl = io.open(jsonl_path, "a")
if not jsonl then print("ERROR: cannot open " .. jsonl_path); return end
jsonl:write(jobj({event="probe_open", ts=os.time(),
    note="Task 5.6 UW stair / cellar probe; mirror $FF7200 (80 B)"}) .. "\n")
jsonl:flush()
local function jappend(o) jsonl:write(jobj(o) .. "\n"); jsonl:flush() end

local prev = nil
local state_ctr = 0

while true do
    local m = read_mirror()
    if m ~= nil then
        state_ctr = state_ctr + 1
        if state_ctr >= 6 then
            local h = io.open(state_path, "w")
            if h then h:write(jobj(m) .. "\n"); h:close() end
            state_ctr = 0
        end

        if prev then
            -- Cellar entry: counter bumped (LOAD path detected entry).
            if m.cellar_entry_ct ~= prev.cellar_entry_ct then
                jappend({
                    event = "stair_entry",
                    frame = m.frame,
                    source_room = m.save_source_room,
                    cellar_room = m.room_id,
                    level = m.uw_level, quest = m.uw_quest,
                    foot_tile_at_fire = prev.foot_tile,
                    entry_count = m.cellar_entry_ct,
                })
            end
            -- Cellar exit: counter bumped.
            if m.cellar_exit_ct ~= prev.cellar_exit_ct then
                jappend({
                    event = "stair_exit",
                    frame = m.frame,
                    cellar_room_at_fire = prev.room_id,
                    dest_room = m.room_id,
                    level = m.uw_level, quest = m.uw_quest,
                    exit_count = m.cellar_exit_ct,
                })
            end
            -- Generic UW room transitions for cross-check.
            if m.scene == 1 and (prev.scene ~= 1 or prev.room_id ~= m.room_id) then
                jappend({
                    event = "room_entry",
                    frame = m.frame, room_id = m.room_id,
                    cellar_state = m.cellar_state,
                    save_source_room = m.save_source_room,
                })
            end
        end
        prev = m
    end
    emu.frameadvance()
end

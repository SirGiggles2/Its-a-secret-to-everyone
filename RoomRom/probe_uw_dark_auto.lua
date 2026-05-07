-- probe_uw_dark_auto.lua
--
-- Task 5.8 auto-verification probe (user unavailable).
-- Scripts joypad B-press at frame ~120 to trigger candle reveal hook.
-- Monitors mirror byte 96 (is_dark) + 97 (is_lit) + 98 (candle count).
-- Then walks south 3 tiles + back to verify persistence on re-entry.
-- Emits same JSONL events as probe_uw_dark.lua so gate_5_8 harness
-- consumes them identically.

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
print("[probe_uw_dark_auto] mirror $FF7200 / persist $FF7C00 / scripted joypad")

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
        link_x     = rb(7),
        link_y     = rb(9),
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
    note="Task 5.8 auto-probe; scripted B-press"}) .. "\n")
jsonl:flush()
local function jappend(o) jsonl:write(jobj(o) .. "\n"); jsonl:flush() end

-- Scripted input plan (frame-counted from probe boot):
--   [   0..  60] idle (let boot complete)
--   [  60..  90] press B (one frame)
--   [  90.. 120] idle
--   [ 120.. 240] hold DOWN to walk south out of $40 to $50
--   [ 240.. 280] idle
--   [ 280.. 400] hold UP to walk back to $40 (verifies persistence)
--   [ 400..  ∞ ] idle, recording

local prev = nil
local fcount = 0
local entered_initial = false
local left_room = false
local came_back = false

while true do
    local m = read_mirror()
    if m ~= nil then
        m.persist_this_room = read_persist(m.room_id)

        -- Snapshot every 6 frames.
        if fcount % 6 == 0 then
            local h = io.open(state_path, "w")
            if h then h:write(jobj(m) .. "\n"); h:close() end
        end

        if m.scene == 1 then
            local first_seen = (prev == nil)
            local room_changed = prev and (prev.scene ~= 1 or prev.room_id ~= m.room_id)
            if (first_seen or room_changed) and m.is_dark == 1 then
                jappend({
                    event = "room_dark_enter",
                    frame = m.frame, room_id = m.room_id,
                    level = m.uw_level, quest = m.uw_quest,
                    is_lit = m.is_lit,
                    persist_this_room = m.persist_this_room,
                })
            end
        end
        if prev and m.scene == 1 then
            if prev.is_lit == 0 and m.is_lit == 1 and m.is_dark == 1 then
                jappend({
                    event = "candle_lit",
                    frame = m.frame, room_id = m.room_id,
                    level = m.uw_level, quest = m.uw_quest,
                    candle_used_count = m.candle_used_count,
                })
            end
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

    -- Scripted joypad. Sequence (fcount-driven; wide gaps to avoid
    -- BizHawk input/frame sync issues observed in earlier runs):
    --   200..220   press B (candle, lights dark $40)
    --   400..410   press X (enter TELEPORT mode)
    --   500..510   press Right (warp $40 -> $41)
    --   600..610   press Left  (warp $41 -> $40, persist test)
    --   700..710   press X (exit TELEPORT)
    local input = {}
    if fcount >= 200 and fcount < 220 then input.B = true end
    if fcount >= 400 and fcount < 410 then input.X = true end
    if fcount >= 500 and fcount < 510 then input.Right = true end
    if fcount >= 600 and fcount < 610 then input.Left = true end
    if fcount >= 700 and fcount < 710 then input.X = true end
    joypad.set(input, 1)

    -- Console trace every 30 frames so we can see what's happening.
    if fcount % 30 == 0 and m ~= nil then
        print(string.format(
            "[f=%d] room=%d dark=%d lit=%d candle=%d link=(%d,%d)",
            fcount, m.room_id, m.is_dark, m.is_lit,
            m.candle_used_count, m.link_x, m.link_y))
    end

    fcount = fcount + 1
    emu.frameadvance()
end

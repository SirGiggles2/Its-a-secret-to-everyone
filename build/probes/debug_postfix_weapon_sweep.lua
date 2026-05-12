local PROBE = "debug_postfix_weapon_sweep"

local function probe_dir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    return src:match("^(.*)[/\\][^/\\]+$") or "."
end

local DIR = probe_dir()
local OUT = DIR .. "\\" .. PROBE .. ".json"

local function raw_json(status, detail)
    local f = io.open(OUT, "w")
    if f then
        f:write("{\n")
        f:write('  "probe": "' .. PROBE .. '",\n')
        f:write('  "status": "' .. status .. '",\n')
        f:write('  "detail": "' .. tostring(detail):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"\n')
        f:write("}\n")
        f:close()
    end
end

local ok_main, main_err = xpcall(function()
local M = dofile(DIR .. "\\debug_postfix_common.lua")

local errors = {}
local observations = {}
local function err(msg) errors[#errors + 1] = msg end
local function obs(msg) observations[#observations + 1] = msg end

local function require_active(slot, label, frames)
    if M.wait_slot_active(slot, frames) then
        obs(label .. " active")
    else
        err(label .. " did not become active in slot " .. slot)
    end
end

local function require_off(slot, label, frames)
    if M.wait_slot_offscreen(slot, frames) then
        obs(label .. " cleared")
    else
        local s = M.read_sat_slot(slot)
        err(label .. " left stale slot " .. slot .. string.format(" x=%d y=%d", s.x, s.y))
    end
end

local ok, detail = M.boot_debug()
if not ok then
    M.write_json(OUT, {{"probe", "debug_postfix_weapon_sweep"}, {"status", "FAIL"}, {"detail", detail}})
    client.exit()
    return
end

M.clear_probe_control()
M.seed_inventory()
M.advance(30, {})

local baseline_off = {}
for slot = 1, 9 do baseline_off[slot] = M.slot_offscreen(slot) end

M.press({"A"}, 2, 1)
require_active(1, "sword", 12)
require_active(2, "beam", 40)
require_off(1, "sword", 120)
require_off(2, "beam", 160)

M.press({"B"}, 2, 1)
require_active(3, "boomerang", 20)
require_off(3, "boomerang", 140)

M.press({"Z"}, 2, 6)
M.press({"B"}, 2, 1)
require_active(4, "arrow", 20)
require_off(4, "arrow", 140)

M.press({"Z"}, 2, 6)
M.press({"B"}, 2, 1)
require_active(5, "bomb fuse", 20)
require_active(6, "bomb explosion", 90)
require_off(5, "bomb", 120)
require_off(6, "explosion", 120)

M.press({"Z"}, 2, 6)
M.press({"B"}, 2, 1)
require_active(8, "candle fire", 30)
require_off(8, "candle fire", 160)

M.press({"Z"}, 2, 6)
M.press({"B"}, 2, 1)
require_active(9, "magic shot", 30)
require_off(9, "magic shot", 160)

for _, slot in ipairs({1,2,3,4,5,6,8,9}) do
    if not M.slot_offscreen(slot) then
        local s = M.read_sat_slot(slot)
        err("final stale slot " .. slot .. string.format(" x=%d y=%d", s.x, s.y))
    end
end

local status = (#errors == 0) and "PASS" or "FAIL"
M.write_json(OUT, {
    {"probe", "debug_postfix_weapon_sweep"},
    {"status", status},
    {"detail", (#errors == 0) and table.concat(observations, "; ") or table.concat(errors, "; ")},
    {"domain", M.RAM_DOMAIN},
    {"baseline_all_weapon_slots_off", baseline_off[1] and baseline_off[2] and baseline_off[3] and baseline_off[4] and baseline_off[5] and baseline_off[6] and baseline_off[8] and baseline_off[9]},
    {"room_id", M.rd_a4(15)},
    {"frame", M.frame()},
})
client.exit()
end, debug.traceback)

if not ok_main then
    raw_json("FAIL", main_err)
    client.exit()
end

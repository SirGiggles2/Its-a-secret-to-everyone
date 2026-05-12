local PROBE = "debug_postfix_soak"

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
local function add_error(msg)
    errors[#errors + 1] = msg
end

local ok, detail = M.boot_debug()
if not ok then
    M.write_json(OUT, {
        {"probe", "debug_postfix_soak"},
        {"status", "FAIL"},
        {"detail", detail},
        {"domain", M.RAM_DOMAIN},
    })
    client.exit()
    return
end

M.clear_probe_control()
M.seed_inventory()

local start_frame = M.frame()
local frames = 18000
local min_room = 255
local max_room = 0
local stress_nonzero = 0

for f = 1, frames do
    local buttons = {}
    local phase = f % 240
    if phase < 60 then buttons = {"Right"}
    elseif phase < 120 then buttons = {"Down"}
    elseif phase < 180 then buttons = {"Left"}
    else buttons = {"Up"} end

    if f % 720 == 20 then buttons = {"A"} end
    if f % 900 == 40 then buttons = {"B"} end
    if f % 1200 == 60 then buttons = {"Z"} end

    M.advance(1, buttons)

    if M.rd_a4(13) ~= 1 then add_error("left RoomRom runtime at frame " .. f) end
    if M.rd(0x7200) ~= 0x57 or M.rd(0x7201) ~= 0x50 then add_error("state mirror magic lost") end
    if M.rd(0x73F8) ~= 0 or M.rd(0x73F9) ~= 0 or M.rd(0x73FA) ~= 0 then add_error("probe control armed during default soak") end
    if M.rd(0x7E00) ~= 0 or M.rd(0x7E01) ~= 0 then stress_nonzero = stress_nonzero + 1 end

    local room = M.rd_a4(15)
    if room < min_room then min_room = room end
    if room > max_room then max_room = room end
end

local stop_frame = M.frame()
local game_frames = stop_frame - start_frame
if game_frames < 0 then game_frames = game_frames + 65536 end
if game_frames ~= frames then add_error("frame drift: expected " .. frames .. " got " .. game_frames) end
if stress_nonzero ~= 0 then add_error("enemy stress probe block became nonzero") end

local status = (#errors == 0) and "PASS" or "FAIL"
M.write_json(OUT, {
    {"probe", "debug_postfix_soak"},
    {"status", status},
    {"detail", (#errors == 0) and "five-minute fixed-window scripted soak held frame count and default probes stayed off" or table.concat(errors, "; ")},
    {"domain", M.RAM_DOMAIN},
    {"emu_frames", frames},
    {"game_frames", game_frames},
    {"start_frame", start_frame},
    {"stop_frame", stop_frame},
    {"room_min", min_room},
    {"room_max", max_room},
    {"stress_nonzero_samples", stress_nonzero},
})
client.exit()
end, debug.traceback)

if not ok_main then
    raw_json("FAIL", main_err)
    client.exit()
end

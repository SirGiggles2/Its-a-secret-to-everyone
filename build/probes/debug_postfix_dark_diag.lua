local PROBE = "debug_postfix_dark_diag"

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
local events = {}
local function rec(label)
    local slot8 = M.read_sat_slot(8)
    events[#events + 1] = string.format(
        "%s room=$%02X dark=%d lit=%d used=%d slot8=%d,%d",
        label, M.rd_a4(15), M.rd(0x7200 + 96), M.rd(0x7200 + 97),
        M.rd(0x7200 + 98), slot8.x, slot8.y)
end

local function teleport_to(target)
    local cur = M.rd_a4(15)
    local cur_col, cur_row = cur % 16, math.floor(cur / 16)
    local dst_col, dst_row = target % 16, math.floor(target / 16)
    M.press({"X"}, 2, 10)
    while cur_col < dst_col do M.press({"Right"}, 2, 12); cur_col = cur_col + 1 end
    while cur_col > dst_col do M.press({"Left"}, 2, 12); cur_col = cur_col - 1 end
    while cur_row < dst_row do M.press({"Down"}, 2, 12); cur_row = cur_row + 1 end
    while cur_row > dst_row do M.press({"Up"}, 2, 12); cur_row = cur_row - 1 end
    M.advance(60, {})
end

local ok, detail = M.boot_debug()
if not ok then
    M.write_json(OUT, {{"probe", PROBE}, {"status", "FAIL"}, {"detail", detail}})
    client.exit()
    return
end

M.clear_probe_control()
M.arm_heavy_mirror()
M.seed_inventory()
M.advance(60, {})
rec("boot")
teleport_to(0x21)
rec("after-teleport")

for i = 1, 6 do
    M.press({"Z"}, 2, 8)
    rec("after-Z-" .. i)
    M.press({"B"}, 2, 100)
    rec("after-B-" .. i)
end

M.write_json(OUT, {
    {"probe", PROBE},
    {"status", "PASS"},
    {"detail", table.concat(events, "; ")},
    {"domain", M.RAM_DOMAIN},
    {"room_id", M.rd_a4(15)},
    {"frame", M.frame()},
})
client.exit()
end, debug.traceback)

if not ok_main then
    raw_json("FAIL", main_err)
    client.exit()
end

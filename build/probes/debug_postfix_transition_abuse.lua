local PROBE = "debug_postfix_transition_abuse"

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
local events = {}
local function err(msg) errors[#errors + 1] = msg end
local function event(msg) events[#events + 1] = msg end

local function bg_word(base, col, row)
    local addr = base + ((row * 64 + col) * 2)
    return memory.read_u8(addr, M.VRAM_DOMAIN) * 256 + memory.read_u8(addr + 1, M.VRAM_DOMAIN)
end

local function plane_count(base)
    local nonzero = 0
    for row = 7, 28 do
        for col = 0, 31 do
            if bg_word(base, col, row) ~= 0 then nonzero = nonzero + 1 end
        end
    end
    return nonzero
end

local function plane_counts()
    local c000 = plane_count(0xC000)
    local d000 = plane_count(0xD000)
    local e000 = plane_count(0xE000)
    return c000, d000, e000
end

local function teleport_to(target)
    local cur = M.rd_a4(15)
    local cur_col, cur_row = cur % 16, math.floor(cur / 16)
    local dst_col, dst_row = target % 16, math.floor(target / 16)
    while cur_col < dst_col do M.press({"Right"}, 2, 12); cur_col = cur_col + 1 end
    while cur_col > dst_col do M.press({"Left"}, 2, 12); cur_col = cur_col - 1 end
    while cur_row < dst_row do M.press({"Down"}, 2, 12); cur_row = cur_row + 1 end
    while cur_row > dst_row do M.press({"Up"}, 2, 12); cur_row = cur_row - 1 end
    M.advance(60, {})
    if M.rd_a4(15) ~= target then
        err(string.format("teleport target $%02X landed in $%02X", target, M.rd_a4(15)))
    end
end

local function check_room(label, room, want_dark, want_cellar, expect_drawn)
    local c000, d000, e000 = plane_counts()
    local dark = M.rd(0x7200 + 96)
    local lit = M.rd(0x7200 + 97)
    local cellar = M.rd(0x7200 + 72)
    local pb = M.rd(0x7200 + 80)
    if expect_drawn and c000 < 100 then err(label .. " BG_A playfield looks too empty: " .. c000) end
    if d000 ~= 0 then err(label .. " window playfield rows not clear: " .. d000) end
    if e000 ~= 0 then err(label .. " BG_B staging playfield not clear: " .. e000) end
    if want_dark ~= nil and dark ~= want_dark then err(label .. " dark expected " .. want_dark .. " got " .. dark) end
    if want_cellar ~= nil and cellar ~= want_cellar then err(label .. " cellar expected " .. want_cellar .. " got " .. cellar) end
    event(string.format("%s room=$%02X dark=%d lit=%d cellar=%d push=%d c000=%d d000=%d e000=%d", label, room, dark, lit, cellar, pb, c000, d000, e000))
end

local function fire_candle_until_lit()
    local lit_before = M.rd(0x7200 + 97)
    if lit_before == 1 then return true, "already-lit" end

    M.press({"X"}, 2, 10) -- leave teleport mode so normal B-item use is active
    for _ = 1, 3 do M.press({"Z"}, 2, 4) end
    M.press({"B"}, 2, 90)
    if M.rd(0x7200 + 97) == 1 then
        M.press({"X"}, 2, 10)
        return true, "direct-cycle"
    end

    for i = 1, 5 do
        M.press({"Z"}, 2, 6)
        M.press({"B"}, 2, 90)
        if M.rd(0x7200 + 97) == 1 then
            M.press({"X"}, 2, 10)
            return true, "fallback-cycle-" .. i
        end
    end
    M.press({"X"}, 2, 10)
    return false, "not-lit"
end

local ok, detail = M.boot_debug()
if not ok then
    M.write_json(OUT, {{"probe", "debug_postfix_transition_abuse"}, {"status", "FAIL"}, {"detail", detail}})
    client.exit()
    return
end

M.clear_probe_control()
M.arm_heavy_mirror()
M.seed_inventory()
M.advance(60, {})
M.press({"X"}, 2, 10) -- teleport mode

teleport_to(0x21)
check_room("dark-before-candle", 0x21, 1, 0, false)
local lit_ok, lit_path = fire_candle_until_lit()
M.advance(30, {})
check_room("dark-after-candle", 0x21, 1, 0, false)
if not lit_ok then err("dark room did not become lit after candle") end
event("candle-light-path=" .. lit_path)

teleport_to(0x22)
check_room("cellar-source-pushblock", 0x22, nil, 0, true)
teleport_to(0x7F)
check_room("cellar-room", 0x7F, nil, 1, false)
teleport_to(0x74)
check_room("pushblock-room-74", 0x74, nil, 0, true)
teleport_to(0x73)
check_room("return-debug-room", 0x73, nil, 0, true)

M.press({"C"}, 2, 120)
check_room("map-toggle-reload", M.rd_a4(15), nil, 0, true)

local status = (#errors == 0) and "PASS" or "FAIL"
M.write_json(OUT, {
    {"probe", "debug_postfix_transition_abuse"},
    {"status", status},
    {"detail", (#errors == 0) and table.concat(events, "; ") or (table.concat(errors, "; ") .. " | " .. table.concat(events, "; "))},
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

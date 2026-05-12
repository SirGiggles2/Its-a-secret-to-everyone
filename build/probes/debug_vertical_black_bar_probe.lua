local PROBE = "debug_vertical_black_bar"

local function probe_dir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    return src:match("^(.*)[/\\][^/\\]+$") or "."
end

local DIR = probe_dir()
local OUT = DIR .. "\\" .. PROBE .. ".json"
local OUT_DIR = DIR .. "\\transition_visual"
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

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

local function signed16(v)
    if v >= 0x8000 then return v - 0x10000 end
    return v
end

local function rd_vsram_word(byte_offset)
    local domain = "VSRAM"
    if not M.domain_exists(domain) and M.domain_exists("VDP VSRAM") then
        domain = "VDP VSRAM"
    end
    if not M.domain_exists(domain) then
        return 0
    end
    return signed16(memory.read_u8(byte_offset, domain) * 256 +
                    memory.read_u8(byte_offset + 1, domain))
end

local function bg_word(base, col, row)
    local addr = base + ((row * 64 + col) * 2)
    return memory.read_u8(addr, M.VRAM_DOMAIN) * 256 +
           memory.read_u8(addr + 1, M.VRAM_DOMAIN)
end

local function plane_rows(base)
    local rows = {}
    for row = 0, 63 do
        local nonzero = 0
        for col = 0, 31 do
            if bg_word(base, col, row) ~= 0 then nonzero = nonzero + 1 end
        end
        rows[#rows + 1] = nonzero
    end
    return rows
end

local function visible_rows(vscroll)
    local offset = vscroll
    if offset < 0 then offset = offset + 512 end
    local tile_offset = math.floor(offset / 8) % 64
    local out = {}
    for screen_row = 7, 27 do
        out[#out + 1] = (screen_row + tile_offset) % 64
    end
    return out
end

local function counts_for(rows, indexes)
    local out = {}
    local zero_count = 0
    for _, row in ipairs(indexes) do
        local n = rows[row + 1]
        out[#out + 1] = n
        if n == 0 then zero_count = zero_count + 1 end
    end
    return out, zero_count
end

local function advance_until_room_changes(start_room)
    for _ = 1, 240 do
        M.advance(1, {"Up"})
        if M.rd_a4(15) ~= start_room then
            M.advance(30, {})
            return true
        end
    end
    return false
end

local function load_room63_canonically()
    local cur = M.rd_a4(15)
    if cur ~= 0x73 then return false, "expected start room $73 got $" .. string.format("%02X", cur) end
    M.press({"X"}, 2, 10)
    M.press({"Up"}, 2, 20)
    M.advance(60, {})
    if M.rd_a4(15) ~= 0x63 then
        return false, "teleport mode Up landed in $" .. string.format("%02X", M.rd_a4(15))
    end
    return true, "ok"
end

local ok, detail = M.boot_debug()
if not ok then
    M.write_json(OUT, {{"probe", PROBE}, {"status", "FAIL"}, {"detail", detail}})
    client.exit()
    return
end

M.clear_probe_control()
M.advance(30, {})
local start_room = M.rd_a4(15)
local did_scroll = advance_until_room_changes(start_room)
local scrolled_room = M.rd_a4(15)
local scrolled_v = rd_vsram_word(0)
local scrolled_rows = plane_rows(0xC000)
local scrolled_visible = visible_rows(scrolled_v)
local scrolled_counts, scrolled_zero = counts_for(scrolled_rows, scrolled_visible)
client.screenshot(OUT_DIR .. "\\blackbar_after_vertical.png")

local canonical_ok = true
local canonical_detail = "ok"
client.reboot_core()
ok, detail = M.boot_debug()
if not ok then
    canonical_ok = false
    canonical_detail = detail
else
    M.clear_probe_control()
    M.advance(30, {})
    canonical_ok, canonical_detail = load_room63_canonically()
end
local canonical_v = rd_vsram_word(0)
local canonical_rows = plane_rows(0xC000)
local canonical_visible = visible_rows(canonical_v)
local canonical_counts, canonical_zero = counts_for(canonical_rows, canonical_visible)
client.screenshot(OUT_DIR .. "\\blackbar_canonical_room63.png")

local status = "PASS"
local out_detail = string.format(
    "vertical room $%02X->$%02X v=%d visible_rows=%s counts=%s zero=%d; canonical_ok=%s detail=%s v=%d visible_rows=%s counts=%s zero=%d",
    start_room, scrolled_room, scrolled_v, M.json_array(scrolled_visible),
    M.json_array(scrolled_counts), scrolled_zero, tostring(canonical_ok),
    canonical_detail, canonical_v, M.json_array(canonical_visible),
    M.json_array(canonical_counts), canonical_zero)

if not did_scroll then
    status = "FAIL"
    out_detail = "vertical scroll did not change room: " .. out_detail
elseif scrolled_zero > canonical_zero then
    status = "FAIL"
    out_detail = "vertical scroll exposes extra blank visible rows: " .. out_detail
elseif not canonical_ok then
    status = "FAIL"
    out_detail = "canonical comparison failed: " .. out_detail
end

M.write_json(OUT, {
    {"probe", PROBE},
    {"status", status},
    {"detail", out_detail},
    {"domain", M.RAM_DOMAIN},
    {"start_room", start_room},
    {"scrolled_room", scrolled_room},
    {"scrolled_vscroll", scrolled_v},
    {"scrolled_visible_rows", M.json_array(scrolled_visible), kind = "raw"},
    {"scrolled_visible_counts", M.json_array(scrolled_counts), kind = "raw"},
    {"scrolled_zero_visible_rows", scrolled_zero},
    {"canonical_ok", tostring(canonical_ok)},
    {"canonical_vscroll", canonical_v},
    {"canonical_visible_rows", M.json_array(canonical_visible), kind = "raw"},
    {"canonical_visible_counts", M.json_array(canonical_counts), kind = "raw"},
    {"canonical_zero_visible_rows", canonical_zero},
})
client.exit()
end, debug.traceback)

if not ok_main then
    raw_json("FAIL", main_err)
    client.exit()
end

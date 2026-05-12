local PROBE = "debug_hud_pingpong"

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

local function row_counts(base, first_row, last_row)
    local rows = {}
    for row = first_row, last_row do
        local nonzero = 0
        for col = 0, 31 do
            if bg_word(base, col, row) ~= 0 then nonzero = nonzero + 1 end
        end
        rows[#rows + 1] = nonzero
    end
    return rows
end

local function row_words(base, row, count)
    local out = {}
    for col = 0, count - 1 do
        out[#out + 1] = bg_word(base, col, row)
    end
    return out
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

local function hud_underlay_rows(vscroll)
    local offset = vscroll
    if offset < 0 then offset = offset + 512 end
    local tile_offset = math.floor(offset / 8) % 64
    local out = {}
    for screen_row = 0, 6 do
        out[#out + 1] = (screen_row + tile_offset) % 64
    end
    return out
end

local function counts_for_rows(base, indexes)
    local out = {}
    local nonblank = 0
    for _, row in ipairs(indexes) do
        local count = row_counts(base, row, row)[1]
        out[#out + 1] = count
        if count ~= 0 then nonblank = nonblank + 1 end
    end
    return out, nonblank
end

local function sample(label)
    local room = M.rd_a4(15)
    local a = rd_vsram_word(0)
    local b = rd_vsram_word(2)
    local underlay_rows = hud_underlay_rows(a)
    local underlay_counts, underlay_nonblank = counts_for_rows(0xC000, underlay_rows)
    client.screenshot(string.format("%s\\hud_pingpong_%s_room%02X_a%d_b%d.png",
        OUT_DIR, label, room, a, b))
    return {
        label = label,
        room = room,
        a = a,
        b = b,
        win_counts = row_counts(0xE000, 0, 6),
        win_row0 = row_words(0xE000, 0, 32),
        win_row2 = row_words(0xE000, 2, 32),
        win_row5 = row_words(0xE000, 5, 32),
        bga_counts_0_6 = row_counts(0xC000, 0, 6),
        hud_underlay_rows = underlay_rows,
        hud_underlay_counts = underlay_counts,
        hud_underlay_nonblank = underlay_nonblank,
        bga_visible_rows = visible_rows(a),
    }
end

local function advance_until_room_changes(button, start_room)
    for _ = 1, 360 do
        M.advance(1, {button})
        if M.rd_a4(15) ~= start_room then
            M.advance(45, {})
            return true
        end
    end
    return false
end

local ok, detail = M.boot_debug()
if not ok then
    M.write_json(OUT, {{"probe", PROBE}, {"status", "FAIL"}, {"detail", detail}})
    client.exit()
    return
end

M.clear_probe_control()
M.advance(30, {})

local boot = sample("boot")
local up_ok = advance_until_room_changes("Up", boot.room)
local after_up = sample("after_up")
local down_ok = false
if up_ok then
    down_ok = advance_until_room_changes("Down", after_up.room)
end
local after_down = sample("after_down")

local boot_win = M.json_array(boot.win_counts)
local up_win = M.json_array(after_up.win_counts)
local down_win = M.json_array(after_down.win_counts)
local detail_out = string.format(
    "boot room=$%02X win=%s underlay=%s/%s a=%d b=%d; up_ok=%s room=$%02X win=%s underlay=%s/%s a=%d b=%d visible=%s; down_ok=%s room=$%02X win=%s underlay=%s/%s a=%d b=%d visible=%s",
    boot.room, boot_win,
    M.json_array(boot.hud_underlay_rows), M.json_array(boot.hud_underlay_counts),
    boot.a, boot.b,
    tostring(up_ok), after_up.room, up_win,
    M.json_array(after_up.hud_underlay_rows), M.json_array(after_up.hud_underlay_counts),
    after_up.a, after_up.b,
    M.json_array(after_up.bga_visible_rows),
    tostring(down_ok), after_down.room, down_win,
    M.json_array(after_down.hud_underlay_rows), M.json_array(after_down.hud_underlay_counts),
    after_down.a, after_down.b,
    M.json_array(after_down.bga_visible_rows))

local status = "PASS"
if not up_ok then
    status = "FAIL"
    detail_out = "up transition failed: " .. detail_out
elseif not down_ok then
    status = "FAIL"
    detail_out = "down transition failed: " .. detail_out
elseif down_win ~= boot_win then
    status = "FAIL"
    detail_out = "window nametable counts changed after up/down: " .. detail_out
elseif boot.hud_underlay_nonblank ~= 0 or after_up.hud_underlay_nonblank ~= 0 or after_down.hud_underlay_nonblank ~= 0 then
    status = "FAIL"
    detail_out = "transparent HUD underlay contains room tiles: " .. detail_out
end

M.write_json(OUT, {
    {"probe", PROBE},
    {"status", status},
    {"detail", detail_out},
    {"domain", M.RAM_DOMAIN},
    {"boot_room", boot.room},
    {"after_up_room", after_up.room},
    {"after_down_room", after_down.room},
    {"boot_window_counts", boot_win, kind = "raw"},
    {"after_up_window_counts", up_win, kind = "raw"},
    {"after_down_window_counts", down_win, kind = "raw"},
    {"boot_hud_underlay_rows", M.json_array(boot.hud_underlay_rows), kind = "raw"},
    {"boot_hud_underlay_counts", M.json_array(boot.hud_underlay_counts), kind = "raw"},
    {"after_up_hud_underlay_rows", M.json_array(after_up.hud_underlay_rows), kind = "raw"},
    {"after_up_hud_underlay_counts", M.json_array(after_up.hud_underlay_counts), kind = "raw"},
    {"after_down_hud_underlay_rows", M.json_array(after_down.hud_underlay_rows), kind = "raw"},
    {"after_down_hud_underlay_counts", M.json_array(after_down.hud_underlay_counts), kind = "raw"},
    {"boot_window_row0", M.json_array(boot.win_row0), kind = "raw"},
    {"after_down_window_row0", M.json_array(after_down.win_row0), kind = "raw"},
    {"boot_window_row2", M.json_array(boot.win_row2), kind = "raw"},
    {"after_down_window_row2", M.json_array(after_down.win_row2), kind = "raw"},
    {"boot_window_row5", M.json_array(boot.win_row5), kind = "raw"},
    {"after_down_window_row5", M.json_array(after_down.win_row5), kind = "raw"},
})
client.exit()
end, debug.traceback)

if not ok_main then
    raw_json("FAIL", main_err)
    client.exit()
end

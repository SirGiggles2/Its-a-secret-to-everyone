local PROBE = "debug_transition_scroll"

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
        return nil, "no VSRAM domain; available=" .. M.domain_list_string()
    end
    return signed16(memory.read_u8(byte_offset, domain) * 256 +
                    memory.read_u8(byte_offset + 1, domain))
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
local change_frame = 0
local changed_room = start_room
local first_scroll_frame = 0
local max_abs_v = 0
local commit_a = 0
local commit_b = 0
local samples_a = {}
local samples_b = {}
local vs_err = nil
local mirror_mismatch = 0

for f = 1, 900 do
    M.advance(1, {"Up"})
    local v
    local vb
    v, vs_err = rd_vsram_word(0)
    if vs_err then break end
    vb, vs_err = rd_vsram_word(2)
    if vs_err then break end
    if vb ~= v and mirror_mismatch == 0 then
        mirror_mismatch = f
    end

    if v ~= 0 then
        if first_scroll_frame == 0 then first_scroll_frame = f end
        local av = math.abs(v)
        if av > max_abs_v then max_abs_v = av end
        if #samples_a < 40 then
            samples_a[#samples_a + 1] = v
            samples_b[#samples_b + 1] = vb
        end
    end

    local room = M.rd_a4(15)
    if change_frame == 0 and room ~= start_room then
        change_frame = f
        changed_room = room
        commit_a = v
        commit_b = vb
    end
    if change_frame ~= 0 and f > change_frame + 60 then
        break
    end
end

local span = 0
if first_scroll_frame ~= 0 and change_frame ~= 0 then
    span = change_frame - first_scroll_frame + 1
end

local status = "PASS"
local out_detail = string.format(
    "room $%02X->$%02X first_scroll=%d room_commit=%d span=%d commit_a=%d commit_b=%d max_abs_a=%d mirror_mismatch=%d samples_a=%s samples_b=%s",
    start_room, changed_room, first_scroll_frame, change_frame, span,
    commit_a, commit_b, max_abs_v, mirror_mismatch,
    M.json_array(samples_a), M.json_array(samples_b))

if vs_err then
    status = "FAIL"
    out_detail = vs_err
elseif change_frame == 0 then
    status = "FAIL"
    out_detail = "holding Up did not commit a room transition from start room $" .. string.format("%02X", start_room)
elseif first_scroll_frame == 0 then
    status = "FAIL"
    out_detail = "room changed but BG_A VSRAM scroll never moved"
elseif span < 31 or span > 34 then
    status = "FAIL"
    out_detail = "scroll span outside 32-frame-plus-mirror-lag tolerance: " .. out_detail
elseif mirror_mismatch ~= 0 then
    status = "FAIL"
    out_detail = "BG_B did not mirror BG_A V scroll: " .. out_detail
end

M.write_json(OUT, {
    {"probe", PROBE},
    {"status", status},
    {"detail", out_detail},
    {"domain", M.RAM_DOMAIN},
    {"start_room", start_room},
    {"changed_room", changed_room},
    {"first_scroll_frame", first_scroll_frame},
    {"room_commit_frame", change_frame},
    {"scroll_span_frames", span},
    {"commit_bg_a_vscroll", commit_a},
    {"commit_bg_b_vscroll", commit_b},
    {"mirror_mismatch_frame", mirror_mismatch},
    {"max_abs_vscroll", max_abs_v},
    {"samples_bg_a", M.json_array(samples_a), kind = "raw"},
    {"samples_bg_b", M.json_array(samples_b), kind = "raw"},
})
client.exit()
end, debug.traceback)

if not ok_main then
    raw_json("FAIL", main_err)
    client.exit()
end

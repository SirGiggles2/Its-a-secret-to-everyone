local PROBE = "debug_transition_pingpong"

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

local function bg_word(base, col, row)
    local addr = base + ((row * 64 + col) * 2)
    return memory.read_u8(addr, M.VRAM_DOMAIN) * 256 +
           memory.read_u8(addr + 1, M.VRAM_DOMAIN)
end

local function plane_playfield_nonzero(base)
    local count = 0
    for row = 7, 28 do
        for col = 0, 63 do
            if bg_word(base, col, row) ~= 0 then count = count + 1 end
        end
    end
    return count
end

local function run_transition(label, button, active_offset, stage_offset, outgoing_base)
    local start_room = M.rd_a4(15)
    local first_scroll = 0
    local commit_frame = 0
    local changed_room = start_room
    local commit_active = 0
    local commit_stage = 0
    local max_abs_active = 0
    local outgoing_nonzero = 0

    for f = 1, 900 do
        M.advance(1, {button})
        local active, err = rd_vsram_word(active_offset)
        if err then return false, err end
        local stage
        stage, err = rd_vsram_word(stage_offset)
        if err then return false, err end

        if active ~= 0 then
            if first_scroll == 0 then first_scroll = f end
            local av = math.abs(active)
            if av > max_abs_active then max_abs_active = av end
        end

        local room = M.rd_a4(15)
        if commit_frame == 0 and room ~= start_room then
            commit_frame = f
            changed_room = room
            commit_active = active
            commit_stage = stage
            M.advance(2, {})
            outgoing_nonzero = plane_playfield_nonzero(outgoing_base)
            break
        end
    end

    local span = 0
    if first_scroll ~= 0 and commit_frame ~= 0 then
        span = commit_frame - first_scroll + 1
    end

    local detail = string.format(
        "%s $%02X->$%02X first=%d commit=%d span=%d commit_active=%d commit_stage=%d max=%d outgoing_nonzero=%d",
        label, start_room, changed_room, first_scroll, commit_frame, span,
        commit_active, commit_stage, max_abs_active, outgoing_nonzero)

    if commit_frame == 0 then
        return false, detail .. " no room commit"
    end
    if first_scroll == 0 then
        return false, detail .. " active plane never scrolled"
    end
    if span < 31 or span > 34 then
        return false, detail .. " span outside 32-frame-plus-mirror-lag tolerance"
    end
    if commit_stage ~= 0 then
        return false, detail .. " staged plane did not become visible origin"
    end
    if outgoing_nonzero ~= 0 then
        return false, detail .. " outgoing plane playfield still contains stale room tiles"
    end
    return true, detail
end

local ok, detail = M.boot_debug()
if not ok then
    M.write_json(OUT, {{"probe", PROBE}, {"status", "FAIL"}, {"detail", detail}})
    client.exit()
    return
end

M.clear_probe_control()
M.advance(30, {})

local ok_up, detail_up = run_transition("up A_to_B", "Up", 0, 2, 0xC000)
M.advance(30, {})
local ok_down, detail_down = false, "skipped"
if ok_up then
    ok_down, detail_down = run_transition("down B_to_A", "Down", 2, 0, 0xE000)
end

local status = (ok_up and ok_down) and "PASS" or "FAIL"
M.write_json(OUT, {
    {"probe", PROBE},
    {"status", status},
    {"detail", detail_up .. "; " .. detail_down},
    {"domain", M.RAM_DOMAIN},
    {"final_room", M.rd_a4(15)},
    {"frame", M.frame()},
})
client.exit()
end, debug.traceback)

if not ok_main then
    raw_json("FAIL", main_err)
    client.exit()
end

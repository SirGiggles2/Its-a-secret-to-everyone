local PROBE = "debug_hud_opaque"

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

local HUD_FIRST_SLOT = 10
local HUD_SPRITE_COUNT = 48
local HUD_LAST_SLOT = HUD_FIRST_SLOT + HUD_SPRITE_COUNT - 1
local HUD_TILE = 1522

local function u16(addr, domain)
    return memory.read_u8(addr, domain) * 256 + memory.read_u8(addr + 1, domain)
end

local function sat(slot)
    local base = M.SAT_BASE + slot * 8
    local size_link = u16(base + 2, M.VRAM_DOMAIN)
    local attr = u16(base + 4, M.VRAM_DOMAIN)
    return {
        y = u16(base + 0, M.VRAM_DOMAIN),
        size = math.floor(size_link / 256) % 16,
        link = size_link % 128,
        attr = attr,
        tile = attr % 2048,
        x = u16(base + 6, M.VRAM_DOMAIN),
    }
end

local function window_word(col, row)
    return u16(0xE000 + ((row * 32 + col) * 2), M.VRAM_DOMAIN)
end

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

local function check_hud_backdrop(label)
    local bad = {}
    for slot = HUD_FIRST_SLOT, HUD_LAST_SLOT do
        local s = sat(slot)
        local idx = slot - HUD_FIRST_SLOT
        local group = math.floor(idx / 16)
        local col = idx % 16
        local exp_x = 128 + col * 16
        local exp_y = (group == 0) and 128 or ((group == 1) and 160 or 176)
        local exp_size = (group == 0) and 7 or ((group == 1) and 5 or 4)
        local exp_link = (slot == HUD_LAST_SLOT) and 0 or (slot + 1)
        if s.x ~= exp_x or s.y ~= exp_y or s.size ~= exp_size or
           s.link ~= exp_link or s.tile ~= HUD_TILE or s.attr >= 0x8000 then
            bad[#bad + 1] = string.format(
                "%s slot%d got x=%d y=%d size=%d link=%d tile=%d attr=%04X want x=%d y=%d size=%d link=%d tile=%d",
                label, slot, s.x, s.y, s.size, s.link, s.tile, s.attr,
                exp_x, exp_y, exp_size, exp_link, HUD_TILE)
            if #bad >= 4 then break end
        end
    end
    return bad
end

local function check_hud_chr()
    for t = 0, 7 do
        local base = (HUD_TILE + t) * 32
        for i = 0, 31 do
            local b = memory.read_u8(base + i, M.VRAM_DOMAIN)
            if b ~= 0x44 then
                return false, string.format("tile %d byte %d = %02X", HUD_TILE + t, i, b)
            end
        end
    end
    return true, "ok"
end

local function check_window_priority()
    local low = {}
    local nonzero = 0
    for row = 0, 6 do
        for col = 0, 31 do
            local word = window_word(col, row)
            local tile = word % 2048
            local pri = math.floor(word / 0x8000) % 2
            if tile ~= 0 then
                nonzero = nonzero + 1
                if pri == 0 then
                    low[#low + 1] = string.format("r%d c%d word=%04X", row, col, word)
                    if #low >= 4 then return nonzero, low end
                end
            end
        end
    end
    return nonzero, low
end

local function bg_word(col, row)
    return u16(0xC000 + ((row * 64 + col) * 2), M.VRAM_DOMAIN)
end

local function is_door_raw(raw)
    if raw >= 0x78 and raw <= 0x81 then return true end
    if raw >= 0x88 and raw <= 0x8B then return true end
    if raw >= 0x98 and raw <= 0xAF then return true end
    return false
end

local function hud_plane_rows(vscroll)
    local offset = vscroll
    if offset < 0 then offset = offset + 512 end
    local tile_offset = math.floor(offset / 8) % 64
    local out = {}
    for screen_row = 0, 6 do
        out[#out + 1] = (screen_row + tile_offset) % 64
    end
    return out
end

local function check_high_priority_doors_under_hud(label)
    local bad = {}
    local rows = hud_plane_rows(rd_vsram_word(0))
    for _, row in ipairs(rows) do
        for col = 0, 31 do
            local word = bg_word(col, row)
            local pri = math.floor(word / 0x8000) % 2
            local tile = word % 2048
            local raw = (tile - 1) % 256
            if pri ~= 0 and is_door_raw(raw) then
                bad[#bad + 1] = string.format("%s row=%d col=%d word=%04X raw=%02X", label, row, col, word, raw)
                if #bad >= 4 then return bad end
            end
        end
    end
    return bad
end

local function find_mid_scroll()
    local start_room = M.rd_a4(15)
    for f = 1, 240 do
        M.advance(1, {"Up"})
        if rd_vsram_word(0) ~= 0 then
            M.advance(8, {"Up"})
            return true, start_room, M.rd_a4(15), f
        end
    end
    return false, start_room, M.rd_a4(15), 0
end

local ok, detail = M.boot_debug()
if not ok then
    M.write_json(OUT, {{"probe", PROBE}, {"status", "FAIL"}, {"detail", detail}})
    client.exit()
    return
end

M.clear_probe_control()
M.advance(30, {})

local boot_bad = check_hud_backdrop("boot")
local chr_ok, chr_detail = check_hud_chr()
local boot_nonzero, boot_low_window = check_window_priority()
local boot_door_bad = check_high_priority_doors_under_hud("boot")
client.screenshot(OUT_DIR .. "\\hud_opaque_boot.png")

local mid_ok, start_room, mid_room, first_scroll_frame = find_mid_scroll()
local mid_bad = check_hud_backdrop("mid")
local mid_nonzero, mid_low_window = check_window_priority()
local mid_door_bad = check_high_priority_doors_under_hud("mid")
client.screenshot(OUT_DIR .. "\\hud_opaque_mid_scroll.png")

local scroll_door_bad = {}
local scroll_door_frame = 0
if mid_ok then
    for rel = 9, 80 do
        M.advance(1, {"Up"})
        local bad = check_high_priority_doors_under_hud("scroll")
        if #bad ~= 0 then
            scroll_door_bad = bad
            scroll_door_frame = rel
            client.screenshot(OUT_DIR .. "\\hud_opaque_door_leak.png")
            break
        end
        if M.rd_a4(15) ~= start_room then
            break
        end
    end
end

local status = "PASS"
local reasons = {}
if #boot_bad ~= 0 then reasons[#reasons + 1] = table.concat(boot_bad, "; ") end
if not chr_ok then reasons[#reasons + 1] = "bad backdrop CHR: " .. chr_detail end
if boot_nonzero == 0 then reasons[#reasons + 1] = "no boot Window HUD tiles" end
if #boot_low_window ~= 0 then reasons[#reasons + 1] = "boot low-priority Window: " .. table.concat(boot_low_window, "; ") end
if #boot_door_bad ~= 0 then reasons[#reasons + 1] = "boot priority doors under HUD: " .. table.concat(boot_door_bad, "; ") end
if not mid_ok then reasons[#reasons + 1] = "could not start upward scroll" end
if #mid_bad ~= 0 then reasons[#reasons + 1] = table.concat(mid_bad, "; ") end
if mid_nonzero == 0 then reasons[#reasons + 1] = "no mid-scroll Window HUD tiles" end
if #mid_low_window ~= 0 then reasons[#reasons + 1] = "mid low-priority Window: " .. table.concat(mid_low_window, "; ") end
if #mid_door_bad ~= 0 then reasons[#reasons + 1] = "mid priority doors under HUD: " .. table.concat(mid_door_bad, "; ") end
if #scroll_door_bad ~= 0 then reasons[#reasons + 1] = "scroll priority doors under HUD at rel " .. tostring(scroll_door_frame) .. ": " .. table.concat(scroll_door_bad, "; ") end
if #reasons ~= 0 then status = "FAIL" end

local out_detail = string.format(
    "start=$%02X mid_room=$%02X first_scroll=%d v=%d boot_nonzero=%d mid_nonzero=%d chr=%s reasons=%s",
    start_room, mid_room, first_scroll_frame, rd_vsram_word(0),
    boot_nonzero, mid_nonzero, chr_detail,
    (#reasons == 0) and "none" or table.concat(reasons, " | "))

M.write_json(OUT, {
    {"probe", PROBE},
    {"status", status},
    {"detail", out_detail},
    {"domain", M.RAM_DOMAIN},
    {"start_room", start_room},
    {"mid_room", mid_room},
    {"first_scroll_frame", first_scroll_frame},
    {"mid_vscroll", rd_vsram_word(0)},
    {"boot_window_nonzero", boot_nonzero},
    {"mid_window_nonzero", mid_nonzero},
    {"backdrop_first_slot", HUD_FIRST_SLOT},
    {"backdrop_last_slot", HUD_LAST_SLOT},
    {"backdrop_tile", HUD_TILE},
})
client.exit()
end, debug.traceback)

if not ok_main then
    raw_json("FAIL", main_err)
    client.exit()
end

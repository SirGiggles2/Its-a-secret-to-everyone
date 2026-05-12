local PROBE = "debug_transition_visual"

local function probe_dir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    return src:match("^(.*)[/\\][^/\\]+$") or "."
end

local DIR = probe_dir()
local OUT_DIR = DIR .. "\\transition_visual"
local OUT = DIR .. "\\" .. PROBE .. ".json"

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
        return nil, "no VSRAM domain; available=" .. M.domain_list_string()
    end
    return signed16(memory.read_u8(byte_offset, domain) * 256 +
                    memory.read_u8(byte_offset + 1, domain))
end

local function shot(label, rel, room)
    local a = rd_vsram_word(0) or 0
    local b = rd_vsram_word(2) or 0
    local path = string.format("%s\\%s_rel%02d_room%02X_a%d_b%d.png",
        OUT_DIR, label, rel, room, a, b)
    client.screenshot(path)
    return path
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
local first = 0
local commit = 0
local shots = {}
local targets = {0, 1, 8, 16, 24, 30, 31, 32, 33, 40}

shots[#shots + 1] = shot("before", 0, start_room)
for f = 1, 240 do
    M.advance(1, {"Up"})
    local a = rd_vsram_word(0) or 0
    if first == 0 and a ~= 0 then first = f end
    if first ~= 0 then
        local rel = f - first + 1
        for _, want in ipairs(targets) do
            if rel == want then
                shots[#shots + 1] = shot("up", rel, M.rd_a4(15))
            end
        end
    end
    if commit == 0 and M.rd_a4(15) ~= start_room then
        commit = f
        shots[#shots + 1] = shot("commit", f - first + 1, M.rd_a4(15))
    end
    if commit ~= 0 and f > commit + 20 then break end
end
shots[#shots + 1] = shot("after", 99, M.rd_a4(15))

M.write_json(OUT, {
    {"probe", PROBE},
    {"status", (first ~= 0 and commit ~= 0) and "PASS" or "FAIL"},
    {"detail", string.format("room $%02X->$%02X first=%d commit=%d shots=%d",
        start_room, M.rd_a4(15), first, commit, #shots)},
    {"domain", M.RAM_DOMAIN},
    {"out_dir", OUT_DIR},
})
client.exit()
end, debug.traceback)

if not ok_main then
    raw_json("FAIL", main_err)
    client.exit()
end

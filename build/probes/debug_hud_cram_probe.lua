local PROBE = "debug_hud_cram"

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

local function cram_word(index)
    local domain = "CRAM"
    if not M.domain_exists(domain) and M.domain_exists("VDP CRAM") then
        domain = "VDP CRAM"
    end
    if not M.domain_exists(domain) then
        return 0
    end
    return memory.read_u8(index * 2, domain) * 256 +
           memory.read_u8(index * 2 + 1, domain)
end

local ok, detail = M.boot_debug()
if not ok then
    M.write_json(OUT, {{"probe", PROBE}, {"status", "FAIL"}, {"detail", detail}})
    client.exit()
    return
end

M.clear_probe_control()
M.advance(30, {})

local values = {}
for i = 0, 15 do
    values[#values + 1] = cram_word(i)
end

M.write_json(OUT, {
    {"probe", PROBE},
    {"status", "PASS"},
    {"detail", "PAL0 CRAM after debug boot"},
    {"domain", M.RAM_DOMAIN},
    {"pal0_cram", M.json_array(values), kind = "raw"},
})
client.exit()
end, debug.traceback)

if not ok_main then
    raw_json("FAIL", main_err)
    client.exit()
end

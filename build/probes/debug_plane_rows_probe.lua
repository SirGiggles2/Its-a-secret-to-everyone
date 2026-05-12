local PROBE = "debug_plane_rows"

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

local function rd16(addr)
    return memory.read_u8(addr, M.VRAM_DOMAIN) * 256 +
           memory.read_u8(addr + 1, M.VRAM_DOMAIN)
end

local function row_nonzero(base, row)
    local n = 0
    for col = 0, 31 do
        if rd16(base + ((row * 64 + col) * 2)) ~= 0 then
            n = n + 1
        end
    end
    return n
end

local ok, detail = M.boot_debug()
if not ok then
    M.write_json(OUT, {{"probe", PROBE}, {"status", "FAIL"}, {"detail", detail}})
    client.exit()
    return
end

M.clear_probe_control()
M.advance(30, {})

local rows_a = {}
local rows_e = {}
for row = 0, 63 do
    rows_a[#rows_a + 1] = row_nonzero(0xC000, row)
    rows_e[#rows_e + 1] = row_nonzero(0xE000, row)
end

M.write_json(OUT, {
    {"probe", PROBE},
    {"status", "PASS"},
    {"detail", "nonzero tile counts for candidate BG tables"},
    {"domain", M.RAM_DOMAIN},
    {"room", M.rd_a4(15)},
    {"rows_c000", M.json_array(rows_a), kind = "raw"},
    {"rows_e000", M.json_array(rows_e), kind = "raw"},
})
client.exit()
end, debug.traceback)

if not ok_main then
    raw_json("FAIL", main_err)
    client.exit()
end

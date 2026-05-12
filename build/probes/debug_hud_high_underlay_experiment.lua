local function probe_dir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    return src:match("^(.*)[/\\][^/\\]+$") or "."
end

local DIR = probe_dir()
local OUT = DIR .. "\\debug_hud_high_underlay_experiment.json"
local OUT_DIR = DIR .. "\\transition_visual"
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local M = dofile(DIR .. "\\debug_postfix_common.lua")

local function write_json(status, detail)
    M.write_json(OUT, {
        {"probe", "debug_hud_high_underlay_experiment"},
        {"status", status},
        {"detail", detail},
    })
end

local function u16(addr, domain)
    return memory.read_u8(addr, domain) * 256 + memory.read_u8(addr + 1, domain)
end

local function w16(addr, val, domain)
    memory.write_u8(addr, math.floor(val / 256) % 256, domain)
    memory.write_u8(addr + 1, val % 256, domain)
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
    return signed16(memory.read_u8(byte_offset, domain) * 256 +
                    memory.read_u8(byte_offset + 1, domain))
end

local ok, detail = M.boot_debug()
if not ok then
    write_json("FAIL", detail)
    client.exit()
    return
end

M.clear_probe_control()
M.advance(30, {})

for slot = 10, 57 do
    local attr_addr = M.SAT_BASE + slot * 8 + 4
    local attr = u16(attr_addr, M.VRAM_DOMAIN)
    w16(attr_addr, attr | 0x8000, M.VRAM_DOMAIN)
end

local start_room = M.rd_a4(15)
local first = 0
for f = 1, 120 do
    M.advance(1, {"Up"})
    if first == 0 and rd_vsram_word(0) ~= 0 then first = f end
    if first ~= 0 and f >= first + 24 then break end
end

client.screenshot(OUT_DIR .. "\\hud_high_underlay_experiment.png")
write_json("DONE", string.format("room=$%02X first=%d v=%d", start_room, first, rd_vsram_word(0)))
client.exit()

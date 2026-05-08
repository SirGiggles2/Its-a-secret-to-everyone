local OUT_PATH = os.getenv("LINK_VIS_OUT")
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\probes\\ph5\\pr5\\link_visibility.json"

local function mkdir_for(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir then
        os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"')
    end
end

local function domain_exists(name)
    for _, d in ipairs(memory.getmemorydomainlist()) do
        if d == name then return true end
    end
    return false
end

local RAM_DOMAIN = "M68K BUS"
local MIRROR_BASE = 0x00FF7200
if domain_exists("68K RAM") then
    RAM_DOMAIN = "68K RAM"; MIRROR_BASE = 0x7200
elseif domain_exists("M68K RAM") then
    RAM_DOMAIN = "M68K RAM"; MIRROR_BASE = 0x7200
end

local VRAM_DOMAIN = nil
for _, n in ipairs({ "VRAM", "VDP VRAM" }) do
    if domain_exists(n) then VRAM_DOMAIN = n; break end
end

-- Boot Title.md
for _ = 1, 120 do emu.frameadvance() end
-- Chord A+B+C 8 frames -> enter RoomRom
for _ = 1, 8 do
    joypad.set({ ["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true })
    emu.frameadvance()
end
joypad.set({})
-- Wait sentinel
local sentinel_seen = false
for _ = 1, 600 do
    emu.frameadvance()
    memory.usememorydomain(RAM_DOMAIN)
    if memory.read_u8(MIRROR_BASE - 0x200) == 0xA4 then
        sentinel_seen = true; break
    end
end
for _ = 1, 60 do emu.frameadvance() end

memory.usememorydomain(RAM_DOMAIN)
local mirror = {}
for i = 0, 119 do mirror[i] = memory.read_u8(MIRROR_BASE + i) end

-- Decode state mirror
local function be16s(hi, lo)
    local v = hi * 256 + lo
    if v >= 32768 then v = v - 65536 end
    return v
end
local link_x = be16s(mirror[6], mirror[7])
local link_y = be16s(mirror[8], mirror[9])
local scene  = mirror[4]
local room   = mirror[5]
local sw_state = mirror[112]
local sw_active_scene = mirror[113]
local sw_rc_hi = mirror[114]
local sw_rc_lo = mirror[115]
local sw_rc = sw_rc_hi * 256 + sw_rc_lo

-- SAT lives at VRAM 0xF400 in 64x32 plane mode (per verify_vram_budget).
-- Each entry = 8 bytes: y, size, link, attr, x. SAT 80 entries max.
local sat = {}
if VRAM_DOMAIN then
    for slot = 0, 8 do
        local base = 0xF400 + slot * 8
        local y_hi = memory.read_u8(base + 0, VRAM_DOMAIN)
        local y_lo = memory.read_u8(base + 1, VRAM_DOMAIN)
        local size = memory.read_u8(base + 2, VRAM_DOMAIN)
        local link = memory.read_u8(base + 3, VRAM_DOMAIN)
        local at_hi = memory.read_u8(base + 4, VRAM_DOMAIN)
        local at_lo = memory.read_u8(base + 5, VRAM_DOMAIN)
        local x_hi = memory.read_u8(base + 6, VRAM_DOMAIN)
        local x_lo = memory.read_u8(base + 7, VRAM_DOMAIN)
        local attr = at_hi * 256 + at_lo
        local tile_id = attr & 0x07FF
        local pri = (attr >> 15) & 1
        local pal = (attr >> 13) & 3
        sat[slot] = string.format("y=%d size=0x%02X link=%d tile=%d pri=%d pal=%d x=%d",
            y_hi*256+y_lo, size, link, tile_id, pri, pal, x_hi*256+x_lo)
    end
end

-- Sample LINK_VRAM_TILE block at tile 1263 (= 0x4F * 32 = 0x9DE0... wait 1263*32=40416=0x9DE0)
local link_tile_addr = 1263 * 32
local link_tile_first16 = ""
if VRAM_DOMAIN then
    for i = 0, 15 do
        link_tile_first16 = link_tile_first16 .. string.format("%02X",
            memory.read_u8(link_tile_addr + i, VRAM_DOMAIN))
    end
end

mkdir_for(OUT_PATH)
local f = assert(io.open(OUT_PATH, "w"))
f:write(string.format([[{
  "ram_domain": "%s", "vram_domain": "%s",
  "sentinel_seen": %s,
  "scene": %d, "room": %d, "link_x": %d, "link_y": %d,
  "swap_state": %d, "swap_active_scene": %d, "swap_request_count": %d,
  "link_tile_addr": "0x%X", "link_tile_first16": "%s",
  "sat": [
]], RAM_DOMAIN, tostring(VRAM_DOMAIN),
    tostring(sentinel_seen), scene, room, link_x, link_y,
    sw_state, sw_active_scene, sw_rc,
    link_tile_addr, link_tile_first16))
for i = 0, 8 do
    f:write(string.format('    "slot%d: %s"%s\n', i, sat[i] or "?", i < 8 and "," or ""))
end
f:write("  ]\n}\n")
f:close()
client.exit()

-- PR-5 verifier: boot Debug.md, drive boss bank dispatch via probe
-- trigger byte at $FF73FE, capture VRAM at SCENE_OBJ slot for UW_L1
-- (UWSPBoss1257) then UW_L3 (UWSPBoss3468), and assert the two banks
-- differ at the byte level.
--
-- Memory contract (RoomRom/src/main.c roomrom_debug_tick):
--   $FF73FE  u8  trigger: write scene_id, main.c calls
--                level_chr_boss_request(scene_id) and clears cell.
--   $FF73FF  u8  ack: incremented after each request fires.
--
-- Boss CHR slot is SCENE_OBJ (ROOMROM_BOSS_TILE_BASE = 1069), 64 tiles
-- = 2048 bytes at VRAM 0x857A0.

local OUT_PATH = os.getenv("BOSS_BANK_PROBE_OUT")
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\probes\\ph5\\pr5\\boss_bank_dispatch.json"

local SCENE_UW_L1 = 4
local SCENE_UW_L3 = 6
local BOSS_TILE_BASE = 1069
local BOSS_TILE_COUNT = 64
local BOSS_BYTES = BOSS_TILE_COUNT * 32  -- 2048
local BOSS_VRAM_ADDR = BOSS_TILE_BASE * 32  -- 0x857A0

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

-- RAM domain selection (matches capture_debug_room.lua)
local RAM_DOMAIN = "M68K BUS"
local CTRL_ADDR  = 0x00FF73F8
local TRIG_ADDR  = 0x00FF73FE
local ACK_ADDR   = 0x00FF73FF
local SENTINEL_BASE = 0x00FF7000
if domain_exists("68K RAM") then
    RAM_DOMAIN = "68K RAM"
    CTRL_ADDR = 0x73F8
    TRIG_ADDR = 0x73FE
    ACK_ADDR  = 0x73FF
    SENTINEL_BASE = 0x7000
elseif domain_exists("M68K RAM") then
    RAM_DOMAIN = "M68K RAM"
    CTRL_ADDR = 0x73F8
    TRIG_ADDR = 0x73FE
    ACK_ADDR  = 0x73FF
    SENTINEL_BASE = 0x7000
end

local VRAM_DOMAIN = nil
for _, name in ipairs({ "VRAM", "VDP VRAM" }) do
    if domain_exists(name) then VRAM_DOMAIN = name; break end
end

local function ram_r8(addr)
    memory.usememorydomain(RAM_DOMAIN)
    return memory.read_u8(addr)
end

local function ram_w8(addr, v)
    memory.usememorydomain(RAM_DOMAIN)
    memory.write_u8(addr, v)
end

-- Boot Debug.md a bit so it's running.
for _ = 1, 120 do emu.frameadvance() end

-- A+B+C chord 8 frames to enter RoomRom runtime from Debug entry.
for _ = 1, 8 do
    joypad.set({ ["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true })
    emu.frameadvance()
end
joypad.set({})

-- Wait for RoomRom metadata-probe sentinel.
local sentinel_seen = false
for _ = 1, 600 do
    emu.frameadvance()
    if ram_r8(SENTINEL_BASE + 0) == 0xA4 and ram_r8(SENTINEL_BASE + 1) == 0x4A then
        sentinel_seen = true
        break
    end
end
for _ = 1, 60 do emu.frameadvance() end

ram_w8(CTRL_ADDR + 0, 0x52) -- 'R'
ram_w8(CTRL_ADDR + 1, 0x50) -- 'P'
ram_w8(CTRL_ADDR + 2, 0x04) -- boss-bank trigger

local function fire_boss(scene_id)
    local ack_before = ram_r8(ACK_ADDR)
    ram_w8(TRIG_ADDR, scene_id)
    -- main.c reads + clears trigger at top of roomrom_debug_tick.
    -- State machine then takes 4 frames: REQUESTED→BLANK→DMA_A→DMA_B→READY.
    -- Wait up to 30 frames for ack increment (covers tick latency).
    local fired = false
    for _ = 1, 30 do
        emu.frameadvance()
        if ram_r8(ACK_ADDR) ~= ack_before then
            fired = true
            break
        end
    end
    -- Then advance 8 more frames so DMA stages finish + READY observed.
    for _ = 1, 8 do emu.frameadvance() end
    return fired
end

local function snapshot_boss_vram()
    local bytes = {}
    if not VRAM_DOMAIN then return bytes end
    for i = 0, BOSS_BYTES - 1 do
        bytes[#bytes + 1] = memory.read_u8(BOSS_VRAM_ADDR + i, VRAM_DOMAIN)
    end
    return bytes
end

local function hash_bytes(bytes)
    -- 32-bit FNV-1a (kept inside Lua int range).
    local h = 2166136261
    for _, b in ipairs(bytes) do
        h = (h ~ b) & 0xFFFFFFFF
        h = (h * 16777619) & 0xFFFFFFFF
    end
    return h
end

local function diff_count(a, b)
    local n = 0
    for i = 1, #a do
        if a[i] ~= (b[i] or 0) then n = n + 1 end
    end
    return n
end

local fired_l1 = fire_boss(SCENE_UW_L1)
local snap_l1 = snapshot_boss_vram()

local fired_l3 = fire_boss(SCENE_UW_L3)
local snap_l3 = snapshot_boss_vram()

local h1 = hash_bytes(snap_l1)
local h3 = hash_bytes(snap_l3)
local diff = diff_count(snap_l1, snap_l3)

mkdir_for(OUT_PATH)
local f = assert(io.open(OUT_PATH, "w"))
-- Diagnostic: write+read self-check using the selected RAM-domain address
-- space. M68K BUS needs full $FFxxxx addresses; 68K RAM needs offsets.
local WRITEBACK_ADDR = CTRL_ADDR - 8
ram_w8(WRITEBACK_ADDR, 0xAB)
local readback = ram_r8(WRITEBACK_ADDR)
local domains = table.concat(memory.getmemorydomainlist(), "|")

f:write(string.format([[{
  "ram_domain": "%s",
  "vram_domain": "%s",
  "domains": "%s",
  "sentinel_seen": %s,
  "writeback_test": "0xAB->0x%02X",
  "boss_tile_base": %d,
  "boss_tile_count": %d,
  "boss_vram_addr": "0x%X",
  "fired_l1": %s,
  "fired_l3": %s,
  "snap_bytes": %d,
  "l1_hash": "0x%08X",
  "l3_hash": "0x%08X",
  "diff_byte_count": %d,
  "l1_first16": "]], RAM_DOMAIN, tostring(VRAM_DOMAIN), domains,
    tostring(sentinel_seen), readback,
    BOSS_TILE_BASE, BOSS_TILE_COUNT, BOSS_VRAM_ADDR,
    tostring(fired_l1), tostring(fired_l3),
    #snap_l1, h1, h3, diff))
for i = 1, math.min(16, #snap_l1) do f:write(string.format("%02X", snap_l1[i])) end
f:write('","l3_first16": "')
for i = 1, math.min(16, #snap_l3) do f:write(string.format("%02X", snap_l3[i])) end
f:write(string.format([[",
  "pass": %s
}
]], tostring(fired_l1 and fired_l3 and diff > 0)))
f:close()
client.exit()

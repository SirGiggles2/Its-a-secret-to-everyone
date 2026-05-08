-- nes_uw_chr_dump_candle.lua
-- Boot NES Zelda 1, warp into Level 1 (UW), then dump PPU sprite
-- pattern table 1 ($1000..$1FFF) plus targeted CHR slices for the
-- candle-fire animation tiles cited by Z_07.asm:4622:
--   ObjAnimFrameHeap[$08..$0B] = $5C, $9E, $44, $CE
--   right tile = left + 2 -> $5C/$5E, $9E/$A0, $44/$46, $CE/$D0
-- and the triforce drop tile ($6E per Anim_ItemFrameTiles[$20]).
--
-- Output: out_dir + per-tile .bin (16 bytes each) + summary JSON.
-- Defaults to RoomRom/out/nes_chr_candle/.

local OUT_DIR = (os.getenv and os.getenv("CODEX_NES_CHR_OUT")) or
                "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\nes_chr_candle"
os.execute("mkdir \"" .. OUT_DIR .. "\" 2>nul")

local CUR_LEVEL      = 0x0010
local GAME_MODE      = 0x0012
local GAME_SUB       = 0x0013
local TARGET_MODE    = 0x005B
local TARGET_MIRROR  = 0x0602
local CUR_SAVE_SLOT  = 0x0016
local NAME_PROGRESS  = 0x0421
local SAVE_ACTIVE0   = 0x0633
local SAVE_ACTIVE1   = 0x0634
local SAVE_ACTIVE2   = 0x0635
local ROOM_TRANS     = 0x004C
local ROOM_ID        = 0x00EB

local function u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr & 0xFFFF)
end
local function w8(addr, val)
    memory.usememorydomain("System Bus")
    memory.write_u8(addr & 0xFFFF, val & 0xFF)
end

-- locate PPU/VRAM domain
local PPU_DOMAIN = nil
do
    local ok, domains = pcall(memory.getmemorydomainlist)
    if ok and domains then
        for _, d in ipairs(domains) do
            local name = (type(d) == "table") and (d.Name or tostring(d)) or tostring(d)
            local lower = name:lower()
            if lower:find("ppu") or lower:find("vram") or lower:find("chr") then
                PPU_DOMAIN = name
                break
            end
        end
    end
end

local function ppu_u8(addr)
    if not PPU_DOMAIN then return 0 end
    memory.usememorydomain(PPU_DOMAIN)
    return memory.read_u8(addr)
end

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 0 }
local function schedule(button, hold_frames, release_frames)
    if input_state.hold_left > 0 or input_state.release_left > 0 then return end
    input_state.button = button
    input_state.hold_left = hold_frames or 1
    input_state.release_left = 0
    input_state.release_after = release_frames or 8
end
local function build_pad()
    local pad = {}
    if input_state.hold_left > 0 and input_state.button then
        pad[input_state.button] = true
        pad["P1 " .. input_state.button] = true
        input_state.hold_left = input_state.hold_left - 1
        if input_state.hold_left == 0 then input_state.release_left = input_state.release_after end
    elseif input_state.release_left > 0 then
        input_state.release_left = input_state.release_left - 1
    end
    return pad
end

local function boot_to_overworld()
    local BOOT_TO_FS1, SELECT_REGISTER, ENTER_REGISTER, TYPE_NAME, FINISH_NAME, WAIT_GAMEPLAY, START_GAME = 1,2,3,4,5,6,7
    local flow = BOOT_TO_FS1
    local last_name = u8(NAME_PROGRESS)
    local name_events = 0
    for frame = 1, 20000 do
        local mode = u8(GAME_MODE)
        local slot = u8(CUR_SAVE_SLOT)
        local name = u8(NAME_PROGRESS)
        local active0 = u8(SAVE_ACTIVE0); local active1 = u8(SAVE_ACTIVE1); local active2 = u8(SAVE_ACTIVE2)
        if flow == BOOT_TO_FS1 then
            if mode == 0x01 then flow = SELECT_REGISTER else schedule("Start", 2, 3) end
        elseif flow == SELECT_REGISTER then
            if slot == 0x03 then flow = ENTER_REGISTER else schedule("Down", 1, 10) end
        elseif flow == ENTER_REGISTER then
            if mode == 0x0E then flow = TYPE_NAME; last_name = name
            elseif mode == 0x01 then schedule("Start", 2, 14) end
        elseif flow == TYPE_NAME then
            if name ~= last_name then name_events = name_events + 1; last_name = name end
            if name_events >= 5 then flow = FINISH_NAME else schedule("A", 1, 10) end
        elseif flow == FINISH_NAME then
            if mode ~= 0x0E then flow = WAIT_GAMEPLAY
            elseif slot ~= 0x03 then schedule("Select", 1, 10)
            else schedule("Start", 2, 14) end
        elseif flow == WAIT_GAMEPLAY then
            if mode == 0x01 then flow = START_GAME end
        elseif flow == START_GAME then
            if mode ~= 0x01 then flow = WAIT_GAMEPLAY
            else
                local target_slot = 0x00
                if active0 == 0 and active1 ~= 0 then target_slot = 0x01
                elseif active0 == 0 and active1 == 0 and active2 ~= 0 then target_slot = 0x02 end
                if slot ~= target_slot then schedule(target_slot > slot and "Down" or "Up", 1, 10)
                else schedule("Start", 2, 14) end
            end
        end
        safe_set(build_pad())
        emu.frameadvance()
        if u8(CUR_LEVEL) == 0 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0
           and u8(ROOM_ID) == 0x77 and u8(ROOM_TRANS) == 0 then
            for _ = 1, 30 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

local function warp_to_level(level)
    w8(CUR_LEVEL, level)
    w8(TARGET_MODE, 2)
    w8(TARGET_MIRROR, 2)
    w8(GAME_MODE, 0x10)
    w8(GAME_SUB, 0)
    for f = 1, 600 do
        safe_set({}); emu.frameadvance()
        if u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 and u8(CUR_LEVEL) == level then
            for _ = 1, 60 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

-- Z1 PPUCTRL bit 3 = 0 -> sprites mapped to PPU $0000-$0FFF.
-- Dump 16 bytes (1 NES tile) from sprite pattern table.
local function dump_tile(tile_id)
    local base = tile_id * 16
    local b = {}
    for i = 0, 15 do b[#b + 1] = ppu_u8(base + i) end
    return b
end

local function bytes_to_hex(b)
    local s = {}
    for i = 1, #b do s[#s + 1] = string.format("%02X", b[i]) end
    return table.concat(s, "")
end

local function write_tile_bin(level, tile_id, bytes)
    local path = string.format("%s\\lvl%d_tile_%02X.bin", OUT_DIR, level, tile_id)
    local f = io.open(path, "wb")
    if f then
        for i = 1, #bytes do f:write(string.char(bytes[i])) end
        f:close()
    end
end

local TILES = { 0x44, 0x46, 0x5C, 0x5E, 0x6E, 0x70, 0x9E, 0xA0, 0xCE, 0xD0 }

local results = {}
local system_id = emu.getsystemid() or "?"
if system_id ~= "NES" then
    print("[chr_dump] not NES system: " .. system_id); client.exit(); return
end

if not boot_to_overworld() then
    print("[chr_dump] boot_to_overworld failed"); client.exit(); return
end

for _, level in ipairs({ 1, 2, 3 }) do
    if warp_to_level(level) then
        local rec = { level = level, tiles = {} }
        for _, t in ipairs(TILES) do
            local b = dump_tile(t)
            write_tile_bin(level, t, b)
            rec.tiles[#rec.tiles + 1] = { id = t, hex = bytes_to_hex(b) }
        end
        client.screenshot(string.format("%s\\lvl%d.png", OUT_DIR, level))
        results[#results + 1] = rec
    else
        print("[chr_dump] warp to level " .. level .. " timed out")
        results[#results + 1] = { level = level, tiles = {}, error = "warp_timeout" }
    end
    -- return to overworld via Save+Continue is heavy; instead re-boot region by
    -- forcing GameMode 0x10 with CurLevel=0 (overworld warp).
    w8(CUR_LEVEL, 0)
    w8(TARGET_MODE, 1)
    w8(GAME_MODE, 0x10)
    w8(GAME_SUB, 0)
    for f = 1, 600 do
        safe_set({}); emu.frameadvance()
        if u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 and u8(CUR_LEVEL) == 0 then break end
    end
end

local jpath = OUT_DIR .. "\\summary.json"
local f = io.open(jpath, "w")
if f then
    f:write("{\n  \"ppu_domain\": \"" .. (PPU_DOMAIN or "?") .. "\",\n  \"levels\": [\n")
    for i, r in ipairs(results) do
        f:write("    { \"level\": " .. tostring(r.level) ..
                ", \"error\": \"" .. (r.error or "") .. "\", \"tiles\": [")
        for j, t in ipairs(r.tiles) do
            f:write("{\"id\":" .. tostring(t.id) .. ",\"hex\":\"" .. t.hex .. "\"}")
            if j < #r.tiles then f:write(",") end
        end
        f:write("] }")
        if i < #results then f:write(",") end
        f:write("\n")
    end
    f:write("  ]\n}\n")
    f:close()
end
print("[chr_dump] DONE -> " .. OUT_DIR)
client.exit()

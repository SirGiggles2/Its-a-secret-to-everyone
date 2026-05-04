-- probe_ph53_doors.lua — Ph5.3 door-system verification.
-- Room 0x73 (L1Q1 entrance): N=key(5), S/E/W=open(0).
-- Checks:
--   1. Door tile art matches expected locked/open state in VRAM plane A.
--   2. Screenshot + plane-A JSON for visual evidence.
--   3. Walkability at critical metatile positions (TL tile < 0x78 = open).

local BASE_OUT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\"
local OUT_PNG  = BASE_OUT .. "ph53_doors_r73.png"
local OUT_JSON = BASE_OUT .. "ph53_doors_r73.json"
local OUT_DONE = BASE_OUT .. "ph53_doors_done.txt"

-- VDP plane A: starts at word address 0xE000 in VRAM.
-- BizHawk VRAM domain is byte-addressed big-endian.
-- Room rows 0..21 live at Gen plane rows 7..28 (ROOMROM_ROOM_FIRST_ROW = 7).
local PLANE_A       = 0xE000
local PLANE_COLS    = 64        -- 64 tiles per plane row
local ROOM_FIRST_ROW = 7
-- ROOMROM_BG_TILE_BASE = 1 (tile 0 is blank).
-- ROOMROM_BG_TILE_BASE_PAL(s) = 1 + s * 256.
-- Plane A word: bit15=priority, bits14-13=0 (pal bits unused — sub-pal
-- encoded in tile index offset), bits10-0 = tile index.
-- Decode: nes_id = (tile_index - 1) % 256, pal = (tile_index - 1) / 256.
local BG_TILE_BASE = 1

local function vram_u16(addr)
    return memory.read_u16_be(addr, "VRAM")
end

-- Read raw tile word at plane A (blob_col, blob_row) — 0-based, room-relative.
local function plane_tile(blob_col, blob_row)
    local plane_row = blob_row + ROOM_FIRST_ROW
    local addr = PLANE_A + plane_row * PLANE_COLS * 2 + blob_col * 2
    return vram_u16(addr)
end

-- Extract NES tile ID from plane A word.
local function decode_nes_tile(word)
    local tile_index = word % 2048       -- strip priority bit (bit 15)
    if tile_index < BG_TILE_BASE then return 0, 0 end
    local base_offset = tile_index - BG_TILE_BASE
    local pal    = math.floor(base_offset / 256) % 4
    local nes_id = base_offset % 256
    return nes_id, pal
end

local function settle(n)
    for _ = 1, n do joypad.set({}, 1); emu.frameadvance() end
end

-- Boot settle: 120 frames for palette + CHR upload to complete.
settle(120)

-- -------------------------------------------------------------------------
-- Read door tile positions (verified against blob NT analysis Ph5.3).
-- Expected open-art tiles: $24=blank, $74=$76=H-threshold.
-- Expected locked-art tiles: $98..$AF range.
-- -------------------------------------------------------------------------

local function read_door_tiles(dir_name, positions)
    local result = {}
    for _, pos in ipairs(positions) do
        local col, row = pos[1], pos[2]
        local word = plane_tile(col, row)
        local nes_id, pal = decode_nes_tile(word)
        result[#result+1] = {
            col = col, row = row,
            word = word, nes_id = nes_id, pal = pal
        }
    end
    return result
end

-- Door tile positions (blob_col, blob_row) — same as s_open_patches in C.
local door_positions = {
    E = {{28,10},{29,10},{28,11},{29,11}},
    W = {{2,10},{3,10},{2,11},{3,11}},
    S = {{15,18},{16,18},{15,19},{16,19}},
    N = {{15,2},{16,2},{15,3},{16,3}},
}

-- In room 0x73: N=key(5) → locked art ($98-$AF), S/E/W=open(0) → threshold art.
-- Open-type tiles in blob are already $74-$77/$24; verify they're < $78.
local expected = {
    E_open = true,  -- open type → tiles should be < $78 (threshold art)
    W_open = true,
    S_open = true,
    N_locked = true, -- key type → tiles should be $98-$AF (locked art)
}

local results = {}
for dir, pos_list in pairs(door_positions) do
    results[dir] = read_door_tiles(dir, pos_list)
end

-- -------------------------------------------------------------------------
-- Walkability check: read TL plane tile of critical metatile per direction.
-- N: mt(8,1)=blob(16,2), S: mt(8,9)=blob(16,18), E: mt(14,5)=blob(28,10),
-- W: mt(1,5)=blob(2,10)  — TL of metatile = blob(mt_col*2, mt_row*2).
-- -------------------------------------------------------------------------
local walk_checks = {
    {dir="E", mt_col=14, mt_row=5},
    {dir="W", mt_col=1,  mt_row=5},
    {dir="S", mt_col=8,  mt_row=9},
    {dir="N", mt_col=8,  mt_row=1},
}
local walk_results = {}
for _, wc in ipairs(walk_checks) do
    local blob_col = wc.mt_col * 2
    local blob_row = wc.mt_row * 2
    local word = plane_tile(blob_col, blob_row)
    local nes_id, pal = decode_nes_tile(word)
    walk_results[#walk_results+1] = {
        dir     = wc.dir,
        mt_col  = wc.mt_col,
        mt_row  = wc.mt_row,
        nes_id  = nes_id,
        pal     = pal,
        walkable = (nes_id < 0x78) and 1 or 0,
    }
end

-- -------------------------------------------------------------------------
-- Validation pass: check N door is locked, S/E/W are open.
-- -------------------------------------------------------------------------
local function check_door_locked(dir)
    for _, entry in ipairs(results[dir]) do
        if entry.nes_id < 0x98 or entry.nes_id > 0xAF then
            -- tiles $98-$AF = locked door art in NES Z1 blob NT
            -- (some locked doors use $78-$97 range too; allow >= $78 as "blocked")
            if entry.nes_id < 0x78 then
                return false, string.format("tile $%02X at (%d,%d) is walkable (expected locked)",
                    entry.nes_id, entry.col, entry.row)
            end
        end
    end
    return true, "ok"
end

local function check_door_open(dir)
    for _, entry in ipairs(results[dir]) do
        -- Open-type door: blob tiles should already be < $78 (threshold or floor)
        if entry.nes_id >= 0x78 then
            return false, string.format("tile $%02X at (%d,%d) is non-walkable (expected open)",
                entry.nes_id, entry.col, entry.row)
        end
    end
    return true, "ok"
end

local checks = {
    {label="N_locked", fn=check_door_locked, dir="N"},
    {label="S_open",   fn=check_door_open,   dir="S"},
    {label="E_open",   fn=check_door_open,   dir="E"},
    {label="W_open",   fn=check_door_open,   dir="W"},
}

local pass_count = 0
local fail_count = 0
local check_results = {}
for _, c in ipairs(checks) do
    local ok, msg = c.fn(c.dir)
    check_results[#check_results+1] = {label=c.label, pass=ok and 1 or 0, msg=msg}
    if ok then pass_count = pass_count + 1 else fail_count = fail_count + 1 end
end

-- Also check N-door metatile walkability: mt(8,1) should be blocked (nes_id >= 0x78).
for _, wc in ipairs(walk_results) do
    local want_walkable = (wc.dir ~= "N") and 1 or 0
    local label = wc.dir .. "_walk_mt"
    if wc.walkable == want_walkable then
        check_results[#check_results+1] = {label=label, pass=1, msg="ok"}
        pass_count = pass_count + 1
    else
        check_results[#check_results+1] = {
            label=label, pass=0,
            msg=string.format("mt(%d,%d) nes_id=$%02X walkable=%d want=%d",
                wc.mt_col, wc.mt_row, wc.nes_id, wc.walkable, want_walkable)
        }
        fail_count = fail_count + 1
    end
end

-- -------------------------------------------------------------------------
-- Capture screenshot.
-- -------------------------------------------------------------------------
client.screenshot(OUT_PNG)

-- -------------------------------------------------------------------------
-- Dump plane-A door-region rows to JSON for archive.
-- -------------------------------------------------------------------------
local function dir_tiles_json(dir)
    local parts = {}
    for _, entry in ipairs(results[dir]) do
        parts[#parts+1] = string.format(
            '{"col":%d,"row":%d,"word":%d,"nes_id":%d,"pal":%d}',
            entry.col, entry.row, entry.word, entry.nes_id, entry.pal)
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local function checks_json()
    local parts = {}
    for _, c in ipairs(check_results) do
        parts[#parts+1] = string.format(
            '{"label":"%s","pass":%d,"msg":"%s"}',
            c.label, c.pass, c.msg:gsub('"', '\\"'))
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local function walk_json()
    local parts = {}
    for _, wc in ipairs(walk_results) do
        parts[#parts+1] = string.format(
            '{"dir":"%s","mt_col":%d,"mt_row":%d,"nes_id":%d,"walkable":%d}',
            wc.dir, wc.mt_col, wc.mt_row, wc.nes_id, wc.walkable)
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local f = assert(io.open(OUT_JSON, "w"))
f:write('{\n')
f:write('  "room": "0x73",\n')
f:write('  "desc": "L1Q1 entrance: N=key(5), S/E/W=open(0)",\n')
f:write(string.format('  "pass_count": %d,\n', pass_count))
f:write(string.format('  "fail_count": %d,\n', fail_count))
f:write('  "checks": ' .. checks_json() .. ',\n')
f:write('  "door_tiles": {\n')
f:write('    "N": ' .. dir_tiles_json("N") .. ',\n')
f:write('    "S": ' .. dir_tiles_json("S") .. ',\n')
f:write('    "E": ' .. dir_tiles_json("E") .. ',\n')
f:write('    "W": ' .. dir_tiles_json("W") .. '\n')
f:write('  },\n')
f:write('  "walkability": ' .. walk_json() .. '\n')
f:write('}\n')
f:close()

local done_f = assert(io.open(OUT_DONE, "w"))
done_f:write(string.format("pass=%d fail=%d", pass_count, fail_count))
done_f:close()

client.exit()

-- gen_room_capture.lua — hotkey room capture for the Genesis port.
-- Pair with nes_room_capture.lua.
--
-- Genesis port already has TURBO_LINK + no-clip baked into the ROM
-- (flag in genesis_shell.asm). This Lua just listens for a capture
-- hotkey and dumps the current room state.
--
-- Hotkey: C button press → dump to builds/reports/rooms/gen_room_XX.json

local OUT_DIR = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms"
local STATE_FILE = OUT_DIR .. "\\_gen_state.State"

-- Auto-load savestate if present (lets you skip the boot/register flow
-- after the first run). Hotkey Start+C saves a new state.
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
do
    local f = io.open(STATE_FILE, "rb")
    if f then
        f:close()
        local ok = pcall(function() savestate.load(STATE_FILE) end)
        if ok then gui.text(10, 50, "Loaded Gen state") end
    end
end

local BUS = 0xFF0000
local ROOM_ID       = BUS + 0xEB
local BUTTONS_PRESS = BUS + 0xF8
local CUR_LEVEL     = BUS + 0x10
local GAME_MODE     = BUS + 0x12
local GAME_SUB      = BUS + 0x13
local PLAYMAP_BASE  = BUS + 0x6530
local NT_CACHE_BASE = BUS + 0x0840
local PLANE_A_VRAM  = 0xC000
local PLANE_A_PITCH = 128
local PLANE_A_TOP_ROW = 8
local ROOM_ROWS     = 22
local ROOM_COLS     = 32

local function u8(addr)
    memory.usememorydomain("M68K BUS"); return memory.read_u8(addr)
end
local function vram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM"); return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end
local function cram_u16(i)
    local ok, v = pcall(function()
        memory.usememorydomain("CRAM"); return memory.read_u16_be(i * 2)
    end)
    return ok and v or 0
end

local function dump_playmap_rows()
    local rows = {}
    for row = 0, ROOM_ROWS - 1 do
        local vals = {}
        for col = 0, ROOM_COLS - 1 do
            vals[#vals+1] = u8(PLAYMAP_BASE + row + col * ROOM_ROWS)
        end
        rows[#rows+1] = vals
    end
    return rows
end

local function dump_nt_cache_rows()
    local rows = {}
    for row = 0, ROOM_ROWS - 1 do
        local vals = {}
        local nt_row = PLANE_A_TOP_ROW + row
        local base = NT_CACHE_BASE + nt_row * 32
        for col = 0, ROOM_COLS - 1 do vals[#vals+1] = u8(base + col) end
        rows[#rows+1] = vals
    end
    return rows
end

local function dump_palette_rows()
    local rows = {}
    for row = 0, ROOM_ROWS - 1 do
        local vals = {}
        local nt_row = PLANE_A_TOP_ROW + row
        local rowbase = PLANE_A_VRAM + nt_row * PLANE_A_PITCH
        for col = 0, ROOM_COLS - 1 do
            local word = vram_u16(rowbase + col * 2)
            vals[#vals+1] = (word >> 13) & 3
        end
        rows[#rows+1] = vals
    end
    memory.usememorydomain("M68K BUS")
    return rows
end

local function dump_cram_bg()
    local vals = {}
    for i = 0, 15 do vals[#vals+1] = cram_u16(i) end
    memory.usememorydomain("M68K BUS")
    return vals
end

local function json_array_1d(t)
    local s={}; for i=1,#t do s[#s+1]=tostring(t[i]) end; return "["..table.concat(s,",").."]"
end
local function json_array_2d(rs)
    local s={}; for i=1,#rs do s[#s+1]=json_array_1d(rs[i]) end; return "["..table.concat(s,",").."]"
end

local function capture()
    local rid = u8(ROOM_ID)
    local path = string.format("%s\\gen_room_%02X.json", OUT_DIR, rid)
    os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
    local fh = io.open(path, "w")
    if not fh then return end
    fh:write("{\n")
    fh:write('  "system": "gen",\n')
    fh:write('  "room_id": ', tostring(rid), ',\n')
    fh:write('  "playmap_rows": ', json_array_2d(dump_playmap_rows()), ',\n')
    fh:write('  "nt_cache_rows": ', json_array_2d(dump_nt_cache_rows()), ',\n')
    fh:write('  "palette_rows": ', json_array_2d(dump_palette_rows()), ',\n')
    fh:write('  "cram_bg": ', json_array_1d(dump_cram_bg()), '\n')
    fh:write("}\n")
    fh:close()
    return rid, path
end

local last_c_held = false
local last_cap_frame = 0
local frame_n = 0

while true do
    emu.frameadvance()
    frame_n = frame_n + 1

    local rid = u8(ROOM_ID)
    gui.text(10, 10, string.format("GEN room $%02X  (C=capture)", rid))

    if u8(CUR_LEVEL) == 0 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 then
        -- Capture: EITHER Shift+F9 on keyboard OR the Gen pad C button.
        local keys = input.get() or {}
        local kb_now = keys.F9 == true and (keys.Shift == true or keys.LeftShift == true or keys.RightShift == true)
        -- Gen C button → NES Select bit 5 in ButtonsPressed.
        local pad_now = (u8(BUTTONS_PRESS) & 0x20) ~= 0
        local key_now = kb_now or pad_now
        if key_now and not last_c_held and (frame_n - last_cap_frame) > 30 then
            local r, path = capture()
            pcall(function() savestate.save(STATE_FILE) end)
            last_cap_frame = frame_n
            gui.text(10, 30, string.format("Captured room $%02X + state", r or 0))
        end
        last_c_held = key_now
    end
end

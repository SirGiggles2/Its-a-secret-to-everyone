-- position_log_12.lua — Stage 2c parity gate.
--
-- Loads C:\tmp\_gen_73_profile.State, runs CAPTURE_TICKS logical ticks
-- (gated on $FF0015 FrameCounter), and for each tick logs the 6 MoveObject
-- output bytes × 12 object slots. Output byte-diffable via cmp.
--
-- Fields captured per slot:
--   ObjX           ($0070 + slot)
--   ObjY           ($0084 + slot)
--   ObjDir         (not per-slot — ($000F) global. Still logged once.)
--   ObjPosFrac     ($03A8 + slot)
--   ObjGridOffset  ($0394 + slot)
--   ObjQSpdFrac    ($03BC + slot)
--
-- Output CSV at builds/reports/position_log_12_TAG.csv. Set TAG via
-- the global variable POSLOG_TAG before loading (or let it default).

local PROJECT_ROOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
local SAVESTATE    = "C:\\tmp\\_gen_73_profile.State"
local TARGET_ROOM  = 0x73
local CAPTURE_TICKS = 300

local TAG = POSLOG_TAG or "default"
local CSV_PATH = string.format(
    "%s\\builds\\reports\\position_log_12_%s.csv", PROJECT_ROOT, TAG)

local BUS = 0xFF0000
local FRAME_COUNTER = BUS + 0x15
local GAME_MODE     = BUS + 0x12
local CUR_LEVEL     = BUS + 0x10
local ROOM_ID       = BUS + 0xEB
local OBJ_DIR       = BUS + 0x000F
local OBJ_X         = BUS + 0x0070
local OBJ_Y         = BUS + 0x0084
local OBJ_GRID      = BUS + 0x0394
local OBJ_POS_FRAC  = BUS + 0x03A8
local OBJ_QSPD_FRAC = BUS + 0x03BC

local function u8(a)
    memory.usememorydomain("M68K BUS")
    return memory.read_u8(a)
end

-- Try loading the savestate. If it fails, bail — the user needs to
-- record a matching savestate via record_inputs.lua for this ROM.
local ok = pcall(savestate.load, SAVESTATE)
if not ok then
    gui.text(10, 10, "FATAL: no savestate " .. SAVESTATE)
    return
end

-- Settle 60 frames.
for i = 1, 60 do emu.frameadvance() end

local mode = u8(GAME_MODE)
local lvl = u8(CUR_LEVEL)
local rid = u8(ROOM_ID)
if rid ~= TARGET_ROOM or mode ~= 0x05 then
    gui.text(10, 10, string.format(
        "WARNING: mode=$%02X lvl=$%02X room=$%02X (expected mode=5 room=$73)",
        mode, lvl, rid))
end

local fh = io.open(CSV_PATH, "w")
if not fh then return end
fh:write(string.format("# tag=%s room=$%02X mode=$%02X lvl=$%02X\n",
    TAG, rid, mode, lvl))
-- Columns: tick, objdir, then per-slot 6 fields × 12 slots.
local cols = { "tick", "objdir" }
for s = 0, 11 do
    for _, f in ipairs({"x","y","pf","go","qf"}) do
        cols[#cols+1] = string.format("s%02d_%s", s, f)
    end
end
fh:write(table.concat(cols, ",") .. "\n")

local tick_idx = 0
local last_fc = u8(FRAME_COUNTER)
local budget_frames = 0

while tick_idx < CAPTURE_TICKS do
    emu.frameadvance()
    budget_frames = budget_frames + 1
    local fc = u8(FRAME_COUNTER)
    local delta = (fc - last_fc) & 0xFF
    if delta > 0 then
        local row = { tostring(tick_idx), string.format("$%02X", u8(OBJ_DIR)) }
        for s = 0, 11 do
            row[#row+1] = string.format("$%02X", u8(OBJ_X + s))
            row[#row+1] = string.format("$%02X", u8(OBJ_Y + s))
            row[#row+1] = string.format("$%02X", u8(OBJ_POS_FRAC + s))
            row[#row+1] = string.format("$%02X", u8(OBJ_GRID + s))
            row[#row+1] = string.format("$%02X", u8(OBJ_QSPD_FRAC + s))
        end
        fh:write(table.concat(row, ",") .. "\n")
        tick_idx = tick_idx + delta
        last_fc = fc
        if tick_idx % 30 == 0 then
            gui.text(10, 10, string.format("pos %d/%d", tick_idx, CAPTURE_TICKS))
        end
    end
    if budget_frames > 2000 then break end
end

fh:close()
pcall(function() client.exit() end)

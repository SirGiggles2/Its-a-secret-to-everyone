-- probe_cave_fade_nes.lua — NES Zelda 1 cave-entry baseline capture.
--
-- Rule Zero baseline for Tier 1 cave-animation work. Captures the
-- NES PPU palette, RAM state, and TRANSFER_BUF record bytes across
-- the cave-entry window (entrance tile detection -> GameMode $10 fade
-- -> cave room load -> GameMode $0B normal-cave).
--
-- USAGE:
--   1. Load real NES Zelda 1 ROM in BizHawk (NES core).
--   2. Either start a fresh save and walk Link to a cave room
--      (e.g. room $77 spawn cave), OR use save-state on first cave
--      entrance tile.
--   3. Set CAPTURE_AT_FRAME global before loading this script (default
--      = current framecount + 60, so you have ~1s to align Link).
--   4. Load the script; it advances frame by frame, dumping per-frame
--      state for 24 frames into the .txt log and one binary snapshot
--      of the full PPU palette + 8-byte cave subpal record into the
--      .bin file.
--
-- OUTPUT:
--   tools/probes/baselines/cave_fade_nes_ground_truth.txt  (human log)
--   tools/probes/baselines/cave_fade_nes_ground_truth.bin  (binary)
--
-- BINARY FORMAT (.bin):
--   [4 bytes magic "CFNB"][4 bytes version u32 LE = 1]
--   [4 bytes capture-start framecount u32 LE]
--   24 frame records, each:
--     [1 byte frame_offset (0..23)]
--     [1 byte $0012 GameMode]
--     [1 byte $0013 Submode]
--     [1 byte $051C FadeCycle]
--     [1 byte $0301 TransferBufPos]
--     [14 bytes $0302..$030F transfer-buf record window]
--     [32 bytes PPU $3F00..$3F1F palette]
--   total per record: 51 bytes; 24 records = 1224 bytes payload.
--
-- Per Rule Zero: the 8 bytes at PPU $3F08-$3F0F captured here are the
-- ground truth that k_cave_subpal_2_3_nes[8] in
-- src/game/world/render/cave_palette.c must match byte-for-byte.

local OUT_TXT = "tools/probes/baselines/cave_fade_nes_ground_truth.txt"
local OUT_BIN = "tools/probes/baselines/cave_fade_nes_ground_truth.bin"

os.execute('if not exist "tools\\probes\\baselines" mkdir "tools\\probes\\baselines"')

local CAPTURE_FRAMES = 24
local CAPTURE_AT_FRAME = CAPTURE_AT_FRAME or (emu.framecount() + 60)

local log_f = assert(io.open(OUT_TXT, "w"))
local bin_f = assert(io.open(OUT_BIN, "wb"))

local function log(s)
    log_f:write(s .. "\n")
    print(s)
end

local function u32le(v)
    return string.char(v & 0xFF) ..
           string.char((v >> 8) & 0xFF) ..
           string.char((v >> 16) & 0xFF) ..
           string.char((v >> 24) & 0xFF)
end

-- Helpers --------------------------------------------------------------

local function bus_u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr)
end

local function palram_block()
    memory.usememorydomain("PALRAM")
    local buf = {}
    for i = 0, 31 do
        buf[#buf + 1] = string.char(memory.read_u8(i))
    end
    return table.concat(buf)
end

local function transfer_buf_window()
    memory.usememorydomain("System Bus")
    local buf = {}
    for i = 0x0302, 0x030F do
        buf[#buf + 1] = string.char(memory.read_u8(i))
    end
    return table.concat(buf)
end

-- Wait for capture start frame -----------------------------------------

log(string.format("probe_cave_fade_nes — start at framecount=%d (target=%d)",
                  emu.framecount(), CAPTURE_AT_FRAME))

while emu.framecount() < CAPTURE_AT_FRAME do
    emu.frameadvance()
end

local start_frame = emu.framecount()

-- Header
bin_f:write("CFNB")
bin_f:write(u32le(1))
bin_f:write(u32le(start_frame))

log(string.format(
    "frame_off | $0012 GameMode | $0013 Submode | $051C FadeCycle | $0301 TxBufPos | $0302..$030F | $3F08..$3F0F"))

for off = 0, CAPTURE_FRAMES - 1 do
    local gm   = bus_u8(0x0012)
    local sm   = bus_u8(0x0013)
    local fade = bus_u8(0x051C)
    local pos  = bus_u8(0x0301)
    local tbw  = transfer_buf_window()
    local pal  = palram_block()

    -- Print cave subpal 2+3 (PPU $3F08..$3F0F) inline.
    local pal_hex = {}
    for i = 9, 16 do  -- 1-indexed Lua: $3F08 = byte index 9
        pal_hex[#pal_hex + 1] = string.format("%02X", string.byte(pal, i))
    end

    local tbw_hex = {}
    for i = 1, #tbw do
        tbw_hex[#tbw_hex + 1] = string.format("%02X", string.byte(tbw, i))
    end

    log(string.format(
        "  +%02d     | %02X            | %02X            | %02X             | %02X            | %s | %s",
        off, gm, sm, fade, pos,
        table.concat(tbw_hex, " "),
        table.concat(pal_hex, " ")))

    -- Binary record
    bin_f:write(string.char(off))
    bin_f:write(string.char(gm))
    bin_f:write(string.char(sm))
    bin_f:write(string.char(fade))
    bin_f:write(string.char(pos))
    bin_f:write(tbw)
    bin_f:write(pal)

    emu.frameadvance()
end

log("")
log("RULE ZERO CHECK: paste these 8 bytes into")
log("  src/game/world/render/cave_palette.c k_cave_subpal_2_3_nes[8]")
log("if they differ from the cited Z_06.asm:714 values.")
log("Frame +N PPU $3F08..$3F0F is the cave subpal 2+3 snapshot when")
log("GameMode == $0B (cave normal). Look for the first row where")
log("GameMode shows $0B and copy $3F08..$3F0F from that row.")

bin_f:close()
log_f:close()
print("Done. Baseline written to:")
print("  " .. OUT_TXT)
print("  " .. OUT_BIN)

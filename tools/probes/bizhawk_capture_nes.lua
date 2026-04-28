-- NES capture probe (S2 Phase D, S1-deferred Q4 closure).
--
-- Produces a single binary dump file at the configured FRAME_TARGET in
-- the format documented by tools/probes/normalize_nes.py:
--
--   header:    8 bytes magic "NESDMP1\0" + 4 bytes frame counter u32 LE
--   regions:   4-byte tag + 4-byte length u32 LE + payload bytes
--   tags:
--     "NTBL"   1024 bytes nametable 0 (PPU $2000..$23FF)
--     "ATTR"   64 bytes attribute table (PPU $23C0..$23FF, redundant
--              with NTBL but emitted explicitly so normalize_nes.py
--              can index it directly)
--     "PAL_"   32 bytes PALRAM ($3F00..$3F1F)
--     "OAM_"   256 bytes sprite RAM
--     "SCRL"   4 bytes (scroll_x, scroll_y, ppu_ctrl, frame_lo)
--     "STAT"   16 bytes selected gameplay state
--   terminator: tag "END_" length 0
--
-- BizHawk NES core domains used:
--   "CIRAM (nametables)"  -- nametable RAM
--   "PALRAM"              -- palette RAM 32 bytes
--   "OAM"                 -- sprite attribute table 256 bytes
--   "System Bus"          -- 6502 address space (for game-state reads)
--
-- Frame target + output path are configurable via globals (set by caller
-- before this script loads), defaults below.

local FRAME_TARGET = FRAME_TARGET or 240
local DUMP_OUT     = DUMP_OUT or "C:\\tmp\\capture_nes.bin"

while emu.framecount() < FRAME_TARGET do
    emu.frameadvance()
end

local function dom_block(domain, start, count)
    memory.usememorydomain(domain)
    local buf = {}
    for i = 0, count - 1 do
        buf[#buf + 1] = string.char(memory.read_u8(start + i))
    end
    return table.concat(buf)
end

local function u32le(v)
    return string.char(v & 0xFF) ..
           string.char((v >> 8) & 0xFF) ..
           string.char((v >> 16) & 0xFF) ..
           string.char((v >> 24) & 0xFF)
end

-- Nametable 0: $2000..$23BF tile cells + $23C0..$23FF attributes.
-- BizHawk CIRAM domain is 4 KB raw nametable RAM, base $0000 maps to PPU $2000.
local ntbl = dom_block("CIRAM (nametables)", 0x0000, 0x03C0)  -- 32 cols * 30 rows
local attr = dom_block("CIRAM (nametables)", 0x03C0, 0x0040)  -- 64 attribute bytes

-- PALRAM: 32 bytes covering BG pal 0..3 + sprite pal 0..3 (4 colors each).
local palram = dom_block("PALRAM", 0x00, 0x20)

-- OAM: 64 sprites * 4 bytes = 256 bytes.
local oam = dom_block("OAM", 0x00, 0x100)

-- Scroll + PPUCTRL: read from main RAM mirror at the canonical Zelda 1
-- locations. PPUCTRL shadow is at NES $00FF (per WHAT IF dump_nes_start_bg);
-- scroll is captured via a similar pattern. ScrollX/Y in Zelda are at $001E
-- and $001F, but these are gameplay-driven and may not exist at title.
-- We use simple zero placeholders for SCRL until the schema needs more.
memory.usememorydomain("System Bus")
local scroll_x = 0
local scroll_y = 0
local ppu_ctrl = memory.read_u8(0x00FF)
local frame_counter = memory.read_u8(0x002F)  -- Zelda FrameCounter at NES $002F

local scrl = string.char(scroll_x) ..
             string.char(scroll_y) ..
             string.char(ppu_ctrl) ..
             string.char(frame_counter)

-- Selected gameplay state: GameMode at $0012, RoomNum at $00EB,
-- CurLevel at $0100 (a few well-known fields per aldonunez disasm).
local function safe_read(addr)
    local ok, v = pcall(memory.read_u8, addr)
    return ok and v or 0
end
local stat = string.char(safe_read(0x0012)) ..  -- GameMode
             string.char(safe_read(0x00EB)) ..  -- RoomNum / CurRoom
             string.char(safe_read(0x002F)) ..  -- FrameCounter
             string.char(safe_read(0x0606)) ..  -- LinkPosX
             string.char(safe_read(0x0626)) ..  -- LinkPosY
             string.char(safe_read(0x0656)) ..  -- LinkObjType
             string.char(safe_read(0x0066)) ..  -- WorldFlagsHi
             string.char(safe_read(0x0065)) ..  -- WorldFlagsLo
             string.rep("\0", 8)                -- reserved padding to 16 bytes

local f = io.open(DUMP_OUT, "wb")
f:write("NESDMP1\0")
f:write(u32le(emu.framecount()))

local function region(tag, payload)
    f:write(tag)
    f:write(u32le(#payload))
    f:write(payload)
end

region("NTBL", ntbl)
region("ATTR", attr)
region("PAL_", palram)
region("OAM_", oam)
region("SCRL", scrl)
region("STAT", stat)
region("END_", "")
f:close()

client.exit()

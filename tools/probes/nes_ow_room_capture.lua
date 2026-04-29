-- tools/probes/nes_ow_room_capture.lua
-- NES side capture for S3.A2 overworld room render probe.
--
-- Boots Zelda 1, navigates through title screen and file select to reach
-- the overworld (room $77 = 0x77, the starting room), then captures PPU
-- state when GameMode == 0x07 (overworld play).
--
-- Globals set by caller before dofile()-ing:
--   DUMP_OUT   -- output path for .bin capture (required)
--   TARGET_ROOM -- expected room id (informational; we just wait for GameMode 7)
--
-- Format: NESDMP1 dump (see bizhawk_capture_nes.lua / normalize_nes.py).

local DUMP_OUT    = DUMP_OUT    or "C:\\tmp\\nes_room_77.bin"
local TARGET_ROOM = TARGET_ROOM or 0x77

-- ---------------------------------------------------------------------------
-- Button-press automation: navigate from title → file select → overworld.
--
-- Zelda 1 boot sequence:
--   Frames 0..~60    : boot / PPUCTRL init (display off)
--   Frames ~60..~180 : title screen animation, GameMode=0x00
--   Press Start at title → GameMode transitions to 0x01 (file select)
--   Press A at file select (slot 1 cursor default) → GameMode transitions to
--     0x05 (loading) → 0x07 (overworld play)
--   Fresh SRAM / no save → new game starts in room $77.
--
-- Strategy: press Start every 30 frames from frame 70 until GameMode > 0x00,
-- then press A every 30 frames until GameMode == 0x07.
-- Cap at 2000 frames to avoid infinite loops on unexpected states.
-- ---------------------------------------------------------------------------

local MAX_FRAMES = 2000
local CAPTURE_SETTLE = 10   -- extra frames after GameMode==7 before capture

local function game_mode()
    memory.usememorydomain("System Bus")
    return memory.read_u8(0x0012)
end

local function room_num()
    memory.usememorydomain("System Bus")
    return memory.read_u8(0x00EB)
end

local started = false   -- have we seen GameMode > 0
local captured = false
local settle_count = 0
local reached_overworld = false

for frame = 0, MAX_FRAMES do
    emu.frameadvance()

    local mode = game_mode()

    if frame >= 70 then
        if mode == 0x00 then
            -- Still at title: press Start every 30 frames
            if (frame % 30) == 0 then
                joypad.set({Start = true}, 1)
            else
                joypad.set({Start = false}, 1)
            end
        elseif mode == 0x01 then
            -- File select: press A every 30 frames to select slot 1
            if (frame % 30) == 0 then
                joypad.set({A = true}, 1)
            else
                joypad.set({A = false}, 1)
            end
        elseif mode == 0x07 then
            -- Overworld play: release all buttons, wait for settle
            joypad.set({}, 1)
            if not reached_overworld then
                reached_overworld = true
                settle_count = 0
            end
            settle_count = settle_count + 1
            if settle_count >= CAPTURE_SETTLE then
                -- Ready to capture
                break
            end
        else
            -- Transition state (0x05 loading etc): release buttons
            joypad.set({}, 1)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Capture PPU state (mirrors bizhawk_capture_nes.lua format).
-- ---------------------------------------------------------------------------

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

-- Nametable 0: tile cells + attribute table
local ntbl = dom_block("CIRAM (nametables)", 0x0000, 0x03C0)
local attr = dom_block("CIRAM (nametables)", 0x03C0, 0x0040)

-- PALRAM: 32 bytes
local palram = dom_block("PALRAM", 0x00, 0x20)

-- OAM: 256 bytes
local oam = dom_block("OAM", 0x00, 0x100)

-- Scroll / state via System Bus
memory.usememorydomain("System Bus")
local function safe_read(addr)
    local ok, v = pcall(memory.read_u8, addr)
    return ok and v or 0
end

local scroll_x     = safe_read(0x001E)
local scroll_y     = safe_read(0x001F)
local ppu_ctrl     = safe_read(0x00FF)
local frame_counter = safe_read(0x002F)

local scrl = string.char(scroll_x) ..
             string.char(scroll_y) ..
             string.char(ppu_ctrl) ..
             string.char(frame_counter)

local stat = string.char(safe_read(0x0012)) ..   -- GameMode
             string.char(safe_read(0x00EB)) ..   -- RoomNum / CurRoom
             string.char(safe_read(0x002F)) ..   -- FrameCounter
             string.char(safe_read(0x0606)) ..   -- LinkPosX
             string.char(safe_read(0x0626)) ..   -- LinkPosY
             string.char(safe_read(0x0656)) ..   -- LinkObjType
             string.char(safe_read(0x0066)) ..   -- WorldFlagsHi
             string.char(safe_read(0x0065)) ..   -- WorldFlagsLo
             string.rep("\0", 8)                 -- reserved padding to 16 bytes

-- Write NESDMP1 dump
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

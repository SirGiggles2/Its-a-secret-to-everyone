-- Phase H3 — NES baseline capture per scenario.
-- Force-state into cave/dungeon mode via RAM writes, advance frames,
-- dump OAM/PALRAM/CIRAM/CHR/RAM/STAT/PNG in GDMP-compatible bundle.
--
-- Driven by prelude.lua written by run_nes_sweep.py with SCENARIO_*
-- globals (same shape as probe_one_gen.lua).

SCENARIO_ID    = SCENARIO_ID     or "cave_6A_enter"
SCENARIO_CAT   = SCENARIO_CAT    or "cave"
SCENARIO_TARGET= SCENARIO_TARGET or 0x77
SCENARIO_EXPECT= SCENARIO_EXPECT or 2
SCENARIO_LEVEL = SCENARIO_LEVEL  or 0
SCENARIO_QUEST = SCENARIO_QUEST  or 1
SCENARIO_CAVE_ID = SCENARIO_CAVE_ID or 0
OUT_DIR        = OUT_DIR         or "C:\\tmp\\g_sweep"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

-- NES RAM cells (Variables.inc):
--   $0010 CurLevel
--   $0012 GameMode
--   $00AC LinkState  (slot 0 ObjState)
--   $00AD CavePersonState
--   $00EB RoomId
--   $0070 LinkX (slot 0)
--   $0084 LinkY (slot 0)
--   $0098 LinkDir (slot 0)
--   $0350 ObjType+1 (slot 1) = cave_id when in cave mode
--   $0413 CaveFlags
--   $0415 PersonTextSelector
--   $0416 CaveTextCharIndex
--   $0422..$0424 CaveItemIds
--   $0430..$0432 CavePrices
--   $062D CurQuest

local function R(o)   return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function PAL(o) return memory.read_u8(o, "PALRAM") end
local function OAM(o) return memory.read_u8(o, "OAM") end
local function CIRAM(o) return memory.read_u8(o, "CIRAM (nametables)") end
local function CHR(o) return memory.read_u8(o, "CHR") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, hold, settle)
    for _=1,hold do joypad.set({[b]=true}, 1); emu.frameadvance() end
    joypad.set({}, 1); for _=1,settle do emu.frameadvance() end
end

-- Boot to gameplay (file-select dance from probe_nes_full_room_dump.lua).
local function boot_to_gameplay()
    idle(360); press("Start", 4, 60)
    press("Down",4,20); press("Down",4,20); press("Down",4,20)
    press("Start",4,60); press("Start",4,60)
    for _=1,5 do press("Down",4,8) end
    for _=1,5 do press("Right",4,8) end
    press("Start",4,60)
    for _=1,5 do press("Up",4,12) end
    press("Start",4,180); idle(180)
end

-- Force-state into cave mode for given cave_id.
--   GameMode=$0B (cave / Mode B)
--   ObjType+1 = cave_id (NPC slot)
--   Trigger InitCave: GameMode change picked up next frame
--
-- Per R3 Sonnet recommendation:
--   1. First go to OW briefly to populate SRAM LBA_E
--   2. Then force-write cave cells
--   3. Advance 3 frames for InitCaveContinue to populate $0422-$0424
local function force_state_cave(cave_id, ow_room)
    -- Step 1: ensure OW SRAM populated. Warp to OW first.
    W(0x0010, 0x00)      -- CurLevel = 0 (OW)
    W(0x00EB, ow_room)   -- RoomId = OW room with cave entrance
    W(0x0012, 0x06)      -- GameMode = $06 (Mode 6 = LoadRoom OW)
    idle(60)             -- wait OW init

    -- Verify SRAM populated (LBA_E base $6A7E should be non-$FF)
    if memory.read_u8(0x6A7E, "RAM") == 0xFF then
        -- Try again with more frames
        idle(120)
    end

    -- Step 2: write RoomId + GameMode FIRST. InitCave reads these
    -- and populates ObjType+1 itself from cave metadata. Per code
    -- review: writing ObjType+1 before mode change gets clobbered
    -- by InitCave. Write order:
    --   RoomId=cave_id -> GameMode=cave_mode -> idle (InitCave runs) ->
    --   THEN force ObjType+1 + positions (in case InitCave used different).
    W(0x062D, SCENARIO_QUEST) -- CurQuest
    W(0x00EB, cave_id)        -- RoomId = cave_id (target)
    W(0x0098, 0x08)           -- Link face = up

    local cave_mode = 0x0B
    if cave_id >= 0x7B then cave_mode = 0x0C end
    W(0x0012, cave_mode)

    -- Step 3: let InitCave + InitCaveContinue run (~3 frames per Z_01.asm).
    -- Extended to 60 to fully settle.
    idle(60)

    -- Step 4: force ObjType+1 + Link/NPC positions AFTER InitCave.
    -- If InitCave already set ObjType+1 = cave_id, this is a no-op.
    -- If different, our force overrides for the capture window.
    W(0x0350, cave_id)        -- ObjType+1 = cave_id (NPC slot)
    W(0x00AD, 0x00)           -- CavePersonState = 0
    W(0x00AC, 0x40)           -- LinkState = halted
    W(0x0071, 0x78)           -- ObjX+1 = NPC X
    W(0x0085, 0x80)           -- ObjY+1 = NPC Y
    W(0x0070, 0x78)           -- Link X
    W(0x0084, 0xC0)           -- Link Y (in cave)

    -- Step 5: extended settle for OAM/PALRAM/CIRAM stable render.
    idle(60)
end

local function force_state_dungeon(level, quest, start_room)
    W(0x062D, quest)
    W(0x0010, level)
    W(0x00EB, start_room)
    W(0x0012, 0x05)  -- GameMode = $05 (UW play)
    W(0x0070, 0x78)
    W(0x0084, 0x80)
    W(0x0098, 0x08)
    idle(120)
end

-- GDMP-compat write helpers (LE u32).
local function u32le(v)
    return string.char(v & 0xFF) .. string.char((v >> 8) & 0xFF) ..
           string.char((v >> 16) & 0xFF) .. string.char((v >> 24) & 0xFF)
end

local function dump_block(read_fn, start, size)
    local buf = {}
    for i = 0, size - 1 do
        buf[#buf+1] = string.char(read_fn(start + i))
    end
    return table.concat(buf)
end

local function read_stat()
    local s = {}
    s[#s+1] = R(0x0012)  -- GameMode
    s[#s+1] = R(0x00EB)  -- RoomId
    s[#s+1] = R(0x0010)  -- CurLevel
    s[#s+1] = R(0x0070)  -- LinkX
    s[#s+1] = R(0x0084)  -- LinkY
    s[#s+1] = R(0x0098)  -- LinkDir
    s[#s+1] = R(0x00AC)  -- LinkState
    s[#s+1] = R(0x00AD)  -- CavePersonState
    s[#s+1] = R(0x0413)  -- CaveFlags
    s[#s+1] = R(0x062D)  -- CurQuest
    s[#s+1] = R(0x0415)  -- PersonTextSelector
    s[#s+1] = R(0x0015)  -- FrameCounter
    for slot = 0, 15 do s[#s+1] = R(0x034F + slot) end  -- ObjType[0..15]
    -- Items + prices (cave-specific)
    for i = 0, 2 do s[#s+1] = R(0x0422 + i) end  -- CaveItemIds[0..2]
    -- Pad to 32
    while #s < 32 do s[#s+1] = 0 end
    local out = ""
    for i = 1, 32 do out = out .. string.char(s[i]) end
    return out
end

local function fnv32(s)
    local h = 2166136261
    for i = 1, #s do
        h = (h ~ string.byte(s, i)) * 16777619
        h = h & 0xFFFFFFFF
    end
    return h
end

local function capture(suffix)
    suffix = suffix or ""
    local bin_path = OUT_DIR .. "\\nes_" .. SCENARIO_ID .. suffix .. ".bin"
    local png_path = OUT_DIR .. "\\nes_" .. SCENARIO_ID .. suffix .. ".png"
    local oam   = dump_block(OAM, 0, 256)
    local palram = dump_block(PAL, 0, 32)
    local ciram = dump_block(CIRAM, 0, 0x800)   -- 2KB nametable
    local zp    = dump_block(R, 0, 256)
    local stat  = read_stat()
    local hash  = fnv32(oam .. palram .. ciram)

    local f = io.open(bin_path, "wb")
    f:write("NDMP")                      -- NES DuMP magic
    f:write(u32le(2))                    -- version
    f:write(u32le(emu.framecount()))
    f:write(u32le(hash))
    local function reg(t, p) f:write(t); f:write(u32le(#p)); f:write(p) end
    reg("OAM_", oam)
    reg("PAL_", palram)
    reg("CIRA", ciram)
    reg("RAM_", zp)
    reg("STAT", stat)
    reg("END_", "")
    f:close()
    client.screenshot(png_path)
end

-- ─── Main flow ─────────────────────────────────────────────────────

print(string.format("NES probe: %s cat=%s target=$%02X",
                    SCENARIO_ID, SCENARIO_CAT, SCENARIO_TARGET))

boot_to_gameplay()

if SCENARIO_CAT == "cave" then
    -- SCENARIO_CAVE_ID set by orchestrator
    force_state_cave(SCENARIO_CAVE_ID, SCENARIO_TARGET)
    capture("")
elseif SCENARIO_CAT == "dungeon" then
    -- SCENARIO_TARGET = uw_start_room_id
    force_state_dungeon(SCENARIO_LEVEL, SCENARIO_QUEST, SCENARIO_TARGET)
    capture("")
elseif SCENARIO_CAT == "dungeon_exit" then
    -- For exit: enter dungeon first, then teleport to OW landing
    force_state_dungeon(SCENARIO_LEVEL, SCENARIO_QUEST, SCENARIO_TARGET)
    idle(30)
    -- For exit, the "destination" is OW. Force OW state.
    W(0x0010, 0x00)
    W(0x00EB, SCENARIO_TARGET)  -- expected OW landing room
    W(0x0012, 0x06)
    idle(120)
    capture("")
else
    capture("_UNKNOWN_CAT")
end

client.exit()

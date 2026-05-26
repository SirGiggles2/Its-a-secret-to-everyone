-- Phase G — Genesis per-scenario capture probe.
--
-- One BizHawk launch per scenario. Reads SCENARIO_ID from a global
-- (set by the orchestrator before this script loads), dumps a full
-- state bundle once a scenario-specific trigger condition is met,
-- writes screenshot, then exits.
--
-- Bundle format = GDMP (matches tools/probes/bizhawk_capture_gen.lua):
--   header:  "GDMP" + version u32 LE + frame u32 LE + payload hash u32 LE
--   regions: PLNA, PLNB, SAT_, CRAM, VSRA, RAM_, STAT (Phase G extension)
--   terminator: END_
--
-- Phase G adds a STAT region: 32 bytes of NES-RAM-mirror cells that
-- pinpoint the scenario state at capture time:
--   [0]  GameMode      ($FF8012)
--   [1]  RoomId        ($FF80EB)
--   [2]  CurLevel      ($FF8010)
--   [3]  LinkX_lo      ($FF8070)
--   [4]  LinkY_lo      ($FF8084)
--   [5]  LinkDir       ($FF8098)
--   [6]  LinkState     ($FF80AC)
--   [7]  CavePersonState ($FF80AD)
--   [8]  CaveFlags     ($FF8413)
--   [9]  CurQuest      ($FF862D)
--   [10] PersonTextSelector ($FF8415)
--   [11] FrameCounter  ($FF8015)
--   [12..27] ObjType[0..15] ($FF834F..$FF835E)
--   [28..31] reserved
--
-- Trigger conditions (per scenario category):
--   cave_enter:   wait for s_scene to become SCENE_CAVE (= 2)
--   dungeon_enter: wait for s_scene to become SCENE_UW (= 1)
--   dungeon_exit: wait for s_scene to transition UW -> OW after entry
--
-- s_scene lives in main.c statics; we read it indirectly via the
-- NES_RAM mirror cell $FF800FA (assert it's used as a scene mirror)
-- OR fall back to GameMode ($0012) cell which transitions through
-- known values per scene.

local SCENARIO_ID = SCENARIO_ID or "cave_6A_enter"
local OUT_BUNDLE  = OUT_BUNDLE  or
    ("C:\\tmp\\g_sweep\\gen_" .. SCENARIO_ID .. ".bin")
local OUT_PNG     = OUT_PNG     or
    ("C:\\tmp\\g_sweep\\gen_" .. SCENARIO_ID .. ".png")
local CAPTURE_FRAMES = CAPTURE_FRAMES or 240   -- post-trigger settle frames
local MAX_BOOT_FRAMES = MAX_BOOT_FRAMES or 900 -- max wait for scenario trigger

-- ─── Helpers ───────────────────────────────────────────────────────

local function u32le(v)
    return string.char(v & 0xFF) ..
           string.char((v >> 8) & 0xFF) ..
           string.char((v >> 16) & 0xFF) ..
           string.char((v >> 24) & 0xFF)
end

local function vram_read_block(start, size)
    local buf = {}
    for i = 0, size - 1 do
        buf[#buf + 1] = string.char(memory.read_u8(start + i, "VRAM"))
    end
    return table.concat(buf)
end

local function cram_read()
    local buf = {}
    for i = 0, 127 do
        buf[#buf + 1] = string.char(memory.read_u8(i, "CRAM"))
    end
    return table.concat(buf)
end

local function vsram_read()
    local buf = {}
    for i = 0, 79 do
        buf[#buf + 1] = string.char(memory.read_u8(i, "VSRAM"))
    end
    return table.concat(buf)
end

local function ram_read_zp()
    local buf = {}
    for i = 0, 255 do
        buf[#buf + 1] = string.char(memory.read_u8(i, "68K RAM"))
    end
    return table.concat(buf)
end

local function nes_r8(addr)
    -- NES_RAM mirror in 68K work RAM at $FF8000 + addr.
    -- 68K RAM domain is 0-indexed at $FF0000 so offset = $8000 + addr.
    return memory.read_u8(0x8000 + addr, "68K RAM")
end

local function read_stat()
    local stat = {}
    stat[1]  = nes_r8(0x0012)  -- GameMode
    stat[2]  = nes_r8(0x00EB)  -- RoomId
    stat[3]  = nes_r8(0x0010)  -- CurLevel
    stat[4]  = nes_r8(0x0070)  -- LinkX
    stat[5]  = nes_r8(0x0084)  -- LinkY
    stat[6]  = nes_r8(0x0098)  -- LinkDir
    stat[7]  = nes_r8(0x00AC)  -- LinkState
    stat[8]  = nes_r8(0x00AD)  -- CavePersonState
    stat[9]  = nes_r8(0x0413)  -- CaveFlags
    stat[10] = nes_r8(0x062D)  -- CurQuest (NES Variables.inc:228)
    stat[11] = nes_r8(0x0415)  -- PersonTextSelector
    stat[12] = nes_r8(0x0015)  -- FrameCounter
    for slot = 0, 15 do
        stat[13 + slot] = nes_r8(0x034F + slot)
    end
    while #stat < 32 do stat[#stat + 1] = 0 end
    local s = ""
    for i = 1, 32 do s = s .. string.char(stat[i]) end
    return s
end

-- ─── Trigger logic ──────────────────────────────────────────────────

local function scenario_category()
    if SCENARIO_ID:find("^cave_") then return "cave_enter" end
    if SCENARIO_ID:find("_enter$") then return "dungeon_enter" end
    if SCENARIO_ID:find("_exit$")  then return "dungeon_exit"  end
    return "unknown"
end

local CATEGORY = scenario_category()

-- s_scene lives at $FF027E (per `nm.exe Debug.out`). 0 = OW, 1 = UW, 2 = CAVE.
-- 68K RAM domain is 0-indexed at $FF0000 so offset = $027E.
local function detect_scene()
    local v = memory.read_u8(0x027E, "68K RAM")
    if v == 0 then return "OW" end
    if v == 1 then return "UW" end
    if v == 2 then return "CAVE" end
    return "UNK"
end

-- Auto-press A+B+C every 30 frames between f30 and f300 to advance
-- past title (same pattern as Phase E/F probes).
local function maybe_chord(frame)
    if frame >= 30 and frame <= 300 and (frame % 30) == 0 then
        joypad.set({["P1 A"] = true,
                    ["P1 B"] = true,
                    ["P1 C"] = true})
    end
end

-- ─── Main capture loop ──────────────────────────────────────────────

local triggered_at = 0
local prev_scene = "OW"

for frame = 1, MAX_BOOT_FRAMES do
    maybe_chord(frame)
    emu.frameadvance()
    local scene = detect_scene()
    if CATEGORY == "cave_enter" and scene == "CAVE" then
        triggered_at = frame
        break
    elseif CATEGORY == "dungeon_enter" and scene == "UW" then
        triggered_at = frame
        break
    elseif CATEGORY == "dungeon_exit"
           and prev_scene == "UW" and scene == "OW" then
        triggered_at = frame
        break
    end
    prev_scene = scene
end

if triggered_at == 0 then
    -- Capture anyway, but flag in filename so the differ knows.
    OUT_BUNDLE = OUT_BUNDLE:gsub("%.bin$", "_NOTRIGGER.bin")
    OUT_PNG    = OUT_PNG:gsub("%.png$",    "_NOTRIGGER.png")
end

-- Let the scenario settle for CAPTURE_FRAMES frames before dumping.
for _ = 1, CAPTURE_FRAMES do emu.frameadvance() end

-- ─── Dump bundle ────────────────────────────────────────────────────

local plana = vram_read_block(0xC000, 0x2000)
local planb = vram_read_block(0xE000, 0x2000)
local sat   = vram_read_block(0xFC00, 640)
local cram  = cram_read()
local vsra  = vsram_read()
local zp    = ram_read_zp()
local stat  = read_stat()

local function fnv32(s)
    local h = 2166136261
    for i = 1, #s do
        h = (h ~ string.byte(s, i)) * 16777619
        h = h & 0xFFFFFFFF
    end
    return h
end
local payload_hash = fnv32(plana .. planb .. sat .. cram .. vsra)

os.execute('if not exist "C:\\tmp\\g_sweep" mkdir "C:\\tmp\\g_sweep"')
local f = io.open(OUT_BUNDLE, "wb")
f:write("GDMP")
f:write(u32le(2))                       -- version (Phase G adds STAT)
f:write(u32le(emu.framecount()))        -- frame at capture
f:write(u32le(payload_hash))

local function region(tag, payload)
    f:write(tag)
    f:write(u32le(#payload))
    f:write(payload)
end
region("PLNA", plana)
region("PLNB", planb)
region("SAT_", sat)
region("CRAM", cram)
region("VSRA", vsra)
region("RAM_", zp)
region("STAT", stat)
region("END_", "")
f:close()

client.screenshot(OUT_PNG)

print(string.format(
    "Phase G probe: SCENARIO=%s CATEGORY=%s triggered_at=%d total_frames=%d -> %s",
    SCENARIO_ID, CATEGORY, triggered_at, emu.framecount(), OUT_BUNDLE))

client.exit()

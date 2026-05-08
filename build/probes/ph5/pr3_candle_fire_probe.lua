-- pr3_candle_fire_probe.lua
-- Boot CombinedDebug, drop into RoomRom UW, switch to candle, spawn
-- fire, capture screenshots covering the full 4-frame animation cycle
-- (4 frames * 4 ticks = 16 frames total). Plus dump SAT slot 8 each
-- screenshot to confirm tile_attr cycling.

local OUT_DIR = "C:\\tmp\\pr3_candle_fire"
os.execute("mkdir " .. OUT_DIR .. " 2>nul")

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then memory.usememorydomain("Main RAM") end
end

local DBG_BASE = 0x7280   -- arrow_active, fire_active, s_b_item, ...

local function read_dbg_u8(off)
    return memory.read_u8(DBG_BASE + off)
end

-- VRAM SAT lives at $F400 in 64x32 mode (per RoomRom/src/roomrom_vram_map.h).
-- One sprite entry = 8 bytes:
--   word 0 (Y),  word 1 (size+link),  word 2 (tile_attr), word 3 (X)
local function sat_slot(slot)
    local addr = 0xF400 + slot * 8
    local function r16(off) return memory.read_u16_be(addr + off, "VRAM") end
    return {
        y = r16(0),
        size_link = r16(2),
        tile_attr = r16(4),
        x = r16(6),
    }
end

local fcount = 0
local snaps = {}

local function snap(name)
    local s = sat_slot(8)
    snaps[#snaps + 1] = {
        name = name, frame = fcount, sat = s,
        arrow_active = read_dbg_u8(0),
        fire_active  = read_dbg_u8(1),
        s_b_item     = read_dbg_u8(2),
    }
    print(string.format(
        "[pr3] %-12s f=%d  fire=%d  b_item=%d  SAT[8]=Y%04X size_link%04X tile_attr%04X X%04X",
        name, fcount, snaps[#snaps].fire_active, snaps[#snaps].s_b_item,
        s.y, s.size_link, s.tile_attr, s.x))
    client.screenshot(OUT_DIR .. "\\" .. name .. ".png")
end

local SPAWN_FRAME = 280
local TOTAL_FRAMES = SPAWN_FRAME + 100

while fcount < TOTAL_FRAMES do
    local input = {}
    -- Frames 60..80: A+B+C chord -> RoomRom UW.
    if fcount >= 60 and fcount < 80 then
        input.A = true; input.B = true; input.C = true
    end
    -- Cycle Z to advance B-item: BOOMERANG -> ARROW -> BOMB -> CANDLE
    if (fcount == 180) or (fcount == 181) or
       (fcount == 210) or (fcount == 211) or
       (fcount == 240) or (fcount == 241) then
        input.Z = true
    end
    -- Press B at SPAWN_FRAME to fire the candle.
    if fcount == SPAWN_FRAME or fcount == SPAWN_FRAME + 1 then
        input.B = true
    end
    joypad.set(input, 1)

    if fcount == 90 then snap("post_boot") end
    if fcount == 270 then snap("pre_spawn") end
    -- Spawn happens at SPAWN_FRAME. Animation cycles 4 frames @ 4 ticks
    -- each. Capture every 2 frames for the first 16 frames (= one full
    -- cycle), then every 8 frames for the standing tail.
    if fcount == SPAWN_FRAME + 2  then snap("after_spawn_t02") end
    if fcount == SPAWN_FRAME + 4  then snap("frame0_mid_t04") end
    if fcount == SPAWN_FRAME + 6  then snap("frame1_mid_t06") end
    if fcount == SPAWN_FRAME + 8  then snap("frame2_start_t08") end
    if fcount == SPAWN_FRAME + 10 then snap("frame2_mid_t10") end
    if fcount == SPAWN_FRAME + 12 then snap("frame3_start_t12") end
    if fcount == SPAWN_FRAME + 14 then snap("frame3_mid_t14") end
    if fcount == SPAWN_FRAME + 16 then snap("cycle_wrap_t16") end
    if fcount == SPAWN_FRAME + 30 then snap("standing_t30") end
    if fcount == SPAWN_FRAME + 60 then snap("standing_t60") end

    fcount = fcount + 1
    emu.frameadvance()
end

local rep = io.open(OUT_DIR .. "\\report.json", "w")
if rep then
    rep:write("{\n  \"snapshots\": [\n")
    for i, s in ipairs(snaps) do
        rep:write(string.format(
            "    {\"name\":\"%s\",\"frame\":%d,\"fire\":%d,\"b_item\":%d," ..
            "\"sat_y\":\"0x%04X\",\"sat_size_link\":\"0x%04X\"," ..
            "\"sat_tile_attr\":\"0x%04X\",\"sat_x\":\"0x%04X\"}%s\n",
            s.name, s.frame, s.fire_active, s.s_b_item,
            s.sat.y, s.sat.size_link, s.sat.tile_attr, s.sat.x,
            i == #snaps and "" or ","))
    end
    rep:write("  ]\n}\n")
    rep:close()
end
print("[pr3] DONE -> " .. OUT_DIR)
client.exit()

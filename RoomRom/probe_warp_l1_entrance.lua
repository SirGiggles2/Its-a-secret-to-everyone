-- probe_warp_l1_entrance.lua
--
-- Task 5.4 (Ph5.4) — passive state recorder for the OW→UW Level 1
-- warp coordinator. User drives input manually; this script reads the
-- 36-byte state mirror at 0xFF7200 every frame and logs transitions.
--
-- Records:
--   * scene + room_id + Link pos every time any of those change
--   * full snapshot at the frame the warp coordinator fires
--   * unsupported-selector counter increments (for L2-L9 walk-on probes)
--
-- Output: RoomRom/out/probe_warp_l1_entrance.log
--   In CombinedDebug runs: builds/probe_warp_l1_entrance.combined.log
--
-- Mirror layout — see RoomRom/src/roomrom_debug_runtime.h
--   ROOMROM_DEBUG_STATE_MIRROR_BASE = 0xFF7200
--   ROOMROM_DEBUG_STATE_MIRROR_BYTES = 36
--
-- Run manually:
--   1. Boot the ROM in BizHawk (RoomRom.md OR CombinedDebug.md).
--   2. Tools -> Lua Console -> Open this script.
--   3. Drive Link onto the L1 entrance tile in OW room $37 (or any
--      tile you want to test).
--   4. Watch the log update on warp / scene change.
--   5. Inspect the log file when done.

local MIRROR_BASE = 0xFF7200
local MIRROR_BYTES = 36
local MAGIC_W = 0x57
local MAGIC_P = 0x50

-- Pick a domain that survives both RoomRom-standalone and CombinedDebug.
-- BizHawk genplus-gx exposes "68K RAM" or "Main RAM" depending on core
-- build; try the common names in order.
local DOMAIN = nil
local function try_domain(name)
    local ok = pcall(function() memory.usememorydomain(name) end)
    if ok then return name end
    return nil
end
DOMAIN = try_domain("68K RAM") or try_domain("Main RAM") or try_domain("MD RAM")
if not DOMAIN then
    print("WARN: no recognized 68K RAM domain; using whatever is current")
end
print("[probe_warp_l1_entrance] memory domain: " .. tostring(DOMAIN))

-- Genesis 68K RAM is mapped at $FF0000-$FFFFFF. The "68K RAM" domain is
-- usually 0x10000 bytes representing $FF0000..$FFFFFF, addressed as 0..0xFFFF.
-- ROOMROM_DEBUG_STATE_MIRROR_BASE = 0xFF7200 -> domain offset 0x7200.
local DOMAIN_OFFSET = 0x7200

local function rb(off)
    return memory.read_u8(DOMAIN_OFFSET + off)
end

local function rs16be(off)
    local hi = memory.read_u8(DOMAIN_OFFSET + off)
    local lo = memory.read_u8(DOMAIN_OFFSET + off + 1)
    local v = hi * 256 + lo
    if v >= 0x8000 then v = v - 0x10000 end
    return v
end

local function ru16be(off)
    return memory.read_u8(DOMAIN_OFFSET + off) * 256
         + memory.read_u8(DOMAIN_OFFSET + off + 1)
end

local function rs8(off)
    local v = memory.read_u8(DOMAIN_OFFSET + off)
    if v >= 0x80 then v = v - 0x100 end
    return v
end

local function read_mirror()
    if rb(0) ~= MAGIC_W or rb(1) ~= MAGIC_P then
        return nil
    end
    return {
        frame      = ru16be(2),
        scene      = rb(4),
        room_id    = rb(5),
        link_x     = rs16be(6),
        link_y     = rs16be(8),
        link_face  = rb(10),
        link_dir   = rb(11),
        link_grid  = rs8(12),
        doorway    = rb(13),
        warp_act   = rb(14),
        warp_unsup = rb(15),
        uw_level   = rb(16),
        uw_quest   = rb(17),
        ow_stable  = rb(18),
        link_frac  = rb(19),
        ug_exit    = rb(20),
        sv_ver     = rb(22),
        sv_src_rm  = rb(23),
        sv_uet     = rb(24),
        sv_uet_raw = rb(25),
        sv_src_x   = rs16be(26),
        sv_src_y   = rs16be(28),
        sv_src_fc  = rb(30),
        sv_dst_lvl = rb(31),
        sv_dst_q   = rb(32),
        sv_dst_rm  = rb(33),
        sv_dst_fc  = rb(34),
    }
end

local function scene_name(s)
    if s == 0 then return "OW" end
    if s == 1 then return "UW" end
    if s == 2 then return "CAVE" end
    return string.format("?%d", s)
end

local function format_brief(m)
    return string.format(
        "f=%5d %s rm=$%02X (%4d,%4d) face=%d dir=%d g=%+d  warp=%d unsup=%d  uw=L%dQ%d  stable=%d",
        m.frame, scene_name(m.scene), m.room_id, m.link_x, m.link_y,
        m.link_face, m.link_dir, m.link_grid,
        m.warp_act, m.warp_unsup, m.uw_level, m.uw_quest, m.ow_stable
    )
end

local function format_save(m)
    return string.format(
        "  save: ver=%d src_rm=$%02X uet=$%02X (raw=$%02X) src=(%d,%d) face=%d  dst=L%dQ%d rm=$%02X face=%d",
        m.sv_ver, m.sv_src_rm, m.sv_uet, m.sv_uet_raw,
        m.sv_src_x, m.sv_src_y, m.sv_src_fc,
        m.sv_dst_lvl, m.sv_dst_q, m.sv_dst_rm, m.sv_dst_fc
    )
end

-- Decide log path. CombinedDebug ROM lives at builds/CombinedDebug.md;
-- RoomRom lives at RoomRom/out/RoomRom.md. We can't introspect the ROM
-- name from Lua, so write to a deterministic path and let the user
-- rename / move per session.
local LOG_PATH = "RoomRom/out/probe_warp_l1_entrance.log"
local log_handle = io.open(LOG_PATH, "w")
if not log_handle then
    print("ERROR: could not open log: " .. LOG_PATH)
    return
end
local function log(line)
    log_handle:write(line .. "\n")
    log_handle:flush()
    print(line)
end

log(string.format("# Task 5.4 warp probe — log opened %s", os.date("%Y-%m-%d %H:%M:%S")))
log("# Mirror base = 0xFF7200, magic 'WP', layout per roomrom_debug_runtime.h")
log("# Drive input manually. Probe logs scene/room/warp transitions.")

local prev = nil
local frames_since_warp = -1

while true do
    local m = read_mirror()
    if m == nil then
        if prev ~= nil then
            log("# mirror magic missing — Title boot still running or RAM not yet initialised")
        end
        prev = nil
    else
        local changed = false
        local notes = {}

        if not prev then
            changed = true
            table.insert(notes, "INITIAL")
        else
            if m.scene ~= prev.scene then
                changed = true
                table.insert(notes, string.format("SCENE %s -> %s",
                    scene_name(prev.scene), scene_name(m.scene)))
            end
            if m.room_id ~= prev.room_id then
                changed = true
                table.insert(notes, string.format("ROOM $%02X -> $%02X",
                    prev.room_id, m.room_id))
            end
            if m.warp_act == 1 and prev.warp_act == 0 then
                changed = true
                frames_since_warp = 0
                table.insert(notes, "WARP_ACTIVE_EDGE")
            end
            if m.warp_act == 0 and prev.warp_act == 1 then
                changed = true
                table.insert(notes, "WARP_DONE")
            end
            if m.warp_unsup ~= prev.warp_unsup then
                changed = true
                table.insert(notes, string.format("UNSUPPORTED_SELECTOR_COUNT %d -> %d",
                    prev.warp_unsup, m.warp_unsup))
            end
            if m.uw_level ~= prev.uw_level or m.uw_quest ~= prev.uw_quest then
                changed = true
                table.insert(notes, string.format("UW_LVL_QST %d/%d -> %d/%d",
                    prev.uw_level, prev.uw_quest, m.uw_level, m.uw_quest))
            end
        end

        if frames_since_warp == 0 then
            log("--- WARP SNAPSHOT (PREPARE/LOAD frame) ---")
            log(format_brief(m))
            log(format_save(m))
            frames_since_warp = 1
        elseif frames_since_warp >= 1 and frames_since_warp <= 4 then
            log(string.format("--- WARP +%d frame ---", frames_since_warp))
            log(format_brief(m))
            log(format_save(m))
            frames_since_warp = frames_since_warp + 1
        end

        if changed then
            log(format_brief(m) .. "  " .. table.concat(notes, " | "))
            if #notes > 0 and notes[1] == "INITIAL" then
                log(format_save(m))
            end
        end

        prev = m
    end

    emu.frameadvance()
end

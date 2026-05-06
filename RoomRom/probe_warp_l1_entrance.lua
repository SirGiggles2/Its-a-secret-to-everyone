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
        foot_tile  = rb(21),
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
        walk_here  = rb(35),
        walk_north = rb(36),
        meta_col   = rb(37),
        meta_row   = rb(38),
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
        "f=%5d %s rm=$%02X (%4d,%4d) face=%d dir=%d g=%+d  foot=$%02X mt=(%2d,%2d) walk_h=%d walk_N=%d  warp=%d unsup=%d  uw=L%dQ%d  stable=%d",
        m.frame, scene_name(m.scene), m.room_id, m.link_x, m.link_y,
        m.link_face, m.link_dir, m.link_grid, m.foot_tile,
        m.meta_col, m.meta_row, m.walk_here, m.walk_north,
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

-- Two outputs: human log + machine-readable JSONL (one event per line).
-- The JSONL file is what the Claude session reads to diagnose without
-- eyeballing the text log.
local LOG_PATH    = "C:\\tmp\\probe_warp_l1_entrance.log"
local JSON_PATH   = "C:\\tmp\\probe_warp_l1_entrance.jsonl"
-- Single-line snapshot of the latest mirror state, overwritten every
-- frame. Used by Claude to read "what's the current state right now"
-- without scanning the JSONL transition history.
local STATE_PATH  = "C:\\tmp\\warp_probe_state.json"
-- Gate B four-boot diff: the probe captures one snapshot at the first
-- stable frame of UW gameplay reached by direct boot, and one at the
-- first stable frame of UW gameplay post-warp. The Python diff harness
-- (tools/gate_b_diff.py) compares the pair across two probe runs
-- (RoomRom + CombinedDebug) for cross-target parity.
local BOOT_D_PATH = "C:\\tmp\\boot_d_snapshot.json"
local BOOT_W_PATH = "C:\\tmp\\boot_w_snapshot.json"
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

local json_handle = io.open(JSON_PATH, "w")
if not json_handle then
    print("ERROR: could not open jsonl: " .. JSON_PATH)
    return
end

-- Minimal JSON encoder for flat tables of strings/numbers/booleans.
local function json_encode_value(v)
    local t = type(v)
    if t == "string" then
        return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
    elseif t == "number" then
        return tostring(v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif v == nil then
        return "null"
    else
        return "null"
    end
end
local function json_encode_obj(obj)
    local parts = {}
    -- Stable key order: sort
    local keys = {}
    for k, _ in pairs(obj) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        parts[#parts + 1] = '"' .. k .. '":' .. json_encode_value(obj[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function jlog(event_type, fields)
    local obj = { event = event_type }
    for k, v in pairs(fields) do obj[k] = v end
    json_handle:write(json_encode_obj(obj) .. "\n")
    json_handle:flush()
end

log(string.format("# Task 5.4 warp probe — log opened %s", os.date("%Y-%m-%d %H:%M:%S")))
log("# Mirror base = 0xFF7200, magic 'WP', layout per roomrom_debug_runtime.h")
log("# Gate D base = 0xFF7300, magic 'GD', layout per probes/metadata_probe.h")
log("# Drive input manually. Probe logs scene/room/warp transitions.")

-- OW raw-tile cache exposed by C side at $FF7400, 32×22 = 704 bytes,
-- column-major layout: cache[col*22 + row]. magic 'TC' at base.
local CACHE_BASE_OFFSET = 0x7400
local cache_dump_last_room = -1
local function dump_cache_once_per_room(m)
    -- Scan only when ow_stable=1 and we haven't dumped this room yet.
    if m == nil or m.scene ~= 0 or m.ow_stable ~= 1 then return end
    local key = m.room_id
    if cache_dump_last_room == key then return end
    cache_dump_last_room = key
    if memory.read_u8(CACHE_BASE_OFFSET) ~= 0x54 or
       memory.read_u8(CACHE_BASE_OFFSET + 1) ~= 0x43 then
        jlog("cache_dump", { room_id = key, error = "no TC magic" })
        return
    end
    local warp_tiles = {}
    for col = 0, 31 do
        for row = 0, 21 do
            local off = CACHE_BASE_OFFSET + 4 + col * 22 + row
            local t = memory.read_u8(off)
            if t == 0x24 or t == 0x88 or
               t == 0x70 or t == 0x71 or t == 0x72 or t == 0x73 then
                warp_tiles[#warp_tiles + 1] =
                    string.format("(%d,%d)=$%02X", col, row, t)
            end
        end
    end
    jlog("cache_dump", {
        room_id = key,
        warp_tile_count = #warp_tiles,
        warp_tiles = table.concat(warp_tiles, ","),
    })
end

-- Gate D: in-ROM metadata probe block at $FF7300.
local GD_OFFSET = 0x7300
local GD_LABELS = {
    [0] = "ow_meta_attr_b(0x37)",
    [1] = "ow_meta_level_selector(0x37)",
    [2] = "ow_meta_is_level_selector(0x04)",
    [3] = "ow_meta_level_from_selector(0x04)",
    [4] = "levelinfo_start_room_for(1,1)  hi=ret lo=dest",
    [5] = "levelinfo_start_room_for(2,1)  hi=ret lo=dest_sentinel",
    [6] = "ROOMROM_HUD_ROWS*8 (playfield top px)",
}

local function read_gate_d()
    if memory.read_u8(GD_OFFSET) ~= 0x47 or memory.read_u8(GD_OFFSET + 1) ~= 0x44 then
        return nil
    end
    local count = memory.read_u8(GD_OFFSET + 2)
    local results = {}
    for i = 0, count - 1 do
        local off = GD_OFFSET + 4 + i * 4
        local actual   = memory.read_u8(off    ) * 256 + memory.read_u8(off + 1)
        local expected = memory.read_u8(off + 2) * 256 + memory.read_u8(off + 3)
        results[i] = {
            actual = actual,
            expected = expected,
            pass = (actual == expected),
            label = GD_LABELS[i] or string.format("check[%d]", i),
        }
    end
    return results
end

local gate_d_logged = false
local function log_gate_d_once()
    if gate_d_logged then return end
    local r = read_gate_d()
    if r == nil then return end
    log("--- Gate D — in-ROM metadata probe ---")
    local all_pass = true
    for i = 0, #r do
        local row = r[i]
        if row then
            local tag = row.pass and "PASS" or "FAIL"
            if not row.pass then all_pass = false end
            log(string.format("  [%s] %-46s  actual=$%04X expected=$%04X",
                tag, row.label, row.actual, row.expected))
            jlog("gate_d", {
                idx = i, label = row.label,
                actual = row.actual, expected = row.expected,
                pass = row.pass,
            })
        end
    end
    log(string.format("--- Gate D overall: %s ---",
        all_pass and "PASS" or "FAIL"))
    jlog("gate_d_summary", { all_pass = all_pass })
    gate_d_logged = true
end

local prev = nil
local frames_since_warp = -1
local boot_d_captured = false
local boot_w_captured = false
local frames_in_uw_post_warp = -1
local has_seen_warp_active = false

local function snapshot_to_json(m, label)
    return json_encode_obj({
        label = label,
        frame = m.frame,
        scene = scene_name(m.scene),
        room_id = m.room_id,
        link_x = m.link_x, link_y = m.link_y,
        link_face = m.link_face, link_dir = m.link_dir,
        link_grid = m.link_grid, link_frac = m.link_frac,
        doorway = m.doorway,
        foot_tile = m.foot_tile,
        meta_col = m.meta_col, meta_row = m.meta_row,
        walk_here = m.walk_here, walk_north = m.walk_north,
        ow_stable = m.ow_stable,
        warp_active = m.warp_act,
        warp_unsupported_count = m.warp_unsup,
        uw_level = m.uw_level, uw_quest = m.uw_quest,
        save_dst_room_id = m.sv_dst_rm,
        save_dst_level = m.sv_dst_lvl,
        save_dst_quest = m.sv_dst_q,
        save_uet = m.sv_uet,
    })
end

local function write_snapshot(path, m, label)
    local h = io.open(path, "w")
    if h then
        h:write(snapshot_to_json(m, label) .. "\n")
        h:close()
        log(string.format("--- snapshot %s -> %s ---", label, path))
    end
end

local state_frame_counter = 0

while true do
    log_gate_d_once()
    local m_pre = read_mirror()
    if m_pre then dump_cache_once_per_room(m_pre) end
    local m = read_mirror()
    if m ~= nil then
        -- Refresh single-line live snapshot every 6 frames so Claude
        -- can read the current state cheaply without thrashing IO.
        state_frame_counter = state_frame_counter + 1
        if state_frame_counter >= 6 then
            local sh = io.open(STATE_PATH, "w")
            if sh then
                sh:write(json_encode_obj({
                    frame = m.frame,
                    scene = scene_name(m.scene),
                    room_id = m.room_id,
                    link_x = m.link_x, link_y = m.link_y,
                    link_face = m.link_face, link_dir = m.link_dir,
                    link_grid = m.link_grid, link_frac = m.link_frac,
                    doorway = m.doorway,
                    foot_tile = m.foot_tile,
                    meta_col = m.meta_col, meta_row = m.meta_row,
                    walk_here = m.walk_here, walk_north = m.walk_north,
                    ow_stable = m.ow_stable,
                    warp_active = m.warp_act,
                    warp_unsupported_count = m.warp_unsup,
                    uw_level = m.uw_level, uw_quest = m.uw_quest,
                }) .. "\n")
                sh:close()
            end
            state_frame_counter = 0
        end
    end
    -- Skip the original mirror-read; read again below for the
    -- transition-detection branch (one extra read; keeps both code
    -- paths aligned).
    m = read_mirror()
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
            if m.foot_tile ~= prev.foot_tile and m.scene == 0 then
                changed = true
                local interesting = {[0x24]=1,[0x88]=1,[0x70]=1,[0x71]=1,[0x72]=1,[0x73]=1}
                local tag = interesting[m.foot_tile] and "WARP_TILE" or "tile"
                table.insert(notes, string.format("FOOT $%02X->$%02X (%s)",
                    prev.foot_tile, m.foot_tile, tag))
            end
            if (m.meta_col ~= prev.meta_col or m.meta_row ~= prev.meta_row)
                    and m.scene == 0 then
                changed = true
                table.insert(notes, string.format("METATILE (%d,%d)->(%d,%d) walk_h=%d walk_N=%d",
                    prev.meta_col, prev.meta_row, m.meta_col, m.meta_row,
                    m.walk_here, m.walk_north))
            end
            if m.walk_north ~= prev.walk_north and m.scene == 0 then
                changed = true
                table.insert(notes, string.format("WALK_NORTH %d->%d",
                    prev.walk_north, m.walk_north))
            end
        end

        -- Boot D snapshot: first frame where scene == UW and we have
        -- never seen a warp fire. Captures the canonical direct-boot
        -- UW $73 state for Gate B comparison.
        if not boot_d_captured and m.scene == 1 and not has_seen_warp_active
                and m.room_id == 0x73 and m.frame >= 1 then
            write_snapshot(BOOT_D_PATH, m, "boot_d")
            boot_d_captured = true
        end
        -- Boot W snapshot fires at the exact frame warp_active goes
        -- 1 -> 0 (LOAD step just applied, RESUME pending). Captures
        -- canonical UW spawn state pre-input — deterministic regardless
        -- of how soon the user releases keys post-warp.
        if prev ~= nil and prev.warp_act == 1 and m.warp_act == 0
                and m.scene == 1 and not boot_w_captured then
            write_snapshot(BOOT_W_PATH, m, "boot_w")
            boot_w_captured = true
        end
        if m.warp_act == 1 then has_seen_warp_active = true end

        if frames_since_warp >= 0 and frames_since_warp <= 4 then
            log(string.format("--- WARP +%d frame ---", frames_since_warp))
            log(format_brief(m))
            log(format_save(m))
            jlog("warp_frame", {
                offset = frames_since_warp,
                frame = m.frame,
                scene = scene_name(m.scene),
                room_id = m.room_id,
                link_x = m.link_x, link_y = m.link_y,
                link_face = m.link_face,
                ow_stable = m.ow_stable,
                save_src_room_id = m.sv_src_rm,
                save_uet = m.sv_uet,
                save_dst_level = m.sv_dst_lvl,
                save_dst_quest = m.sv_dst_q,
                save_dst_room_id = m.sv_dst_rm,
            })
            frames_since_warp = frames_since_warp + 1
        end

        if changed then
            log(format_brief(m) .. "  " .. table.concat(notes, " | "))
            if #notes > 0 and notes[1] == "INITIAL" then
                log(format_save(m))
            end
            jlog("transition", {
                frame = m.frame,
                scene = scene_name(m.scene),
                room_id = m.room_id,
                link_x = m.link_x, link_y = m.link_y,
                link_face = m.link_face, link_dir = m.link_dir,
                link_grid = m.link_grid, link_frac = m.link_frac,
                doorway = m.doorway,
                foot_tile = m.foot_tile,
                meta_col = m.meta_col, meta_row = m.meta_row,
                walk_here = m.walk_here, walk_north = m.walk_north,
                ow_stable = m.ow_stable,
                warp_active = m.warp_act,
                warp_unsupported_count = m.warp_unsup,
                uw_level = m.uw_level, uw_quest = m.uw_quest,
                save_version = m.sv_ver,
                save_src_room_id = m.sv_src_rm,
                save_uet = m.sv_uet, save_uet_raw = m.sv_uet_raw,
                save_src_x = m.sv_src_x, save_src_y = m.sv_src_y,
                save_src_face = m.sv_src_fc,
                save_dst_level = m.sv_dst_lvl,
                save_dst_quest = m.sv_dst_q,
                save_dst_room_id = m.sv_dst_rm,
                save_dst_face = m.sv_dst_fc,
                notes = table.concat(notes, ";"),
            })
        end

        prev = m
    end

    emu.frameadvance()
end

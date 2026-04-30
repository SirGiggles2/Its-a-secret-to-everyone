-- probe_nes_uw_dump.lua
-- Sequential per-(level,quest) NES Z1 underworld room dump probe.
--
-- Boot to overworld, optionally enable second quest by patching
-- QuestNumbers RAM, TargetMode-warp into the chosen dungeon level,
-- then drive each target room through GameMode=3 / GameSub=2 to reach
-- LayOutRoom via Sub8. After the room settles, dump CIRAM nametable
-- (30 rows x 32 cols), attribute table (64 bytes), and PALRAM
-- (32 bytes). Emit a single JSON file.
--
-- Env contract (set by tools/run_uw_level.py):
--   CODEX_UW_LEVEL          -- int level 1..9
--   CODEX_UW_QUEST          -- int quest 1..2
--   CODEX_UW_ROOMS_JSON     -- path to data/uw_levelL_questQ_rooms.json
--   CODEX_UW_MANIFEST_JSON  -- path to data/uw_levelL_questQ_manifest.json
--   CODEX_UW_OUT_JSON       -- path to per-run dump JSON output
--   CODEX_UW_MAP_ID         -- "orig" or "redux"  (just metadata)
--   CODEX_UW_MAP_NAME       -- human-readable map name
--
-- Per-room reload procedure:
--   1. Reset transition / door RAM state.
--   2. Write RoomId=$00EB, NextRoomId=$00EC, GameMode=$0012=3,
--      GameSub=$0013=2, IsUpdatingMode=$0011=0.
--      (GameSub=2 is intentional because Sub1 overwrites RoomId from
--       LevelInfo_StartRoomId; Sub2 advances forward through attr/
--       palette transfer to Sub8 where LayOutRoom runs.)
--   3. Settle predicate (max 1500 frames, 12 consecutive stable):
--        GameMode == 5 AND GameSub == 0 AND IsUpdatingMode == 1
--        AND (PPU $2001 & $18) == $18  (BG+sprite enable)
--        AND NT/attr/PALRAM hash unchanged across 12-frame window.
--   4. On timeout emit {"room_id": ..., "code": "settle_timeout"}.

----------------------------------------------------------------------
-- Configuration / RAM map
----------------------------------------------------------------------

local IS_UPDATING_MODE = 0x0011  -- $11
local CUR_LEVEL        = 0x0010  -- $10
local GAME_MODE        = 0x0012  -- $12
local GAME_SUB         = 0x0013  -- $13
local TILE_BUF_SEL     = 0x0014  -- $14
local FRAME_COUNTER    = 0x0015  -- $15
local CUR_SAVE_SLOT    = 0x0016
local TARGET_MODE      = 0x005B  -- $5B
local DOORWAY_DIR      = 0x0053
local TRIGGERED_DOOR_CMD = 0x0054
local TRIGGERED_DOOR_DIR = 0x0055
local ROOM_TRANS       = 0x004C
local ROOM_ID          = 0x00EB
local NEXT_ROOM_ID     = 0x00EC
local CUR_OPENED_DOORS = 0x00EE
local CUR_PPU_MASK     = 0x00FE
local OPEN_DOORWAY_MASK = 0x033F
local NAME_PROGRESS    = 0x0421
local FADE_CYCLE       = 0x051C
local PREV_OPENED_DOORS = 0x0521
local SPAWN_CYCLE      = 0x0524
local CUR_EDGE_SPAWN   = 0x0525
local CAVE_SOURCE_ROOM = 0x0526
local CELLAR_SRC_ROOM  = 0x0527
local TARGET_MIRROR    = 0x0602
-- LevelInfo_StartRoomId at $6BAD. The Zelda Redux Dungeon Automap hack
-- (PRG bank 6 CPU $AF17 LDA $6BAD; STA $EB) restores RoomId from this
-- RAM byte while running .map_full. Forced room reloads must overwrite
-- $6BAD with the target room id so the restore lands on the target
-- instead of the level's start room. Vanilla Z1 ignores this; harmless
-- to write on both ROMs.
local LEVEL_INFO_START_ROOM = 0x6BAD
local QUEST_NUMBERS    = 0x062D  -- 3 bytes, one per save slot
local SAVE_ACTIVE0     = 0x0633
local SAVE_ACTIVE1     = 0x0634
local SAVE_ACTIVE2     = 0x0635

local CIRAM_BASE = 0x0000
local ATTR_BASE  = 0x03C0

local MAX_BOOT_FRAMES   = 20000
local MAX_WARP_FRAMES   = 1200
local MAX_SETTLE_FRAMES = 1500
local STABLE_WINDOW     = 12   -- frames

----------------------------------------------------------------------
-- Memory helpers
----------------------------------------------------------------------

local function u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr & 0xFFFF)
end

local function w8(addr, val)
    memory.usememorydomain("System Bus")
    memory.write_u8(addr & 0xFFFF, val & 0xFF)
end

local function read_domain_u8(domain, addr)
    local ok, v = pcall(function()
        memory.usememorydomain(domain)
        return memory.read_u8(addr)
    end)
    if ok then return v end
    return nil
end

local function ciram_u8(addr)
    for _, d in ipairs({"CIRAM (nametables)", "CIRAM", "Nametable RAM"}) do
        local v = read_domain_u8(d, addr)
        if v ~= nil then return v end
    end
    return 0
end

local PAL_DOMAIN = nil
do
    local ok, domains = pcall(memory.getmemorydomainlist)
    if ok and domains then
        for _, d in ipairs(domains) do
            local name = (type(d) == "table") and (d.Name or tostring(d)) or tostring(d)
            local lower = name:lower()
            if lower:find("pal") or lower:find("palette") then
                local size_ok, size = pcall(memory.getmemorydomainsize, name)
                if size_ok and size and size <= 64 then
                    PAL_DOMAIN = name
                    break
                end
            end
        end
    end
end

local function palram_u8(addr)
    if PAL_DOMAIN then
        local v = read_domain_u8(PAL_DOMAIN, addr)
        if v ~= nil then return v end
    end
    return 0
end

----------------------------------------------------------------------
-- Input scheduler (cloned from probe_nes_hud_reference.lua)
----------------------------------------------------------------------

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 0 }

local function schedule(button, hold_frames, release_frames)
    if input_state.hold_left > 0 or input_state.release_left > 0 then return end
    input_state.button = button
    input_state.hold_left = hold_frames or 1
    input_state.release_left = 0
    input_state.release_after = release_frames or 8
end

local function build_pad()
    local pad = {}
    if input_state.hold_left > 0 and input_state.button then
        pad[input_state.button] = true
        pad["P1 " .. input_state.button] = true
        input_state.hold_left = input_state.hold_left - 1
        if input_state.hold_left == 0 then
            input_state.release_left = input_state.release_after
        end
    elseif input_state.release_left > 0 then
        input_state.release_left = input_state.release_left - 1
    end
    return pad
end

----------------------------------------------------------------------
-- Boot to overworld (file select state machine)
----------------------------------------------------------------------

local function boot_to_overworld()
    local BOOT_TO_FS1, SELECT_REGISTER, ENTER_REGISTER, TYPE_NAME, FINISH_NAME, WAIT_GAMEPLAY, START_GAME = 1,2,3,4,5,6,7
    local flow = BOOT_TO_FS1
    local last_name = u8(NAME_PROGRESS)
    local name_events = 0
    for frame = 1, MAX_BOOT_FRAMES do
        local mode = u8(GAME_MODE)
        local slot = u8(CUR_SAVE_SLOT)
        local name = u8(NAME_PROGRESS)
        local active0 = u8(SAVE_ACTIVE0)
        local active1 = u8(SAVE_ACTIVE1)
        local active2 = u8(SAVE_ACTIVE2)
        if flow == BOOT_TO_FS1 then
            if mode == 0x01 then flow = SELECT_REGISTER else schedule("Start", 2, 3) end
        elseif flow == SELECT_REGISTER then
            if slot == 0x03 then flow = ENTER_REGISTER else schedule("Down", 1, 10) end
        elseif flow == ENTER_REGISTER then
            if mode == 0x0E then flow = TYPE_NAME; last_name = name
            elseif mode == 0x01 then schedule("Start", 2, 14) end
        elseif flow == TYPE_NAME then
            if name ~= last_name then name_events = name_events + 1; last_name = name end
            if name_events >= 5 then flow = FINISH_NAME else schedule("A", 1, 10) end
        elseif flow == FINISH_NAME then
            if mode ~= 0x0E then flow = WAIT_GAMEPLAY
            elseif slot ~= 0x03 then schedule("Select", 1, 10)
            else schedule("Start", 2, 14) end
        elseif flow == WAIT_GAMEPLAY then
            if mode == 0x01 then flow = START_GAME end
        elseif flow == START_GAME then
            if mode ~= 0x01 then flow = WAIT_GAMEPLAY
            else
                local target_slot = 0x00
                if active0 == 0 and active1 ~= 0 then target_slot = 0x01
                elseif active0 == 0 and active1 == 0 and active2 ~= 0 then target_slot = 0x02 end
                if slot ~= target_slot then schedule(target_slot > slot and "Down" or "Up", 1, 10)
                else schedule("Start", 2, 14) end
            end
        end
        safe_set(build_pad())
        emu.frameadvance()
        if u8(CUR_LEVEL) == 0 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0
           and u8(ROOM_ID) == 0x77 and u8(ROOM_TRANS) == 0 then
            for _ = 1, 30 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

----------------------------------------------------------------------
-- TargetMode warp into chosen dungeon level
----------------------------------------------------------------------

local function force_quest(quest)
    -- Patch QuestNumbers[CurSaveSlot] to (quest-1). Q1 leaves it at 0.
    if quest == 2 then
        local slot = u8(CUR_SAVE_SLOT)
        w8(QUEST_NUMBERS + slot, 1)
    end
end

local function warp_to_level(level)
    w8(CUR_LEVEL, level)
    w8(TARGET_MODE, 0x02)
    w8(TARGET_MIRROR, 0x02)
    w8(GAME_MODE, 0x10)
    w8(GAME_SUB, 0x00)
    safe_set({})
    -- Wait for play state in the chosen level
    for f = 1, MAX_WARP_FRAMES do
        emu.frameadvance()
        if u8(CUR_LEVEL) == level and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 then
            -- Hold for 30 stable frames
            local stable = 0
            for _ = 1, 60 do
                emu.frameadvance()
                if u8(CUR_LEVEL) == level and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 then
                    stable = stable + 1
                    if stable >= 30 then return true end
                else
                    stable = 0
                end
            end
        end
    end
    return false
end

----------------------------------------------------------------------
-- Reset transition / door RAM before forced room reload
----------------------------------------------------------------------

local function reset_transition_ram()
    -- Door / transition state (per repo-truth corrections in the plan).
    w8(ROOM_TRANS, 0)
    w8(DOORWAY_DIR, 0)
    w8(TRIGGERED_DOOR_CMD, 0)
    w8(TRIGGERED_DOOR_DIR, 0)
    w8(CUR_OPENED_DOORS, 0)
    w8(OPEN_DOORWAY_MASK, 0)
    w8(PREV_OPENED_DOORS, 0)
    w8(SPAWN_CYCLE, 0)
    w8(CUR_EDGE_SPAWN, 0)
    w8(CAVE_SOURCE_ROOM, 0)
    w8(CELLAR_SRC_ROOM, 0)
    w8(FADE_CYCLE, 0)
end

----------------------------------------------------------------------
-- Force room load and settle
----------------------------------------------------------------------

local function force_room(target)
    reset_transition_ram()
    -- Neutralize Zelda Redux Dungeon Automap restore (.map_full does
    -- LDA $6BAD; STA $EB after scanning). Set both to target.
    w8(LEVEL_INFO_START_ROOM, target)
    w8(ROOM_ID, target)
    w8(NEXT_ROOM_ID, target)
    w8(GAME_MODE, 0x03)
    w8(GAME_SUB, 0x02)
    w8(IS_UPDATING_MODE, 0x00)
end

local function dump_nt()
    local rows = {}
    for r = 0, 29 do
        local row = {}
        local base = CIRAM_BASE + r * 32
        for c = 0, 31 do
            row[#row + 1] = ciram_u8(base + c)
        end
        rows[#rows + 1] = row
    end
    return rows
end

local function dump_attr()
    local vals = {}
    for i = 0, 63 do vals[#vals + 1] = ciram_u8(ATTR_BASE + i) end
    return vals
end

local function dump_palram()
    local vals = {}
    for i = 0, 31 do vals[#vals + 1] = palram_u8(i) end
    return vals
end

local function hash_state(nt_rows, attr)
    -- djb2-style fold over NT + attr only. PALRAM intentionally excluded:
    -- Redux + many ROM hacks animate palette cycles every ~8 frames, which
    -- would prevent the stable-window predicate from ever firing while the
    -- room itself is fully laid out and idle. PALRAM is captured at the
    -- moment NT/attr settle.
    local h = 5381
    for r = 1, #nt_rows do
        local row = nt_rows[r]
        for c = 1, #row do h = (h * 33 + row[c]) % 4294967296 end
    end
    for i = 1, #attr   do h = (h * 33 + attr[i])   % 4294967296 end
    return h
end

local function settle_and_capture(target)
    local stable = 0
    local prev_hash = nil
    local last_nt, last_attr, last_pal = nil, nil, nil
    local diag_samples = {}
    local diag_period = 100
    local last_hash = 0
    local last_mode, last_sub, last_upd, last_mask, last_rid = 0, 0, 0, 0, 0
    for f = 1, MAX_SETTLE_FRAMES do
        emu.frameadvance()
        local mode = u8(GAME_MODE)
        local sub  = u8(GAME_SUB)
        local upd  = u8(IS_UPDATING_MODE)
        local mask = u8(CUR_PPU_MASK)
        local rid  = u8(ROOM_ID)
        last_mode, last_sub, last_upd, last_mask, last_rid = mode, sub, upd, mask, rid
        if mode == 0x05 and sub == 0x00 and upd == 0x01
           and (mask % 0x20) >= 0x18 and rid == target then
            local bg_spr = 0
            if bit32 and bit32.band then bg_spr = bit32.band(mask, 0x18)
            else bg_spr = mask % 0x20 - mask % 0x08 end
            if bg_spr == 0x18 then
                local nt_rows = dump_nt()
                local attr = dump_attr()
                local h = hash_state(nt_rows, attr)
                last_hash = h
                if prev_hash ~= nil and h == prev_hash then
                    stable = stable + 1
                    last_nt, last_attr = nt_rows, attr
                    if stable >= STABLE_WINDOW then
                        last_pal = dump_palram()
                        return true, last_nt, last_attr, last_pal, f, nil
                    end
                else
                    stable = 0
                    prev_hash = h
                    last_nt, last_attr = nt_rows, attr
                end
            else
                stable = 0
                prev_hash = nil
            end
        else
            stable = 0
            prev_hash = nil
        end
        if (f % diag_period) == 0 then
            diag_samples[#diag_samples + 1] = {
                f = f, mode = mode, sub = sub, upd = upd,
                mask = mask, rid = rid, hash = last_hash, stable = stable,
            }
        end
    end
    return false, nil, nil, nil, MAX_SETTLE_FRAMES, {
        last_mode = last_mode, last_sub = last_sub, last_upd = last_upd,
        last_mask = last_mask, last_rid = last_rid, last_hash = last_hash,
        samples = diag_samples,
    }
end

----------------------------------------------------------------------
-- Minimal JSON writer
----------------------------------------------------------------------

local function j1(t)
    local s = {}
    for i = 1, #t do s[#s + 1] = tostring(t[i]) end
    return "[" .. table.concat(s, ",") .. "]"
end

local function j2(rows)
    local s = {}
    for i = 1, #rows do s[#s + 1] = j1(rows[i]) end
    return "[" .. table.concat(s, ",") .. "]"
end

local function escape_json_string(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
    return '"' .. s .. '"'
end

----------------------------------------------------------------------
-- Rooms-list loader
----------------------------------------------------------------------

local function read_file(path)
    local f, err = io.open(path, "rb")
    if not f then return nil, err end
    local txt = f:read("*all"); f:close()
    return txt
end

local function parse_rooms_json(path)
    -- Minimal extractor: pull "rooms": ["0xNN", ...] tokens.
    local txt, err = read_file(path)
    if not txt then return nil, err end
    local block = txt:match('"rooms"%s*:%s*%[([^%]]*)%]')
    if not block then return nil, "rooms_field_missing" end
    local rooms = {}
    for tok in block:gmatch('"0x([0-9A-Fa-f]+)"') do
        rooms[#rooms + 1] = tonumber(tok, 16)
    end
    if #rooms == 0 then return nil, "no_rooms" end
    return rooms
end

----------------------------------------------------------------------
-- Main
----------------------------------------------------------------------

local LEVEL    = tonumber(os.getenv("CODEX_UW_LEVEL") or "1") or 1
local QUEST    = tonumber(os.getenv("CODEX_UW_QUEST") or "1") or 1
local ROOMS    = os.getenv("CODEX_UW_ROOMS_JSON") or ""
local OUT_JSON = os.getenv("CODEX_UW_OUT_JSON") or "RoomRom/out/nes_uw_dump.json"
local MAP_ID   = os.getenv("CODEX_UW_MAP_ID") or "orig"
local MAP_NAME = os.getenv("CODEX_UW_MAP_NAME") or "?"

local system_id = emu.getsystemid() or "?"
local boot_ok = false
local warp_ok = false
local rooms = nil
local rooms_err = nil
local results = {}
local fail_kind = nil

if system_id ~= "NES" then
    fail_kind = "wrong_system_" .. system_id
else
    rooms, rooms_err = parse_rooms_json(ROOMS)
    if not rooms then
        fail_kind = "rooms_load_failed:" .. tostring(rooms_err)
    else
        boot_ok = boot_to_overworld()
        if not boot_ok then
            fail_kind = "boot_failed"
        else
            force_quest(QUEST)
            warp_ok = warp_to_level(LEVEL)
            if not warp_ok then
                fail_kind = "warp_failed"
            else
                for _, rid in ipairs(rooms) do
                    force_room(rid)
                    local ok, nt, attr, pal, frames, diag = settle_and_capture(rid)
                    if ok then
                        results[#results + 1] = {
                            kind = "ok",
                            room_id = rid,
                            settle_frames = frames,
                            cur_level = u8(CUR_LEVEL),
                            game_mode = u8(GAME_MODE),
                            game_sub = u8(GAME_SUB),
                            ppu_mask = u8(CUR_PPU_MASK),
                            quest = QUEST,
                            nt = nt, attr = attr, palram = pal,
                        }
                    else
                        results[#results + 1] = {
                            kind = "timeout", room_id = rid,
                            code = "settle_timeout", settle_frames = frames,
                            diag = diag,
                        }
                    end
                end
            end
        end
    end
end

local f = assert(io.open(OUT_JSON, "w"))
f:write("{\n")
f:write('  "system_id": ', escape_json_string(system_id), ',\n')
f:write('  "boot_ok": ', tostring(boot_ok), ',\n')
f:write('  "warp_ok": ', tostring(warp_ok), ',\n')
f:write('  "rom": ', escape_json_string(MAP_ID), ',\n')
f:write('  "map_name": ', escape_json_string(MAP_NAME), ',\n')
f:write('  "level": ', tostring(LEVEL), ',\n')
f:write('  "quest": ', tostring(QUEST), ',\n')
local captured, failed = 0, 0
for _, r in ipairs(results) do
    if r.kind == "ok" then captured = captured + 1 else failed = failed + 1 end
end
f:write('  "rooms_requested": ', tostring(rooms and #rooms or 0), ',\n')
f:write('  "rooms_captured": ', tostring(captured), ',\n')
f:write('  "rooms_failed": ', tostring(failed), ',\n')
if fail_kind then
    f:write('  "fatal_error": ', escape_json_string(fail_kind), ',\n')
end
f:write('  "results": [\n')
for i, r in ipairs(results) do
    f:write("    {")
    if r.kind == "ok" then
        f:write('"room_id": ', tostring(r.room_id), ', ')
        f:write('"cur_level": ', tostring(r.cur_level), ', ')
        f:write('"game_mode": ', tostring(r.game_mode), ', ')
        f:write('"game_sub": ', tostring(r.game_sub), ', ')
        f:write('"quest": ', tostring(r.quest), ', ')
        f:write('"ppu_mask": ', tostring(r.ppu_mask), ', ')
        f:write('"settle_frames": ', tostring(r.settle_frames), ', ')
        f:write('"nt": ', j2(r.nt), ', ')
        f:write('"attr": ', j1(r.attr), ', ')
        f:write('"palram": ', j1(r.palram))
    else
        f:write('"room_id": ', tostring(r.room_id), ', ')
        f:write('"code": ', escape_json_string(r.code), ', ')
        f:write('"settle_frames": ', tostring(r.settle_frames))
        if r.diag then
            f:write(', "diag": {')
            f:write('"last_mode": ', tostring(r.diag.last_mode), ', ')
            f:write('"last_sub": ', tostring(r.diag.last_sub), ', ')
            f:write('"last_upd": ', tostring(r.diag.last_upd), ', ')
            f:write('"last_mask": ', tostring(r.diag.last_mask), ', ')
            f:write('"last_rid": ', tostring(r.diag.last_rid), ', ')
            f:write('"last_hash": ', tostring(r.diag.last_hash), ', ')
            f:write('"samples": [')
            for si, s in ipairs(r.diag.samples or {}) do
                f:write('{"f":', tostring(s.f), ',"mode":', tostring(s.mode))
                f:write(',"sub":', tostring(s.sub), ',"upd":', tostring(s.upd))
                f:write(',"mask":', tostring(s.mask), ',"rid":', tostring(s.rid))
                f:write(',"hash":', tostring(s.hash), ',"stable":', tostring(s.stable), '}')
                if si < #(r.diag.samples or {}) then f:write(',') end
            end
            f:write(']}')
        end
    end
    f:write("}")
    if i < #results then f:write(",") end
    f:write("\n")
end
f:write("  ]\n")
f:write("}\n")
f:close()

client.exit()

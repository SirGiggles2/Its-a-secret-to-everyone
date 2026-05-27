-- Phase G — Genesis 56-scenario sweep.
--
-- Single BizHawk launch:
--   1. Boot ROM, A+B+C chord f30..f300 to enter debug gameplay (OW @ $77).
--   2. For each scenario in SCENARIOS list:
--      a. Use MODE_TELEPORT (X button toggle + D-pad press) to walk
--         across the 16x8 OW room grid to the target room.
--      b. Wait one frame for room load + cave_entrance_check.
--      c. If entry fires (s_scene becomes CAVE/UW), wait settle frames,
--         capture full bundle + screenshot, then exit (C+START chord
--         for caves, walk to $7D doorway for dungeons).
--      d. If entry doesn't fire, capture diagnostic + flag NOTRIGGER.
--   3. After all 56: client.exit().
--
-- Outputs in C:\tmp\g_sweep\:
--   gen_<scenario_id>.bin   GDMP v2 bundle (PLNA, PLNB, SAT, CRAM,
--                            VSRA, RAM_, STAT)
--   gen_<scenario_id>.png   Frame buffer screenshot
--   sweep_log.txt           Per-scenario trigger frame + status

local OUT_DIR = "C:\\tmp\\g_sweep"
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

-- s_scene + s_room_id VMAs (per nm.exe Debug.out 2026-05-26):
--   s_scene at $FF027E -> 68K RAM offset $027E
--   s_room_id at $FF0041 -> 68K RAM offset $0041
--   s_in_gameplay at $FF0274 -> 68K RAM offset $0274
-- s_scene + s_mode are 4-byte ints in BSS (big-endian on 68K).
-- Read low byte at base+3 for u8 enum value.
local OFF_SCENE         = 0x0281   -- low byte of s_scene (BSS @ $FF027E)
local OFF_MODE          = 0x027D   -- low byte of s_mode  (BSS @ $FF027A)
local OFF_ROOM_ID       = 0x0041
local OFF_IN_GAMEPLAY   = 0x0274
-- players[0] struct base ($FF1564). LinkState layout starts with
-- signed short x (offset 0), signed short y (offset 2). 68K big-endian.
local OFF_PLAYERS0_X    = 0x1564
local OFF_PLAYERS0_Y    = 0x1566

local SCENE_OW   = 0
local SCENE_UW   = 1
local SCENE_CAVE = 2

-- Inline scenarios manifest (Phase G G1 output baked in so this Lua
-- runs without an external JSON parser). Each row: {id, category,
-- target_room, expected_scene_after_warp}.
local SCENARIOS = {
    -- 20 cave entries — first OW room per cave_id from Phase A oracle
    {id="cave_6A_enter", cat="cave", target=0x77, expect=SCENE_CAVE},
    {id="cave_6B_enter", cat="cave", target=0x06, expect=SCENE_CAVE},
    {id="cave_6C_enter", cat="cave", target=0x0A, expect=SCENE_CAVE},
    {id="cave_6D_enter", cat="cave", target=0x09, expect=SCENE_CAVE},
    {id="cave_6E_enter", cat="cave", target=0x1D, expect=SCENE_CAVE},
    {id="cave_6F_enter", cat="cave", target=0x1C, expect=SCENE_CAVE},
    {id="cave_70_enter", cat="cave", target=0x16, expect=SCENE_CAVE},
    {id="cave_71_enter", cat="cave", target=0x01, expect=SCENE_CAVE},
    {id="cave_72_enter", cat="cave", target=0x0E, expect=SCENE_CAVE},
    {id="cave_73_enter", cat="cave", target=0x75, expect=SCENE_CAVE},
    {id="cave_74_enter", cat="cave", target=0x02, expect=SCENE_CAVE},
    {id="cave_75_enter", cat="cave", target=0x1A, expect=SCENE_CAVE},
    {id="cave_76_enter", cat="cave", target=0x70, expect=SCENE_CAVE},
    {id="cave_77_enter", cat="cave", target=0x25, expect=SCENE_CAVE},
    {id="cave_78_enter", cat="cave", target=0x0C, expect=SCENE_CAVE},
    {id="cave_79_enter", cat="cave", target=0x26, expect=SCENE_CAVE},
    {id="cave_7A_enter", cat="cave", target=0x34, expect=SCENE_CAVE},
    {id="cave_7B_enter", cat="cave", target=0x28, expect=SCENE_CAVE},
    {id="cave_7C_enter", cat="cave", target=0x53, expect=SCENE_CAVE},
    {id="cave_7D_enter", cat="cave", target=0x2B, expect=SCENE_CAVE},
    -- 18 dungeon entries Q1 + Q2 (Q2 OW room same as Q1 fallback per
    -- gen_scenarios.py inheritance rule)
    {id="dungeon_L1Q1_enter", cat="dungeon", target=0x37, expect=SCENE_UW, level=1, quest=1},
    {id="dungeon_L1Q2_enter", cat="dungeon", target=0x37, expect=SCENE_UW, level=1, quest=2},
    {id="dungeon_L2Q1_enter", cat="dungeon", target=0x3C, expect=SCENE_UW, level=2, quest=1},
    {id="dungeon_L2Q2_enter", cat="dungeon", target=0x3C, expect=SCENE_UW, level=2, quest=2},
    {id="dungeon_L3Q1_enter", cat="dungeon", target=0x80, expect=SCENE_UW, level=3, quest=1},
    {id="dungeon_L3Q2_enter", cat="dungeon", target=0x80, expect=SCENE_UW, level=3, quest=2},
    {id="dungeon_L4Q1_enter", cat="dungeon", target=0x45, expect=SCENE_UW, level=4, quest=1},
    {id="dungeon_L4Q2_enter", cat="dungeon", target=0x45, expect=SCENE_UW, level=4, quest=2},
    {id="dungeon_L5Q1_enter", cat="dungeon", target=0x0B, expect=SCENE_UW, level=5, quest=1},
    {id="dungeon_L5Q2_enter", cat="dungeon", target=0x0B, expect=SCENE_UW, level=5, quest=2},
    {id="dungeon_L6Q1_enter", cat="dungeon", target=0x22, expect=SCENE_UW, level=6, quest=1},
    {id="dungeon_L6Q2_enter", cat="dungeon", target=0x22, expect=SCENE_UW, level=6, quest=2},
    {id="dungeon_L7Q1_enter", cat="dungeon", target=0x19, expect=SCENE_UW, level=7, quest=1},
    {id="dungeon_L7Q2_enter", cat="dungeon", target=0x19, expect=SCENE_UW, level=7, quest=2},
    {id="dungeon_L8Q1_enter", cat="dungeon", target=0x6C, expect=SCENE_UW, level=8, quest=1},
    {id="dungeon_L8Q2_enter", cat="dungeon", target=0x6C, expect=SCENE_UW, level=8, quest=2},
    {id="dungeon_L9Q1_enter", cat="dungeon", target=0x00, expect=SCENE_UW, level=9, quest=1},
    {id="dungeon_L9Q2_enter", cat="dungeon", target=0x00, expect=SCENE_UW, level=9, quest=2},
    -- 18 dungeon exits — entered first, then walked south to $7D doorway
    {id="dungeon_L1Q1_exit", cat="dungeon_exit", entry_room=0x37, expect=SCENE_OW, level=1, quest=1},
    {id="dungeon_L1Q2_exit", cat="dungeon_exit", entry_room=0x37, expect=SCENE_OW, level=1, quest=2},
    {id="dungeon_L2Q1_exit", cat="dungeon_exit", entry_room=0x3C, expect=SCENE_OW, level=2, quest=1},
    {id="dungeon_L2Q2_exit", cat="dungeon_exit", entry_room=0x3C, expect=SCENE_OW, level=2, quest=2},
    {id="dungeon_L3Q1_exit", cat="dungeon_exit", entry_room=0x80, expect=SCENE_OW, level=3, quest=1},
    {id="dungeon_L3Q2_exit", cat="dungeon_exit", entry_room=0x80, expect=SCENE_OW, level=3, quest=2},
    {id="dungeon_L4Q1_exit", cat="dungeon_exit", entry_room=0x45, expect=SCENE_OW, level=4, quest=1},
    {id="dungeon_L4Q2_exit", cat="dungeon_exit", entry_room=0x45, expect=SCENE_OW, level=4, quest=2},
    {id="dungeon_L5Q1_exit", cat="dungeon_exit", entry_room=0x0B, expect=SCENE_OW, level=5, quest=1},
    {id="dungeon_L5Q2_exit", cat="dungeon_exit", entry_room=0x0B, expect=SCENE_OW, level=5, quest=2},
    {id="dungeon_L6Q1_exit", cat="dungeon_exit", entry_room=0x22, expect=SCENE_OW, level=6, quest=1},
    {id="dungeon_L6Q2_exit", cat="dungeon_exit", entry_room=0x22, expect=SCENE_OW, level=6, quest=2},
    {id="dungeon_L7Q1_exit", cat="dungeon_exit", entry_room=0x19, expect=SCENE_OW, level=7, quest=1},
    {id="dungeon_L7Q2_exit", cat="dungeon_exit", entry_room=0x19, expect=SCENE_OW, level=7, quest=2},
    {id="dungeon_L8Q1_exit", cat="dungeon_exit", entry_room=0x6C, expect=SCENE_OW, level=8, quest=1},
    {id="dungeon_L8Q2_exit", cat="dungeon_exit", entry_room=0x6C, expect=SCENE_OW, level=8, quest=2},
    {id="dungeon_L9Q1_exit", cat="dungeon_exit", entry_room=0x00, expect=SCENE_OW, level=9, quest=1},
    {id="dungeon_L9Q2_exit", cat="dungeon_exit", entry_room=0x00, expect=SCENE_OW, level=9, quest=2},
}

-- ─── Memory helpers ────────────────────────────────────────────────

local function r8(domain_offset, domain)
    return memory.read_u8(domain_offset, domain or "68K RAM")
end

local function read_scene() return r8(OFF_SCENE) end
local function read_room()  return r8(OFF_ROOM_ID) end
local function read_mode()  return r8(OFF_MODE) end
local function nes_r8(addr) return r8(0x8000 + addr) end -- NES mirror

-- Players[0] position helpers (68K big-endian signed short).
local function read_link_x()
    return memory.read_s16_be(OFF_PLAYERS0_X, "68K RAM")
end
local function read_link_y()
    return memory.read_s16_be(OFF_PLAYERS0_Y, "68K RAM")
end
local function write_link_xy(x, y)
    -- Defensive: write both u16_be (preferred) AND raw byte pair
    -- (in case BizHawk Lua's write_s16_be doesn't honor "68K RAM").
    memory.write_u8(OFF_PLAYERS0_X,     (x >> 8) & 0xFF, "68K RAM")
    memory.write_u8(OFF_PLAYERS0_X + 1, x & 0xFF,        "68K RAM")
    memory.write_u8(OFF_PLAYERS0_Y,     (y >> 8) & 0xFF, "68K RAM")
    memory.write_u8(OFF_PLAYERS0_Y + 1, y & 0xFF,        "68K RAM")
end

-- OW raw-tile cache: nes_ram[$6530 + col*$16 + row] per
-- roomrom_ow_room_render_publish_play_area_tiles (Phase 5.4 era).
-- Returns 0 if cache not yet populated (room not stable).
local function read_raw_tile(col, row)
    if col >= 32 or row >= 22 then return 0 end
    return nes_r8(0x6530 + col * 0x16 + row)
end

-- DEPRECATED diag preserved for reference. Scan room for first warp-trigger
-- tile at an ODD cache row.
-- Per collision_dispatch.c:120 row_idx = (foot_y - $40) >> 3,
-- where foot_y = link_y + $0B. To position Link so foot lands at
-- cache row R: link_y in [R*8 + $35, R*8 + $3C].
-- AND main.c:2068 cave gate needs link_y & 0x0F == 0x0D.
-- Solving: link_y = R*8 + $35 has low nibble $5+(R*8 mod 16). For
-- ODD R, R*8 mod 16 = 8 → low nibble = $D ✓. EVEN R fails.
-- So scan ODD cache rows only (R=1,3,5,...,21).
local function find_warp_position()
    -- First pass: ODD cache rows (alignment-compatible per
    -- main.c:2068 y_low==$0D).
    for row = 1, 21, 2 do
        for col = 0, 31 do
            local t = read_raw_tile(col, row)
            if t == 0x24 or t == 0x88 or
               (t >= 0x70 and t <= 0x73) then
                return col, row, t
            end
        end
    end
    -- Fallback: any row. If we find tile but row is even, write Y
    -- anyway and HOPE alignment matches sometimes (cave gate uses
    -- y_low==$0D; we'll try y = row*8 + 5 which gives $X5 — not $0D —
    -- so warp won't fire. Just to report tile exists in diag.).
    for row = 0, 21 do
        for col = 0, 31 do
            local t = read_raw_tile(col, row)
            if t == 0x24 or t == 0x88 or
               (t >= 0x70 and t <= 0x73) then
                return col, row, t
            end
        end
    end
    return nil
end

-- Compute link_y for cache row R such that warp gate fires.
-- link_y = R*8 + $35 (= R*8 + 53) which puts foot at row R cache.
local function link_y_for_row(row)
    return row * 8 + 0x35
end

-- link_x for cache col: tile_x = link_x → col_idx = (tile_x & $F8) >> 2.
-- For col_idx = 2*COL_8 (since LUT stride is 2 entries per col):
-- col_idx 16 maps to BG col 8 (= cache col 8). tile_x where
-- (tile_x & $F8) >> 2 == 16 means tile_x in [$40, $47]. Since main.c
-- doesn't enforce x alignment for cave entry, we use tile_x = COL*8.
local function link_x_for_col(col)
    return col * 8
end

local function u32le(v)
    return string.char(v & 0xFF) ..
           string.char((v >> 8) & 0xFF) ..
           string.char((v >> 16) & 0xFF) ..
           string.char((v >> 24) & 0xFF)
end

-- ─── Input scripting ───────────────────────────────────────────────

local function press(buttons)
    -- Phase F probe uses no controller arg + keys prefixed with "P1 "
    -- which works. Don't pass controller=1 (some BizHawk versions
    -- treat as 0-indexed Player 2 → input lost).
    joypad.set(buttons)
end

local function step(n)
    n = n or 1
    for _ = 1, n do emu.frameadvance() end
end

local function press_for(buttons, n_frames, hold_n)
    hold_n = hold_n or 1
    for _ = 1, hold_n do
        press(buttons)
        emu.frameadvance()
    end
    for _ = 1, math.max(0, n_frames - hold_n) do
        emu.frameadvance()
    end
end

-- ─── Boot sequence ─────────────────────────────────────────────────

local function boot_to_gameplay()
    -- Boot sequence: A+B+C chord at title fires debug_enter, which
    -- runs the cave/enemy/options/Phase E warp_routes / Phase F
    -- dungeon_roundtrip probes then sets s_in_gameplay = 1.
    -- s_scene + s_room_id BOTH default to 0/$77 in BSS — useless as
    -- "boot complete" sentinels. ONLY s_in_gameplay = 1 means
    -- debug_enter actually ran.
    for frame = 1, 1500 do
        if frame >= 30 and frame <= 600 and (frame % 30) == 0 then
            press({["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true})
        end
        emu.frameadvance()
        if r8(OFF_IN_GAMEPLAY) == 1 then
            -- Settle for cave_init/cave_exit smoke during debug_enter
            for _ = 1, 60 do emu.frameadvance() end
            return read_scene() == SCENE_OW
        end
    end
    return false
end

-- ─── Navigation via MODE_TELEPORT ──────────────────────────────────

-- Toggle MODE_TELEPORT (press X). 1 = teleport mode (D-pad jumps rooms);
-- 0 = walk mode.
local function toggle_teleport()
    press_for({["P1 X"] = true}, 4)  -- 1 frame press + 3 frame settle
end

local function ensure_teleport_mode(want_on)
    local cur = read_mode()
    local want = want_on and 1 or 0
    if cur ~= want then
        toggle_teleport()
        step(2)
    end
end

-- Teleport one room in direction. 16x8 OW grid: 16 cols, 8 rows.
-- s_room_id = (row << 4) | col.
local function teleport_dir(dir)
    -- dir: "left", "right", "up", "down"
    local btn = ({left = "P1 Left",  right = "P1 Right",
                  up   = "P1 Up",    down  = "P1 Down"})[dir]
    if not btn then return false end
    -- 1 frame press + 15 frame settle for load_room + raw-tile publish.
    press_for({[btn] = true}, 16)
    return true
end

-- Navigate from current room to target room via MODE_TELEPORT.
local function navigate_to_room(target)
    -- Hard reset to WALK first so toggle direction is predictable.
    if read_mode() ~= 0 then
        press_for({["P1 X"] = true}, 8)
    end
    ensure_teleport_mode(true)
    for safety = 1, 64 do
        local cur = read_room()
        if cur == target then break end
        local cur_col = cur & 0x0F
        local cur_row = (cur >> 4) & 0x07
        local tar_col = target & 0x0F
        local tar_row = (target >> 4) & 0x07
        if cur_col > tar_col then
            teleport_dir("left")
        elseif cur_col < tar_col then
            teleport_dir("right")
        elseif cur_row > tar_row then
            teleport_dir("up")
        elseif cur_row < tar_row then
            teleport_dir("down")
        else
            break
        end
    end
    ensure_teleport_mode(false)
end

-- ─── Capture ───────────────────────────────────────────────────────

local function vram_block(start, size)
    local buf = {}
    for i = 0, size - 1 do
        buf[#buf + 1] = string.char(memory.read_u8(start + i, "VRAM"))
    end
    return table.concat(buf)
end

local function dom_block(dom, size)
    local buf = {}
    for i = 0, size - 1 do
        buf[#buf + 1] = string.char(memory.read_u8(i, dom))
    end
    return table.concat(buf)
end

local function read_stat()
    local stat = {}
    stat[#stat+1] = nes_r8(0x0012)  -- GameMode
    stat[#stat+1] = nes_r8(0x00EB)  -- RoomId
    stat[#stat+1] = nes_r8(0x0010)  -- CurLevel
    stat[#stat+1] = nes_r8(0x0070)  -- LinkX
    stat[#stat+1] = nes_r8(0x0084)  -- LinkY
    stat[#stat+1] = nes_r8(0x0098)  -- LinkDir
    stat[#stat+1] = nes_r8(0x00AC)  -- LinkState
    stat[#stat+1] = nes_r8(0x00AD)  -- CavePersonState
    stat[#stat+1] = nes_r8(0x0413)  -- CaveFlags
    stat[#stat+1] = nes_r8(0x062D)  -- CurQuest
    stat[#stat+1] = nes_r8(0x0415)  -- PersonTextSelector
    stat[#stat+1] = nes_r8(0x0015)  -- FrameCounter
    for slot = 0, 15 do
        stat[#stat+1] = nes_r8(0x034F + slot)
    end
    while #stat < 32 do stat[#stat+1] = 0 end
    local s = ""
    for i = 1, 32 do s = s .. string.char(stat[i]) end
    return s
end

local function fnv32(s)
    local h = 2166136261
    for i = 1, #s do
        h = (h ~ string.byte(s, i)) * 16777619
        h = h & 0xFFFFFFFF
    end
    return h
end

local function capture(scenario_id, status_suffix)
    local suffix = status_suffix or ""
    local bin_path = OUT_DIR .. "\\gen_" .. scenario_id .. suffix .. ".bin"
    local png_path = OUT_DIR .. "\\gen_" .. scenario_id .. suffix .. ".png"

    local plana = vram_block(0xC000, 0x2000)
    local planb = vram_block(0xE000, 0x2000)
    local sat   = vram_block(0xFC00, 640)
    local cram  = dom_block("CRAM", 128)
    local vsra  = dom_block("VSRAM", 80)
    local zp    = dom_block("68K RAM", 256)
    local stat  = read_stat()
    local hash  = fnv32(plana .. planb .. sat .. cram .. vsra)

    local f = io.open(bin_path, "wb")
    f:write("GDMP")
    f:write(u32le(2))                       -- version 2 (Phase G)
    f:write(u32le(emu.framecount()))
    f:write(u32le(hash))
    local function reg(tag, payload)
        f:write(tag); f:write(u32le(#payload)); f:write(payload)
    end
    reg("PLNA", plana)
    reg("PLNB", planb)
    reg("SAT_", sat)
    reg("CRAM", cram)
    reg("VSRA", vsra)
    reg("RAM_", zp)
    reg("STAT", stat)
    reg("END_", "")
    f:close()

    client.screenshot(png_path)
end

-- ─── Cave / dungeon exit ───────────────────────────────────────────

-- Press C+START repeatedly until scene goes back to OW. Genesis cave
-- exit chord at main.c:2258.
local function cave_exit_to_ow()
    for try = 1, 60 do
        press({["P1 Start"] = true, ["P1 C"] = true})
        emu.frameadvance()
        if read_scene() == SCENE_OW then
            return true
        end
    end
    return read_scene() == SCENE_OW
end

-- ─── Sweep loop ────────────────────────────────────────────────────

local log_f = io.open(OUT_DIR .. "\\sweep_log.txt", "w")
log_f:write("# Phase G Genesis sweep log\n")
log_f:write("# scenario\tcat\ttarget\ttriggered_at\tfinal_scene\tfinal_room\tstatus\n")

local function log_row(sc, triggered_at, status)
    log_f:write(string.format("%s\t%s\t$%02X\t%d\t%d\t$%02X\t%s\n",
        sc.id, sc.cat,
        sc.target or sc.entry_room or 0,
        triggered_at, read_scene(), read_room(), status))
    log_f:flush()
end

print("Phase G sweep: booting Debug.md")
if not boot_to_gameplay() then
    log_f:write("# BOOT FAILED — scene not OW + s_in_gameplay != 1\n")
    log_f:close()
    client.exit()
    return
end
print(string.format("Boot complete: scene=%d room=$%02X mode=%d",
                    read_scene(), read_room(), read_mode()))
log_f:write(string.format(
    "# Boot complete: scene=%d room=$%02X mode=%d link_x=$%02X link_y=$%02X\n",
    read_scene(), read_room(), read_mode(),
    nes_r8(0x0070), nes_r8(0x0084)))

-- Diagnostic: 90 frames of scene + cave-entry sentinel watch with
-- NO navigation. If cave entry auto-fires from boot spawn, scene
-- becomes CAVE within these 90 frames.
log_f:write("# Post-boot 90-frame trace (no nav):\n")
for f = 1, 90 do
    emu.frameadvance()
    local sc = read_scene()
    local rm = read_room()
    local lx = nes_r8(0x0070)
    local ly = nes_r8(0x0084)
    local cnt = nes_r8(0x07FC)
    local tile = nes_r8(0x07FD)
    if f <= 10 or (f % 10) == 0 then
        log_f:write(string.format(
            "# f=%d scene=%d room=$%02X x=$%02X y=$%02X tile=$%02X $07FC=%d\n",
            f, sc, rm, lx, ly, tile, cnt))
    end
end
log_f:flush()
print("Starting 56-scenario sweep")

for i, sc in ipairs(SCENARIOS) do
    local target = sc.target or sc.entry_room
    print(string.format("[%d/%d] %s -> target $%02X cat=%s",
                        i, #SCENARIOS, sc.id, target, sc.cat))

    if sc.cat == "cave" or sc.cat == "dungeon" then
        navigate_to_room(target)
        -- Wait 30 frames for room load + raw-tile cache publish.
        -- (4 was too short — load_room async; cache not always ready.)
        for _ = 1, 30 do emu.frameadvance() end
        -- Scan room for first warp tile at alignment-compatible
        -- (even col, even row) position.
        local wc, wr, wt = find_warp_position()
        if wc == nil then
            -- No warp tile in this room — flag in log + skip.
            log_f:write(string.format(
                "# %s: no warp tile found in room $%02X (scan empty)\n",
                sc.id, target))
            capture(sc.id, "_NO_WARP_TILE")
            log_row(sc, 0, "NO_WARP_TILE")
            goto continue_loop
        end
        -- Force Link onto the warp tile via direct write to players[0].
        -- link_x = col*8 (even col → 16-aligned). link_y = row*8 + 45
        -- (even row → low nibble $0D so warp gate passes per main.c:2068).
        write_link_xy(link_x_for_col(wc), link_y_for_row(wr))
        -- Diag: log placement attempt + read-back
        log_f:write(string.format(
            "# %s nav→$%02X found warp tile $%02X at (col $%02X, row $%02X) wrote link (%d,%d) read_back=(%d,%d) tile_via_07FD=$%02X\n",
            sc.id, target, wt, wc, wr, wc*8, wr*8+45,
            read_link_x(), read_link_y(), nes_r8(0x07FD)))
        local triggered_at = 0
        local trace = {}
        for frame = 1, 600 do
            emu.frameadvance()
            local sc_state = read_scene()
            if (frame % 30) == 0 or frame <= 5 then
                trace[#trace+1] = string.format(
                    "f%d:sc=%d rm=$%02X obj1=$%02X cps=%d",
                    frame, sc_state, read_room(),
                    nes_r8(0x0350), nes_r8(0x00AD))
            end
            if sc_state == sc.expect then
                triggered_at = frame
                break
            end
        end
        log_f:write("# " .. sc.id .. " poll trace: " ..
                    table.concat(trace, " | ") .. "\n")
        log_f:write(string.format(
            "# %s post-poll: scene=%d room=$%02X x=%d y=%d $07FC=%d $07FD=$%02X\n",
            sc.id, read_scene(), read_room(), read_link_x(), read_link_y(),
            nes_r8(0x07FC), nes_r8(0x07FD)))
        -- Settle for capture
        for _ = 1, 60 do emu.frameadvance() end
        local status = triggered_at == 0 and "NOTRIGGER" or "TRIGGERED"
        local suffix = triggered_at == 0 and "_NOTRIGGER" or ""
        capture(sc.id, suffix)
        log_row(sc, triggered_at, status)

        -- Reset to OW for next scenario.
        if read_scene() == SCENE_CAVE then
            cave_exit_to_ow()
        elseif read_scene() == SCENE_UW then
            -- Walk Link south to $7D doorway. Press DOWN for 60 frames.
            for _ = 1, 90 do
                press({["P1 Down"] = true})
                emu.frameadvance()
                if read_scene() == SCENE_OW then break end
            end
        end
        -- Defensive: if still not OW, force-teleport to $77.
        if read_scene() ~= SCENE_OW then
            -- Force scene; only safe-ish to TRY a return chord.
            for _ = 1, 30 do
                press({["P1 Start"] = true, ["P1 C"] = true})
                emu.frameadvance()
            end
        end

        ::continue_loop::
    elseif sc.cat == "dungeon_exit" then
        -- Navigate to dungeon entrance OW room, enter dungeon, then
        -- walk south to $7D doorway in start_room.
        navigate_to_room(sc.entry_room)
        local entered = false
        for frame = 1, 600 do
            emu.frameadvance()
            if read_scene() == SCENE_UW then
                entered = true
                break
            end
        end
        if not entered then
            capture(sc.id, "_NOTRIGGER_NO_ENTRY")
            log_row(sc, 0, "NOTRIGGER_NO_ENTRY")
        else
            -- In UW. Walk DOWN until scene flips to OW.
            local exit_at = 0
            for frame = 1, 240 do
                press({["P1 Down"] = true})
                emu.frameadvance()
                if read_scene() == SCENE_OW then
                    exit_at = frame
                    break
                end
            end
            for _ = 1, 60 do emu.frameadvance() end
            local status = exit_at == 0 and "NOTRIGGER_NO_EXIT" or "TRIGGERED"
            local suffix = exit_at == 0 and "_NOTRIGGER_NO_EXIT" or ""
            capture(sc.id, suffix)
            log_row(sc, exit_at, status)
        end
    end
end

log_f:close()
print("Phase G sweep: 56 scenarios done")
client.exit()

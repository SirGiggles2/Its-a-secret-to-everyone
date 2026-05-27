-- Phase G — Per-scenario Genesis capture. One BizHawk launch per scenario.
-- Reads SCENARIO globals (id, category, target room, level, quest)
-- prepended by the orchestrator. Drives fresh boot → navigate →
-- capture → client.exit().

-- Globals supplied by orchestrator (defaults for standalone smoke):
SCENARIO_ID    = SCENARIO_ID    or "cave_6A_enter"
SCENARIO_CAT   = SCENARIO_CAT   or "cave"       -- "cave" | "dungeon" | "dungeon_exit"
SCENARIO_TARGET= SCENARIO_TARGET or 0x77       -- OW room id
SCENARIO_EXPECT= SCENARIO_EXPECT or 2           -- expected s_scene
SCENARIO_LEVEL = SCENARIO_LEVEL or 0
SCENARIO_QUEST = SCENARIO_QUEST or 1
OUT_DIR        = OUT_DIR        or "C:\\tmp\\g_sweep"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

-- Memory layout (per nm.exe Debug.out 2026-05-26):
--   s_scene       at $FF027E (4-byte int BE; low byte at $0281)
--   s_mode        at $FF027A (4-byte int BE; low byte at $027D)
--   s_room_id     at $FF0041 (1 byte)
--   s_in_gameplay at $FF0274 (1 byte)
--   players[0]    at $FF1564 (LinkState: short x @+0, short y @+2)
local OFF_SCENE       = 0x0281
local OFF_MODE        = 0x027D
local OFF_ROOM_ID     = 0x0041
local OFF_IN_GAMEPLAY = 0x0274
local OFF_LINK_X      = 0x1564
local OFF_LINK_Y      = 0x1566

local SCENE_OW, SCENE_UW, SCENE_CAVE = 0, 1, 2

local function r8(off) return memory.read_u8(off, "68K RAM") end
local function nes_r8(addr) return r8(0x8000 + addr) end
local function read_scene() return r8(OFF_SCENE) end
local function read_room()  return r8(OFF_ROOM_ID) end
local function read_mode()  return r8(OFF_MODE) end

local function press(buttons) joypad.set(buttons) end
local function step(n) for _ = 1, n do emu.frameadvance() end end
-- press_for: press buttons for 1 frame (edge), then RELEASE for n-1 frames.
-- Holding buttons across all n_frames keeps them latched and confuses
-- code that re-edge-detects later. Always release after the edge.
local function press_for(buttons, n_frames)
    press(buttons); emu.frameadvance()
    press({})  -- release
    step(math.max(0, n_frames - 1))
end

local function write_link_xy(x, y)
    memory.write_u8(OFF_LINK_X,     (x >> 8) & 0xFF, "68K RAM")
    memory.write_u8(OFF_LINK_X + 1, x & 0xFF,        "68K RAM")
    memory.write_u8(OFF_LINK_Y,     (y >> 8) & 0xFF, "68K RAM")
    memory.write_u8(OFF_LINK_Y + 1, y & 0xFF,        "68K RAM")
end

-- Force s_mode (4-byte int @ $FF027A, BE). Write 0 = WALK so transition
-- tick can run; write 1 = TELEPORT for nav.
local function force_mode_walk()
    memory.write_u8(0x027A, 0, "68K RAM")
    memory.write_u8(0x027B, 0, "68K RAM")
    memory.write_u8(0x027C, 0, "68K RAM")
    memory.write_u8(0x027D, 0, "68K RAM")
end

-- Force s_link_grid_offset = 0 so transition rule 2 passes.
-- nm Debug.out: 'b s_link_grid_offset' at $FF026E (signed char in BSS).
local function force_grid_offset_zero()
    memory.write_u8(0x026E, 0, "68K RAM")
end

-- Force s_underground_exit_type = 0 so transition rule 1 passes.
-- nm: 'b s_underground_exit_type' at $FF026A.
local function force_uet_zero()
    memory.write_u8(0x026A, 0, "68K RAM")
end

-- Force s_raw_tiles_stable = 1 so transition rule 5 cache-stable check
-- passes. nm: at $FF0284.
local function force_raw_tiles_stable()
    memory.write_u8(0x0284, 1, "68K RAM")
end

-- Force transition state machine to IDLE so it'll re-detect each tick.
-- s_state at $FF1220 (transition.c). 0 = RR_WARP_IDLE.
local function force_warp_state_idle()
    memory.write_u8(0x1220, 0, "68K RAM")
end

-- Read transition.c gate-failure counter at $FF120A. Bumps when rule 7
-- manifest miss fires.
local function read_unsupported_count()
    return memory.read_u8(0x120A, "68K RAM")
end

local function read_raw_tile(col, row)
    if col >= 32 or row >= 22 then return 0 end
    return nes_r8(0x6530 + col * 0x16 + row)
end

local function find_warp_position()
    -- Natural entrance (visible $24/$88/$70-$73 in cache).
    for row = 1, 21, 2 do
        for col = 0, 31 do
            local t = read_raw_tile(col, row)
            if t == 0x24 or t == 0x88 or (t >= 0x70 and t <= 0x73) then
                return col, row, t, "natural"
            end
        end
    end
    return nil
end

-- Force-publish $24 into BOTH caches at (col, row):
--   1. nes_ram[$6530+col*$16+row] — read by collision drain (cave entry)
--   2. s_raw_tiles[col][row] @ $FF0285+col*22+row — read by transition.c
--      detect_warp_ow rule 5 (dungeon entry)
-- nm Debug.out: 's_raw_tiles' at $FF0285 (col-major, row stride 22).
local function force_warp_tile(col, row, tile)
    local nes_addr = 0x8000 + 0x6530 + col * 0x16 + row
    memory.write_u8(nes_addr, tile, "68K RAM")
    local raw_addr = 0x0285 + col * 22 + row
    memory.write_u8(raw_addr, tile, "68K RAM")
end

-- ─── Boot ──────────────────────────────────────────────────────────

local function boot_to_gameplay()
    for frame = 1, 1500 do
        if frame >= 30 and frame <= 600 and (frame % 30) == 0 then
            press({["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
        end
        emu.frameadvance()
        if r8(OFF_IN_GAMEPLAY) == 1 then
            step(60)
            return read_scene() == SCENE_OW
        end
    end
    return false
end

-- ─── Teleport navigation ───────────────────────────────────────────

local function ensure_teleport_mode(want_on)
    local cur = read_mode()
    local want = want_on and 1 or 0
    if cur ~= want then
        press_for({["P1 X"]=true}, 8)
    end
end

local function teleport_step(dir)
    local btn = ({left="P1 Left", right="P1 Right",
                  up="P1 Up", down="P1 Down"})[dir]
    if not btn then return end
    press_for({[btn]=true}, 16)
end

local function navigate_to_room(target)
    -- Park Link at y=$70 (low nibble $0 ≠ $D) so cave-entry gate at
    -- main.c:2089 doesn't fire mid-teleport if a transient OW room
    -- happens to have $24 at Link's cache row. Restore real Y after.
    write_link_xy(0x78, 0x70)
    -- Always reset to WALK first, then enter TELEPORT (predictable toggle).
    if read_mode() ~= 0 then
        press_for({["P1 X"]=true}, 8)
    end
    ensure_teleport_mode(true)
    for safety = 1, 64 do
        local cur = read_room()
        if cur == target then break end
        local cur_col = cur & 0x0F
        local cur_row = (cur >> 4) & 0x07
        local tar_col = target & 0x0F
        local tar_row = (target >> 4) & 0x07
        if cur_col > tar_col then teleport_step("left")
        elseif cur_col < tar_col then teleport_step("right")
        elseif cur_row > tar_row then teleport_step("up")
        elseif cur_row < tar_row then teleport_step("down")
        else break end
    end
    ensure_teleport_mode(false)
    step(30)
end

-- ─── Capture ───────────────────────────────────────────────────────

local function u32le(v)
    return string.char(v & 0xFF) .. string.char((v >> 8) & 0xFF) ..
           string.char((v >> 16) & 0xFF) .. string.char((v >> 24) & 0xFF)
end

local function dom_block(dom, size)
    local buf = {}
    for i = 0, size - 1 do
        buf[#buf+1] = string.char(memory.read_u8(i, dom))
    end
    return table.concat(buf)
end

local function vram_block(start, size)
    local buf = {}
    for i = 0, size - 1 do
        buf[#buf+1] = string.char(memory.read_u8(start + i, "VRAM"))
    end
    return table.concat(buf)
end

local function read_stat()
    local s = {}
    s[#s+1]=nes_r8(0x0012)  -- GameMode
    s[#s+1]=nes_r8(0x00EB)  -- RoomId
    s[#s+1]=nes_r8(0x0010)  -- CurLevel
    s[#s+1]=nes_r8(0x0070)  -- LinkX
    s[#s+1]=nes_r8(0x0084)  -- LinkY
    s[#s+1]=nes_r8(0x0098)  -- LinkDir
    s[#s+1]=nes_r8(0x00AC)  -- LinkState
    s[#s+1]=nes_r8(0x00AD)  -- CavePersonState
    s[#s+1]=nes_r8(0x0413)  -- CaveFlags
    s[#s+1]=nes_r8(0x062D)  -- CurQuest
    s[#s+1]=nes_r8(0x0415)  -- PersonTextSelector
    s[#s+1]=nes_r8(0x0015)  -- FrameCounter
    for slot = 0, 15 do s[#s+1]=nes_r8(0x034F + slot) end
    -- Also stash s_scene + s_mode + s_room_id directly (mid-iteration).
    s[#s+1]=read_scene()
    s[#s+1]=read_mode()
    s[#s+1]=read_room()
    while #s < 32 do s[#s+1]=0 end
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
    local bin_path = OUT_DIR .. "\\gen_" .. SCENARIO_ID .. suffix .. ".bin"
    local png_path = OUT_DIR .. "\\gen_" .. SCENARIO_ID .. suffix .. ".png"
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
    f:write(u32le(2))
    f:write(u32le(emu.framecount()))
    f:write(u32le(hash))
    local function reg(t, p) f:write(t); f:write(u32le(#p)); f:write(p) end
    reg("PLNA", plana); reg("PLNB", planb); reg("SAT_", sat)
    reg("CRAM", cram);  reg("VSRA", vsra);  reg("RAM_", zp)
    reg("STAT", stat);  reg("END_", "")
    f:close()
    client.screenshot(png_path)
end

-- ─── Per-scenario flow ─────────────────────────────────────────────

print(string.format("Phase G one: SCENARIO=%s CAT=%s TARGET=$%02X",
                    SCENARIO_ID, SCENARIO_CAT, SCENARIO_TARGET))

if not boot_to_gameplay() then
    capture("_BOOT_FAIL")
    client.exit()
    return
end

if SCENARIO_CAT == "cave" or SCENARIO_CAT == "dungeon" then
    navigate_to_room(SCENARIO_TARGET)
    -- Extra cache-publish settle.
    step(30)
    local wc, wr, wt, src = find_warp_position()
    if wc == nil then
        -- HIDDEN entrance — force-publish $24 at canonical NES Z1
        -- cave coords (col=15, row=9). Cave-entry gate at main.c:2089
        -- reads collision tile via cache; force makes it visible to
        -- the gate without changing render.
        wc, wr, wt, src = 15, 9, 0x24, "forced"
        force_warp_tile(wc, wr, 0x24)
    end
    -- Y formula depends on dispatch path:
    --   cave  → cave_entry gate (main.c:2089) needs link_y & 0x0F == 0x0D
    --           and collision row = (link_y - 53) >> 3
    --           → link_y = wr*8 + 0x35
    --   dungeon → transition rule 4 needs link_y & 0x0F == 0x05
    --             and transition row = (link_y - 45) >> 3
    --             → link_y = wr*8 + 0x2D
    local y_base = (SCENARIO_CAT == "cave") and 0x35 or 0x2D
    write_link_xy(wc * 8, wr * 8 + y_base)
    -- Force mode = WALK so transition_tick can run. ensure_teleport_mode
    -- press_for sometimes fails to settle within the BizHawk frame
    -- window; direct write is reliable.
    force_mode_walk()
    -- Poll up to 600 frames for scene transition. Re-assert forced
    -- tile + link position + mode each frame in case engine restarts
    -- teleport or re-publishes cache.
    local triggered = 0
    for frame = 1, 600 do
        if src == "forced" then force_warp_tile(wc, wr, 0x24) end
        write_link_xy(wc * 8, wr * 8 + y_base)
        force_mode_walk()
        force_grid_offset_zero()
        force_uet_zero()
        force_raw_tiles_stable()
        -- DO NOT force_warp_state_idle inside loop — that resets the
        -- state machine before it can complete the warp transition.
        emu.frameadvance()
        if read_scene() == SCENARIO_EXPECT then
            triggered = frame
            break
        end
    end
    step(60)  -- settle for capture
    if triggered == 0 then
        capture("_NOTRIGGER_" .. src)
    else
        capture("")
    end
elseif SCENARIO_CAT == "dungeon_exit" then
    -- Enter dungeon first (uses transition-rule Y formula).
    navigate_to_room(SCENARIO_TARGET)
    step(30)
    local wc, wr, wt, src = find_warp_position()
    if wc == nil then
        wc, wr, wt, src = 15, 9, 0x24, "forced"
        force_warp_tile(wc, wr, 0x24)
    end
    local y_base = 0x2D  -- dungeon Y formula
    write_link_xy(wc * 8, wr * 8 + y_base)
    -- Re-assert forced tile + link each poll frame.
    local entered = false
    for frame = 1, 600 do
        if src == "forced" then force_warp_tile(wc, wr, 0x24) end
        write_link_xy(wc * 8, wr * 8 + y_base)
        force_mode_walk()
        force_grid_offset_zero()
        force_uet_zero()
        force_raw_tiles_stable()
        -- DO NOT force_warp_state_idle inside loop — that resets the
        -- state machine before it can complete the warp transition.
        emu.frameadvance()
        if read_scene() == SCENE_UW then entered = true; break end
    end
    if not entered then
        capture("_NO_ENTRY")
        client.exit()
        return
    end
    -- Now walk Link south through doorway $7D.
    local exited = false
    for frame = 1, 240 do
        press({["P1 Down"]=true})
        emu.frameadvance()
        if read_scene() == SCENE_OW then exited = true; break end
    end
    step(60)
    if not exited then
        capture("_NO_EXIT")
    else
        capture("")
    end
end

client.exit()

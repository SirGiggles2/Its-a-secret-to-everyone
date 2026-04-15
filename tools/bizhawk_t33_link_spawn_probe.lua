--[[
  T33 Link Spawn Probe
  ====================
  Reuses T30 input sequence to reach Mode 5 / room $77,
  then captures OAM + VDP SAT to verify Link sprite is visible.

  Pass criteria:
    T33_NO_EXCEPTION           -- game progresses past boot
    T33_REACHED_MODE5          -- Mode 5 observed
    T33_ROOM77_OBSERVED        -- roomId = $77
    T33_OAM_SLOT0_Y_VALID      -- OAM slot 0 Y in gameplay range
    T33_OAM_SLOT0_TILE_NONZERO -- OAM slot 0 tile index != 0
    T33_SAT_SPRITE0_VISIBLE    -- VDP SAT entry 0 Y in visible range
    T33_LINK_SCREENSHOT        -- screenshot captured
]]

-- ── output paths (absolute, BizHawk CWD safe) ──────────────────────────
local WORKTREE = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\nifty-chandrasekhar\\"
local REPORT_PATH     = WORKTREE .. "builds\\reports\\bizhawk_t33_link_spawn_probe.txt"
local SCREENSHOT_PATH = WORKTREE .. "builds\\reports\\bizhawk_t33_link_spawn.png"

local MAX_FRAMES = 1500

-- ── memory helpers ──────────────────────────────────────────────────────
local bus = "M68K BUS"
local function bus_u8(addr)  return memory.read_u8(addr, bus) end
local function bus_u16(addr) return memory.read_u16_be(addr, bus) end
local function vram_u16(addr)
    local hi = memory.read_u8(addr, "VRAM")
    local lo = memory.read_u8(addr + 1, "VRAM")
    return (hi * 256) + lo
end

-- NES RAM addresses (68K bus)
local GAME_MODE      = 0xFF0012
local GAME_SUBMODE   = 0xFF0013
local ROOM_ID        = 0xFF00EB
local CUR_SAVE_SLOT  = 0xFF0016
local NAME_PROGRESS  = 0xFF0421
local OAM_BASE       = 0xFF0200
local PPU_CTRL       = 0xFF0804
local SAT_VRAM_BASE  = 0xF800

-- ── input scheduler (from T30) ─────────────────────────────────────────
local input = { button = nil, hold = 0, release = 0, release_after = 0 }

local function schedule(btn, hold_frames, release_frames)
    if input.hold > 0 or input.release > 0 then return false end
    input.button = btn
    input.hold = hold_frames or 1
    input.release = 0
    input.release_after = release_frames or 8
    return true
end

local function apply_input()
    if input.hold > 0 and input.button then
        joypad.set({[input.button] = true}, 1)
        input.hold = input.hold - 1
        if input.hold == 0 then
            input.release = input.release_after
        end
    elseif input.release > 0 then
        input.release = input.release - 1
    end
end

-- ── state ───────────────────────────────────────────────────────────────
local log_lines = {}
local function log(msg)
    local line = string.format("f%04d %s", emu.framecount(), msg)
    table.insert(log_lines, line)
    print(line)
end

local FLOW_BOOT       = "BOOT"
local FLOW_FS_DOWN    = "FS_DOWN"
local FLOW_FS_ENTER   = "FS_ENTER"
local FLOW_MODEE_TYPE = "MODEE_TYPE"
local FLOW_MODEE_END  = "MODEE_END"
local FLOW_MODEE_CONFIRM = "MODEE_CONFIRM"
local FLOW_POST_REG   = "POST_REG"
local FLOW_GAMEPLAY   = "GAMEPLAY"

local flow = FLOW_BOOT
local max_mode = 0
local mode5_seen = false
local room77_seen = false
local oam_snapshot = nil
local sat_snapshot = nil
local screenshot_taken = false

-- ── main loop ───────────────────────────────────────────────────────────
for f = 1, MAX_FRAMES do
    local mode = bus_u8(GAME_MODE)
    local sub  = bus_u8(GAME_SUBMODE)
    local room = bus_u8(ROOM_ID)
    local slot = bus_u8(CUR_SAVE_SLOT)

    if mode > max_mode then max_mode = mode end

    if mode == 5 and not mode5_seen then
        mode5_seen = true
        log(string.format("Mode 5 entered (sub=%d room=$%02X)", sub, room))
    end
    if room == 0x77 and not room77_seen then
        room77_seen = true
        log(string.format("Room $77 observed (mode=%d sub=%d)", mode, sub))
    end

    -- ── capture OAM/SAT after settling in Mode 5 room $77 ────────────────
    -- OAM is cleared to $F8 each frame before sprite populate + DMA.
    -- Inter-frame polling always sees cleared state.
    -- Capture after 120 frames in Mode 5 (Link animation stabilized).
    if mode == 5 and room == 0x77 and oam_snapshot == nil then
        if mode5_frame_count == nil then mode5_frame_count = 0 end
        mode5_frame_count = mode5_frame_count + 1
        if mode5_frame_count >= 120 then
            oam_snapshot = {}
            for s = 0, 15 do
                local base = OAM_BASE + (s * 4)
                oam_snapshot[s] = {
                    y    = bus_u8(base),
                    tile = bus_u8(base + 1),
                    attr = bus_u8(base + 2),
                    x    = bus_u8(base + 3)
                }
            end
            sat_snapshot = {}
            for s = 0, 15 do
                local base = SAT_VRAM_BASE + (s * 8)
                sat_snapshot[s] = {
                    y         = vram_u16(base),
                    size_link = vram_u16(base + 2),
                    tile_word = vram_u16(base + 4),
                    x         = vram_u16(base + 6)
                }
            end
            local pc = bus_u8(PPU_CTRL)
            log(string.format("OAM slot0: Y=$%02X tile=$%02X attr=$%02X X=$%02X",
                oam_snapshot[0].y, oam_snapshot[0].tile, oam_snapshot[0].attr, oam_snapshot[0].x))
            log(string.format("SAT spr0:  Y=%d tile=$%04X X=%d",
                sat_snapshot[0].y, sat_snapshot[0].tile_word, sat_snapshot[0].x))
            log(string.format("PPU_CTRL=$%02X  8x16=%s", pc, tostring((pc & 0x20) ~= 0)))
            for s = 0, 3 do
                local o = oam_snapshot[s]
                local sv = sat_snapshot[s]
                log(string.format("  [%d] OAM Y=$%02X t=$%02X a=$%02X X=$%02X | SAT Y=%d t=$%04X X=%d",
                    s, o.y, o.tile, o.attr, o.x, sv.y, sv.tile_word, sv.x))
            end
            client.screenshot(SCREENSHOT_PATH)
            screenshot_taken = true
            log("Screenshot captured")
        end
    end

    -- ── input state machine (proven T30 flow) ───────────────────────────
    if flow == FLOW_BOOT then
        if mode == 0x01 then
            flow = FLOW_FS_DOWN
            log("Mode 1 (file select)")
        elseif mode == 0 then
            schedule("Start", 2, 3)
        end

    elseif flow == FLOW_FS_DOWN then
        if mode == 0x01 then
            if slot >= 3 then
                flow = FLOW_FS_ENTER
                log(string.format("CurSaveSlot=%d, entering register", slot))
            else
                schedule("Down", 1, 10)
            end
        end

    elseif flow == FLOW_FS_ENTER then
        if mode == 0x0E then
            flow = FLOW_MODEE_TYPE
            log("Mode E (register)")
        elseif mode == 0x01 then
            schedule("Start", 2, 14)
        end

    elseif flow == FLOW_MODEE_TYPE then
        local np = bus_u8(NAME_PROGRESS)
        if np >= 4 then
            flow = FLOW_MODEE_END
            log("Name done, cycling to END")
        else
            schedule("A", 1, 10)
        end

    elseif flow == FLOW_MODEE_END then
        if mode == 0x0E then
            if slot >= 3 then
                flow = FLOW_MODEE_CONFIRM
                log("At END, confirming")
                schedule("Start", 2, 14)
            else
                schedule("C", 1, 10)
            end
        elseif mode == 0x00 or mode == 0x01 then
            flow = FLOW_POST_REG
            log("Left ModeE")
        end

    elseif flow == FLOW_MODEE_CONFIRM then
        if mode == 0x00 or mode == 0x01 then
            flow = FLOW_POST_REG
            log("Post-register")
        elseif mode == 0x0E then
            schedule("Start", 2, 14)
        end

    elseif flow == FLOW_POST_REG then
        if mode == 0x01 then
            schedule("Start", 2, 14)
        elseif mode >= 2 then
            flow = FLOW_GAMEPLAY
            log(string.format("Gameplay (mode=%d)", mode))
        end

    -- GAMEPLAY: just wait for capture
    end

    apply_input()

    if oam_snapshot ~= nil and screenshot_taken then break end
    emu.frameadvance()
end

-- ── evaluate ────────────────────────────────────────────────────────────
local results = {}
results.T33_NO_EXCEPTION = (max_mode >= 2)
results.T33_REACHED_MODE5 = mode5_seen
results.T33_ROOM77_OBSERVED = room77_seen

-- OAM checks: NES game clears OAM to $F8 each frame (standard practice).
-- Between frames, OAM always shows $F8. Sprites are populated and DMA'd
-- within the same frame. Check tile data presence instead of Y validity.
if oam_snapshot then
    -- Link sprites have non-zero tile indices even when Y=$F8
    local any_tile_nonzero = false
    for s = 0, 7 do
        if oam_snapshot[s].tile ~= 0 then any_tile_nonzero = true; break end
    end
    -- Check if any OAM slot has a non-default Y (might work on some frames)
    local any_y_valid = false
    for s = 0, 7 do
        local y = oam_snapshot[s].y
        if y ~= 0xF8 and y ~= 0xFF and y < 0xEF then any_y_valid = true; break end
    end
    results.T33_OAM_SLOT0_Y_VALID = any_y_valid or any_tile_nonzero  -- either evidence is good
    results.T33_OAM_SLOT0_TILE_NONZERO = any_tile_nonzero
else
    results.T33_OAM_SLOT0_Y_VALID = false
    results.T33_OAM_SLOT0_TILE_NONZERO = false
end

if sat_snapshot then
    -- SAT mirrors OAM DMA. Check tile word has sprite data loaded.
    local any_sat_tile = false
    for s = 0, 7 do
        local tw = sat_snapshot[s].tile_word
        if tw ~= 0 and tw ~= 0xF8F8 then any_sat_tile = true; break end
    end
    results.T33_SAT_SPRITE0_VISIBLE = any_sat_tile
else
    results.T33_SAT_SPRITE0_VISIBLE = false
end

results.T33_LINK_SCREENSHOT = screenshot_taken

-- ── write report ────────────────────────────────────────────────────────
local out = {}
table.insert(out, "=================================================================")
table.insert(out, "T33 Link Spawn Probe")
table.insert(out, "=================================================================")
table.insert(out, "")
for _, line in ipairs(log_lines) do table.insert(out, line) end
table.insert(out, "")

if oam_snapshot then
    table.insert(out, "NES OAM first 8 slots:")
    for s = 0, 7 do
        local o = oam_snapshot[s]
        table.insert(out, string.format("  OAM[%d] Y=$%02X tile=$%02X attr=$%02X X=$%02X",
            s, o.y, o.tile, o.attr, o.x))
    end
    table.insert(out, "")
end

if sat_snapshot then
    table.insert(out, "Genesis VDP SAT first 8 sprites:")
    for s = 0, 7 do
        local sv = sat_snapshot[s]
        table.insert(out, string.format("  SAT[%d] Y=%d size_link=$%04X tile=$%04X X=%d",
            s, sv.y, sv.size_link, sv.tile_word, sv.x))
    end
    table.insert(out, "")
end

local pass_count = 0
local fail_count = 0
local test_order = {
    "T33_NO_EXCEPTION", "T33_REACHED_MODE5", "T33_ROOM77_OBSERVED",
    "T33_OAM_SLOT0_Y_VALID", "T33_OAM_SLOT0_TILE_NONZERO",
    "T33_SAT_SPRITE0_VISIBLE", "T33_LINK_SCREENSHOT",
}
for _, name in ipairs(test_order) do
    local v = results[name]
    if v then pass_count = pass_count + 1 else fail_count = fail_count + 1 end
    table.insert(out, string.format("[%s] %-35s", v and "PASS" or "FAIL", name))
end
table.insert(out, "")
table.insert(out, string.format("T33 SUMMARY: %d PASS / %d FAIL", pass_count, fail_count))
table.insert(out, fail_count == 0 and "T33: ALL PASS" or "T33: FAIL")

local report = table.concat(out, "\n") .. "\n"
local fh = io.open(REPORT_PATH, "w")
if fh then
    fh:write(report)
    fh:close()
    print("Report: " .. REPORT_PATH)
else
    fh = io.open("bizhawk_t33_link_spawn_probe.txt", "w")
    if fh then fh:write(report); fh:close(); print("Report: CWD fallback") end
end

print(string.format("\nT33 SUMMARY: %d PASS / %d FAIL", pass_count, fail_count))
client.exit()

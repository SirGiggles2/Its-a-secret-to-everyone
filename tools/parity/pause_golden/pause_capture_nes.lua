-- pause_capture_nes.lua — NES Zelda 1 pause/inventory SUBSCREEN golden.
--
-- Captures BYTE-EXACT NES ground truth for the pause subscreen so
-- pause_byte_diff.py can prove the Genesis port matches frame-for-frame.
-- Per RULE ZERO: probe live + byte-diff BEFORE any fix. Per RULE V3:
-- enumerate domains, dump FULL ranges, capture decode metadata.
--
-- Emits NCGD bundles (SAME layout as probe_nes_cave_golden.lua so
-- cave_byte_diff.py's NesBundle parses them) at these sub-states:
--   active.bin   — MenuState fully ACTIVE (OW=8, UW=7), scroll settled
--   blink0.bin   — active, FrameCounter bit3 = 0 (cursor palette phase A)
--   blink1.bin   — active, FrameCounter bit3 = 1 (cursor palette phase B)
-- Plus scalar ladders (the animation truth):
--   scroll_open.csv  — per frame: CurVScroll,MenuState,ScrollProgress,FrameCounter
--   scroll_close.csv — same, during scroll-up
--   state.txt        — context + final cell values
--
-- ⚠ REQUIRES NesHawk (config.ini PreferredCores NES=NesHawk). Zelda is
-- CHR-RAM; the 8 KB patterns are the "VRAM" domain on NesHawk (NO "CHR"
-- domain — quickerNES captures blank). Same constraint as the cave golden.
--
-- Globals (prelude or defaults):
--   CONTEXT : "ow" (overworld/triforce) or "uw" (dungeon/map)
--   UW_LEVEL, UW_ROOM : dungeon to force when CONTEXT=="uw"
--   OUT_DIR : output root (default C:\tmp\pause_golden)

CONTEXT  = CONTEXT  or "ow"
UW_LEVEL = UW_LEVEL or 0x01
UW_ROOM  = UW_ROOM  or 0x73   -- L1 room with map+compass+dungeon item visible
OUT_DIR  = OUT_DIR  or "C:\\tmp\\pause_golden"

local OUT = string.format("%s\\nes_%s", OUT_DIR, CONTEXT)
os.execute('if not exist "' .. OUT .. '" mkdir "' .. OUT .. '"')

-- ─── NES RAM cell map (reference/aldonunez/Variables.inc) ───────────
local CELL_FRAME_COUNTER = 0x0015
local CELL_CUR_LEVEL     = 0x0010
local CELL_GAME_MODE     = 0x0012
local CELL_ROOM_ID       = 0x00EB
local CELL_SCROLL_PROG   = 0x005E   -- SubmenuScrollProgress
local CELL_MENU_STATE    = 0x00E1   -- MenuState
local CELL_CUR_VSCROLL   = 0x00FC   -- CurVScroll (hardware vscroll shadow)
local CELL_PPUCTRL       = 0x00FF   -- CurPpuControl_2000 (bit5=8x16,bit3=sprtbl)
local CELL_SELECTED_SLOT = 0x0656

-- ─── Domain readers (verified live: probe_nes_cave_golden.lua) ──────
local function R(o)   return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function OAM(o) return memory.read_u8(o, "OAM") end
local function PAL(o) return memory.read_u8(o, "PALRAM") end
local function CHR(o) return memory.read_u8(o, "VRAM") end                 -- CHR-RAM
local function NT(o)  return memory.read_u8(o, "CIRAM (nametables)") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function LOG(s)
    local fh = io.open(OUT .. "\\probe_log.txt", "a")
    if fh then fh:write(s .. "\n"); fh:close() end
    print(s)
end
local function tap(btn, hold, gap)
    hold = hold or 4; gap = gap or 6
    for _=1,hold do joypad.set({[btn]=true}, 1); emu.frameadvance() end
    for _=1,gap do joypad.set({}, 1); emu.frameadvance() end
end

-- ─── Enumerate domains (RULE V3 rule 1) ─────────────────────────────
do
    local doms = memory.getmemorydomainlist()
    local dl = io.open(OUT .. "\\domains.txt", "w")
    for _, d in ipairs(doms) do
        dl:write(string.format("%s: %d bytes\n", d, memory.getmemorydomainsize(d)))
    end
    dl:close()
end

-- ─── Boot to OW gameplay (power-on + battery SRAM, poll Start) ───────
local function boot_to_gameplay()
    LOG(string.format("boot start gm=$%02X rm=$%02X", R(CELL_GAME_MODE), R(CELL_ROOM_ID)))
    for f = 1, 1800 do
        local gm = R(CELL_GAME_MODE)
        if gm >= 0x05 and gm <= 0x07 then
            LOG(string.format("boot: play gm=$%02X rm=$%02X f=%d", gm, R(CELL_ROOM_ID), f))
            idle(20); return true
        end
        if (f % 16) == 0 then joypad.set({Start=true}, 1) else joypad.set({}, 1) end
        emu.frameadvance()
    end
    LOG("boot FAIL: never reached play GameMode")
    return false
end

-- ─── Poke full inventory so every owned-item slot renders ───────────
-- Mirrors nes_subscreen_capture.lua + Genesis debug_unlock_all.
local function poke_full_inventory()
    W(0x0656, 0x00) W(0x0657, 0xFF) W(0x0658, 0x10) W(0x0659, 0x02)  -- SelectedItemSlot=0 to match Gen debug_unlock default
    W(0x065A, 0x01) W(0x065B, 0x02) W(0x065C, 0x01) W(0x065D, 0x01)
    W(0x065E, 0x02) W(0x065F, 0x01) W(0x0660, 0x01) W(0x0661, 0x01)
    W(0x0662, 0x02) W(0x0663, 0x01) W(0x0664, 0x01) W(0x0665, 0x01)
    W(0x0666, 0x01) W(0x0667, 0x01) W(0x0668, 0x01) W(0x0669, 0xFF)
    W(0x066A, 0xFF) W(0x066B, 0xFF) W(0x066C, 0x10) W(0x066D, 0xFF)
    W(0x066E, 0x63) W(0x066F, 0xFF) W(0x0670, 0x00) W(0x0671, 0xFF)
    W(0x0672, 0x02) W(0x0673, 0x01)
    idle(2)
end

-- ─── Force into a dungeon for CONTEXT=="uw" ─────────────────────────
-- The pause MAP marker + compass + dungeon-item only exist in the
-- underworld (CurLevel != 0). Reaching a real dungeon room via SRAM-boot
-- nav is flaky, so warp: set CurLevel + RoomId, re-enter play. (OW keeps
-- CurLevel 0.) Capture proves whether the warp produced a coherent UW.
local function force_uw()
    if CONTEXT ~= "uw" then return end
    W(CELL_CUR_LEVEL, UW_LEVEL)
    W(CELL_ROOM_ID,   UW_ROOM)
    idle(8)
    LOG(string.format("force_uw level=$%02X room=$%02X -> gm=$%02X",
        UW_LEVEL, UW_ROOM, R(CELL_GAME_MODE)))
    -- RULE V3: a bare CurLevel+RoomId poke does NOT run the real dungeon
    -- level-load (CHR bankswap + PALRAM + CIRAM for that level). If CurLevel
    -- didn't stick or the room is incoherent, ABORT LOUD — never write a
    -- garbage UW golden that looks fine and poisons the diff. A real UW
    -- capture requires driving through the in-ROM dungeon load (separate
    -- step); until then OW (CONTEXT="ow") is the trusted path.
    if R(CELL_CUR_LEVEL) == 0 then
        LOG("!!! UW NOT REACHED (CurLevel==0) — aborting, no golden written !!!")
        client.exit(); error("uw load failed")
    end
end

-- ─── Close subscreen if nav opened it ───────────────────────────────
local function ensure_menu_closed()
    if R(CELL_MENU_STATE) ~= 0 then
        tap("Start", 4, 30)
        for _ = 1, 20 do if R(CELL_MENU_STATE) == 0 then break end idle(8) end
    end
    LOG(string.format("pre-open MenuState=$%02X", R(CELL_MENU_STATE)))
end

-- ─── NCGD bundle writer (identical layout to cave golden) ───────────
local function capture(name)
    local f = io.open(OUT .. "\\" .. name, "wb")
    f:write("NCGD")
    f:write(string.char(R(CELL_FRAME_COUNTER) & 0xFF))
    f:write(string.char(R(CELL_MENU_STATE) & 0xFF))   -- "cave" slot = MenuState
    f:write(string.char(R(CELL_GAME_MODE)))
    f:write(string.char(R(CELL_CUR_LEVEL)))           -- "person_state" slot = CurLevel
    for i = 0, 255  do f:write(string.char(OAM(i))) end
    for i = 0, 31   do f:write(string.char(PAL(i))) end
    for i = 0, 8191 do f:write(string.char(CHR(i))) end
    f:write(string.char(R(CELL_PPUCTRL)))
    for i = 0, 2047 do f:write(string.char(NT(i))) end
    f:close()
    LOG(string.format("wrote %s  MenuState=$%02X VScroll=$%02X FC=$%02X ppuctrl=$%02X",
        name, R(CELL_MENU_STATE), R(CELL_CUR_VSCROLL), R(CELL_FRAME_COUNTER), R(CELL_PPUCTRL)))
end

-- ─── Log one scroll ladder (scalar animation truth) ─────────────────
local function log_ladder(csv_name, max_frames, done_pred)
    local f = io.open(OUT .. "\\" .. csv_name, "w")
    f:write("frame,CurVScroll,MenuState,ScrollProgress,FrameCounter\n")
    for k = 0, max_frames - 1 do
        f:write(string.format("%d,%d,%d,%d,%d\n", k,
            R(CELL_CUR_VSCROLL), R(CELL_MENU_STATE), R(CELL_SCROLL_PROG),
            R(CELL_FRAME_COUNTER)))
        if done_pred() then break end
        emu.frameadvance()
    end
    f:close()
end

local ACTIVE = (CONTEXT == "ow") and 8 or 7

-- ─── Main ───────────────────────────────────────────────────────────
LOG("NES pause golden CONTEXT=" .. CONTEXT)
if not boot_to_gameplay() then print("BOOT FAIL"); client.exit(); return end
poke_full_inventory()
force_uw()
ensure_menu_closed()
client.screenshot(OUT .. "\\00_pre.png")

-- Open: press Start (no other buttons), then log the scroll-down ladder
-- until MenuState reaches ACTIVE (scroll settled).
tap("Start", 4, 2)
log_ladder("scroll_open.csv", 90, function() return R(CELL_MENU_STATE) == ACTIVE end)

-- Settle to a fully-stable ACTIVE frame. Review C3: gate on BOTH
-- MenuState==ACTIVE AND CurVScroll==$41 (scroll target) AND
-- SubmenuScrollProgress==0, stable ≥10 consecutive frames — so the
-- bundle is never captured one step into active while pixels still move.
do
    -- True settle markers: MenuState at ACTIVE index AND CurVScroll parked
    -- at the $41 target. (SubmenuScrollProgress decrements past 0 to $FF
    -- when done, so it is NOT a ==0 gate.) Stable ≥10 consecutive frames.
    local stab = 0
    for _ = 1, 300 do
        if R(CELL_MENU_STATE) == ACTIVE and R(CELL_CUR_VSCROLL) == 0x41 then
            stab = stab + 1
        else
            stab = 0
        end
        if stab >= 10 then break end
        idle(1)
    end
end
LOG(string.format("ACTIVE settled MenuState=$%02X VScroll=$%02X ScrollProg=$%02X",
    R(CELL_MENU_STATE), R(CELL_CUR_VSCROLL), R(CELL_SCROLL_PROG)))

-- Force SelectedItemSlot = 0 AFTER the menu's selection-ensure logic has
-- run, so the cursor sits on slot 0 to match the Genesis default
-- (s_cursor_slot=0). Without this the NES selection logic can land on a
-- different slot, making the cursor byte-diff a non-bug mismatch.
W(CELL_SELECTED_SLOT, 0x00)
idle(6)
LOG(string.format("forced SelectedItemSlot=$%02X", R(CELL_SELECTED_SLOT)))

-- Review C8: pin blink phase before EVERY bundle so cursor-palette golden
-- is reproducible across launches (FrameCounter bit3 drives cursor pal).
local function advance_to_bit3(want)
    for _ = 1, 40 do
        if ((R(CELL_FRAME_COUNTER) >> 3) & 1) == want then return end
        emu.frameadvance()
    end
end
advance_to_bit3(0)
client.screenshot(OUT .. "\\01_active.png")
capture("active.bin")
advance_to_bit3(0); capture("blink0.bin")
advance_to_bit3(1); capture("blink1.bin")

-- state.txt
do
    local f = io.open(OUT .. "\\state.txt", "w")
    f:write(string.format("CONTEXT=%s\n", CONTEXT))
    f:write(string.format("CurLevel $10 = $%02X\n", R(CELL_CUR_LEVEL)))
    f:write(string.format("RoomId $EB = $%02X\n", R(CELL_ROOM_ID)))
    f:write(string.format("MenuState $E1 = $%02X (active expect $%02X)\n", R(CELL_MENU_STATE), ACTIVE))
    f:write(string.format("CurVScroll $FC = $%02X (active expect $41)\n", R(CELL_CUR_VSCROLL)))
    f:write(string.format("ppuctrl $FF = $%02X (bit5 8x16=%d bit3 sprtbl=%d)\n",
        R(CELL_PPUCTRL), (R(CELL_PPUCTRL)>>5)&1, (R(CELL_PPUCTRL)>>3)&1))
    f:write(string.format("SelectedItemSlot $656 = $%02X\n", R(CELL_SELECTED_SLOT)))
    f:close()
end

-- Close: press Start, log scroll-up ladder until MenuState == 0.
tap("Start", 4, 2)
log_ladder("scroll_close.csv", 90, function() return R(CELL_MENU_STATE) == 0 end)
client.screenshot(OUT .. "\\02_post.png")

print("done: " .. OUT)
client.exit()

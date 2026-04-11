-- bizhawk_phase10_fs1_probe.lua
-- Phase 10.1 — File Select 1 (GameMode=$01) diagnostic probe.
--
-- Answers:
--   FS1-A: cursor Y vs Link pair Y per slot (delta)
--   FS1-B: per-slot Link pair left/right half attr bytes, VDP SAT view,
--          CRAM PAL0..PAL3 values
--
-- Dumps:
--   - 68K work-RAM OAM shadow $FF0200..$FF0243 (17 sprites × 4 bytes)
--   - Genesis VDP SAT at VRAM $F800..$F9C0 (56 sprites × 8 bytes) —
--     source of truth after _oam_dma CHR-expansion bridge
--   - Full CRAM (64 × word)
--   - Plane A NT slice (rows 8..22, cols 0..31) at VRAM $C000, stride $80
--   - Mode1CursorSpriteYs constants (hardcoded $5C $74 $8C $A8 $B8)
--   - Per-slot cursor-Y vs Link-Y delta computation
--
-- Output: builds/reports/fs1_p10_diag.txt

local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
local ROOT = (env_root and env_root ~= "" and env_root:gsub("/", "\\"))
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\nifty-chandrasekhar"
local OUT_TXT = ROOT .. "\\builds\\reports\\fs1_p10_diag.txt"

local M68K   = "M68K BUS"
local RAM68K = "68K RAM"

local lines = {}
local function log(s) lines[#lines + 1] = s end

local function ram_u8(bus_addr) return memory.read_u8(bus_addr - 0xFF0000, RAM68K) end
local function vram_u16(off)   return memory.read_u16_be(off, "VRAM") end
local function cram_u16(off)   return memory.read_u16_be(off, "CRAM") end

local frame_no = 0
local function adv(n)
    n = n or 1
    for i = 1, n do
        frame_no = frame_no + 1
        emu.frameadvance()
    end
end

local function press(buttons, frames)
    frames = frames or 1
    for i = 1, frames do
        joypad.set(buttons)
        frame_no = frame_no + 1
        emu.frameadvance()
    end
end

------------------------------------------------------------------------
-- Boot to FS1 (GameMode=$01) using the same pattern as fs1_vram_snap.
------------------------------------------------------------------------
for f = 1, 220 do
    if f >= 90 and f <= 110 then
        joypad.set({["P1 Start"] = true})
    end
    frame_no = f
    emu.frameadvance()
end

log("=== fs1_p10_diag probe start ===")
log(string.format("f=%d GameMode=$%02X Sub=$%02X CurSaveSlot=$%02X",
    frame_no, ram_u8(0xFF0012), ram_u8(0xFF0013), ram_u8(0xFF0016)))

if ram_u8(0xFF0012) ~= 0x01 then
    log(string.format("WARN: expected GameMode=$01, got $%02X -- advancing extra",
        ram_u8(0xFF0012)))
    adv(60)
    log(string.format("f=%d GameMode=$%02X Sub=$%02X",
        frame_no, ram_u8(0xFF0012), ram_u8(0xFF0013)))
end

------------------------------------------------------------------------
-- (1) 68K work-RAM OAM shadow ($FF0200-$FF0243, 17 sprites x 4 bytes)
------------------------------------------------------------------------
-- NES OAM shadow format: [Y, Tile, Attr, X] per sprite.
-- For Mode 1, sprite 0 is the cursor triplet entry 0 and sprites 4..9
-- are the three Link pairs (2 halves each).
log("--- (1) NES OAM shadow $FF0200..$FF0243 ---")
for spr = 0, 16 do
    local base = 0xFF0200 + spr * 4
    local y  = ram_u8(base + 0)
    local t  = ram_u8(base + 1)
    local a  = ram_u8(base + 2)
    local x  = ram_u8(base + 3)
    log(string.format("  spr%02d: Y=$%02X Tile=$%02X Attr=$%02X X=$%02X",
        spr, y, t, a, x))
end

------------------------------------------------------------------------
-- (2) Genesis VDP SAT dump at VRAM $F800..$F9C0 (56 slots * 8 bytes)
------------------------------------------------------------------------
-- SAT format (4 words per entry): YYYY, LLLL, AAAA, XXXX
--   Y: $80 = top of viewport on Gen
--   L: size (upper byte) + link (lower 7 bits)
--   A: PPpp-... bits 13-14 = palette 0..3
--   X: $80 = left of viewport
log("--- (2) VDP SAT $F800..$F9C0 (non-empty slots) ---")
for i = 0, 55 do
    local base = 0xF800 + i * 8
    local y = vram_u16(base + 0)
    local l = vram_u16(base + 2)
    local a = vram_u16(base + 4)
    local x = vram_u16(base + 6)
    if y ~= 0 or a ~= 0 or x ~= 0 then
        local pal = (a >> 13) & 0x3
        local pri = (a >> 15) & 0x1
        log(string.format("  sat%02d: Y=%04X SL=%04X AT=%04X(pal=%d pri=%d) X=%04X",
            i, y, l, a, pal, pri, x))
    end
end

------------------------------------------------------------------------
-- (3) Full CRAM dump (64 × word = 4 palettes of 16)
------------------------------------------------------------------------
log("--- (3) CRAM dump (PAL0..PAL3 x 16 words) ---")
for pal = 0, 3 do
    local row = {string.format("  PAL%d:", pal)}
    for i = 0, 15 do
        local w = cram_u16(pal * 32 + i * 2)
        row[#row + 1] = string.format("%04X", w)
    end
    log(table.concat(row, " "))
end

------------------------------------------------------------------------
-- (4) Plane A NT slice rows 8..22, cols 0..31 (V64 stride $80)
------------------------------------------------------------------------
log("--- (4) Plane A NT rows 8..22 cols 0..31 ---")
local PLANE_A_BASE = 0xC000
local STRIDE = 0x80
for row = 8, 22 do
    local parts = {string.format("  row %02d:", row)}
    for col = 0, 31 do
        local w = vram_u16(PLANE_A_BASE + row * STRIDE + col * 2)
        parts[#parts + 1] = string.format("%04X", w)
    end
    log(table.concat(parts, " "))
end

------------------------------------------------------------------------
-- (5) Mode1CursorSpriteYs (known ROM constants, per z_02.asm:3759)
------------------------------------------------------------------------
log("--- (5) Mode1CursorSpriteYs (compile-time) ---")
log("  NES cursor Y table: $5C $74 $8C $A8 $B8")
log("  slot0=$5C(92)  slot1=$74(116)  slot2=$8C(140)  regname=$A8(168)  elim=$B8(184)")

------------------------------------------------------------------------
-- (6) Per-slot cursor Y vs Link-half Y delta
------------------------------------------------------------------------
-- After _L_z02_UpdateMode1Menu_Sub0_WriteCursorSprite seeds $0001=$58,
-- Mode1_WriteLinkSprites loop for slot 0..2:
--   slot 0: Y_L0 = $58 SBC #$03 = $54 (84); X_L0 = $30; ADC #$18 -> $0001=$70
--   slot 1: Y_L1 = $70 SBC #$03 = $6C (108); X_L1 = $30; ADC #$18 -> $0001=$88
--   slot 2: Y_L2 = $88 SBC #$03 = $84 (132); X_L2 = $30; ADC #$18 -> $0001=$A0
-- With systemic X-flag bug, SBC #$03 actually subtracts 4 (not 3), so:
--   slot 0: $54 (84) vs bug=$53 (83), cursor=$5C (92), delta=8 or 9
--   slot 1: $6C (108) vs bug=$6B (107), cursor=$74 (116), delta=8 or 9
--   slot 2: $84 (132) vs bug=$83 (131), cursor=$8C (140), delta=8 or 9
log("--- (6) Cursor Y vs Link-half Y deltas (observed from OAM shadow) ---")
local cur_y = ram_u8(0xFF0200)
log(string.format("  observed cursor Y (spr0.Y = $FF0200) = $%02X (%d)", cur_y, cur_y))
log("  observed Link-pair Ys (sprites 4..9 inclusive):")
for spr = 4, 9 do
    local y = ram_u8(0xFF0200 + spr * 4)
    local a = ram_u8(0xFF0200 + spr * 4 + 2)
    log(string.format("    spr%d: Y=$%02X (%d) Attr=$%02X", spr, y, y, a))
end

-- Also dump the $0000/$0001/$0004/$0343 work-RAM state that the loop used
log("--- (6b) Work-RAM state ---")
log(string.format("  $FF0000 = $%02X  $FF0001 = $%02X  $FF0004 = $%02X  $FF0343 = $%02X",
    ram_u8(0xFF0000), ram_u8(0xFF0001), ram_u8(0xFF0004), ram_u8(0xFF0343)))
log(string.format("  $FF062D..$FF062F (IsSaveSlotActive[0..2]) = $%02X $%02X $%02X",
    ram_u8(0xFF062D), ram_u8(0xFF062E), ram_u8(0xFF062F)))
log(string.format("  $FF0016 (CurSaveSlot) = $%02X", ram_u8(0xFF0016)))

------------------------------------------------------------------------
-- (7) Advance a few frames, dump again to catch any per-frame drift
------------------------------------------------------------------------
adv(10)
log("--- (7) After +10 frames: OAM shadow spr0..spr12 Y/Attr ---")
for spr = 0, 12 do
    local base = 0xFF0200 + spr * 4
    log(string.format("  spr%02d: Y=$%02X Attr=$%02X", spr,
        ram_u8(base + 0), ram_u8(base + 2)))
end

log("=== fs1_p10_diag end ===")

local fh = assert(io.open(OUT_TXT, "w"))
fh:write(table.concat(lines, "\n") .. "\n")
fh:close()
client.exit()

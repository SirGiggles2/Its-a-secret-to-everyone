-- hud_backdrop_retirement_probe.lua
--
-- Verify the HUD-backdrop sprite-strip retirement (2026-05-15):
--   * SAT slots 10..41 NO LONGER hold the 32-sprite black HUD strip
--   * Gameplay slots 0..9 stay populated (Link + items + projectiles)
--   * Enemy slots 10..63 host the OW enemy bridge
--   * Slots 64+ are never written
--   * BG_A tile 0 underlay shows under the HUD plane (opaque black)
--
-- Outputs (under C:\tmp\):
--   hud_backdrop_retirement.png        screenshot
--   hud_backdrop_retirement.log        verify log (text)
--
-- Probe advances ~480 frames to let RoomRom boot + spawn OW enemies in
-- the default 4-Tektite room (per project_roomrom_debug_teleport memory).

local OUT_PNG = "C:\\tmp\\hud_backdrop_retirement.png"
local OUT_LOG = "C:\\tmp\\hud_backdrop_retirement.log"

local function log_line(f, s)
    f:write(s .. "\n")
end

local function hex(n, w)
    return string.format("%0" .. (w or 2) .. "X", n)
end

local f = io.open(OUT_LOG, "w")
log_line(f, "hud_backdrop_retirement probe — 2026-05-15")
log_line(f, "=========================================")

-- Boot timeline:
--   frame 0..~120     title fade-in
--   frame 121         press+hold A+B+C => roomrom_debug_enter()
--   frame 121..150    chord held so gameplay runtime takes input edge
--   frame 151+        release; runtime now ticking in OW 4-Tektite room
--   frame +240        let enemies populate via enemy_loop_room_init
local function press(buttons, frames)
    for f = 1, frames do
        joypad.set(buttons, 1)
        emu.frameadvance()
    end
end
local function idle(frames)
    for f = 1, frames do
        emu.frameadvance()
    end
end
idle(120)
press({A=true, B=true, C=true}, 30)
idle(360)

client.screenshot(OUT_PNG)
log_line(f, "screenshot saved: " .. OUT_PNG)

-- Genesis VRAM SAT lives at $F400. SGDK keeps a host-side SAT mirror
-- the renderer DMAs each frame; the live VDP table at $F400 is what
-- actually drives the display. Read SAT via Lua memory.read on the VDP
-- VRAM domain.
-- BizHawk Genesis exposes "VRAM" as a memory domain on this version.
local function read_sat()
    -- Each SAT entry = 8 bytes:
    --   +0..1  Y (10 bits)
    --   +2     size_link_hi (size=top 4 bits, link top 1)
    --   +3     link low 6 bits
    --   +4..5  attr (tile + flip + pal + prio)
    --   +6..7  X (10 bits)
    local entries = {}
    for slot = 0, 79 do
        local base = 0xF400 + slot * 8
        local y_hi = memory.read_u8(base + 0, "VRAM")
        local y_lo = memory.read_u8(base + 1, "VRAM")
        local size = memory.read_u8(base + 2, "VRAM")
        local link = memory.read_u8(base + 3, "VRAM")
        local at_hi= memory.read_u8(base + 4, "VRAM")
        local at_lo= memory.read_u8(base + 5, "VRAM")
        local x_hi = memory.read_u8(base + 6, "VRAM")
        local x_lo = memory.read_u8(base + 7, "VRAM")
        local y = ((y_hi & 0x03) * 256) + y_lo
        local x = ((x_hi & 0x03) * 256) + x_lo
        local tile = ((at_hi & 0x07) * 256) + at_lo
        local pal  = (at_hi >> 5) & 0x03
        local prio = (at_hi >> 7) & 0x01
        entries[slot] = {y=y, x=x, size=size, link=link, tile=tile, pal=pal, prio=prio,
                          raw = hex(y_hi)..hex(y_lo).."."..hex(size)..hex(link).."."..hex(at_hi)..hex(at_lo).."."..hex(x_hi)..hex(x_lo)}
    end
    return entries
end

local sat = read_sat()

log_line(f, "")
log_line(f, "SAT dump (slot Y X size link tile pal prio raw)")
log_line(f, "------------------------------------------------")
for slot = 0, 79 do
    local e = sat[slot]
    local marker = ""
    if slot <= 9 then marker = "GAMEPLAY"
    elseif slot <= 63 then marker = "ENEMY  "
    else marker = "OFF-HW " end
    log_line(f, string.format("%-8s slot=%2d y=%4d x=%4d size=%02X link=%02X tile=%04X pal=%d prio=%d  raw=%s",
        marker, slot, e.y, e.x, e.size, e.link, e.tile, e.pal, e.prio, e.raw))
end

-- HUD-backdrop retirement check: slots 10..41 should NOT all share
-- one tile id at y=0..55. If we see 16 contiguous sprites with
-- identical tile + low pal + size (2,4) starting at slot 10, the
-- backdrop strip is back.
local function backdrop_strip_present()
    -- A real backdrop strip has 16+ same-tile slots at y in [0..56]
    -- with a non-zero tile. All-zero records (unused slots) must NOT
    -- count toward the match.
    local first = sat[10]
    if first.tile == 0 then return false end
    if first.y > 56 then return false end
    local same_tile_count = 0
    for slot = 10, 41 do
        if sat[slot].tile == first.tile and sat[slot].tile ~= 0
            and sat[slot].pal == first.pal and sat[slot].y <= 56 then
            same_tile_count = same_tile_count + 1
        end
    end
    return same_tile_count >= 24
end

log_line(f, "")
local strip_back = backdrop_strip_present()
log_line(f, "HUD-backdrop strip detection: " .. (strip_back and "PRESENT (REGRESSION)" or "ABSENT (retirement holds)"))

-- Slot 64+ must be unused (Y == 0 or off-screen).
local off_hw_active = 0
for slot = 64, 79 do
    if sat[slot].y > 0 and sat[slot].y < 480 then
        off_hw_active = off_hw_active + 1
    end
end
log_line(f, "Slots 64..79 with on-screen Y: " .. off_hw_active .. " (expect 0)")

-- Gameplay slots 0..9 occupancy: Link at slot 0 should have non-zero Y.
log_line(f, "Slot 0 (Link)  y=" .. sat[0].y .. " x=" .. sat[0].x ..
            "  tile=" .. hex(sat[0].tile, 4))

-- Enemy slot range 10..63 occupancy count.
local enemy_active = 0
for slot = 10, 63 do
    if sat[slot].y > 32 and sat[slot].y < 240 then
        enemy_active = enemy_active + 1
    end
end
log_line(f, "Enemy slots 10..63 with playfield Y (32..240): " .. enemy_active)

-- BG_A underlay check: HUD rows are 0..6 (ROOMROM_HUD_ROWS).
-- Plane A base = $C000. Plane width = 64 cells * 2 bytes = 128 per row.
-- For row r col c: cell @ ($C000 + r*128 + c*2). Word value = tile id +
-- palette bits + flip bits. Cell value 0 = tile 0 (PAL0 color 0 = black).
log_line(f, "")
log_line(f, "BG_A HUD underlay rows 0..6, col 0..31 (expect tile 0 for opacity)")
log_line(f, "-------------------------------------------------------------")
for row = 0, 6 do
    local nonzero = 0
    for col = 0, 31 do
        local addr = 0xC000 + row * 128 + col * 2
        local w = memory.read_u8(addr + 0, "VRAM") * 256
               + memory.read_u8(addr + 1, "VRAM")
        if w ~= 0 then nonzero = nonzero + 1 end
    end
    log_line(f, "  row=" .. row .. "  non-zero cells in cols 0..31: " .. nonzero)
end

-- CRAM PAL0 color 0 (the actual HUD-underlay color) should be 0x0000 (black).
log_line(f, "")
log_line(f, "CRAM check (palette 0, color 0 = HUD underlay color)")
local cram_hi = memory.read_u8(0x0000, "CRAM")
local cram_lo = memory.read_u8(0x0001, "CRAM")
log_line(f, string.format("  CRAM[0]=%02X%02X  (expect 0000 = black)", cram_hi, cram_lo))

-- Window plane HUD glyph spot-check.
-- Window at $E000. NES Z1 HUD has a "-" between hearts; the top rows
-- are tile data so just count non-zero cells in row 0..6 cols 0..31.
log_line(f, "")
log_line(f, "Window plane (HUD glyphs) rows 0..6, col 0..31")
log_line(f, "----------------------------------------------")
for row = 0, 6 do
    local nonzero = 0
    for col = 0, 31 do
        local addr = 0xE000 + row * 128 + col * 2
        local w = memory.read_u8(addr + 0, "VRAM") * 256
               + memory.read_u8(addr + 1, "VRAM")
        if w ~= 0 then nonzero = nonzero + 1 end
    end
    log_line(f, "  row=" .. row .. "  non-zero cells in cols 0..31: " .. nonzero)
end

-- VDP regs spot
log_line(f, "")
log_line(f, "Done. Screenshot=" .. OUT_PNG)
f:close()

-- Visible on-screen banner while running.
gui.text(8, 8, "hud_backdrop probe — see C:\\tmp\\hud_backdrop_retirement.log")

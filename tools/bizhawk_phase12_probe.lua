-- bizhawk_phase12_probe.lua
-- Phase 12 combined alignment + typing probe.
--
-- Captures:
--   Probe A: FS1 (Mode $01) heart cursor + 3 Link sprite Y/X vs Plane A slot row Y.
--   Probe C: FS2 (Mode $0E) flashing block cursor + name cursor + 3 Link sprite Y/X
--            vs Plane A slot row Y and char-board letter row Y.
--   Probe B: FS2 A/B button edge detection + $0420/$041F/$0421/$0638 buffer watch
--            as scripted "press A" sequences run.
--   Probe D: FS1 Link sprite tile index + 4 CHR bank dumps for that tile.
--
-- Output: builds/reports/phase12_probe.txt

local ROOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT  = ROOT .. "builds\\reports\\phase12_probe.txt"

os.execute('if not exist "' .. ROOT .. 'builds\\reports\\" mkdir "' .. ROOT .. 'builds\\reports\\"')
local f = assert(io.open(OUT, "w"))
local function log(s) f:write(s.."\n"); f:flush(); print(s) end

local RAM68K = "68K RAM"
local function u8(bus)  return memory.read_u8(bus - 0xFF0000, RAM68K) end
local function vr16(o)  return memory.read_u16_be(o, "VRAM") end
local function vr8(o)   return memory.read_u8(o, "VRAM") end

local function adv(n)
    n = n or 1
    for i = 1, n do emu.frameadvance() end
end
local function press(btn, n)
    n = n or 1
    for i = 1, n do joypad.set({[btn]=true}); emu.frameadvance() end
    adv(3)
end

local frame = 0
local function boot_to_fs1()
    -- Tap Start around f90-110 to skip title screen
    for fc = 1, 230 do
        if fc >= 90 and fc <= 110 then joypad.set({["P1 Start"]=true}) end
        emu.frameadvance()
        frame = fc
    end
end

log(string.format("=== Phase 12 probe — Zelda27.86 + Lua-only ==="))

boot_to_fs1()

log(string.format("f=%d GameMode=$%02X Sub=$%02X CurSaveSlot=$%02X",
    frame, u8(0xFF0012), u8(0xFF0013), u8(0xFF0016)))

if u8(0xFF0012) ~= 0x01 then
    for i=1,120 do emu.frameadvance(); frame=frame+1 end
    log(string.format("  advanced extra: f=%d GameMode=$%02X", frame, u8(0xFF0012)))
end

------------------------------------------------------------------------
-- PROBE A — FS1 alignment (GameMode=$01, CurSaveSlot=0)
------------------------------------------------------------------------
log("")
log("======= PROBE A — FS1 alignment =======")
log(string.format("CurSaveSlot=$%02X", u8(0xFF0016)))

-- SAT sprite 0 (heart cursor) and 4..9 (3 Link pairs)
log("--- VDP SAT (Y,link,attr,X) for sprites 0,4..9 ---")
local sat_A = {}
for _, idx in ipairs({0, 4, 5, 6, 7, 8, 9}) do
    local base = 0xF800 + idx * 8
    local y = vr16(base + 0)
    local l = vr16(base + 2)
    local a = vr16(base + 4)
    local x = vr16(base + 6)
    local pal = (a >> 13) & 0x3
    local tile = a & 0x7FF
    local screen_Y = y - 0x80
    local screen_X = x - 0x80
    sat_A[idx] = {y=y, x=x, tile=tile, pal=pal, sy=screen_Y, sx=screen_X}
    log(string.format("  spr%02d: Y=$%04X X=$%04X tile=$%03X pal=%d  screen(X=%d,Y=%d)",
        idx, y, x, tile, pal, screen_X, screen_Y))
end

-- Plane A nametable slice rows 8..22 cols 0..31 to find slot row Y
log("--- Plane A rows 8..22 cols 0..31 (cell tile index) ---")
local PLANE_A = 0xC000
local STRIDE  = 0x80
local slot_row_screen_Y = {}
for row = 8, 22 do
    local parts = {string.format("  row%02d:", row)}
    local first_nonblank_col = -1
    for col = 0, 31 do
        local w = vr16(PLANE_A + row * STRIDE + col * 2)
        local t = w & 0x7FF
        parts[#parts+1] = string.format("%03X", t)
        if first_nonblank_col < 0 and t ~= 0x124 and t ~= 0x000 then
            first_nonblank_col = col
        end
    end
    log(table.concat(parts, " "))
    if first_nonblank_col >= 0 then
        log(string.format("    first_nonblank_col=%d screen_Y=%d", first_nonblank_col, row*8))
    end
end

-- Delta: cursor sprite vs Link sprite Y on FS1
log("--- Computed FS1 deltas ---")
local heart_sy = sat_A[0].sy
local link0_sy = sat_A[4] and sat_A[4].sy or -1
local link0_sx = sat_A[4] and sat_A[4].sx or -1
local heart_sx = sat_A[0].sx
log(string.format("  heart sprite screen=(X=%d,Y=%d)", heart_sx, heart_sy))
log(string.format("  link0  sprite screen=(X=%d,Y=%d)", link0_sx, link0_sy))
log(string.format("  heart_X - link0_X = %d", heart_sx - link0_sx))
log(string.format("  heart_Y - link0_Y = %d", heart_sy - link0_sy))

-- Link tile index
if sat_A[4] then
    log(string.format("  link sprite tile = $%03X", sat_A[4].tile))
end

------------------------------------------------------------------------
-- PROBE D — dump CHR tile at link_tile from 4 bank bases
------------------------------------------------------------------------
log("")
log("======= PROBE D — FS1 Link CHR tile bank dump =======")
if sat_A[4] then
    local ti = sat_A[4].tile
    -- Genesis CHR is 32 bytes per 8x8 tile. Banks per CHR_EXPANSION: A=0, B=+512 tiles, C=+1024 tiles, D=+1536 tiles
    -- In byte offsets: A: tile*32, B: (tile+512)*32, C: (tile+1024)*32, D: (tile+1536)*32
    -- But actual VRAM addresses depend on layout. Use VRAM offsets 0x0000/0x4000/0x6000/0x8000 as proxies.
    local banks = {
        {name="BANK_A", base=ti*32},
        {name="BANK_B", base=(ti+512)*32},
        {name="BANK_C", base=(ti+1024)*32},
        {name="BANK_D", base=(ti+1536)*32},
    }
    for _, b in ipairs(banks) do
        local row = {string.format("  %s (vram $%04X):", b.name, b.base)}
        for i=0,31 do
            row[#row+1] = string.format("%02X", vr8(b.base + i))
        end
        log(table.concat(row, " "))
    end
else
    log("  (no link sprite detected)")
end

------------------------------------------------------------------------
-- PROBE C — navigate to FS2 REGISTER and dump alignment
------------------------------------------------------------------------
log("")
log("======= PROBE C — FS2 alignment =======")
-- From FS1 with CurSaveSlot=0, press Down 3 times to reach REGISTER (slot 3)
-- Then Start to enter REGISTER mode.
log(string.format("entering REGISTER: f=%d GameMode=$%02X", frame, u8(0xFF0012)))
press("P1 Down", 1); frame=frame+1
press("P1 Down", 1); frame=frame+1
press("P1 Down", 1); frame=frame+1
log(string.format("  after 3x Down: CurSaveSlot=$%02X", u8(0xFF0016)))
press("P1 Start", 1); frame=frame+1
adv(30); frame=frame+30
log(string.format("  after Start+30f: f=%d GameMode=$%02X Sub=$%02X",
    frame, u8(0xFF0012), u8(0xFF0013)))

if u8(0xFF0012) == 0x0E then
    log("  REGISTER mode reached")
else
    log(string.format("  WARN: GameMode=$%02X not $0E", u8(0xFF0012)))
    -- Try more advances
    adv(60); frame=frame+60
    log(string.format("  +60f: GameMode=$%02X", u8(0xFF0012)))
end

-- Dump SAT sprites 0..15
log("--- FS2 VDP SAT sprites 0..15 ---")
local sat_C = {}
for idx = 0, 15 do
    local base = 0xF800 + idx * 8
    local y = vr16(base + 0)
    local a = vr16(base + 4)
    local x = vr16(base + 6)
    local tile = a & 0x7FF
    local pal = (a >> 13) & 0x3
    local sy = y - 0x80
    local sx = x - 0x80
    sat_C[idx] = {y=y, x=x, tile=tile, pal=pal, sy=sy, sx=sx}
    if y ~= 0 then
        log(string.format("  spr%02d: Y=$%04X X=$%04X tile=$%03X pal=%d  screen(X=%d,Y=%d)",
            idx, y, x, tile, pal, sx, sy))
    end
end

-- Dump Plane A FS2 rows
log("--- FS2 Plane A rows 4..22 cols 0..31 ---")
for row = 4, 22 do
    local parts = {string.format("  row%02d:", row)}
    for col = 0, 31 do
        local w = vr16(PLANE_A + row * STRIDE + col * 2)
        local t = w & 0x7FF
        parts[#parts+1] = string.format("%03X", t)
    end
    log(table.concat(parts, " "))
end

-- Work-RAM key state
log("--- FS2 work-RAM state ---")
log(string.format("  $0012 GameMode = $%02X", u8(0xFF0012)))
log(string.format("  $0085 cursor Y base = $%02X", u8(0xFF0085)))
log(string.format("  $0084 name cursor Y = $%02X", u8(0xFF0084)))
log(string.format("  $0070 name cursor X = $%02X", u8(0xFF0070)))
log(string.format("  $0071 cursor X      = $%02X", u8(0xFF0071)))
log(string.format("  $041F CharBoardIndex = $%02X", u8(0xFF041F)))
log(string.format("  $0420 InitName      = $%02X", u8(0xFF0420)))
log(string.format("  $0421 NameCharOfs   = $%02X", u8(0xFF0421)))

-- FS2 cursor-vs-letter-row delta: sprite 2 is the flashing block cursor.
if sat_C[2] then
    log(string.format("  block cursor (spr2) screen Y=%d  (work RAM $0085=$%02X → expected sprite Y=%d)",
        sat_C[2].sy, u8(0xFF0085), u8(0xFF0085) - 8 - 8 + 128 - 0x80))
end

------------------------------------------------------------------------
-- PROBE B — A-press diagnosis: before, press, after
------------------------------------------------------------------------
log("")
log("======= PROBE B — A-press / typing diagnosis =======")

local function dump_state(tag)
    log(string.format("  [%s] f=%d $00F8=$%02X $0420=$%02X $041F=$%02X $0421=$%02X $0305=$%02X",
        tag, frame, u8(0xFF00F8), u8(0xFF0420), u8(0xFF041F), u8(0xFF0421), u8(0xFF0305)))
    local row = {"    $0638..$063F:"}
    for i=0,7 do row[#row+1]=string.format("%02X", u8(0xFF0638+i)) end
    log(table.concat(row," "))
end

if u8(0xFF0012) == 0x0E then
    dump_state("pre-A")
    -- Try P1 A (Genesis A button, often maps to NES A via _ctrl_strobe)
    log("  pressing P1 A 1 frame...")
    joypad.set({["P1 A"]=true}); emu.frameadvance(); frame=frame+1
    dump_state("post-A-1")
    adv(3); frame=frame+3
    dump_state("post-A-4")

    -- Move Right once
    log("  pressing P1 Right 1 frame...")
    joypad.set({["P1 Right"]=true}); emu.frameadvance(); frame=frame+1
    adv(3); frame=frame+3
    dump_state("post-Right")

    -- A again
    log("  pressing P1 A 1 frame...")
    joypad.set({["P1 A"]=true}); emu.frameadvance(); frame=frame+1
    dump_state("post-A-2nd")
    adv(3); frame=frame+3
    dump_state("post-A-2nd-4")

    -- Try B
    log("  pressing P1 B 1 frame...")
    joypad.set({["P1 B"]=true}); emu.frameadvance(); frame=frame+1
    dump_state("post-B")
    adv(3); frame=frame+3
    dump_state("post-B-4")

    -- Try C
    log("  pressing P1 C 1 frame...")
    joypad.set({["P1 C"]=true}); emu.frameadvance(); frame=frame+1
    dump_state("post-C")
    adv(3); frame=frame+3
    dump_state("post-C-4")
else
    log("  skipped — GameMode is not $0E")
end

log("")
log("=== phase12 probe end ===")
f:close()
client.exit()

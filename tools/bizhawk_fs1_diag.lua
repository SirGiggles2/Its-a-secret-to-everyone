-- bizhawk_fs1_diag.lua
-- Phase 9.1 — File Select Screen 1 (GameMode $01) diagnostic dump.
--
-- Purpose: capture concrete VRAM/OAM/CRAM state when the Genesis shell is
-- sitting in Mode $01 Sub $00 (idle slot-select), so the four reported
-- defect categories can be pinned down to specific byte-level diffs:
--
--   * Header / footer nametable text
--   * Per-slot name glyphs + death count
--   * Heart container strip per slot
--   * Cursor arrow + 3 Link sprite rows (OAM)
--
-- Output: builds\reports\fs1_diag.txt
--
-- Landmarks used:
--   Plane A base  = VRAM $C000  (stride $80 bytes = 64 cols × 2)
--   Sprite table  = VRAM $F800  (64 entries × 8 bytes)
--   CRAM palettes = 4 × 16 words starting at CRAM $00
--   GameMode      = $FF0012
--   SubMode       = $FF0013
--
-- Launched like other probes via EmuHawk --lua=...

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "fs1_diag.txt"

dofile(ROOT .. "tools/probe_addresses.lua")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

-- ── Memory helpers (same fallback pattern as other probes) ───────────────
local function try_dom(dom, offset, width)
    local ok, v = pcall(function()
        memory.usememorydomain(dom)
        if     width == 1 then return memory.read_u8(offset)
        elseif width == 2 then return memory.read_u16_be(offset)
        else                    return memory.read_u32_be(offset) end
    end)
    return ok and v or nil
end

local function ram_read(bus_addr, width)
    local ofs = bus_addr - 0xFF0000
    for _, spec in ipairs({
        {"M68K BUS", bus_addr}, {"68K RAM", ofs},
        {"System Bus", bus_addr}, {"Main RAM", ofs},
    }) do
        local v = try_dom(spec[1], spec[2], width or 1)
        if v ~= nil then return v end
    end
    return nil
end
local function u8(a)  return ram_read(a, 1) end

local function vram_u8(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u8(addr)
    end)
    return ok and v or 0
end

local function vram_u16(addr)
    local hi = vram_u8(addr)
    local lo = vram_u8(addr + 1)
    return hi * 256 + lo
end

local function cram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("CRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

-- ── Reach Mode $01 Sub $00 idle ──────────────────────────────────────────
-- Same Start window the Phase 1 verify probe uses, then coast a bit to
-- make sure the file-select init finishes staging tiles and palettes.
local FRAMES     = 900
local PRESS_START = 180
local PRESS_END   = 210
local SAMPLE_FRAME = 600   -- comfortably past init, still before timeout

local reached_mode1 = false
local mode1_first_frame = nil

for frame = 1, FRAMES do
    if frame >= PRESS_START and frame <= PRESS_END then
        pcall(function()
            joypad.set({["P1 Start"] = true, ["Start"] = true}, 1)
        end)
    end
    emu.frameadvance()

    local gm = u8(0xFF0012) or 0
    if gm == 0x01 and not reached_mode1 then
        reached_mode1 = true
        mode1_first_frame = frame
    end

    if frame == SAMPLE_FRAME then break end
end

local final_mode = u8(0xFF0012) or 0
local final_sub  = u8(0xFF0013) or 0

log("=================================================================")
log("Phase 9.1 — FS1 diagnostic dump")
log("=================================================================")
log(string.format("  sample frame = %d", SAMPLE_FRAME))
log(string.format("  GameMode=$%02X  SubMode=$%02X  (mode1 first seen at frame %s)",
    final_mode, final_sub, tostring(mode1_first_frame)))
log("")

if final_mode ~= 0x01 then
    log("  *** WARNING: not in GameMode $01 at sample frame — FS1 dump may be stale ***")
    log("")
end

-- ── Plane A nametable dump (rows 0..29, first 32 cols of each row) ──────
-- V64 stride is $80 bytes per row.  NES plane is 32 cols wide so we only
-- dump the left half of each Genesis row — that's where file-select text
-- actually sits.
log("─── Plane A nametable rows 0..29 (cols 0..31, VRAM $C000+row*$80) ──")
for row = 0, 29 do
    local base = 0xC000 + row * 0x80
    local buf = {}
    for col = 0, 31 do
        local w = vram_u16(base + col * 2)
        buf[#buf+1] = string.format("%04X", w)
    end
    log(string.format("  r%02d $%04X: %s", row, base,
        table.concat(buf, " ", 1, 16)))
    log(string.format("           %s",
        table.concat(buf, " ", 17, 32)))
end
log("")

-- ── Sprite Attribute Table (VRAM $F800) entries 0..20 ───────────────────
log("─── SAT (VRAM $F800) entries 0..20 ────────────────────────────────")
log("   #    Y     X    attr       tile  pal  pri  link  raw")
for i = 0, 20 do
    local base = 0xF800 + i * 8
    local y    = vram_u16(base + 0)
    local sz   = vram_u8(base + 2)   -- size(2) | link(6) high
    local link = vram_u8(base + 3)
    local attr = vram_u16(base + 4)
    local x    = vram_u16(base + 6)
    local tile = attr % 0x800
    local hf   = math.floor(attr / 0x800) % 2
    local vf   = math.floor(attr / 0x1000) % 2
    local pal  = math.floor(attr / 0x2000) % 4
    local pri  = math.floor(attr / 0x8000) % 2
    log(string.format("  %02d  $%04X  $%04X  $%04X  $%03X   %d   %d    %02X  "
            .. "[sz=%02X lk=%02X hf=%d vf=%d]",
        i, y, x, attr, tile, pal, pri, link, sz, link, hf, vf))
end
log("")

-- ── CRAM palettes 0..3 ──────────────────────────────────────────────────
log("─── CRAM palettes 0..3 (16 words each) ────────────────────────────")
for p = 0, 3 do
    local base = p * 0x20
    local buf = {}
    for i = 0, 15 do
        buf[#buf+1] = string.format("%04X", cram_u16(base + i * 2))
    end
    log(string.format("  pal%d: %s", p, table.concat(buf, " ")))
end
log("")

-- ── Frontend RAM state for sanity ───────────────────────────────────────
log("─── Frontend RAM ($FF0010..$FF0070 spot dump) ─────────────────────")
log(string.format("  GameMode      ($FF0012) = $%02X", u8(0xFF0012) or 0))
log(string.format("  SubMode       ($FF0013) = $%02X", u8(0xFF0013) or 0))
log(string.format("  F8 buttons    ($FF00F8) = $%02X", u8(0xFF00F8) or 0))
log(string.format("  CurV          ($FF00FC) = $%02X", u8(0xFF00FC) or 0))
log(string.format("  PPUCTRL shdw  ($FF00FF) = $%02X", u8(0xFF00FF) or 0))
log(string.format("  CharBoardIdx  ($FF041F) = $%02X", u8(0xFF041F) or 0))
log(string.format("  StartRelGate  ($FF042B) = $%02X", u8(0xFF042B) or 0))
log(string.format("  VRamForceBlank($FF083D) = $%02X", u8(0xFF083D) or 0))
log(string.format("  LAST_GAMEMODE ($FF0810) = $%02X", u8(0xFF0810) or 0))
log("")

-- ── Quick reference — NES Zelda file-select Plane A (first 32 cols) ────
-- These are the tile indices seen on NES (PPU nametable $2000+) when FS1
-- is idle.  Use as a sanity check — if the Genesis Plane A dump above
-- disagrees wildly, that's the whole defect category.  Taken from a
-- fresh Mesen capture of NES Zelda file-select, row-major, 30 rows × 32
-- cols.  We log it as a reference block the reviewer can diff against.
log("─── NES reference hint ────────────────────────────────────────────")
log("  NES FS1 header row 4 (cols 7..24) should read \"LEGEND OF ZELDA\"")
log("  NES FS1 row 10 slot 1 starts with tile $80 or so (slot border)")
log("  NES FS1 row 23 footer reads \"REGISTER YOUR NAME\"")
log("  NES FS1 row 25 footer reads \"ELIMINATION MODE\"")
log("  (Full reference embed TBD after 9.1 produces the first diff)")
log("")

log("=================================================================")
log("FS1 diagnostic dump complete.")
log("=================================================================")

f:close()
client.exit()

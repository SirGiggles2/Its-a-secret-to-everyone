-- bizhawk_nes_nametable_capture.lua
-- T22 NES reference: run NES Zelda to title screen, dump PPU nametable $2000-$23FF.
--
-- Outputs:
--   builds/reports/nes_nametable.txt   — 960 bytes: one hex tile index per line ($2000-$23BF)
--   builds/reports/nes_attrtable.txt   — 64 bytes:  attribute table bytes ($23C0-$23FF)
--   builds/reports/nes_nametable_meta.txt — timing info + tile statistics
--
-- BizHawk NES PPU RAM domain:  "PPU Bus" or "PPU RAM" at PPU address $2000-$3FFF

local ROOT    = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR = ROOT .. "builds\\reports\\"
local OUT_NT  = OUT_DIR .. "nes_nametable.txt"
local OUT_AT  = OUT_DIR .. "nes_attrtable.txt"
local OUT_META= OUT_DIR .. "nes_nametable_meta.txt"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local fmeta = assert(io.open(OUT_META, "w"))
local function mlog(msg) fmeta:write(msg.."\n") fmeta:flush() print(msg) end

mlog("NES nametable capture starting...")

local MAX_FRAMES = 400
local display_frame = nil

-- Helper: try reading from a memory domain
local function try_read(dom, addr)
    local ok, v = pcall(function()
        memory.usememorydomain(dom)
        return memory.read_u8(addr)
    end)
    return ok and v or nil
end

-- Detect display enable by polling known domain options
local function get_ppumask()
    -- BizHawk NES: PPUMASK ($2001) readable on "PPU Bus" or "System Bus"
    local v = try_read("PPU Bus", 0x2001)
    if v ~= nil then return v end
    v = try_read("System Bus", 0x2001)
    if v ~= nil then return v end
    return nil
end

-- Wait for title screen: detect when PPUMASK has bg-enable (bit 3) set
for frame = 1, MAX_FRAMES do
    emu.frameadvance()

    if not display_frame then
        -- Try reading NES CPU RAM $0012 (game mode) — once stable at title, mode=1
        local mode = try_read("RAM", 0x0012) or 0
        local ppumask = get_ppumask() or 0

        if (ppumask & 0x08) ~= 0 or (ppumask & 0x10) ~= 0 then
            display_frame = frame
            mlog(string.format("  Display enable at frame %d (PPUMASK=$%02X, mode=$%02X)",
                frame, ppumask, mode))
        elseif mode ~= 0 and frame > 60 then
            -- Fallback: game mode non-zero past frame 60 → title screen active
            display_frame = frame
            mlog(string.format("  Title screen via mode at frame %d (mode=$%02X)", frame, mode))
        end
    end

    if frame <= 5 or frame % 60 == 0 then
        local mode = try_read("RAM", 0x0012) or 0
        local ppumask = get_ppumask() or 0
        mlog(string.format("  f%03d  mode=$%02X  PPUMASK=$%02X  disp=%s",
            frame, mode, ppumask, tostring(display_frame or "-")))
    end

    if display_frame and frame >= display_frame + 15 then
        mlog(string.format("  15-frame settle at frame %d — capturing nametable", frame))
        break
    end
end

if not display_frame then
    mlog("  WARNING: display never detected in " .. MAX_FRAMES .. " frames — capturing anyway")
end

-- ── Determine which domain holds PPU RAM ────────────────────────────────────
-- BizHawk NES exposes PPU memory on "PPU Bus" (full PPU address space)
-- Nametable 0 = $2000-$23FF on the PPU Bus
local ppu_domain = nil
for _, dom in ipairs({"PPU Bus", "PPU RAM", "System Bus"}) do
    local v = try_read(dom, 0x2000)
    if v ~= nil then
        ppu_domain = dom
        mlog(string.format("  Using PPU domain: '%s'  (test byte at $2000 = $%02X)", dom, v))
        break
    end
end

if not ppu_domain then
    mlog("  ERROR: no PPU domain found — trying 'RAM' for fallback")
    ppu_domain = "RAM"
end

-- ── Dump nametable $2000-$23BF (960 tile bytes) ─────────────────────────────
local tile_counts = {}  -- tile_index → count
local fnt = assert(io.open(OUT_NT, "w"))
for i = 0, 0x3BF do
    local v = try_read(ppu_domain, 0x2000 + i) or 0
    fnt:write(string.format("%02X\n", v))
    tile_counts[v] = (tile_counts[v] or 0) + 1
end
fnt:close()

-- ── Dump attribute table $23C0-$23FF (64 bytes) ─────────────────────────────
local fat = assert(io.open(OUT_AT, "w"))
for i = 0, 0x3F do
    local v = try_read(ppu_domain, 0x23C0 + i) or 0
    fat:write(string.format("%02X\n", v))
end
fat:close()

-- ── Statistics ───────────────────────────────────────────────────────────────
local distinct = 0
for _ in pairs(tile_counts) do distinct = distinct + 1 end
mlog(string.format("  Distinct tile indices in nametable: %d", distinct))
mlog("  Top tile counts:")
-- Sort by count descending, show top 10
local sorted = {}
for k, v in pairs(tile_counts) do sorted[#sorted+1] = {k, v} end
table.sort(sorted, function(a, b) return a[2] > b[2] end)
for i = 1, math.min(10, #sorted) do
    mlog(string.format("    tile $%02X: %d times", sorted[i][1], sorted[i][2]))
end

-- Show nametable rows 5-10 (title logo area, same as T21 probe)
mlog("  Nametable rows 5-10 (first 16 cols):")
for row = 5, 10 do
    local line = string.format("    row%02d:", row)
    for col = 0, 15 do
        local v = try_read(ppu_domain, 0x2000 + row * 32 + col) or 0
        line = line .. string.format(" %02X", v)
    end
    mlog(line)
end

mlog("")
mlog("Nametable dump: " .. OUT_NT)
mlog("Attr table dump: " .. OUT_AT)
fmeta:close()
client.exit()

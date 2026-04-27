-- dump_nes_item_scroll.lua
-- Snapshots NES PPU state at multiple mid-item-scroll frames so we can
-- reconstruct the full item layout in Genesis tile form.
--
-- Per-frame dump:
--   nt_<frame>.bin    : 2048 bytes ($2000-$27FF, NT1+NT2)
--   oam_<frame>.bin   : 256 bytes (OAM)
--   meta_<frame>.txt  : scroll Y, frame count
--
-- Static (one-shot) dump:
--   bg_chr.bin     : 4096 bytes ($1000-$1FFF, BG pattern table)
--   sp_chr.bin     : 4096 bytes ($0000-$0FFF, sprite pattern table)
--   palette.bin    : 32 bytes ($3F00-$3F1F, NES palette)

local OUT_DIR = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/intro_demo/nes_dump"

-- Dump every 10 frames from 2050 (just before item-scroll start) to 5000
-- (well past expected loop-back). Use a generated set so coverage is dense
-- enough to stitch the full content of all items.
local DUMP_FRAMES = {}
for f = 2050, 5000, 10 do table.insert(DUMP_FRAMES, f) end
local LAST_FRAME = 5100

local function emu_frame()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

local function read_ppu(addr)
    local ok, v = pcall(function() return memory.read_u8(addr, "PPU Bus") end)
    return ok and v or 0
end

local function read_oam(off)
    -- OAM is its own memory domain in BizHawk NES core
    local ok, v = pcall(function() return memory.read_u8(off, "OAM") end)
    return ok and v or 0
end

local function dump_static()
    -- BG pattern table $1000-$1FFF
    local f = io.open(OUT_DIR .. "/bg_chr.bin", "wb")
    for a = 0x1000, 0x1FFF do f:write(string.char(read_ppu(a))) end
    f:close()
    -- Sprite pattern table $0000-$0FFF
    f = io.open(OUT_DIR .. "/sp_chr.bin", "wb")
    for a = 0x0000, 0x0FFF do f:write(string.char(read_ppu(a))) end
    f:close()
    -- Palette $3F00-$3F1F (32 bytes)
    f = io.open(OUT_DIR .. "/palette.bin", "wb")
    for a = 0x3F00, 0x3F1F do f:write(string.char(read_ppu(a))) end
    f:close()
    print("Static dumps written")
end

local function dump_per_frame(f_no)
    -- NT1 + NT2 ($2000-$27FF)
    local f = io.open(OUT_DIR .. "/nt_" .. f_no .. ".bin", "wb")
    for a = 0x2000, 0x27FF do f:write(string.char(read_ppu(a))) end
    f:close()
    -- OAM (256 bytes)
    f = io.open(OUT_DIR .. "/oam_" .. f_no .. ".bin", "wb")
    for o = 0, 255 do f:write(string.char(read_oam(o))) end
    f:close()
    -- Meta: NES CurVScroll at zero-page $FC, CurHScroll $FD
    f = io.open(OUT_DIR .. "/meta_" .. f_no .. ".txt", "w")
    f:write(string.format("frame=%d\nscroll_y=%d\nscroll_x=%d\n",
        f_no, mainmemory.read_u8(0xFC), mainmemory.read_u8(0xFD)))
    f:close()
end

local dumped = {}
for _, fn in ipairs(DUMP_FRAMES) do dumped[fn] = false end

while emu_frame() < LAST_FRAME do
    emu.frameadvance()
    local cur = emu_frame()
    for _, fn in ipairs(DUMP_FRAMES) do
        if cur == fn and not dumped[fn] then
            dump_per_frame(fn)
            dumped[fn] = true
            print("Dumped frame " .. fn)
        end
    end
end
dump_static()
print("ALL DONE")

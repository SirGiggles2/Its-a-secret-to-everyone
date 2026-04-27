-- dump_fs_chr.lua
-- Boot Redux NES ROM, advance to File Select screen, dump live CHR-RAM
-- (PPU $0000-$1FFF = 8KB pattern table) to binary file.
--
-- Frame timing mirrors dump_fs_nametable.lua:
--   300 frames advance + Start press + 118 frames settle = ~421 total.
-- This lands squarely on the FS screen, at which point the NES has already
-- overwritten CHR-RAM with FS-mode tile bitmaps.
--
-- Output: C:\tmp\fs_chr.bin  (8192 bytes = 512 NES 8x8 tiles)
-- After dump, copy to tools/file_select_test/ref/fs_chr.bin.
--
-- BizHawk NES domain: "PPU Bus" — $0000-$1FFF = both pattern table halves.
-- ($0000-$0FFF = first 256 tiles, $1000-$1FFF = second 256 tiles)

local OUT_BIN = "C:\\tmp\\fs_chr.bin"

print("dump_fs_chr: out=" .. OUT_BIN)

-- Advance past title screen (300 frames matches dump_fs_nametable.lua timing)
for f = 1, 300 do emu.frameadvance() end

-- Press Start to leave title screen (hold 2 frames, release)
joypad.set({ ["P1 Start"] = true }, 1)
emu.frameadvance()
joypad.set({}, 1)
emu.frameadvance()

-- Settle into File Select screen (118 frames, same as nametable dump)
for f = 1, 118 do emu.frameadvance() end

print("dump_fs_chr: at FS frame, framecount=" .. emu.framecount())

-- Dump 8KB PPU pattern table ($0000-$1FFF) from "PPU Bus" domain
local fh = assert(io.open(OUT_BIN, "wb"))
for i = 0, 0x1FFF do
    local v = memory.read_u8(i, "PPU Bus")
    fh:write(string.char(v))
end
fh:close()

print("dump_fs_chr: wrote 8192 bytes to " .. OUT_BIN)

-- Spot-check: print first tile ($0000-$000F) and tile at $1000 (second half start)
print("=== Spot check: tile 0 ($0000, plane0) ===")
local fh2 = assert(io.open(OUT_BIN, "rb"))
local raw = fh2:read("*a")
fh2:close()

-- Tile 0 low plane (bytes 0..7)
local t0_lo = ""
for i = 1, 8 do t0_lo = t0_lo .. string.format("%02X ", string.byte(raw, i)) end
print("tile0 lo: " .. t0_lo)

-- Tile 0 high plane (bytes 8..15)
local t0_hi = ""
for i = 9, 16 do t0_hi = t0_hi .. string.format("%02X ", string.byte(raw, i)) end
print("tile0 hi: " .. t0_hi)

-- Tile at $1000 offset = tile 256 = second pattern table start (byte 4097)
local t256_lo = ""
for i = 4097, 4104 do t256_lo = t256_lo .. string.format("%02X ", string.byte(raw, i)) end
print("tile256 ($1000) lo: " .. t256_lo)

-- Count non-zero bytes in each half to verify both halves populated
local nz_lo, nz_hi = 0, 0
for i = 1, 4096 do
    if string.byte(raw, i) ~= 0 then nz_lo = nz_lo + 1 end
end
for i = 4097, 8192 do
    if string.byte(raw, i) ~= 0 then nz_hi = nz_hi + 1 end
end
print(string.format("Non-zero bytes: $0000-$0FFF=%d  $1000-$1FFF=%d", nz_lo, nz_hi))

client.exit()

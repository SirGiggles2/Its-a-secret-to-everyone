-- vram_tile_dump.lua — dump Genesis VRAM bytes at tile slots used for
-- type $07 octorok (anim row $08 → tile $CE) and type $53 shot
-- (anim row $54 → tile $AA). NES tile -> Genesis tile via translate_tile:
--   NES $CE (>= $8E) → SCENE_OBJ base 1069 + ($CE-$8E)=$40 → Genesis 1133
--   NES $AA          → 1069 + ($AA-$8E)=$1C → Genesis 1097
-- Genesis tile N = VRAM bytes [N*32 .. N*32+31]
-- Boot, walk into $67 (force octorocks), then dump VRAM for the
-- relevant tile slots so we can see if atlas data lives there.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\vram_dump.txt"
local f = io.open(OUT, "w")

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)
for i=1,200 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(30)

local function dump_tile(tile_idx, label)
  local base = tile_idx * 32
  f:write(string.format("\n=== Genesis tile %d (%s, VRAM $%04X) ===\n",
    tile_idx, label, base))
  -- 8 rows × 4 bytes = 32 bytes
  for row=0,7 do
    f:write("  ")
    for col=0,3 do
      local byte = memory.read_u8(base + row*4 + col, "VRAM")
      f:write(string.format("%02X ", byte))
    end
    -- ASCII representation of the row (pixel pattern)
    f:write(" | ")
    for col=0,3 do
      local byte = memory.read_u8(base + row*4 + col, "VRAM")
      local hi = (byte >> 4) & 0x0F
      local lo = byte & 0x0F
      f:write((hi ~= 0) and "#" or ".")
      f:write((lo ~= 0) and "#" or ".")
    end
    f:write("\n")
  end
end

-- Octorok body tiles: NES $CE/$D2/$F0/$F4 (anim row 1: $5C,$9E,$44,$CE,$D2...)
-- Map each to Genesis tile via translate_tile.
-- For NES $CE: bank=$CE-$8E=$40, Genesis tile = 1069+64 = 1133
-- For NES $D2: bank=$D2-$8E=$44, Genesis tile = 1069+68 = 1137
-- For NES $F0: bank=$F0-$8E=$62, Genesis tile = 1069+98 = 1167
-- For NES $F4: bank=$F4-$8E=$66, Genesis tile = 1069+102 = 1171
dump_tile(1133, "NES $CE octorok top")
dump_tile(1134, "Genesis next slot (pairs with $CE in 8x16)")
dump_tile(1137, "NES $D2 octorok variant")
dump_tile(1138, "Genesis pair of $D2")

-- Shot rock tile: NES $AA → Genesis 1069+($AA-$8E)=$1C → 1097
dump_tile(1097, "NES $AA shot rock")
dump_tile(1098, "Genesis pair of $AA")
dump_tile(1099, "NES $AC slot")

-- Also dump common sprite block (NES tile $00..$8D maps 1:1 to SPR_BASE=1025)
dump_tile(1025, "SPR_BASE = NES tile $00")
dump_tile(1071, "NES tile $2E (random check)")

client.screenshot("C:\\tmp\\vram_dump.png")
idle(10)
client.exit()

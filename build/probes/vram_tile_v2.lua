-- vram_tile_v2.lua — fixed index calc. Dump correct tiles for shot + octorok.
-- type $07 RedOctorok: anim_idx=$08; k_obj_animations[$08]=$1B;
--   heap[$1B]=$B8; Genesis tile = 1069 + ($B8-$8E)=$2A = 1111
-- type $53 FlyingRock shot: anim_idx=$54; k_obj_animations[$54]=$09;
--   heap[$09]=$9E; Genesis tile = 1069 + ($9E-$8E)=$10 = 1085

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\vram_v2.txt"
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
  for row=0,7 do
    f:write("  ")
    for col=0,3 do
      local byte = memory.read_u8(base + row*4 + col, "VRAM")
      f:write(string.format("%02X ", byte))
    end
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

dump_tile(1085, "NES $9E = shot rock (type $53)")
dump_tile(1086, "$9F pair")
dump_tile(1111, "NES $B8 = octorok body (type $07 frame 0)")
dump_tile(1112, "$B9 pair")
-- Slot 19 = ENEMY_CUR_SPRITE_ATTR (frame variant)
dump_tile(1115, "NES $BC frame variant")
dump_tile(1116, "$BD pair")

-- Now check what nes_ram has for shot slot 11 OAM:
-- enemy_render_native_sweep emits SAT per s_enemy_entries[slot][n] which holds
-- {tile, attrs, x, y}. The TILE field is the NES tile id before translate.
-- We can dump SAT directly to see what tile_id the VDP renders.
-- Read SAT (sprite table at $F400 in VRAM, 8 bytes per entry).
-- Sprite slots 10+ used for enemies. Sprite link chain matters.
f:write("\n=== SAT slot 0..30 ===\n")
local sat_base = 0xF400
for s=0,30 do
  local off = sat_base + s * 8
  local y = memory.read_u8(off, "VRAM") * 256 + memory.read_u8(off+1, "VRAM")
  local size = memory.read_u8(off+2, "VRAM")
  local link = memory.read_u8(off+3, "VRAM")
  local tile_hi = memory.read_u8(off+4, "VRAM")
  local tile_lo = memory.read_u8(off+5, "VRAM")
  local tile = (tile_hi & 0x07) * 256 + tile_lo
  local pal = (tile_hi >> 5) & 0x03
  local x = memory.read_u8(off+6, "VRAM") * 256 + memory.read_u8(off+7, "VRAM")
  f:write(string.format("  slot %2d: Y=$%04X size=$%02X link=$%02X tile=$%03X pal=%d X=$%04X\n",
    s, y, size, link, tile, pal, x))
end

-- Dump CRAM (Genesis palette) to see PAL3 actual colors
f:write("\n=== CRAM (4 palettes × 16 entries × 2 bytes = 128 bytes) ===\n")
for pal=0,3 do
  f:write(string.format("PAL%d: ", pal))
  for col=0,15 do
    local addr = pal*32 + col*2
    local hi = memory.read_u8(addr, "CRAM")
    local lo = memory.read_u8(addr+1, "CRAM")
    f:write(string.format("$%02X%02X ", hi, lo))
  end
  f:write("\n")
end

client.screenshot("C:\\tmp\\vram_v2.png")
idle(10)
client.exit()

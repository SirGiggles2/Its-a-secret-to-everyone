-- T-CHR palette usage probe.
--
-- Goal: determine how many distinct NES BG sub-palettes (0..3) and NES sprite
-- sub-palettes (0..3) are actually referenced in each scene, so we can
-- architect the CRAM layout correctly.
--
-- For BG: scan the NES nametable attribute tables ($23C0-$23FF and
-- $2BC0-$2BFF) to find which 2-bit sub-palette values appear, and which are
-- the "hot" (majority) palette vs cold.
--
-- For sprites: scan OAM ($0200-$02FF in NES RAM) and count sub-palette usage
-- in the attribute byte (bits 1:0), excluding sprites with Y >= 240 (hidden).
--
-- Also dump the actual RGB colors written to $3F00-$3F1F at that scene so we
-- can see which palettes are non-zero (i.e., the game actually set them).
--
-- Samples 4 scenes: boot, title, intro (story), items.

local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/palette_usage.txt"
local f = io.open(OUT, "w")
f:write("# NES BG + sprite sub-palette usage probe\n\n")

f:write("# Available memory domains:\n")
local doms = memory.getmemorydomainlist()
for i = 1, #doms do f:write("#   " .. doms[i] .. "\n") end
f:write("\n")

-- Pick the VRAM/PPU domain name that actually exists.
local function find_dom(candidates)
  local present = {}
  for i = 1, #doms do present[doms[i]] = true end
  for _, name in ipairs(candidates) do
    if present[name] then return name end
  end
  return doms[1]  -- last-resort fallback
end

local VRAM_DOM   = find_dom({"PPU Bus", "CIRAM (nametables)", "VRAM", "PPU"})
local PALRAM_DOM = find_dom({"PALRAM", "Palette RAM", "PPU Bus"})
f:write("# VRAM_DOM=" .. VRAM_DOM .. "\n")
f:write("# PALRAM_DOM=" .. PALRAM_DOM .. "\n\n")

-- Offset adjustments: "PPU Bus" is indexed at absolute PPU addresses; other
-- domains are usually 0-based within their own space.
local function ppu_read(addr)
  if VRAM_DOM == "PPU Bus" then
    return memory.read_u8(addr, VRAM_DOM) or 0
  elseif VRAM_DOM == "CIRAM (nametables)" then
    -- CIRAM covers $2000-$2FFF, 0-based.
    return memory.read_u8(addr - 0x2000, VRAM_DOM) or 0
  else
    return memory.read_u8(addr, VRAM_DOM) or 0
  end
end

local function palram_read(addr)
  if PALRAM_DOM == "PALRAM" then
    return memory.read_u8(addr - 0x3F00, PALRAM_DOM) or 0
  else
    return memory.read_u8(addr, PALRAM_DOM) or 0
  end
end

local function dump_scene(label, target_frame)
  while emu.framecount() < target_frame do
    emu.frameadvance()
  end

  f:write(string.format("=== %s  frame=%d ===\n", label, emu.framecount()))

  -- ------- NES $3F00-$3F1F palette RAM content -------
  f:write("  NES palette RAM $3F00-$3F1F:\n")
  for base_offset = 0, 31, 4 do
    local line = string.format("    $3F%02X:", base_offset)
    for c = 0, 3 do
      local v = palram_read(0x3F00 + base_offset + c)
      line = line .. string.format(" %02X", v)
    end
    f:write(line .. "\n")
  end

  -- ------- NES BG nametable attribute usage -------
  local bg_counts = {[0]=0,[1]=0,[2]=0,[3]=0}
  local function count_attr_region(base)
    for i = 0, 63 do
      local byte = ppu_read(base + i)
      for q = 0, 3 do
        local p = (byte >> (q*2)) & 0x3
        bg_counts[p] = bg_counts[p] + 1
      end
    end
  end
  count_attr_region(0x23C0)  -- NT_A
  count_attr_region(0x2BC0)  -- NT_B
  f:write("  BG sub-palette quadrant counts (NT_A + NT_B, 512 total):\n")
  for p = 0, 3 do
    f:write(string.format("    pal %d: %d\n", p, bg_counts[p]))
  end

  -- ------- NES sprite (OAM) sub-palette usage -------
  -- OAM at NES $0200-$02FF (RAM). Each sprite = 4 bytes: Y, tile, attr, X.
  local sp_counts = {[0]=0,[1]=0,[2]=0,[3]=0}
  local sp_visible = 0
  for s = 0, 63 do
    local y = memory.read_u8(0x0200 + s*4, "RAM") or 0
    local attr = memory.read_u8(0x0200 + s*4 + 2, "RAM") or 0
    if y < 240 then
      sp_visible = sp_visible + 1
      local p = attr & 0x3
      sp_counts[p] = sp_counts[p] + 1
    end
  end
  f:write(string.format("  Sprite OAM: %d visible sprites (Y<240)\n", sp_visible))
  for p = 0, 3 do
    f:write(string.format("    sub-pal %d: %d sprites\n", p, sp_counts[p]))
  end

  f:write("\n")
end

dump_scene("boot",   90)
dump_scene("title",  600)
dump_scene("intro",  2000)
dump_scene("items",  2400)

f:close()
client.exit()

-- Dump top visible item-title tile rows plus palette state for one exact frame.
-- Used to diagnose the ALL OF TREASURES flourish color mismatch.

local system = emu.getsystemid() or "?"
local is_genesis = (system == "GEN" or system == "SAT")
local label = is_genesis and "gen" or "nes"
local target = tonumber(os.getenv("ITEM_TITLE_FRAME") or (is_genesis and "2303" or "2243")) or 0
local out = string.format(
  "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/item_title_palette_%s_f%05d.txt",
  label, target
)

local domains = {}
for _, name in ipairs(memory.getmemorydomainlist()) do
  domains[name] = true
end

local function pick_domain(candidates)
  for _, name in ipairs(candidates) do
    if domains[name] then return name end
  end
  return nil
end

local function framecount()
  local ok, v = pcall(function() return emu.framecount() end)
  return ok and v or 0
end

while framecount() < target do
  emu.frameadvance()
end

local f = assert(io.open(out, "w"))
f:write(string.format("system=%s frame=%d\n", system, framecount()))

if is_genesis then
  local ram_domain = pick_domain({"68K RAM", "M68K RAM", "M68K BUS"})
  local function rd8_68k(addr)
    if not ram_domain then return 0xFF end
    local off = addr - 0xFF0000
    if ram_domain == "M68K BUS" then off = addr end
    local ok, v = pcall(function() return memory.read_u8(off, ram_domain) end)
    return ok and v or 0xFF
  end
  local function rd16_be(addr, domain)
    local ok, v = pcall(function() return memory.read_u16_be(addr, domain) end)
    return ok and v or 0xFFFF
  end

  local vsram0 = rd16_be(0, "VSRAM")
  local cur_v = rd8_68k(0xFF00FC)
  local phase = rd8_68k(0xFF042C)
  local subphase = rd8_68k(0xFF042D)
  f:write(string.format("phase=%02X subphase=%02X curV=%02X vsram0=%04X\n", phase, subphase, cur_v, vsram0))

  f:write("cram palettes 0..3:\n")
  for pal = 0, 3 do
    f:write(string.format("  pal%d:", pal))
    for slot = 0, 15 do
      local cram_addr = pal * 0x20 + slot * 2
      f:write(string.format(" %04X", rd16_be(cram_addr, "CRAM")))
    end
    f:write("\n")
  end

  local base_pixel = vsram0 % 512
  f:write("visible top tile rows:\n")
  for screen_row = 0, 15 do
    local pixel_y = (base_pixel + screen_row * 8) % 512
    local plane_row = math.floor(pixel_y / 8) % 64
    local row_in_tile = pixel_y % 8
    f:write(string.format("  row%02d plane_row=%02d row_in_tile=%d\n", screen_row, plane_row, row_in_tile))
    for col = 0, 31 do
      local vram_addr = 0xC000 + plane_row * 0x80 + col * 2
      local word = rd16_be(vram_addr, "VRAM")
      local pal = math.floor(word / 0x2000) % 4
      local tile = word % 0x800
      f:write(string.format("    c%02d=%04X pal=%d tile=%03X\n", col, word, pal, tile))
    end
  end

  f:write("plane A fixed top rows:\n")
  for plane_row = 0, 7 do
    f:write(string.format("  arow%02d\n", plane_row))
    for col = 0, 31 do
      local vram_addr = 0xC000 + plane_row * 0x80 + col * 2
      local word = rd16_be(vram_addr, "VRAM")
      local pal = math.floor(word / 0x2000) % 4
      local tile = word % 0x800
      f:write(string.format("    c%02d=%04X pal=%d tile=%03X\n", col, word, pal, tile))
    end
  end

  f:write("plane A nonblank rows (compact):\n")
  for plane_row = 0, 63 do
    local cells = {}
    for col = 0, 31 do
      local vram_addr = 0xC000 + plane_row * 0x80 + col * 2
      local word = rd16_be(vram_addr, "VRAM")
      local tile = word % 0x800
      if tile ~= 0x124 then
        local pal = math.floor(word / 0x2000) % 4
        cells[#cells + 1] = string.format("c%02d=%03X/p%d", col, tile, pal)
      end
    end
    if #cells > 0 then
      f:write(string.format("  arow%02d %s\n", plane_row, table.concat(cells, " ")))
    end
  end

  f:write("window plane top rows:\n")
  for plane_row = 0, 7 do
    f:write(string.format("  wrow%02d\n", plane_row))
    for col = 0, 31 do
      local vram_addr = 0xB000 + plane_row * 0x40 + col * 2
      local word = rd16_be(vram_addr, "VRAM")
      local pal = math.floor(word / 0x2000) % 4
      local tile = word % 0x800
      f:write(string.format("    c%02d=%04X pal=%d tile=%03X\n", col, word, pal, tile))
    end
  end

  f:write("plane B visible top rows:\n")
  for screen_row = 0, 15 do
    local pixel_y = (screen_row * 8) % 256
    local plane_row = math.floor(pixel_y / 8) % 32
    f:write(string.format("  brow%02d plane_row=%02d\n", screen_row, plane_row))
    for col = 0, 31 do
      local vram_addr = 0xE000 + plane_row * 0x40 + col * 2
      local word = rd16_be(vram_addr, "VRAM")
      local pal = math.floor(word / 0x2000) % 4
      local tile = word % 0x800
      f:write(string.format("    c%02d=%04X pal=%d tile=%03X\n", col, word, pal, tile))
    end
  end
else
  local ciram = pick_domain({"CIRAM (nametables)", "CIRAM"})
  local palram = pick_domain({"PALRAM", "PalRAM"})
  local ram = pick_domain({"RAM"})
  local function rd8(addr, domain)
    if not domain then return 0xFF end
    local ok, v = pcall(function() return memory.read_u8(addr, domain) end)
    return ok and v or 0xFF
  end

  local cur_v = rd8(0x00FC, ram)
  local phase = rd8(0x042C, ram)
  local subphase = rd8(0x042D, ram)
  f:write(string.format("phase=%02X subphase=%02X curV=%02X ciram=%s palram=%s\n", phase, subphase, cur_v, tostring(ciram), tostring(palram)))

  f:write("palram 0..31:\n  ")
  for i = 0, 31 do
    f:write(string.format("%02X ", rd8(i, palram)))
  end
  f:write("\n")

  if ciram then
    f:write("nametable top rows:\n")
    for row = 0, 5 do
      f:write(string.format("  row%02d:", row))
      for col = 0, 31 do
        local nt = rd8(0x400 + row * 32 + col, ciram)
        f:write(string.format(" %02X", nt))
      end
      f:write("\n")
    end
    f:write("attr bytes 2BC0..2BFF:\n  ")
    for i = 0, 63 do
      f:write(string.format("%02X ", rd8(0x7C0 + i, ciram)))
      if i % 16 == 15 then f:write("\n  ") end
    end
    f:write("\n")
  end
end

f:close()
client.exit()

-- Dump detailed visible sprite state for one item-scroll frame on either
-- NES or Genesis. Used to diagnose wrong-heart / icon fidelity issues.

local system = emu.getsystemid() or "?"
local is_genesis = (system == "GEN" or system == "SAT")
local label = is_genesis and "gen" or "nes"

local target = tonumber(os.getenv("ITEM_PROBE_FRAME") or (is_genesis and "2302" or "2243")) or 0
local out = string.format(
  "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/item_probe_%s_f%05d.txt",
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

local ram_domain = nil
if is_genesis then
  ram_domain = pick_domain({"68K RAM", "M68K RAM", "M68K BUS"})
end

local function framecount()
  local ok, v = pcall(function() return emu.framecount() end)
  return ok and v or 0
end

local function rd_nes(addr)
  local ok, v = pcall(function() return memory.read_u8(addr, "RAM") end)
  return ok and v or 0xFF
end

local function rd_68k(addr)
  if not ram_domain then return 0xFF end
  local off = addr - 0xFF0000
  if ram_domain == "M68K BUS" then off = addr end
  local ok, v = pcall(function() return memory.read_u8(off, ram_domain) end)
  return ok and v or 0xFF
end

local function rd_shared(addr)
  if is_genesis then
    return rd_68k(0xFF0000 + addr)
  end
  return rd_nes(addr)
end

while framecount() < target do
  emu.frameadvance()
end

local f = assert(io.open(out, "w"))
f:write(string.format("system=%s frame=%d ramDomain=%s\n", system, framecount(), tostring(ram_domain)))
f:write(string.format("gameMode=%02X phase=%02X subphase=%02X curV=%02X line=%02X text=%02X vram=%02X%02X\n",
  rd_shared(0x0012), rd_shared(0x042C), rd_shared(0x042D), rd_shared(0x00FC),
  rd_shared(0x041B), rd_shared(0x042E), rd_shared(0x041D), rd_shared(0x041C)))

if is_genesis then
  local vs = 0xFFFF
  local ok, v = pcall(function() return memory.read_u16_be(0, "VSRAM") end)
  if ok then vs = v end
  f:write(string.format("vsram0=%04X ppuY=%02X introMode=%02X activeSeg=%02X\n",
    vs, rd_68k(0xFF0807), rd_68k(0xFF081F), rd_68k(0xFF083C)))
  f:write("visible OAM shadow sprites:\n")
  for i = 0, 63 do
    local base = 0x0200 + i * 4
    local y = rd_shared(base + 0)
    local tile = rd_shared(base + 1)
    local attr = rd_shared(base + 2)
    local x = rd_shared(base + 3)
    if y < 0xEF then
      f:write(string.format("  OAM%02d y=%3d x=%3d tile=%02X attr=%02X\n", i, y, x, tile, attr))
    end
  end
  f:write("visible SAT sprites:\n")
  for i = 0, 79 do
    local base = 0xF800 + i * 8
    local y = memory.read_u16_be(base + 0, "VRAM")
    local sl = memory.read_u16_be(base + 2, "VRAM")
    local tw = memory.read_u16_be(base + 4, "VRAM")
    local x = memory.read_u16_be(base + 6, "VRAM")
    if y >= 128 and y <= 352 and x >= 128 and x <= 448 then
      local pal = math.floor(tw / 8192) % 4
      f:write(string.format("  SPR%02d y=%3d x=%3d tile=%04X pal=%d size=%02X\n",
        i, y - 128, x - 128, tw, pal, math.floor(sl / 256)))
    end
  end
else
  local oam = pick_domain({"OAM"})
  f:write(string.format("oamDomain=%s\n", tostring(oam)))
  if oam then
    f:write("visible OAM sprites:\n")
    for i = 0, 63 do
      local base = i * 4
      local y = memory.read_u8(base + 0, oam)
      local tile = memory.read_u8(base + 1, oam)
      local attr = memory.read_u8(base + 2, oam)
      local x = memory.read_u8(base + 3, oam)
      if y < 0xEF then
        f:write(string.format("  OAM%02d y=%3d x=%3d tile=%02X attr=%02X\n", i, y, x, tile, attr))
      end
    end
  end
end

f:close()
client.exit()

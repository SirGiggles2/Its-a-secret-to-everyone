-- Run against the NES Zelda ROM.
-- Captures the first submenu episode with valid NES domains:
--   * screenshots every frame while submenu is active (+ a short tail)
--   * PALRAM snapshot per frame
--   * submenu/menu state from NES RAM
--
-- This replaces the old invalid "PPU" domain usage.

local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/nes_items"
local LOG = OUT .. "/nes_items.txt"
os.execute('mkdir "' .. OUT:gsub("/", "\\") .. '" 2>nul')

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

local PALRAM = pick_domain({"PALRAM", "Palette RAM"})
local OAMDOM = pick_domain({"OAM"})

local function ram_u8(addr)
  local ok, v = pcall(function() return memory.read_u8(addr, "RAM") end)
  return ok and v or 0xFF
end

local function pal_u8(idx)
  if not PALRAM then return 0xFF end
  local ok, v = pcall(function() return memory.read_u8(idx, PALRAM) end)
  return ok and v or 0xFF
end

local function visible_oam_count()
  if not OAMDOM then return -1 end
  local n = 0
  for i = 0, 63 do
    local y = memory.read_u8(i * 4 + 0, OAMDOM)
    if y < 0xEF then n = n + 1 end
  end
  return n
end

local function framecount()
  local ok, v = pcall(function() return emu.framecount() end)
  return ok and v or 0
end

local f = io.open(LOG, "w")
f:write(string.format("# PALRAM=%s OAM=%s\n", tostring(PALRAM), tostring(OAMDOM)))
f:write("# frame,menuState,pauseState,submenuProgress,curVScroll,ppuCtrl,switchReq,tileBufSel,oamVisible,"
  .. "BG0,BG1,BG2,BG3,SP0,SP1,SP2,SP3\n")

local seen_menu = false
local tail = 0

while framecount() < 6000 do
  emu.frameadvance()
  local frame = framecount()
  local menuState = ram_u8(0x00E1)
  local pauseState = ram_u8(0x00E0)
  local submenuProgress = ram_u8(0x005E)
  local curV = ram_u8(0x00FC)
  local ppuCtrl = ram_u8(0x00FF)
  local switchReq = ram_u8(0x005C)
  local tileBufSel = ram_u8(0x0014)

  if menuState ~= 0 then
    seen_menu = true
    tail = 8
  elseif seen_menu and tail > 0 then
    tail = tail - 1
  end

  if seen_menu then
    local pal = {}
    for i = 0, 31 do pal[i] = pal_u8(i) end
    f:write(string.format(
      "%05d,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%d,%02X%02X%02X%02X,%02X%02X%02X%02X,%02X%02X%02X%02X,%02X%02X%02X%02X,%02X%02X%02X%02X,%02X%02X%02X%02X,%02X%02X%02X%02X,%02X%02X%02X%02X\n",
      frame, menuState, pauseState, submenuProgress, curV, ppuCtrl, switchReq, tileBufSel,
      visible_oam_count(),
      pal[0], pal[1], pal[2], pal[3],
      pal[4], pal[5], pal[6], pal[7],
      pal[8], pal[9], pal[10], pal[11],
      pal[12], pal[13], pal[14], pal[15],
      pal[16], pal[17], pal[18], pal[19],
      pal[20], pal[21], pal[22], pal[23],
      pal[24], pal[25], pal[26], pal[27],
      pal[28], pal[29], pal[30], pal[31]
    ))
    client.screenshot(string.format("%s/nes_f%05d.png", OUT, frame))
    if menuState == 0 and tail == 0 then break end
  end
end

f:close()
client.exit()

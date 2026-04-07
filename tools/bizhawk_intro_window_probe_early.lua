-- Hardcoded early intro-window state probe.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local OUT_DIR = ROOT .. "builds/reports/intro_window_early"
local OUT_CSV = OUT_DIR .. "/intro_window_probe_early.csv"
local START_FRAME = 1455
local END_FRAME = 1472

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local DOMAINS = {}
for _, name in ipairs(memory.getmemorydomainlist()) do
  DOMAINS[name] = true
end

local RAM_DOMAIN = nil
if DOMAINS["68K RAM"] then
  RAM_DOMAIN = "68K RAM"
elseif DOMAINS["M68K BUS"] then
  RAM_DOMAIN = "M68K BUS"
end

local function rd8(addr)
  if not RAM_DOMAIN then
    return 0xFF
  end
  local ok, v = pcall(function() return memory.read_u8(addr, RAM_DOMAIN) end)
  return ok and v or 0xFF
end

local function rd16_ram(addr)
  if not RAM_DOMAIN then
    return 0xFFFF
  end
  local ok, v = pcall(function() return memory.read_u16_be(addr, RAM_DOMAIN) end)
  return ok and v or 0xFFFF
end

local function rd16_vsram(addr)
  if not DOMAINS["VSRAM"] then
    return 0xFFFF
  end
  local ok, v = pcall(function() return memory.read_u16_be(addr, "VSRAM") end)
  return ok and v or 0xFFFF
end

local fh = assert(io.open(OUT_CSV, "w"))
fh:write("frame,curVScroll,ppuScrlY,demoLineTextIndex,lineCounter,hintQCount,hintQ0Ctr,hintQ0Vsram,hintPendSplit,introScrollMode,stagedMode,stagedHintCtr,stagedBase,stagedEvent,vsram0\n")

while emu.framecount() < END_FRAME do
  emu.frameadvance()
  local frame = emu.framecount() or 0
  if frame >= START_FRAME then
    fh:write(string.format(
      "%d,%02X,%02X,%02X,%02X,%02X,%02X,%04X,%02X,%02X,%02X,%02X,%04X,%04X,%04X\n",
      frame,
      rd8(0x00FC),
      rd8(0x0807),
      rd8(0x042E),
      rd8(0x041B),
      rd8(0x0816),
      rd8(0x0817),
      rd16_ram(0x0818),
      rd8(0x081E),
      rd8(0x081F),
      rd8(0x080A),
      rd8(0x080B),
      rd16_ram(0x080C),
      rd16_ram(0x080E),
      rd16_vsram(0x0000)
    ))
  end
end

fh:close()
client.exit()

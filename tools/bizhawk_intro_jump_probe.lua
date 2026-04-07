-- Capture exact Genesis intro frames around suspected teleports.
-- Writes screenshots plus a CSV of the end-of-frame state needed to explain
-- whether a visible jump came from V-scroll, the H-int queue, or intro mode.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local OUT_DIR = ROOT .. "builds/reports/intro_jump_probe"
local OUT_CSV = OUT_DIR .. "/intro_jump_probe.csv"

local target_env = os.getenv("INTRO_TARGETS") or "1468,1469,1470,1471,1472,2622,2623,2624,2625"
local TARGETS = {}
for token in string.gmatch(target_env, "[^,%s]+") do
  local frame = tonumber(token)
  if frame then
    TARGETS[#TARGETS + 1] = frame
  end
end
table.sort(TARGETS)

local TARGET_SET = {}
for _, frame in ipairs(TARGETS) do
  TARGET_SET[frame] = true
end

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local DOMAINS = {}
for _, name in ipairs(memory.getmemorydomainlist()) do
  DOMAINS[name] = true
end

local RAM_DOMAIN = nil
if DOMAINS["68K RAM"] then
  RAM_DOMAIN = "68K RAM"
elseif DOMAINS["M68K RAM"] then
  RAM_DOMAIN = "M68K RAM"
elseif DOMAINS["M68K BUS"] then
  RAM_DOMAIN = "M68K BUS"
end

local function ram_addr(addr)
  if RAM_DOMAIN == "M68K BUS" then
    return 0xFF0000 + addr
  end
  return addr
end

local function rd8_ram(addr)
  if not RAM_DOMAIN then
    return 0xFF
  end
  local ok, v = pcall(function() return memory.read_u8(ram_addr(addr), RAM_DOMAIN) end)
  return ok and v or 0xFF
end

local function rd16_ram(addr)
  if not RAM_DOMAIN then
    return 0xFFFF
  end
  local ok, v = pcall(function() return memory.read_u16_be(ram_addr(addr), RAM_DOMAIN) end)
  return ok and v or 0xFFFF
end

local function rd16_vsram(addr)
  if not DOMAINS["VSRAM"] then
    return 0xFFFF
  end
  local ok, v = pcall(function() return memory.read_u16_be(addr, "VSRAM") end)
  return ok and v or 0xFFFF
end

local rows = {}

local function capture(frame)
  local row = {
    frame = frame,
    gameMode = rd8_ram(0x0012),
    phase = rd8_ram(0x042C),
    subphase = rd8_ram(0x042D),
    curVScroll = rd8_ram(0x00FC),
    curHScroll = rd8_ram(0x00FD),
    ppuScrlX = rd8_ram(0x0806),
    ppuScrlY = rd8_ram(0x0807),
    demoLineTextIndex = rd8_ram(0x042E),
    lineCounter = rd8_ram(0x041B),
    lineAttrIndex = rd8_ram(0x0419),
    lineDst = rd16_ram(0x041C),
    attrDst = rd16_ram(0x0417),
    switchReq = rd8_ram(0x005C),
    hintQCount = rd8_ram(0x0816),
    hintQ0Ctr = rd8_ram(0x0817),
    hintQ0Vsram = rd16_ram(0x0818),
    hintQ1Ctr = rd8_ram(0x081A),
    hintQ1Vsram = rd16_ram(0x081B),
    hintPendSplit = rd8_ram(0x081E),
    introScrollMode = rd8_ram(0x081F),
    activeBase = rd16_ram(0x0836),
    activeEvent = rd16_ram(0x0838),
    activeHintCtr = rd8_ram(0x083A),
    stagedSegment = rd8_ram(0x083B),
    activeSegment = rd8_ram(0x083C),
    vsram0 = rd16_vsram(0x0000),
    vsram1 = rd16_vsram(0x0002),
  }
  row.screenshot = string.format("%s/gen_f%05d.png", OUT_DIR, frame)
  client.screenshot(row.screenshot)
  rows[#rows + 1] = row
end

local last_target = TARGETS[#TARGETS] or 0
while (emu.framecount() or 0) < last_target do
  emu.frameadvance()
  local frame = emu.framecount() or 0
  if TARGET_SET[frame] then
    capture(frame)
  end
end

local fh = assert(io.open(OUT_CSV, "w"))
fh:write(table.concat({
  "frame", "gameMode", "phase", "subphase", "curVScroll", "curHScroll",
  "ppuScrlX", "ppuScrlY", "demoLineTextIndex", "lineCounter", "lineAttrIndex",
  "lineDst", "attrDst", "switchReq", "hintQCount", "hintQ0Ctr",
  "hintQ0Vsram", "hintQ1Ctr", "hintQ1Vsram", "hintPendSplit",
  "introScrollMode", "activeBase", "activeEvent", "activeHintCtr",
  "stagedSegment", "activeSegment", "vsram0", "vsram1", "screenshot"
}, ",") .. "\n")

for _, row in ipairs(rows) do
  fh:write(string.format(
    "%d,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%04X,%04X,%02X,%02X,%02X,%04X,%02X,%04X,%02X,%02X,%04X,%04X,%02X,%02X,%02X,%04X,%04X,%s\n",
    row.frame,
    row.gameMode,
    row.phase,
    row.subphase,
    row.curVScroll,
    row.curHScroll,
    row.ppuScrlX,
    row.ppuScrlY,
    row.demoLineTextIndex,
    row.lineCounter,
    row.lineAttrIndex,
    row.lineDst,
    row.attrDst,
    row.switchReq,
    row.hintQCount,
    row.hintQ0Ctr,
    row.hintQ0Vsram,
    row.hintQ1Ctr,
    row.hintQ1Vsram,
    row.hintPendSplit,
    row.introScrollMode,
    row.activeBase,
    row.activeEvent,
    row.activeHintCtr,
    row.stagedSegment,
    row.activeSegment,
    row.vsram0,
    row.vsram1,
    row.screenshot
  ))
end

fh:close()
client.exit()

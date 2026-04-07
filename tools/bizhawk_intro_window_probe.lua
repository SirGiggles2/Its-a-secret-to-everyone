-- Capture Genesis intro-scroll state every frame across the full intro window.
-- This is a lightweight companion to the canonical screenshot/trace capture:
-- it records H-int queue state and VSRAM fields that are not present in the
-- full trace so we can classify display-vs-content bugs across the whole run.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local OUT_DIR = ROOT .. "builds/reports/intro_window"
local OUT_CSV = OUT_DIR .. "/intro_window_probe.csv"
local START_FRAME = tonumber(os.getenv("INTRO_START") or "850")
local END_FRAME = tonumber(os.getenv("INTRO_END") or "3000")

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

local function ram_addr(addr)
  if RAM_DOMAIN == "M68K BUS" then
    return 0xFF0000 + addr
  end
  return addr
end

local function rd8(addr)
  if not RAM_DOMAIN then
    return 0xFF
  end
  local ok, v = pcall(function() return memory.read_u8(ram_addr(addr), RAM_DOMAIN) end)
  return ok and v or 0xFF
end

local function rd16_be(addr, domain)
  if domain == "VSRAM" and not DOMAINS["VSRAM"] then
    return 0xFFFF
  end
  if domain == "68K RAM" then
    if not RAM_DOMAIN then
      return 0xFFFF
    end
    domain = RAM_DOMAIN
    addr = ram_addr(addr)
  elseif not DOMAINS[domain] then
    return 0xFFFF
  end
  local ok, v = pcall(function() return memory.read_u16_be(addr, domain) end)
  return ok and v or 0xFFFF
end

local fh = assert(io.open(OUT_CSV, "w"))
fh:write(table.concat({
  "frame", "gameMode", "phase", "subphase", "curVScroll", "demoLineTextIndex",
  "demoNTWraps", "lineCounter", "lineAttrIndex", "lineDstLo", "lineDstHi",
  "attrDstLo", "attrDstHi", "switchReq", "ppuCtrl", "ppuScrlY", "vsram0",
  "hintQCount", "hintPendSplit", "introScrollMode", "activeHintCtr",
  "stagedSegment", "activeSegment", "activeBase", "activeEvent"
}, ",") .. "\n")

while emu.framecount() < END_FRAME do
  emu.frameadvance()
  local frame = emu.framecount() or 0
  if frame >= START_FRAME and frame <= END_FRAME then
    fh:write(string.format(
      "%d,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%04X,%02X,%02X,%02X,%02X,%02X,%02X,%04X,%04X\n",
      frame,
      rd8(0x0012), -- game mode
      rd8(0x042C), -- phase
      rd8(0x042D), -- subphase
      rd8(0x00FC), -- CurVScroll
      rd8(0x042E), -- DemoLineTextIndex
      rd8(0x0415), -- DemoNTWraps
      rd8(0x041B), -- lineCounter
      rd8(0x0419), -- lineAttrIndex
      rd8(0x041C), -- lineDstLo
      rd8(0x041D), -- lineDstHi
      rd8(0x0417), -- attrDstLo
      rd8(0x0418), -- attrDstHi
      rd8(0x005C), -- switchReq
      rd8(0x00FF), -- ppuCtrl
      rd8(0x0807), -- PPU_SCRL_Y shadow
      rd16_be(0, "VSRAM"),
      rd8(0x0816), -- HINT_Q_COUNT
      rd8(0x081E), -- HINT_PEND_SPLIT
      rd8(0x081F), -- INTRO_SCROLL_MODE
      rd8(0x083A), -- ACTIVE_HINT_CTR
      rd8(0x083B), -- STAGED_SEGMENT
      rd8(0x083C), -- ACTIVE_SEGMENT
      rd16_be(0x0836, "68K RAM"),
      rd16_be(0x0838, "68K RAM")
    ))
  end
end

fh:close()
client.exit()

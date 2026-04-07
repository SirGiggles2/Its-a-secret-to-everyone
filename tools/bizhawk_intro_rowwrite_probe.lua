-- Probe the translated intro story-scroll writer on Genesis.
-- Logs, per frame, which text line and destination rows were selected during
-- AnimateDemoPhase1Subphase2 so we can separate content-generation bugs from
-- display/split bugs.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local OUT_DIR = ROOT .. "builds/reports/intro_window"
local OUT_CSV = OUT_DIR .. "/intro_rowwrite_probe.csv"
local LST_PATH = ROOT .. "builds/whatif.lst"
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

local function find_symbol(name)
  for line in io.lines(LST_PATH) do
    local addr = line:match("^(%x+)%s+" .. name .. "%s*$")
    if addr then
      return tonumber(addr, 16)
    end
  end
  return nil
end

local ADDR_SUBPHASE2 = assert(find_symbol("AnimateDemoPhase1Subphase2"), "missing AnimateDemoPhase1Subphase2")
local ADDR_CLEARLINE = assert(find_symbol("_L_z02_AnimateDemoPhase1Subphase2_ClearLine"), "missing ClearLine")
local ADDR_ENDLINE = assert(find_symbol("_L_z02_AnimateDemoPhase1Subphase2_EndLine"), "missing EndLine")
local ADDR_PROCESS_ATTRS = assert(find_symbol("ProcessDemoLineAttrs"), "missing ProcessDemoLineAttrs")

-- Stable offsets inside the current P8-patched translated routine:
--   ClearLine + $14 = first read of ($041D,A4) before line-dst advance
--   ProcessDemoLineAttrs + $16 = first read of ($0418,A4) before attr-dst advance
local ADDR_LINE_DST_CAPTURE = ADDR_CLEARLINE + 0x14
local ADDR_ATTR_DST_CAPTURE = ADDR_PROCESS_ATTRS + 0x16

local recs = {}

local function ensure_frame(frame)
  local rec = recs[frame]
  if rec then
    return rec
  end
  rec = {
    subphase2_hits = 0,
    line_record_hit = 0,
    text_end_hit = 0,
    attr_record_hit = 0,
    demo_line_selected = 0xFF,
    plane_line_dst = 0xFFFF,
    attr_line_dst = 0xFFFF,
  }
  recs[frame] = rec
  return rec
end

local function note_frame()
  return (emu.framecount() or 0) + 1
end

event.onmemoryexecute(function()
  local rec = ensure_frame(note_frame())
  rec.subphase2_hits = rec.subphase2_hits + 1
end, ADDR_SUBPHASE2, "intro_rowwrite_subphase2", "M68K BUS")

event.onmemoryexecute(function()
  local rec = ensure_frame(note_frame())
  rec.line_record_hit = rec.line_record_hit + 1
  rec.plane_line_dst = (rd8(0x041D) << 8) | rd8(0x041C)
end, ADDR_LINE_DST_CAPTURE, "intro_rowwrite_line_dst", "M68K BUS")

event.onmemoryexecute(function()
  local rec = ensure_frame(note_frame())
  rec.text_end_hit = rec.text_end_hit + 1
  rec.demo_line_selected = rd8(0x042E)
end, ADDR_ENDLINE, "intro_rowwrite_endline", "M68K BUS")

event.onmemoryexecute(function()
  local rec = ensure_frame(note_frame())
  rec.attr_record_hit = rec.attr_record_hit + 1
  rec.attr_line_dst = (rd8(0x0418) << 8) | rd8(0x0417)
end, ADDR_ATTR_DST_CAPTURE, "intro_rowwrite_attr_dst", "M68K BUS")

local fh = assert(io.open(OUT_CSV, "w"))
fh:write(table.concat({
  "frame", "gameMode", "phase", "subphase", "curVScroll", "demoLineTextIndex",
  "demoNTWraps", "lineCounter", "lineAttrIndex", "lineDst", "attrDst",
  "switchReq", "subphase2Hits", "lineRecordHit", "demoLineSelected",
  "planeLineDst", "attrRecordHit", "attrLineDst", "lineAdvanced",
  "attrAdvanced", "ntWrapped"
}, ",") .. "\n")

local prev_line_dst = nil
local prev_attr_dst = nil
local prev_nt_wraps = nil
local prev_switch_req = nil

while emu.framecount() < END_FRAME do
  emu.frameadvance()
  local frame = emu.framecount() or 0
  local rec = ensure_frame(frame)
  local game_mode = rd8(0x0012)
  local phase = rd8(0x042C)
  local subphase = rd8(0x042D)
  local line_dst = (rd8(0x041D) << 8) | rd8(0x041C)
  local attr_dst = (rd8(0x0418) << 8) | rd8(0x0417)
  local demo_nt_wraps = rd8(0x0415)
  local switch_req = rd8(0x005C)

  local line_advanced = 0
  local attr_advanced = 0
  local nt_wrapped = 0
  if prev_line_dst ~= nil and line_dst ~= prev_line_dst then
    line_advanced = 1
  end
  if prev_attr_dst ~= nil and attr_dst ~= prev_attr_dst then
    attr_advanced = 1
  end
  if prev_nt_wraps ~= nil and demo_nt_wraps ~= prev_nt_wraps then
    nt_wrapped = 1
  end
  if prev_switch_req ~= nil and switch_req ~= prev_switch_req then
    nt_wrapped = 1
  end

  if frame >= START_FRAME and frame <= END_FRAME then
    fh:write(string.format(
      "%d,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%04X,%04X,%02X,%d,%d,%02X,%04X,%d,%04X,%d,%d,%d\n",
      frame,
      game_mode,
      phase,
      subphase,
      rd8(0x00FC),
      rd8(0x042E),
      demo_nt_wraps,
      rd8(0x041B),
      rd8(0x0419),
      line_dst,
      attr_dst,
      switch_req,
      rec.subphase2_hits or 0,
      rec.line_record_hit or 0,
      rec.demo_line_selected or 0xFF,
      rec.plane_line_dst or 0xFFFF,
      rec.attr_record_hit or 0,
      rec.attr_line_dst or 0xFFFF,
      line_advanced,
      attr_advanced,
      nt_wrapped
    ))
  end

  prev_line_dst = line_dst
  prev_attr_dst = attr_dst
  prev_nt_wraps = demo_nt_wraps
  prev_switch_req = switch_req
end

fh:close()
client.exit()

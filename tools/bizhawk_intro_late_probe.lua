-- Capture late-intro Genesis state at fixed target frames.
-- Writes one screenshot per target frame plus a CSV of end-of-frame state and
-- execute counts for _ags_flush, _ags_prearm, and HBlankISR.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local OUT_DIR = ROOT .. "builds/reports/intro_late_probe"
local OUT_CSV = OUT_DIR .. "/intro_late_probe_state.csv"

local TARGETS = {1508, 1772, 1901, 1965, 2147}
local TARGET_SET = {}
for _, frame in ipairs(TARGETS) do
  TARGET_SET[frame] = true
end

local ADDR_HBLANKISR = 0x00038C
local ADDR_AGS_FLUSH = 0x000524
local ADDR_AGS_PREARM = 0x0005BE

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

local function vdp_reg(reg)
  if not DOMAINS["VDP Regs"] then
    return 0xFF
  end
  local ok, v = pcall(function() return memory.read_u8(reg, "VDP Regs") end)
  return ok and v or 0xFF
end

local function get_cycles()
  return 0
end

local probe = {}
local frame_start_cycles = {}

local function ensure_frame(frame)
  local rec = probe[frame]
  if rec then
    return rec
  end
  rec = {
    ags_flush_hits = 0,
    ags_prearm_hits = 0,
    hblank_hits = 0,
    ags_flush_first = -1,
    ags_prearm_first = -1,
    hblank_first = -1,
  }
  probe[frame] = rec
  return rec
end

local function note_hit(frame, key_hits, key_first)
  if not TARGET_SET[frame] then
    return
  end
  local rec = ensure_frame(frame)
  rec[key_hits] = rec[key_hits] + 1
  if rec[key_first] < 0 then
    rec[key_first] = get_cycles()
  end
end

event.onmemoryexecute(function()
  note_hit((emu.framecount() or 0) + 1, "hblank_hits", "hblank_first")
end, ADDR_HBLANKISR, "intro_hblank")

event.onmemoryexecute(function()
  note_hit((emu.framecount() or 0) + 1, "ags_flush_hits", "ags_flush_first")
end, ADDR_AGS_FLUSH, "intro_ags_flush")

event.onmemoryexecute(function()
  note_hit((emu.framecount() or 0) + 1, "ags_prearm_hits", "ags_prearm_first")
end, ADDR_AGS_PREARM, "intro_ags_prearm")

local function sample_frame(frame)
  local rec = ensure_frame(frame)
  local start_cycles = frame_start_cycles[frame] or 0

  rec.game_mode = rd8(0x0012)
  rec.phase = rd8(0x042C)
  rec.subphase = rd8(0x042D)
  rec.cur_vscroll = rd8(0x00FC)
  rec.cur_hscroll = rd8(0x00FD)
  rec.demo_line_text = rd8(0x042E)
  rec.line_counter = rd8(0x041B)
  rec.line_attr_index = rd8(0x0419)
  rec.switch_req = rd8(0x005C)
  rec.ppu_ctrl = rd8(0x00FF)
  rec.ppu_scrl_x = rd8(0x0806)
  rec.ppu_scrl_y = rd8(0x0807)
  rec.hint_q_count = rd8(0x0816)
  rec.hint_q0_ctr = rd8(0x0817)
  rec.hint_q0_vsram = rd16_be(0x0818, "68K RAM")
  rec.hint_pend_split = rd8(0x081E)
  rec.vsram0 = rd16_be(0, "VSRAM")
  rec.vsram1 = rd16_be(2, "VSRAM")
  rec.vdp_r00 = vdp_reg(0)
  rec.vdp_r10 = vdp_reg(10)
  rec.vdp_r11 = vdp_reg(11)
  rec.vdp_r17 = vdp_reg(17)
  rec.vdp_r18 = vdp_reg(18)

  if rec.ags_flush_first >= 0 then
    rec.ags_flush_first = rec.ags_flush_first - start_cycles
  end
  if rec.ags_prearm_first >= 0 then
    rec.ags_prearm_first = rec.ags_prearm_first - start_cycles
  end
  if rec.hblank_first >= 0 then
    rec.hblank_first = rec.hblank_first - start_cycles
  end

  rec.screenshot = string.format("%s/gen_f%05d.png", OUT_DIR, frame)
  client.screenshot(rec.screenshot)
end

local last_target = TARGETS[#TARGETS]
while emu.framecount() < last_target do
  local next_frame = (emu.framecount() or 0) + 1
  if TARGET_SET[next_frame] then
    frame_start_cycles[next_frame] = get_cycles()
  end

  emu.frameadvance()

  local current = emu.framecount() or 0
  if TARGET_SET[current] then
    sample_frame(current)
  end
end

local fh = assert(io.open(OUT_CSV, "w"))
fh:write(table.concat({
  "frame", "gameMode", "phase", "subphase", "curVScroll", "curHScroll",
  "demoLineTextIndex", "lineCounter", "lineAttrIndex", "switchReq", "ppuCtrl",
  "ppuScrlX", "ppuScrlY", "vsram0", "vsram1", "hintQCount", "hintQ0Ctr",
  "hintQ0Vsram", "hintPendSplit", "vdpR00", "vdpR10", "vdpR11", "vdpR17",
  "vdpR18", "agsFlushHits", "agsFlushFirstRel", "agsPrearmHits",
  "agsPrearmFirstRel", "hblankHits", "hblankFirstRel", "screenshot"
}, ",") .. "\n")

for _, frame in ipairs(TARGETS) do
  local rec = ensure_frame(frame)
  fh:write(string.format(
    "%d,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%04X,%04X,%02X,%02X,%04X,%02X,%02X,%02X,%02X,%02X,%02X,%d,%d,%d,%d,%d,%d,%s\n",
    frame,
    rec.game_mode or 0xFF,
    rec.phase or 0xFF,
    rec.subphase or 0xFF,
    rec.cur_vscroll or 0xFF,
    rec.cur_hscroll or 0xFF,
    rec.demo_line_text or 0xFF,
    rec.line_counter or 0xFF,
    rec.line_attr_index or 0xFF,
    rec.switch_req or 0xFF,
    rec.ppu_ctrl or 0xFF,
    rec.ppu_scrl_x or 0xFF,
    rec.ppu_scrl_y or 0xFF,
    rec.vsram0 or 0xFFFF,
    rec.vsram1 or 0xFFFF,
    rec.hint_q_count or 0xFF,
    rec.hint_q0_ctr or 0xFF,
    rec.hint_q0_vsram or 0xFFFF,
    rec.hint_pend_split or 0xFF,
    rec.vdp_r00 or 0xFF,
    rec.vdp_r10 or 0xFF,
    rec.vdp_r11 or 0xFF,
    rec.vdp_r17 or 0xFF,
    rec.vdp_r18 or 0xFF,
    rec.ags_flush_hits or 0,
    rec.ags_flush_first or -1,
    rec.ags_prearm_hits or 0,
    rec.ags_prearm_first or -1,
    rec.hblank_hits or 0,
    rec.hblank_first or -1,
    rec.screenshot or ""
  ))
end

fh:close()
client.exit()

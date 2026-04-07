-- Log intro scroll pipeline hook order around the known bad windows.
-- This records which path actually calls _ags_apply_active for each target
-- frame: PREARM fallback, P1 SetScroll hook, or P2 post-game-logic hook.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local OUT_DIR = ROOT .. "builds/reports/intro_hook_probe"
local OUT_CSV = OUT_DIR .. "/intro_hook_probe.csv"

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

local LIST_PATH = ROOT .. "builds/whatif.lst"

local function load_list_text(path)
  local fh = io.open(path, "r")
  if not fh then return nil end
  local txt = fh:read("*a")
  fh:close()
  return txt
end

local function find_label_addr(txt, label)
  if not txt then return nil end
  local hex = txt:match("\n(%x+)%s+" .. label .. "\r?\n")
  if not hex then
    hex = txt:match("\r?\n(%x+)%s+" .. label .. "\r?\n")
  end
  return hex and tonumber(hex, 16) or nil
end

local function find_jsr_site(txt, label, comment_hint)
  if not txt then return nil end
  local pattern = "02:%x+ (%x+)%s+.-jsr%s+" .. label
  for line in txt:gmatch("[^\r\n]+") do
    if line:find("jsr%s+" .. label, 1, false) and (not comment_hint or line:find(comment_hint, 1, true)) then
      local addr = line:match("^02:(%x+)")
      if addr then return tonumber(addr, 16) end
    end
  end
  return nil
end

local list_txt = load_list_text(LIST_PATH)
local ADDR_PREARM = find_label_addr(list_txt, "_ags_prearm") or 0x00000760
local ADDR_APPLY_ACTIVE = find_label_addr(list_txt, "_ags_apply_active") or 0x000007DE
local ADDR_P1 = find_jsr_site(list_txt, "_apply_genesis_scroll", "Apply scroll shadows to VDP VSRAM/H-scroll") or 0x00019862
local ADDR_P2 = find_jsr_site(list_txt, "_apply_genesis_scroll", "P2: re-apply scroll after game logic") or 0x0001990E

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

local last_hook = "NONE"
local seq = 0
local rows = {}

local function capture(kind, hook, frame)
  if not TARGET_SET[frame] then
    return
  end
  seq = seq + 1
  rows[#rows + 1] = {
    seq = seq,
    frame = frame,
    kind = kind,
    hook = hook,
    phase = rd8_ram(0x042C),
    subphase = rd8_ram(0x042D),
    frameCounter = rd8_ram(0x0015),
    curVScroll = rd8_ram(0x00FC),
    ppuScrlY = rd8_ram(0x0807),
    ppuScrlX = rd8_ram(0x0806),
    ppuCtrl = rd8_ram(0x00FF),
    switchReq = rd8_ram(0x005C),
    stagedMode = rd8_ram(0x080A),
    stagedHintCtr = rd8_ram(0x080B),
    stagedBase = rd16_ram(0x080C),
    stagedEvent = rd16_ram(0x080E),
    activeMode = rd8_ram(0x081F),
    hintQCount = rd8_ram(0x0816),
    hintQ0Ctr = rd8_ram(0x0817),
    hintQ0Vsram = rd16_ram(0x0818),
    vsram0 = rd16_vsram(0x0000),
    vsram1 = rd16_vsram(0x0002),
  }
end

local function note_hook(hook)
  local frame = (emu.framecount() or 0) + 1
  last_hook = hook
  capture("hook", hook, frame)
end

event.onmemoryexecute(function()
  note_hook("PREARM")
end, ADDR_PREARM, "intro_prearm", "M68K BUS")

event.onmemoryexecute(function()
  note_hook("P1")
end, ADDR_P1, "intro_p1", "M68K BUS")

event.onmemoryexecute(function()
  note_hook("P2")
end, ADDR_P2, "intro_p2", "M68K BUS")

event.onmemoryexecute(function()
  local frame = (emu.framecount() or 0) + 1
  capture("apply", last_hook, frame)
end, ADDR_APPLY_ACTIVE, "intro_apply_active", "M68K BUS")

local last_target = TARGETS[#TARGETS] or 0
while (emu.framecount() or 0) < last_target do
  emu.frameadvance()
end

local fh = assert(io.open(OUT_CSV, "w"))
fh:write(table.concat({
  "seq", "frame", "kind", "hook", "phase", "subphase", "frameCounter", "curVScroll", "ppuScrlY", "ppuScrlX", "ppuCtrl", "switchReq",
  "stagedMode", "stagedHintCtr", "stagedBase", "stagedEvent", "activeMode",
  "hintQCount", "hintQ0Ctr", "hintQ0Vsram", "vsram0", "vsram1"
}, ",") .. "\n")

for _, row in ipairs(rows) do
  fh:write(string.format(
    "%d,%d,%s,%s,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%04X,%04X,%02X,%02X,%02X,%04X,%04X,%04X\n",
    row.seq,
    row.frame,
    row.kind,
    row.hook,
    row.phase,
    row.subphase,
    row.frameCounter,
    row.curVScroll,
    row.ppuScrlY,
    row.ppuScrlX,
    row.ppuCtrl,
    row.switchReq,
    row.stagedMode,
    row.stagedHintCtr,
    row.stagedBase,
    row.stagedEvent,
    row.activeMode,
    row.hintQCount,
    row.hintQ0Ctr,
    row.hintQ0Vsram,
    row.vsram0,
    row.vsram1
  ))
end

fh:close()
client.exit()

-- Force the active queue immediately after a chosen intro scroll hook on a
-- target frame. By default we hook the caller-side return immediately after
-- PREARM, which lets us test whether a vblank-time queued event can still move
-- the visible handoff before IsrNmi begins.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local OUT_DIR = ROOT .. "builds/reports/intro_prearm_handoff_probe"
local OUT_TXT = OUT_DIR .. "/probe_log.txt"

local TARGET_FRAME = tonumber(os.getenv("INTRO_TARGET_FRAME") or "1470")
local FORCE_VSRAM = tonumber(os.getenv("INTRO_FORCE_VSRAM") or "0")
local FORCE_CTR = tonumber(os.getenv("INTRO_FORCE_CTR") or "31")
local hook_env = os.getenv("INTRO_HOOK_ADDR") or "0x0000037C"
local ADDR_HOOK = tonumber(hook_env)
if not ADDR_HOOK then
  error("bad INTRO_HOOK_ADDR: " .. tostring(hook_env))
end

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local hit = false
local log_lines = {}
local DOMAINS = {}
for _, name in ipairs(memory.getmemorydomainlist()) do
  DOMAINS[name] = true
end

local function log(s)
  log_lines[#log_lines + 1] = s
end

local function wr16_ram(addr, value)
  local ok = pcall(function()
    memory.write_u16_be(addr, value, "68K RAM")
  end)
  return ok
end

local function wr8_ram(addr, value)
  local ok = pcall(function()
    memory.write_u8(addr, value, "68K RAM")
  end)
  return ok
end

local function wr8_vdp_reg(reg, value)
  if not DOMAINS["VDP Regs"] then
    return false
  end
  local ok = pcall(function()
    memory.write_u8(reg, value, "VDP Regs")
  end)
  return ok
end

event.onmemoryexecute(function()
  local frame = (emu.framecount() or 0) + 1
  if frame ~= TARGET_FRAME or hit then
    return
  end
  local ok_ctr = wr8_ram(0x0817, FORCE_CTR)
  local ok_vs = wr16_ram(0x0818, FORCE_VSRAM)
  local ok_cnt = wr8_ram(0x0816, 1)
  local ok_reg10 = wr8_vdp_reg(10, FORCE_CTR)
  hit = true
  log(string.format(
    "frame=%d hook=%06X ctr_ok=%s vs_ok=%s cnt_ok=%s reg10_ok=%s force_ctr=%02X force_vs=%04X",
    frame, ADDR_HOOK, tostring(ok_ctr), tostring(ok_vs), tostring(ok_cnt), tostring(ok_reg10),
    FORCE_CTR & 0xFF, FORCE_VSRAM & 0xFFFF
  ))
end, ADDR_HOOK, "intro_prearm_handoff_apply", "M68K BUS")

while (emu.framecount() or 0) < TARGET_FRAME do
  emu.frameadvance()
end

client.screenshot(string.format("%s/gen_f%05d_forced.png", OUT_DIR, TARGET_FRAME))

local fh = assert(io.open(OUT_TXT, "w"))
if not hit then
  fh:write(string.format("no_hit frame=%d hook=%06X\n", TARGET_FRAME, ADDR_HOOK))
end
for _, line in ipairs(log_lines) do
  fh:write(line .. "\n")
end
fh:close()
client.exit()

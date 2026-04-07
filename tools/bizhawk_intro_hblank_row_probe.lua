-- Override only HINT_Q0_VSRAM at P2 for a target frame, then capture that
-- frame. Comparing the result to the baseline same-frame screenshot shows the
-- actual row where the already-queued HBlank event lands.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local OUT_DIR = ROOT .. "builds/reports/intro_hblank_row_probe"
local OUT_TXT = OUT_DIR .. "/probe_log.txt"

local TARGET_FRAME = tonumber(os.getenv("INTRO_TARGET_FRAME") or "1470")
local FORCE_VSRAM = tonumber(os.getenv("INTRO_FORCE_VSRAM") or "0")
local FORCE_CTR = tonumber(os.getenv("INTRO_FORCE_CTR") or "-1")
local ADDR_P2 = 0x0001BA40

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local hit = false
local log_lines = {}

local function log(s)
  log_lines[#log_lines + 1] = s
end

local function wr16_ram(addr, value)
  local ok = pcall(function()
    memory.write_u16_be(addr, value, "68K RAM")
  end)
  return ok
end

local function wr8_vdp_reg(reg, value)
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
  local before = 0xFFFF
  local ok_read, v = pcall(function() return memory.read_u16_be(0x0818, "68K RAM") end)
  if ok_read then before = v end
  local before_ctr = 0xFF
  local ok_ctr, c = pcall(function() return memory.read_u8(0x0817, "68K RAM") end)
  if ok_ctr then before_ctr = c end
  local ok_write = wr16_ram(0x0818, FORCE_VSRAM)
  local ok_write_reg = true
  if FORCE_CTR >= 0 then
    pcall(function() memory.write_u8(0x0817, FORCE_CTR, "68K RAM") end)
    ok_write_reg = wr8_vdp_reg(10, FORCE_CTR)
  end
  local after = 0xFFFF
  local ok_after, v2 = pcall(function() return memory.read_u16_be(0x0818, "68K RAM") end)
  if ok_after then after = v2 end
  local after_ctr = 0xFF
  local ok_ctr2, c2 = pcall(function() return memory.read_u8(0x0817, "68K RAM") end)
  if ok_ctr2 then after_ctr = c2 end
  hit = true
  log(string.format(
    "frame=%d before=%04X write_ok=%s after=%04X ctr_before=%02X ctr_after=%02X reg10_write_ok=%s force_ctr=%d",
    frame, before, tostring(ok_write), after, before_ctr, after_ctr, tostring(ok_write_reg), FORCE_CTR
  ))
end, ADDR_P2, "intro_hblank_row_probe_p2", "M68K BUS")

while (emu.framecount() or 0) < TARGET_FRAME do
  emu.frameadvance()
end

client.screenshot(string.format("%s/gen_f%05d_forced.png", OUT_DIR, TARGET_FRAME))

local fh = assert(io.open(OUT_TXT, "w"))
for _, line in ipairs(log_lines) do
  fh:write(line .. "\n")
end
fh:close()
client.exit()

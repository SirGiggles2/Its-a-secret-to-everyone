-- Probe live HV counter reads from the VDP port during the bad intro frames.
-- If GPGX exposes the counter at $C00008/$C00009 on M68K BUS, this gives the
-- current scanline at PREARM/P1/P2/HBLANK without needing TotalExecutedCycles.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local OUT = ROOT .. "builds/reports/hv_counter_probe.txt"

local target_env = os.getenv("INTRO_TARGETS") or "1468,1469,1470,2622,2623,2624"
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

local ADDR_HBLANKISR = 0x0000038C
local ADDR_PREARM = 0x0000062C
local ADDR_P1 = 0x0001B968
local ADDR_P2 = 0x0001BA40

local lines = {}

local function rd8_bus(addr)
  local ok, v = pcall(function() return memory.read_u8(addr, "M68K BUS") end)
  return ok and v or 0xFF
end

local function rd16_bus(addr)
  local ok, v = pcall(function() return memory.read_u16_be(addr, "M68K BUS") end)
  return ok and v or 0xFFFF
end

local function sample(tag, frame)
  if not TARGET_SET[frame] then
    return
  end
  local hv = rd16_bus(0x00C00008)
  local h = rd8_bus(0x00C00008)
  local v = rd8_bus(0x00C00009)
  lines[#lines + 1] = string.format(
    "f%05d %-6s HV=%04X H=%02X V=%02X",
    frame, tag, hv, h, v
  )
end

event.onmemoryexecute(function()
  sample("PREARM", (emu.framecount() or 0) + 1)
end, ADDR_PREARM, "hv_prearm", "M68K BUS")

event.onmemoryexecute(function()
  sample("P1", (emu.framecount() or 0) + 1)
end, ADDR_P1, "hv_p1", "M68K BUS")

event.onmemoryexecute(function()
  sample("P2", (emu.framecount() or 0) + 1)
end, ADDR_P2, "hv_p2", "M68K BUS")

event.onmemoryexecute(function()
  sample("HBLANK", (emu.framecount() or 0) + 1)
end, ADDR_HBLANKISR, "hv_hblank", "M68K BUS")

local last_target = TARGETS[#TARGETS] or 0
while (emu.framecount() or 0) < last_target do
  emu.frameadvance()
end

local fh = assert(io.open(OUT, "w"))
for _, line in ipairs(lines) do
  fh:write(line .. "\n")
end
fh:close()
client.exit()

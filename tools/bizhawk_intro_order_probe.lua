-- Record the within-frame execution order of the intro scroll pipeline.
-- This answers whether HBlankISR's queued event fires before or after the
-- P1/P2 scroll hooks on the known bad frames.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local OUT = ROOT .. "builds/reports/intro_order_probe.txt"

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

local ADDR_HBLANKISR = 0x0000038C
local ADDR_PREARM = 0x0000062C
local ADDR_APPLY_ACTIVE = 0x00000688
local ADDR_P1 = 0x0001B968
local ADDR_P2 = 0x0001BA40

local lines = {}
local per_frame = {}

local function note(tag, frame)
  if not TARGET_SET[frame] then
    return
  end
  local seq = per_frame[frame] or 0
  seq = seq + 1
  per_frame[frame] = seq
  lines[#lines + 1] = string.format("f%05d #%02d %s", frame, seq, tag)
end

event.onmemoryexecute(function()
  note("HBLANK", (emu.framecount() or 0) + 1)
end, ADDR_HBLANKISR, "intro_order_hblank", "M68K BUS")

event.onmemoryexecute(function()
  note("PREARM", (emu.framecount() or 0) + 1)
end, ADDR_PREARM, "intro_order_prearm", "M68K BUS")

event.onmemoryexecute(function()
  note("APPLY", (emu.framecount() or 0) + 1)
end, ADDR_APPLY_ACTIVE, "intro_order_apply", "M68K BUS")

event.onmemoryexecute(function()
  note("P1", (emu.framecount() or 0) + 1)
end, ADDR_P1, "intro_order_p1", "M68K BUS")

event.onmemoryexecute(function()
  note("P2", (emu.framecount() or 0) + 1)
end, ADDR_P2, "intro_order_p2", "M68K BUS")

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

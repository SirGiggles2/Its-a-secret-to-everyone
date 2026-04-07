-- Hook the case-2 VSRAM initial write inside _apply_genesis_scroll and log
-- cycles-into-frame for each hit. Codex hypothesis: P2 call lands during
-- active display on alternating frames.
--
-- Target PCs in whatif.md build:
--   $0000061C = move.w D0,(VDP_DATA).l   (case-2 initial VSRAM write)
--   $00000660 = move.w D0,(VDP_DATA).l   (case-1 initial VSRAM write)
--   $00000502 = AGS entry
--
-- Gen NTSC: ~127840 cycles/frame, 262 lines × ~488 cycles/line.
-- Active display lines 0..223, VBlank lines 224..261.
-- If frame starts at top of active display: cycles 0..~109k = active, ~109k..127k = VBlank.
-- If frame starts at VBlank start (BizHawk convention is usually "end of VBlank = frame end"),
-- then cycles 0..~18k = VBlank end, ~18k..127k = active display.
-- Either way, a large relative difference between P1 and P2 cycles confirms the timing race.

local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/vsram_raster_gen.txt"

local frame = 0
local log_start = 2305
local log_end   = 2318
local hits = {}
local frame_start_cycles = 0

local function get_cycles()
  local ok, c = pcall(function() return emu.totalexecutedcycles() end)
  if ok and c then return c end
  return 0
end

local function get_d0()
  local ok, v = pcall(function() return emu.getregister("M68K D0") end)
  if ok and v then return v end
  return 0
end

local function log_hit(tag, pc)
  if frame < log_start or frame > log_end then return end
  local c = get_cycles()
  local rel = c - frame_start_cycles
  table.insert(hits, string.format("f=%05d tag=%-12s pc=%06X cyc_rel=%6d D0=%04X",
    frame, tag, pc or 0, rel, get_d0() % 0x10000))
end

local ok_exec = pcall(function()
  event.onmemoryexecute(function() log_hit("AGS_ENTER",    0x000502) end, 0x000502, "ags_enter",    "M68K BUS")
  event.onmemoryexecute(function() log_hit("CASE2_VSRAM",  0x00061C) end, 0x00061C, "case2_vsram",  "M68K BUS")
  event.onmemoryexecute(function() log_hit("CASE2_HINT",   0x00062E) end, 0x00062E, "case2_hint",   "M68K BUS")
  event.onmemoryexecute(function() log_hit("CASE1_VSRAM",  0x000660) end, 0x000660, "case1_vsram",  "M68K BUS")
end)

local f = io.open(OUT, "w")
f:write(string.format("ok_exec=%s\n", tostring(ok_exec)))

while frame < log_end do
  frame_start_cycles = get_cycles()
  emu.frameadvance()
  frame = frame + 1
end

f:write(string.format("total_hits=%d\n", #hits))
for _,h in ipairs(hits) do f:write(h .. "\n") end
f:close()
client.exit()

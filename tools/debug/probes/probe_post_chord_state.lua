-- probe_gameplay_state.lua — press A+B+C chord to enter ROOMROM gameplay,
-- then dump live state for 600 frames. NO pause at end.
-- Debug.md A4 = $FF8000 per platform_abi.h:14-21. nesram() adds 0x8000 offset.

local OUT = "C:\\tmp\\gameplay_state_report.txt"
local SHOT_DIR = "C:\\tmp\\gp_state\\"
os.execute("mkdir " .. SHOT_DIR .. " 2>NUL")

local function nesram(off) return memory.read_u8(0x8000 + off, "68K RAM") end
local function press(buttons, frames)
  for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
  for i = 1, frames do emu.frameadvance() end
end

-- Boot settle
idle(120)
client.screenshot(SHOT_DIR .. "frame_0120_title.png")

-- Press A+B+C chord (CHORD_DEBUG per a4_probe_main.c:15) to enter ROOMROM
-- Edge-trigger: hold all three for several frames so press is detected
press({A=true, B=true, C=true}, 8)
idle(8)
client.screenshot(SHOT_DIR .. "frame_0136_post_chord.png")

-- Capture post-chord state — should see roomrom_debug_tick running
local hist = {}
local trace = {}
local TRACE_EVERY = 30
local SHOT_EVERY = 100

local function log_frame(f)
  local gm   = nesram(0x0012)
  local sub  = nesram(0x0013)
  local lvl  = nesram(0x0010)
  local lx   = nesram(0x07F5)
  local ly   = nesram(0x07F6)
  local rm   = nesram(0x07F7)
  local fc   = nesram(0x0015)
  hist[gm] = (hist[gm] or 0) + 1
  if (f % TRACE_EVERY) == 0 then
    trace[#trace+1] = string.format(
      "f=%4d gm=$%02X sub=$%02X lvl=$%02X fc=$%02X lx=%3d ly=%3d rm=$%02X",
      f, gm, sub, lvl, fc, lx, ly, rm
    )
  end
  if (f % SHOT_EVERY) == 0 then
    client.screenshot(string.format("%sframe_%04d.png", SHOT_DIR, f))
  end
end

-- 600 frames post-chord
for f = 1, 200 do emu.frameadvance(); log_frame(f) end

-- Try movement: Right
press({Right=true}, 60)
for f = 201, 260 do log_frame(f) end

-- Try sword swing: A
press({A=true}, 4); idle(20)
for f = 261, 320 do log_frame(f) end

-- Up
press({Up=true}, 60)
for f = 321, 380 do log_frame(f) end

-- Down
press({Down=true}, 60)
for f = 381, 440 do log_frame(f) end

-- Left
press({Left=true}, 60)
for f = 441, 500 do log_frame(f) end

-- Sample PlayAreaTiles[$06A0..$06BF] (T0.4 collision buffer)
local play_area = {}
for off = 0x06A0, 0x06BF do
  play_area[#play_area+1] = string.format("$%04X=$%02X", off, nesram(off))
end

-- Sample link state cells
local link_state = {
  string.format("$0070(ObjX[0])=$%02X", nesram(0x0070)),
  string.format("$0084(ObjY[0])=$%02X", nesram(0x0084)),
  string.format("$008C(ObjDir[0])=$%02X", nesram(0x008C)),
  string.format("$00EB(CurRoomId)=$%02X", nesram(0x00EB)),
  string.format("$066F(Hearts)=$%02X", nesram(0x066F)),
  string.format("$0670(HeartPartial)=$%02X", nesram(0x0670)),
  string.format("$00F8(BtnsPressed)=$%02X", nesram(0x00F8)),
  string.format("$00FA(BtnsDown)=$%02X", nesram(0x00FA)),
}

local f = io.open(OUT, "w")
f:write("probe_gameplay_state report — " .. os.date() .. "\n")
f:write("Boot: settle 120f -> A+B+C chord 8f -> idle 8f -> 500 gameplay frames\n")
f:write("Debug.md A4=$FF8000 (nesram = 0x8000+off in 68K RAM domain)\n")
f:write("===========================================================\n\n")

f:write("GAMEMODE ($FF8012) HISTOGRAM over 500 post-chord frames:\n")
f:write("-----------------------------------------------------\n")
local sorted_keys = {}
for k in pairs(hist) do sorted_keys[#sorted_keys+1] = k end
table.sort(sorted_keys)
for _, k in ipairs(sorted_keys) do
  f:write(string.format("  $%02X = %4d frames\n", k, hist[k]))
end
f:write("\n")

f:write("PER-30-FRAME TRACE:\n")
f:write("-------------------\n")
for _, line in ipairs(trace) do f:write(line .. "\n") end
f:write("\n")

f:write("Link / input state cells at frame 500:\n")
f:write("--------------------------------------\n")
for _, line in ipairs(link_state) do f:write("  " .. line .. "\n") end
f:write("\n")

f:write("PlayAreaTiles[$06A0..$06BF] at frame 500:\n")
f:write("-----------------------------------------\n")
f:write(table.concat(play_area, " ") .. "\n\n")

-- Verdict
local park_at = nil
local max_frames = 0
for k, v in pairs(hist) do
  if v > max_frames then max_frames = v; park_at = k end
end
f:write(string.format("VERDICT: dominant GameMode = $%02X (%d frames out of 500)\n",
  park_at or 0, max_frames))
if park_at == 0x05 then
  f:write("  -> Mode 5 Play active. roomrom_debug_tick running.\n")
elseif park_at == 0xCD then
  f:write("  -> Stuck at $CD sentinel. Chord likely not registered.\n")
elseif park_at == 0x0C then
  f:write("  -> Mode C park (rare in stub dispatcher).\n")
else
  f:write(string.format("  -> Unexpected: $%02X\n", park_at))
end

f:close()
print("Wrote " .. OUT)
-- NO client.pause(). Let user keep playing.

-- Advance to a target frame, overlay a label, then pause the emulator.
-- Used for side-by-side visual comparisons between two ROM builds.

local TARGET = tonumber(os.getenv("INTRO_FRAME") or "1901")
local LABEL = os.getenv("COMPARE_LABEL") or "BUILD"
local SCREENSHOT = os.getenv("COMPARE_SHOT") or ""

local done = false

local function overlay()
  gui.text(4, 4, string.format("%s  f=%05d", LABEL, emu.framecount() or 0), "yellow", "black")
end

event.onframeend(function()
  overlay()
  if done then
    return
  end
  if (emu.framecount() or 0) >= TARGET then
    if SCREENSHOT ~= "" then
      client.screenshot(SCREENSHOT)
    end
    print(string.format("[compare] %s paused at frame %d", LABEL, emu.framecount() or 0))
    client.pause()
    done = true
  end
end)

while not done do
  emu.frameadvance()
end

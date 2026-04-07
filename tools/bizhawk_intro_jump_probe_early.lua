-- Hardcoded early-story jump probe.
-- We use a dedicated script here because BizHawk's env var handoff for
-- os.getenv("INTRO_TARGETS") has been flaky in this setup.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local OUT_DIR = ROOT .. "builds/reports/intro_jump_probe_early"
local TARGETS = {1468, 1469, 1470, 1471, 1472}

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local target_set = {}
for _, frame in ipairs(TARGETS) do
  target_set[frame] = true
end

local last_target = TARGETS[#TARGETS]
while (emu.framecount() or 0) < last_target do
  emu.frameadvance()
  local frame = emu.framecount() or 0
  if target_set[frame] then
    client.screenshot(string.format("%s/gen_f%05d.png", OUT_DIR, frame))
  end
end

client.exit()

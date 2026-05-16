-- cave_pause_smoke.lua — Tier 0 verify: cave entry + pause freeze.
-- Boots Debug.md → A+B+C debug entry → walks Link onto an OW cave-
-- entrance tile (Down toward known stairs at room 0x77) → snapshots
-- SCENE state. Then presses START to pause, walks (input should be
-- swallowed), unpauses, snapshots. Outputs:
--   C:\tmp\cave_pause\pre.png       — pre-entry OW
--   C:\tmp\cave_pause\cave.png      — after stepping on entrance
--   C:\tmp\cave_pause\paused.png    — paused + attempted-walk frame
--   C:\tmp\cave_pause\unpaused.png  — resumed
--   C:\tmp\cave_pause\report.log    — NES cells, scene transitions

local OUTDIR = "C:\\tmp\\cave_pause\\"
os.execute("mkdir " .. OUTDIR .. " 2>NUL")

local function press(buttons, frames)
    for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
    for i = 1, frames do emu.frameadvance() end
end
local function nesram(off) return memory.read_u8(0x8000 + off, "68K RAM") end

idle(60)
press({A=true, B=true, C=true}, 30)
idle(180)

-- Pre snapshot.
client.screenshot(OUTDIR .. "pre.png")
local pre_scene  = nesram(0x0010)
local pre_room   = nesram(0x00EB)
local pre_x      = nesram(0x0070)
local pre_y      = nesram(0x0084)
local pre_cave   = nesram(0x0350)

-- NES Z1 starting room 0x77 cave mouth is north-center (visible black
-- rectangle in trees ~y=50, x=80). Walk UP toward it.
press({Up=true}, 120)
idle(30)
client.screenshot(OUTDIR .. "cave.png")
local mid_scene  = nesram(0x0010)
local mid_room   = nesram(0x00EB)
local mid_x      = nesram(0x0070)
local mid_y      = nesram(0x0084)
local mid_cave   = nesram(0x0350)

-- Continue walking Up + slight Left/Right to align with cave mouth.
press({Up=true}, 60)
idle(15)
press({Up=true, Left=true}, 30)
idle(15)
client.screenshot(OUTDIR .. "post_walk.png")
local walk_scene = nesram(0x0010)
local walk_room  = nesram(0x00EB)
local walk_cave  = nesram(0x0350)

-- Verify pause: press START to pause.
press({Start=true}, 3)
idle(2)
local pause_state_on = memory.read_u8(0xE0, "68K RAM")  -- guess: g_paused near $00E0
-- Better: read C-side g_paused — find via NES Z1 convention $00E0 OR
-- via the s_scene/control state. Try also $00FB which is a known
-- Genesis sentinel area.

-- Hold Down while paused — Link should NOT move
local pre_link_x = nesram(0x0070)
local pre_link_y = nesram(0x0084)
press({Down=true}, 30)
local post_link_x = nesram(0x0070)
local post_link_y = nesram(0x0084)
client.screenshot(OUTDIR .. "paused.png")

-- Un-pause: START again. Release joypad first to clear edge state.
joypad.set({}, 1); emu.frameadvance()
press({Start=true}, 3)
joypad.set({}, 1); emu.frameadvance()
idle(2)
-- Walk Up + Right — Link should move now (open OW directions).
press({Up=true}, 30)
local unpause_x = nesram(0x0070)
local unpause_y = nesram(0x0084)
client.screenshot(OUTDIR .. "unpaused.png")

-- Report.
local f = io.open(OUTDIR .. "report.log", "w")
f:write("cave_pause_smoke — Tier 0 verify\n")
f:write("================================\n\n")

f:write("Boot/initial state:\n")
f:write(string.format("  $0010 SCENE        = $%02X\n", pre_scene))
f:write(string.format("  $00EB ROOM         = $%02X\n", pre_room))
f:write(string.format("  $0070 Link X       = $%02X\n", pre_x))
f:write(string.format("  $0084 Link Y       = $%02X\n", pre_y))
f:write(string.format("  $0350 CaveRoomType = $%02X\n\n", pre_cave))

f:write("After walk-Down 60 frames:\n")
f:write(string.format("  $0010 SCENE        = $%02X\n", mid_scene))
f:write(string.format("  $00EB ROOM         = $%02X\n", mid_room))
f:write(string.format("  $0070 Link X       = $%02X\n", mid_x))
f:write(string.format("  $0084 Link Y       = $%02X\n", mid_y))
f:write(string.format("  $0350 CaveRoomType = $%02X\n\n", mid_cave))

f:write("After walk path:\n")
f:write(string.format("  $0010 SCENE        = $%02X\n", walk_scene))
f:write(string.format("  $00EB ROOM         = $%02X\n", walk_room))
f:write(string.format("  $0350 CaveRoomType = $%02X (NOTE: alias enemy slot 1 type)\n", walk_cave))
local cave_fire_ctr = nesram(0x07FC)
local last_tile    = nesram(0x07FD)
f:write(string.format("  $07FC cave-entry fires  = %d\n", cave_fire_ctr))
f:write(string.format("  $07FD last-standing-tile = $%02X\n", last_tile))
local cave_entered = (cave_fire_ctr > 0)
f:write(string.format("  CAVE ENTERED (sentinel-verified): %s\n\n", cave_entered and "YES" or "NO"))

f:write("Pause freeze test:\n")
f:write(string.format("  Pre-hold Link X/Y    = $%02X/$%02X\n", pre_link_x, pre_link_y))
f:write(string.format("  Post-hold Link X/Y   = $%02X/$%02X\n", post_link_x, post_link_y))
local pause_works = (pre_link_x == post_link_x) and (pre_link_y == post_link_y)
f:write(string.format("  PAUSE FREEZES LINK:  %s\n\n",
    pause_works and "YES" or "NO (Link moved while paused)"))

f:write("Un-pause resume test:\n")
f:write(string.format("  Post-unpause Link X/Y = $%02X/$%02X\n", unpause_x, unpause_y))
local resume_works = (unpause_x ~= post_link_x) or (unpause_y ~= post_link_y)
f:write(string.format("  UNPAUSE RESUMES MOTION: %s\n\n",
    resume_works and "YES" or "NO (Link still frozen after un-pause)"))

f:write("OVERALL VERDICT:\n")
f:write(string.format("  T0.1 cave entry:  %s\n", cave_entered and "PASS" or "FAIL"))
f:write(string.format("  T0.2 pause freeze: %s\n", pause_works and "PASS" or "FAIL"))
f:write(string.format("  T0.2 un-pause:    %s\n", resume_works and "PASS" or "FAIL"))

f:close()
gui.text(8, 8, "cave_pause smoke done")
client.exit()

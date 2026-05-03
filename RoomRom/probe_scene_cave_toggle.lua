-- probe_scene_cave_toggle.lua
-- Phase 3 cave port harness: verify SCENE_CAVE wiring in RoomRom main.c.
--
-- Sequence:
--   1. Boot RoomRom (default scene = SCENE_UW).
--   2. Press START to toggle SCENE_UW -> SCENE_OW.
--   3. Capture OW screenshot.
--   4. Hold C + press START -> SCENE_CAVE (cave_init(0x6A)).
--   5. Tick ~30 frames in cave_tick (currently a stub — visual stays
--      OW, but main loop stays in SCENE_CAVE branch and doesn't crash).
--   6. Capture in-cave screenshot.
--   7. Hold C + press START -> SCENE_OW (cave_exit).
--   8. Capture post-exit screenshot.
--
-- Pass criteria: 3 PNGs written, EmuHawk doesn't hang or crash, frame
-- count advances normally throughout. Visual identity OW/in-cave/post-
-- exit is expected (cave_tick stub) — Phase 4 native object_draw
-- changes that.
--
-- Usage: invoke via /bizhawkScript skill with this file as arg.

local OUT_DIR = os.getenv("ROOMROM_PROBE_OUT") or "C:\\tmp"

local function press(buttons, frames)
    for _ = 1, frames do
        joypad.set(buttons, 1)
        emu.frameadvance()
    end
end

local function release(frames)
    for _ = 1, frames do
        joypad.set({}, 1)
        emu.frameadvance()
    end
end

local function shot(name)
    local path = OUT_DIR .. "\\" .. name
    local ok, err = pcall(function() client.screenshot(path) end)
    if not ok then
        print("screenshot failed: " .. tostring(err))
    else
        print("captured: " .. path)
    end
end

-- 1. Settle boot
release(120)
shot("roomrom_cave_probe_01_boot_uw.png")

-- 2. Toggle SCENE_UW -> SCENE_OW
press({Start = true}, 1)
release(20)
shot("roomrom_cave_probe_02_ow.png")

-- 3. Hold C + tap START -> SCENE_CAVE
joypad.set({C = true}, 1); emu.frameadvance()           -- C only, get C into joy state
joypad.set({C = true, Start = true}, 1); emu.frameadvance()  -- C held, START edge
joypad.set({C = true}, 1); emu.frameadvance()           -- release START, keep C held briefly
release(40)
shot("roomrom_cave_probe_03_in_cave.png")

-- 4. Hold C + tap START -> SCENE_OW (exit)
joypad.set({C = true}, 1); emu.frameadvance()
joypad.set({C = true, Start = true}, 1); emu.frameadvance()
joypad.set({C = true}, 1); emu.frameadvance()
release(40)
shot("roomrom_cave_probe_04_post_exit.png")

print("probe_scene_cave_toggle complete")

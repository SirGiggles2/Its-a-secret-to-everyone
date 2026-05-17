-- nes_ow_capture.lua — drive NES Z1 from boot to overworld scene with
-- name registered, then capture room $77 (boot OW) + a scrolled scene.
-- Avoids the inventory-screen trap by using a tighter button cadence
-- matched to NES file select state machine.

local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn, hold, gap)
  hold = hold or 4
  gap = gap or 6
  for _=1,hold do joypad.set({[btn]=true}, 1); emu.frameadvance() end
  for _=1,gap do joypad.set({}, 1); emu.frameadvance() end
end

-- 1) Boot title — wait for it to appear, Start to file select
idle(240)        -- boot logo + title intro
tap("Start", 4, 30)
idle(30)
tap("Start", 4, 30)   -- title → file select

-- 2) File select: register a name on slot 1
--    Cursor starts at "1. NAME 1". Press Start to "Register your name".
--    Actually default cursor sequence: 1, 2, 3, Register, Elimination
--    Move down 3 times to reach "Register your name"
for _=1,3 do tap("Down", 4, 6) end
tap("Start", 4, 30)
idle(60)

-- 3) Register screen: cursor on letter grid. To get to "End", move
--    down/right past the grid. Simplest: hold Down a while then Start.
for _=1,6 do tap("Down", 4, 4) end
tap("Start", 4, 30)   -- accept name (likely "A" or default)
idle(60)

-- 4) Back to file select with slot 1 populated. Cursor near top now.
--    Press Start to go to slot 1, then Start to begin.
tap("Up", 4, 6)
tap("Up", 4, 6)
tap("Up", 4, 6)
tap("Up", 4, 6)
tap("Start", 4, 30)
idle(60)
tap("Start", 4, 30)   -- begin game
idle(120)

-- 5) Should be in OW room $77 now. Screenshot.
client.screenshot("C:\\tmp\\nes_ref_ow.png")

-- 6) Walk up a few rooms
for _=1,300 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(60)
client.screenshot("C:\\tmp\\nes_ref_ow_scrolled.png")

idle(20)
client.exit()

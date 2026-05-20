-- Boot NES Z1, nav to OW gameplay, poke ALL items, leave running.
-- User can press Start to view inventory subscreen.

local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn, hold, gap)
  hold = hold or 4; gap = gap or 6
  for _=1,hold do joypad.set({[btn]=true}, 1); emu.frameadvance() end
  for _=1,gap do joypad.set({}, 1); emu.frameadvance() end
end
local function W(addr, val) memory.writebyte(addr, val, "RAM") end

idle(240)
tap("Start", 4, 30); idle(30)
tap("Start", 4, 30)
for _=1,3 do tap("Down", 4, 6) end
tap("Start", 4, 30); idle(60)
for _=1,6 do tap("Down", 4, 4) end
tap("Start", 4, 30); idle(60)
for _=1,4 do tap("Up", 4, 6) end
tap("Start", 4, 30); idle(60)
tap("Start", 4, 30); idle(120)

-- Poke ALL items + max counts
W(0x0656, 0x00)  -- SelectedItemSlot = boomerang
W(0x0657, 0xFF)  -- Items bitfield
W(0x0658, 0x10)  -- Bombs = 16
W(0x0659, 0x02)  -- Arrow = silver
W(0x065A, 0x01)  -- Bow
W(0x065B, 0x02)  -- Candle = red
W(0x065C, 0x01)  -- Recorder
W(0x065D, 0x01)  -- Food
W(0x065E, 0x02)  -- Potion = red
W(0x065F, 0x01)  -- Wand
W(0x0660, 0x01)  -- Raft
W(0x0661, 0x01)  -- Book
W(0x0662, 0x02)  -- Ring
W(0x0663, 0x01)  -- Ladder
W(0x0664, 0x01)  -- MagicKey
W(0x0665, 0x01)  -- Bracelet
W(0x0666, 0x01)  -- Letter
W(0x0667, 0xFF)  -- Compass Q1
W(0x0668, 0xFF)  -- Map Q1
W(0x0669, 0xFF)  -- Compass L9
W(0x066A, 0xFF)  -- Map L9
W(0x066B, 0xFF)  -- HeartPieces
W(0x066C, 0x10)  -- MaxBombs
W(0x066D, 0xFF)  -- Rupees
W(0x066E, 0x63)  -- Keys = 99
W(0x066F, 0xFF)  -- HeartContainers
W(0x0670, 0x00)
W(0x0671, 0xFF)  -- Triforce
W(0x0674, 0x02)  -- BoomerangWood (lvl 2 = magic)
W(0x0675, 0x01)  -- BoomerangMagic
W(0x0676, 0x01)  -- MagicShield

print("All items poked. Press Start to view inventory.")
-- DO NOT call client.exit() — leave running for user.

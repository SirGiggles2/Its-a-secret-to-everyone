-- nes_reference_capture.lua — capture NES Zelda 1 reference shots.
-- 1. Boot NES ROM, press Start past title, name file select Start, register
-- 2. Press Start to enter game
-- 3. Walk into OW
-- 4. Screenshot OW + post-scroll OW
-- (memory.read needs different domain for NES)

local function idle(n) for _=1,n do emu.frameadvance() end end

idle(60)
-- press Start to skip title
for i=1,10 do joypad.set({Start=true}, 1); emu.frameadvance() end
idle(30)
-- choose name register slot 1 → press Down then Start
for i=1,4 do joypad.set({Down=true}, 1); emu.frameadvance(); idle(3) end
idle(20)
for i=1,5 do joypad.set({Start=true}, 1); emu.frameadvance() end
idle(60)
-- type one letter in register, then Down to "End" / Start
for i=1,30 do joypad.set({Start=true}, 1); emu.frameadvance() end
idle(30)
-- back to file select, Start enters game
for i=1,10 do joypad.set({Start=true}, 1); emu.frameadvance() end
idle(60)

client.screenshot("C:\\tmp\\nes_ref_boot.png")

-- Walk down to leave start cave
for i=1,200 do joypad.set({Down=true}, 1); emu.frameadvance() end
idle(60)
client.screenshot("C:\\tmp\\nes_ref_ow.png")

idle(30)
client.exit()

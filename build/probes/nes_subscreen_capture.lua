-- nes_subscreen_capture.lua v2 — NES Z1: boot to OW, force ACTIVE subscreen
-- state, dump screenshot + PALRAM + nametable + OAM + CPU RAM.
--
-- Robustness fixes from v1:
--   - Detect MenuState BEFORE pressing Start (file select flow sometimes
--     auto-opens subscreen depending on save slot state)
--   - Poke items into inventory RAM cells so subscreen shows full kit
--     (matches Genesis Debug.md debug_unlock_all_items)
--   - Wait for MenuState to STABILIZE (non-zero + 30 frames same value)
--
-- Output: $CODEX_BIZHAWK_ROOT/nes_subscreen/

local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/nes_subscreen"
os.execute("mkdir " .. OUT:gsub("/","\\") .. " 2>nul")

local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn, hold, gap)
  hold = hold or 4; gap = gap or 6
  for _=1,hold do joypad.set({[btn]=true}, 1); emu.frameadvance() end
  for _=1,gap do joypad.set({}, 1); emu.frameadvance() end
end
local function R(addr) return memory.read_u8(addr, "RAM") end
local function W(addr, val) memory.writebyte(addr, val, "RAM") end
local function P(addr) return memory.read_u8(addr, "PPU Bus") end
local function PAL(off) return memory.read_u8(off, "PALRAM") end

-- Boot + nav (same as nes_ow_capture.lua)
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

local room_pre = R(0x00EB)
local menu_pre = R(0x00E1)
print(string.format("Post-nav room $%02X MenuState=$%02X", room_pre, menu_pre))

-- Force MenuState to $00 (gameplay) first — if subscreen already open from
-- nav, close it
if menu_pre ~= 0 then
  tap("Start", 4, 30); idle(60)
  -- wait for full scroll-out
  for tries = 1, 10 do
    if R(0x00E1) == 0 then break end
    idle(10)
  end
  print(string.format("After force-close MenuState=$%02X", R(0x00E1)))
end

-- Poke all items into inventory cells $657-$67E (mirror NES Z1 inventory)
-- Mirrors src/game/items/debug_unlock_all.c — full items bitfield, max
-- bombs, all dungeon compass/map, max keys, hearts, triforce
W(0x0656, 0x01)  -- SelectedItemSlot = boomerang
W(0x0657, 0xFF)  -- Items bitfield (all 8 base items)
W(0x0658, 0x10)  -- Bombs = 16
W(0x0659, 0x02)  -- Arrow = silver
W(0x065A, 0x01)  -- Bow
W(0x065B, 0x02)  -- Candle = red
W(0x065C, 0x01)  -- Whistle (Recorder)
W(0x065D, 0x01)  -- Food
W(0x065E, 0x02)  -- Potion = red
W(0x065F, 0x01)  -- Magic Rod
W(0x0660, 0x01)  -- Raft
W(0x0661, 0x01)  -- Book
W(0x0662, 0x02)  -- Ring = red
W(0x0663, 0x01)  -- Stepladder
W(0x0664, 0x01)  -- Magic Key
W(0x0665, 0x01)  -- Power Bracelet
W(0x0666, 0x01)  -- Letter
W(0x0667, 0x01)  -- Compass Q1 OW (single bit)
W(0x0668, 0x01)  -- Map Q1 OW
W(0x0669, 0xFF)  -- Compass dungeons L1-L8
W(0x066A, 0xFF)  -- Map dungeons L1-L8
W(0x066B, 0xFF)  -- Heart pieces
W(0x066C, 0x10)  -- MaxBombs
W(0x066D, 0xFF)  -- Rupees
W(0x066E, 0x63)  -- Keys = 99
W(0x066F, 0xFF)  -- HeartContainers (lowmask 7 = 8 hearts)
W(0x0670, 0x00)  -- PartialHeart
W(0x0671, 0xFF)  -- Triforce
W(0x0672, 0x02)  -- Boomerang Wood/Magic
W(0x0673, 0x01)  -- Magic Shield

idle(2)

-- Pre-pause screenshot to confirm OW state
client.screenshot(OUT .. "/00_pre_pause.png")

-- Press Start to open subscreen
tap("Start", 4, 6)

-- Hard idle 180 frames to let scroll-in fully complete ($EF -> $41 takes
-- 43 frames + slop). Then verify ScrollProgress + MenuState stable.
idle(180)

-- Confirm stability: ScrollProgress AND MenuState unchanged 30 frames
local last_menu = R(0x00E1)
local last_scroll = R(0x005E)
local stable_count = 0
for tries = 1, 200 do
  local cur_menu = R(0x00E1)
  local cur_scroll = R(0x005E)
  if cur_menu == last_menu and cur_scroll == last_scroll and cur_menu ~= 0 then
    stable_count = stable_count + 1
    if stable_count >= 30 then break end
  else
    stable_count = 0
  end
  last_menu = cur_menu
  last_scroll = cur_scroll
  idle(1)
end

local menu_active = R(0x00E1)
local scroll_prog = R(0x005E)
print(string.format("Active MenuState=$%02X ScrollProg=$%02X stable=%d",
  menu_active, scroll_prog, stable_count))

-- ACTIVE-state screenshot
client.screenshot(OUT .. "/01_active.png")

-- Dump PALRAM 32 B via PALRAM domain (PPU Bus reads return open-bus $F2)
local f = io.open(OUT .. "/palram.bin", "wb")
for off = 0, 31 do
  f:write(string.char(PAL(off)))
end
f:close()

-- Dump Nametable via CIRAM domain (PPU Bus reads need pre-buffer prime,
-- return $F2 open-bus garbage otherwise). CIRAM = 2 KB physical, mapped
-- to nametable address space per mirroring config.
f = io.open(OUT .. "/nametable.bin", "wb")
for off = 0, 0x7FF do
  f:write(string.char(memory.read_u8(off, "CIRAM (nametables)")))
end
f:close()

-- Dump OAM 256 B
f = io.open(OUT .. "/oam.bin", "wb")
for addr = 0x0000, 0x00FF do
  f:write(string.char(memory.readbyte(addr, "OAM")))
end
f:close()

-- Dump 2 KB CPU RAM
f = io.open(OUT .. "/cpu_ram.bin", "wb")
for addr = 0x0000, 0x07FF do
  f:write(string.char(R(addr)))
end
f:close()

-- State log
f = io.open(OUT .. "/state.txt", "w")
f:write(string.format("Room $%02X\n", room_pre))
f:write(string.format("MenuState $E1 = $%02X\n", menu_active))
f:write(string.format("SubmenuScrollProgress $5E = $%02X\n", scroll_prog))
f:write(string.format("SelectedItemSlot $656 = $%02X\n", R(0x0656)))
f:write(string.format("Items bitfield $657 = $%02X (expect $FF post-poke)\n", R(0x0657)))
f:write(string.format("Bombs $658 = $%02X\n", R(0x0658)))
f:write(string.format("Bow $65A = $%02X\n", R(0x065A)))
f:write(string.format("Compass dungeons $669 = $%02X\n", R(0x0669)))
f:write(string.format("Triforce $671 = $%02X\n", R(0x0671)))
f:close()

-- Close subscreen
tap("Start", 4, 6); idle(60)
for tries = 1, 10 do
  if R(0x00E1) == 0 then break end
  idle(10)
end
client.screenshot(OUT .. "/02_post_resume.png")

print("wrote " .. OUT)
client.exit()

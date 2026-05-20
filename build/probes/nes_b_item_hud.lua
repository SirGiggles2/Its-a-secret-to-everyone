-- Capture NES Z1 HUD B-item in BOTH states: subscreen + gameplay.
-- Goal: pixel-exact NES position + which sprites + which tile_ids.

local OUT = "C:\\tmp\\nes_b_item"
os.execute("mkdir " .. OUT:gsub("/","\\") .. " 2>nul")

local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn, hold, gap)
  hold = hold or 4; gap = gap or 6
  for _=1,hold do joypad.set({[btn]=true},1); emu.frameadvance() end
  for _=1,gap do joypad.set({},1); emu.frameadvance() end
end
local function R(a) return memory.read_u8(a, "RAM") end
local function W(a,v) memory.writebyte(a, v, "RAM") end

-- Boot + nav to OW
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

-- Poke items + bombs selected
W(0x0656, 0x01)  -- SelectedItemSlot = 1 = BOMBS
W(0x0657, 0xFF)  -- Items bitfield all
W(0x0658, 0x10)  -- bombs 16
W(0x0659, 0x02)  -- arrow
W(0x065A, 0x01)  -- bow
W(0x065B, 0x02)  -- candle
W(0x065C, 0x01)  -- recorder
W(0x065D, 0x01)  -- food
W(0x065E, 0x02)  -- potion
W(0x065F, 0x01)  -- wand
W(0x0660, 0x01)  -- raft
W(0x0661, 0x01)  -- book
W(0x0662, 0x02)  -- ring
W(0x0663, 0x01)  -- ladder
W(0x0664, 0x01)  -- magic_key
W(0x0665, 0x01)  -- bracelet
W(0x0666, 0x01)  -- letter
W(0x0667, 0xFF)  -- compass
W(0x0668, 0xFF)  -- map
W(0x0669, 0xFF); W(0x066A, 0xFF)
W(0x066B, 0xFF); W(0x066C, 0x10); W(0x066D, 0xFF); W(0x066E, 0x63)
W(0x066F, 0xFF); W(0x0670, 0x00); W(0x0671, 0xFF)
W(0x0674, 0x01); W(0x0676, 0x01)
idle(2)

-- === STATE A: GAMEPLAY (no subscreen) ===
client.screenshot(OUT .. "/A_gameplay.png")
local f = io.open(OUT .. "/A_gameplay_oam.txt", "w")
f:write("=== NES GAMEPLAY OAM (SelectedItemSlot=$01 bombs) ===\n")
f:write(string.format("MenuState $E1=$%02X (expect 0 = gameplay)\n", R(0x00E1)))
f:write("slot Y    Tile Attr X     subpal hflip\n")
for i = 0, 63 do
  local y = memory.readbyte(i*4+0, "OAM")
  local t = memory.readbyte(i*4+1, "OAM")
  local a = memory.readbyte(i*4+2, "OAM")
  local x = memory.readbyte(i*4+3, "OAM")
  if y < 0xEF and t ~= 0xFF then
    f:write(string.format("  %2d $%02X  $%02X  $%02X $%02X    pal%d   hf=%d\n",
      i, y, t, a, x, a%4, (a>>6)%2))
  end
end
f:close()

-- === STATE B: SUBSCREEN ===
tap("Start", 4, 30)
-- Wait stable subscreen
idle(180)
local last_menu = R(0x00E1)
local stable = 0
for tries=1,200 do
  local cur = R(0x00E1)
  if cur == last_menu and cur ~= 0 then stable=stable+1; if stable>=30 then break end
  else stable=0 end
  last_menu = cur; idle(1)
end

client.screenshot(OUT .. "/B_subscreen.png")
f = io.open(OUT .. "/B_subscreen_oam.txt", "w")
f:write("=== NES SUBSCREEN OAM (MenuState=$"..string.format("%02X",R(0x00E1))..") ===\n")
f:write(string.format("SelectedItemSlot $656=$%02X\n", R(0x0656)))
f:write("slot Y    Tile Attr X     subpal hflip  area\n")
for i = 0, 63 do
  local y = memory.readbyte(i*4+0, "OAM")
  local t = memory.readbyte(i*4+1, "OAM")
  local a = memory.readbyte(i*4+2, "OAM")
  local x = memory.readbyte(i*4+3, "OAM")
  if y < 0xEF and t ~= 0xFF then
    -- B-box area: NES cell col 7-10 row 14-17 = pixel X 56-80, Y 112-136
    local area = ""
    if x >= 0x38 and x <= 0x58 and y >= 0x70 and y <= 0x88 then
      area = " <-- B-BOX subscreen"
    elseif y == 0x1F then
      area = " <-- HUD B-item row"
    end
    f:write(string.format("  %2d $%02X  $%02X  $%02X $%02X    pal%d   hf=%d %s\n",
      i, y, t, a, x, a%4, (a>>6)%2, area))
  end
end
f:close()

print("dumps in " .. OUT)
client.exit()

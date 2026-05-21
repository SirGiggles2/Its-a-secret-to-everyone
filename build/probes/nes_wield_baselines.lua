-- W1: NES Z1 wield baselines per slot 0..8.
-- Boots Z1, skips title/FS to OW, pokes full inventory, cycles SelectedItemSlot,
-- presses B per slot, captures OAM + RAM cells at frames 0/1/2/5/10/20.
-- Output: C:/tmp/nes_wield/wield_slot_<N>_{log.txt,oam_fr<M>.bin,screen.png}
--
-- RAM bases (per reference/aldonunez/Variables.inc):
--   ObjTimer = $28, ObjX = $70, ObjY = $84, ObjDir = $98, ObjState = $AC
--   ObjType  = $34F, ObjMetastate = $405, ObjUninitialized = $492
--   SelectedItemSlot = $656

local OUT = "C:\\tmp\\nes_wield\\"
os.execute("mkdir " .. OUT:gsub("/", "\\"))

local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn, hold, gap)
  hold = hold or 4; gap = gap or 6
  for _=1,hold do joypad.set({[btn]=true}, 1); emu.frameadvance() end
  for _=1,gap do joypad.set({}, 1); emu.frameadvance() end
end
local function R(addr) return memory.readbyte(addr, "RAM") end
local function W(addr, val) memory.writebyte(addr, val, "RAM") end

-- Boot + nav title -> file select -> name entry -> gameplay
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

-- Poke ALL items + max counts (mirror nes_all_items_live.lua)
W(0x0657, 0xFF)  -- Items bitfield
W(0x0658, 0x10); W(0x0659, 0x02); W(0x065A, 0x01); W(0x065B, 0x02)
W(0x065C, 0x01); W(0x065D, 0x01); W(0x065E, 0x02); W(0x065F, 0x01)
W(0x0660, 0x01); W(0x0661, 0x01); W(0x0662, 0x02); W(0x0663, 0x01)
W(0x0664, 0x01); W(0x0665, 0x01); W(0x0666, 0x01)
W(0x0667, 0xFF); W(0x0668, 0xFF); W(0x0669, 0xFF); W(0x066A, 0xFF)
W(0x066B, 0xFF); W(0x066C, 0x10); W(0x066D, 0xFF); W(0x066E, 0x63)
W(0x066F, 0xFF); W(0x0670, 0x00); W(0x0671, 0xFF)
W(0x0674, 0x02); W(0x0675, 0x01); W(0x0676, 0x01)
idle(6)

-- Boot nav sequence above ends with Start pressed in gameplay → opens inventory
-- subscreen. Close it so B-press fires WieldItem (not subscreen cursor nav).
-- MenuState = $E1; 0 = active gameplay.
local function in_pause()
  return memory.readbyte(0x00E1, "RAM") ~= 0
end
if in_pause() then
  tap("Start", 4, 30); idle(20)
end
-- Idle until game tick stabilizes
idle(20)

local CAP_FRAMES = {0, 1, 2, 5, 10, 20}

local function dump_oam_to_file(path)
  local oam = {}
  for i = 0, 255 do oam[#oam+1] = string.char(memory.readbyte(i, "OAM")) end
  local f = io.open(path, "wb"); f:write(table.concat(oam)); f:close()
end

local function snapshot_ram_state(slot, frame, logf)
  logf:write(string.format("\n--- slot=%d frame=%d ---\n", slot, frame))
  logf:write("idx  Type State X    Y    Dir Timer Meta Uninit\n")
  for i = 0, 11 do
    local t = memory.readbyte(0x034F + i, "RAM")
    local s = memory.readbyte(0x00AC + i, "RAM")
    local x = memory.readbyte(0x0070 + i, "RAM")
    local y = memory.readbyte(0x0084 + i, "RAM")
    local d = memory.readbyte(0x0098 + i, "RAM")
    local tm = memory.readbyte(0x0028 + i, "RAM")
    local m = memory.readbyte(0x0405 + i, "RAM")
    local u = memory.readbyte(0x0492 + i, "RAM")
    logf:write(string.format(" %2d  $%02X  $%02X $%02X $%02X $%02X $%02X  $%02X $%02X\n",
      i, t, s, x, y, d, tm, m, u))
  end
end

-- Save savestate at gameplay so each slot test starts from same point.
local BASE_STATE_PATH = OUT .. "base.State"
savestate.save(BASE_STATE_PATH)

for slot = 0, 8 do
  savestate.load(BASE_STATE_PATH)
  idle(2)

  -- Cycle SelectedItemSlot to target value
  W(0x0656, slot)
  idle(6)

  -- Press B for one frame (NES button "B")
  -- Use tap helper to ensure edge detection works
  joypad.set({B=true}, 1)
  emu.frameadvance()
  joypad.set({B=true}, 1)
  emu.frameadvance()
  joypad.set({}, 1)

  local logf = io.open(OUT .. string.format("wield_slot_%d_log.txt", slot), "w")
  logf:write(string.format("=== NES Wield Slot %d ===\n", slot))
  logf:write(string.format("SelectedItemSlot=$%02X  LinkX=$%02X LinkY=$%02X LinkDir=$%02X\n",
    R(0x0656), R(0x0070), R(0x0084), R(0x0098)))
  logf:write(string.format("Inv: Bombs=%d Arrow=$%02X Bow=%d Candle=$%02X Recorder=%d Food=%d Potion=$%02X Wand=%d\n",
    R(0x0658), R(0x0659), R(0x065A), R(0x065B), R(0x065C), R(0x065D), R(0x065E), R(0x065F)))

  -- Snapshot at each capture frame
  local last_frame = 0
  for _, cf in ipairs(CAP_FRAMES) do
    local delta = cf - last_frame
    if delta > 0 then idle(delta) end
    last_frame = cf
    dump_oam_to_file(OUT .. string.format("wield_slot_%d_oam_fr%d.bin", slot, cf))
    snapshot_ram_state(slot, cf, logf)
  end
  client.screenshot(OUT .. string.format("wield_slot_%d_screen.png", slot))
  logf:close()

  -- Settle between slots — clear any pending projectile
  idle(120)
end

print("W1: NES wield baselines complete in " .. OUT)
client.exit()

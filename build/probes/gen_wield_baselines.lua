-- W10: Genesis Debug.md per-Wield SAT baseline. Mirror of nes_wield_baselines.lua.
-- Boots Debug.md, ABC chord → gameplay, cycles s_b_item via Z presses, fires B,
-- captures SAT bytes + 68K RAM cells at frames 0/1/2/5/10/20.
--
-- s_b_item enum (RoomRom/src/main.c:132):
--   NONE=0 BOOMERANG=1 ARROW=2 BOMB=3 CANDLE=4 ROD=5 FLUTE=6 FOOD=7
-- Press order targets NES SelectedItemSlot 0..8 sequence:
--   NES slot 0=boomerang → BOOMERANG (cycle to 1)
--   NES slot 1=bomb      → BOMB      (cycle to 3)
--   NES slot 2=arrow     → ARROW     (cycle to 2)
--   NES slot 4=candle    → CANDLE    (cycle to 4)
--   NES slot 5=recorder  → FLUTE     (cycle to 6)  [SFX-only stub]
--   NES slot 6=food      → FOOD      (cycle to 7)  [SFX-only stub]
--   NES slot 8=wand      → ROD       (cycle to 5)
-- Skip NES slot 3 (bow), 7 (potion) — not B-press wields.

local OUT = "C:\\tmp\\gen_wield\\"
os.execute("mkdir " .. OUT:gsub("/", "\\"))

local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(btns, hold, gap)
  hold = hold or 4; gap = gap or 6
  for _=1,hold do joypad.set(btns, 1); emu.frameadvance() end
  for _=1,gap do joypad.set({}, 1); emu.frameadvance() end
end

-- Boot title, fire ABC chord to enter debug gameplay
idle(240)
press({A=true,B=true,C=true}, 8, 60)
idle(60)

-- Move Link slightly to ensure not on edge
press({Right=true}, 6, 6)
idle(20)

-- Map NES SelectedItemSlot (0..8) → Genesis b_item enum value
-- and number of Z presses to reach from BOOMERANG (initial state = 1).
local SLOTS = {
  {nes_slot=0, name="boomerang", gen_enum=1, z_presses=0},
  {nes_slot=1, name="bomb",      gen_enum=3, z_presses=2},
  {nes_slot=2, name="arrow",     gen_enum=2, z_presses=1},
  {nes_slot=4, name="candle",    gen_enum=4, z_presses=3},
  {nes_slot=5, name="flute",     gen_enum=6, z_presses=5},
  {nes_slot=6, name="food",      gen_enum=7, z_presses=6},
  {nes_slot=8, name="rod",       gen_enum=5, z_presses=4},
}

local CAP_FRAMES = {0, 1, 2, 5, 10, 20}
local SAT_BASE = 0xF400

local function dump_sat(label, fpath)
  local sat = {}
  for off = 0, 639 do
    sat[#sat+1] = string.char(memory.read_u8(SAT_BASE + off, "VRAM"))
  end
  local f = io.open(fpath, "wb"); f:write(table.concat(sat)); f:close()
end

local function log_sat(logf, frame)
  logf:write(string.format("\n--- frame=%d ---\n", frame))
  logf:write("slot  Y     X     tile  pal  hf  vf  prio  link\n")
  for slot = 0, 31 do
    local off = SAT_BASE + slot*8
    local y = memory.read_u16_be(off+0, "VRAM")
    local sz = memory.read_u8(off+2, "VRAM")
    local lk = memory.read_u8(off+3, "VRAM")
    local a = memory.read_u16_be(off+4, "VRAM")
    local x = memory.read_u16_be(off+6, "VRAM")
    if y ~= 0 or x ~= 0 or a ~= 0 then
      local tile = a % 0x800
      local pal = math.floor(a / 0x2000) % 4
      local hf = math.floor(a / 0x800) % 2
      local vf = math.floor(a / 0x1000) % 2
      local prio = math.floor(a / 0x8000) % 2
      logf:write(string.format("  %2d  $%04X $%04X $%04X %d   %d   %d   %d     %d\n",
        slot, y, x, a, pal, hf, vf, prio, lk))
    end
  end
end

local BASE_STATE_PATH = OUT .. "base.State"
savestate.save(BASE_STATE_PATH)

-- s_b_item resets to BOOMERANG only on debug enter; after savestate load it
-- restores the snapshot's value. To cycle reliably we re-load base then cycle.
-- But s_b_item may not be in savestate (if it's C static in unmapped RAM).
-- Tactic: load base, cycle by Z presses from initial = BOOMERANG.

for _, entry in ipairs(SLOTS) do
  savestate.load(BASE_STATE_PATH)
  idle(2)

  -- Cycle to target b_item via Z presses
  for _=1, entry.z_presses do
    press({Z=true}, 4, 4)
  end
  idle(10)

  -- Press B to fire wield
  joypad.set({B=true}, 1); emu.frameadvance()
  joypad.set({B=true}, 1); emu.frameadvance()
  joypad.set({}, 1)

  local logf = io.open(OUT .. string.format("wield_%s_log.txt", entry.name), "w")
  logf:write(string.format("=== Genesis Wield NES_slot=%d (%s, b_item enum=%d) ===\n",
    entry.nes_slot, entry.name, entry.gen_enum))

  local last_frame = 0
  for _, cf in ipairs(CAP_FRAMES) do
    local delta = cf - last_frame
    if delta > 0 then idle(delta) end
    last_frame = cf
    dump_sat(entry.name, OUT .. string.format("wield_%s_sat_fr%d.bin", entry.name, cf))
    log_sat(logf, cf)
  end
  client.screenshot(OUT .. string.format("wield_%s_screen.png", entry.name))
  logf:close()
  idle(120)
end

print("W10 Genesis wield baselines complete in " .. OUT)
client.exit()

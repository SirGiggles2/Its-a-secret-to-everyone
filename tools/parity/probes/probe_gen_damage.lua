-- Damage verification probe. Spawn enemy, fire damage hook,
-- verify HP delta matches NES HpPairs expectation.

local NES_BASE = 0x8000
local function R(o)   return memory.read_u8(NES_BASE + o, "68K RAM") end
local function W(o,v) memory.write_u8(NES_BASE + o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function safe_set(p)
  local ok = pcall(function() joypad.set(p or {}, 1) end)
  if not ok then joypad.set(p or {}) end
end
local PROBE_CTRL = 0x73F8
local DMG_CTRL = 0x77E0

for _ = 1, 60 do emu.frameadvance() end
for _ = 1, 30 do
  safe_set({A=true, B=true, C=true,
            ["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
  emu.frameadvance()
end
safe_set({})
for _ = 1, 240 do emu.frameadvance() end

-- Warp to OW r$77
W(0x0098, 0x08)
memory.write_u8(PROBE_CTRL + 0, 0x52, "68K RAM")
memory.write_u8(PROBE_CTRL + 1, 0x50, "68K RAM")
memory.write_u8(PROBE_CTRL + 3, 0, "68K RAM")
memory.write_u8(PROBE_CTRL + 4, 0, "68K RAM")
memory.write_u8(PROBE_CTRL + 5, 0, "68K RAM")
memory.write_u8(PROBE_CTRL + 6, 0x77, "68K RAM")
memory.write_u8(PROBE_CTRL + 7, 0x5A, "68K RAM")
for _ = 1, 30 do
  emu.frameadvance()
  if memory.read_u8(PROBE_CTRL + 7, "68K RAM") == 0 then break end
end
idle(180)

local out = io.open("C:/tmp/gen_damage_probe.txt", "w")

-- Per NES Z_04.asm HpPairs: 1 byte per 2 types (high nibble = even type, low = odd type).
-- HP * 16 = actual.
local expected_hp = {
  [0x01]=0x40, [0x02]=0x30, [0x03]=0x20, [0x04]=0x50, [0x05]=0x10, [0x06]=0x40,
  [0x07]=0x10, [0x08]=0x20, [0x09]=0x20, [0x0A]=0x40, [0x0B]=0xF0, [0x0C]=0x80,
  [0x0F]=0x10, [0x10]=0x20, [0x11]=0x20, [0x12]=0x20, [0x13]=0x00, [0x15]=0x00,
  [0x16]=0x20, [0x17]=0xA0, [0x1A]=0x10, [0x1B]=0x00, [0x1C]=0x00, [0x1D]=0x00,
  [0x1E]=0x20, [0x21]=0x20, [0x22]=0x20, [0x27]=0x20, [0x28]=0x10, [0x2A]=0x20,
  [0x2B]=0x00, [0x2C]=0x00, [0x2D]=0x00, [0x30]=0x20,
}

-- Damage hook: $FF77E0 magic='DD', slot=1, damage_amount
local function damage_slot(slot, dmg_amt)
  memory.write_u8(DMG_CTRL + 0, 0x44, "68K RAM")  -- 'D'
  memory.write_u8(DMG_CTRL + 1, 0x44, "68K RAM")  -- 'D'
  memory.write_u8(DMG_CTRL + 2, slot, "68K RAM")
  memory.write_u8(DMG_CTRL + 3, 0x10, "68K RAM")  -- sword L1
  memory.write_u8(DMG_CTRL + 4, dmg_amt, "68K RAM")
  for _ = 1, 4 do emu.frameadvance() end
end

-- Iterate sample enemies
local types = {0x01,0x02,0x07,0x08,0x0B,0x0C,0x1B,0x1A,0x27,0x28,0x2A,0x2B,0x30}

for _, t in ipairs(types) do
  -- Clear slot 1
  for s = 1, 19 do
    W(0x034F+s, 0); W(0x0485+s, 0); W(0x0405+s, 0); W(0x0492+s, 0)
  end
  -- Force-spawn via spawn-arm hook
  memory.write_u8(0x77D0 + 0, 0x46, "68K RAM")  -- 'F'
  memory.write_u8(0x77D0 + 1, 0x58, "68K RAM")  -- 'X'
  memory.write_u8(0x77D0 + 2, t, "68K RAM")
  memory.write_u8(0x77D0 + 3, 0x80, "68K RAM")  -- x
  memory.write_u8(0x77D0 + 4, 0x88, "68K RAM")  -- y
  memory.write_u8(0x77D0 + 5, 0, "68K RAM")
  memory.write_u8(0x77D0 + 6, 0x01, "68K RAM")  -- slot 1
  memory.write_u8(0x77D0 + 7, 0, "68K RAM")
  memory.write_u8(0x77D0 + 8, 0x77, "68K RAM")
  for _ = 1, 8 do emu.frameadvance() end
  idle(30)

  local actual_t = R(0x0350)
  local hp0 = R(0x0486)
  local alive0 = R(0x0492+1)
  damage_slot(1, 0x10)  -- L1 sword
  local hp1 = R(0x0486)
  local alive1 = R(0x0492+1)
  damage_slot(1, 0x10)  -- second hit
  local hp2 = R(0x0486)
  local alive2 = R(0x0492+1)

  local exp = expected_hp[t] or 0
  out:write(string.format("t=$%02X spawn_t=$%02X exp_hp=$%02X hp0=$%02X hp1=$%02X hp2=$%02X alive=%d->%d->%d\n",
    t, actual_t, exp, hp0, hp1, hp2, alive0, alive1, alive2))
  out:flush()
end

out:close()
client.exit()

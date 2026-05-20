-- Verify P6.1: enter gameplay via ABC chord, dump inventory cells.
local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/inventory_verify.txt"

local function press(b, n)
  for _=1,n do joypad.set(b, 1); emu.frameadvance() end
  joypad.set({}, 1); emu.frameadvance()
end
local function idle(n) for _=1,n do emu.frameadvance() end end
-- nes_ram at $FF8000 in 68K BUS
local function R(addr) return memory.read_u8(0x8000 + addr, "68K RAM") end

idle(240)
press({A=true, B=true, C=true}, 8); idle(120)

local f = io.open(OUT, "w")
f:write("INVENTORY VERIFY post-ABC-chord (P6.1):\n\n")
local cells = {
  {0x0657, "Items bitfield"},
  {0x0658, "InvBombs"},
  {0x0659, "InvArrow"},
  {0x065A, "Bow"},
  {0x065B, "InvCandle"},
  {0x065D, "InvFood"},
  {0x065E, "Potion"},
  {0x0660, "InvRaft"},
  {0x0661, "InvBook"},
  {0x0662, "InvRing"},
  {0x0663, "InvLadder"},
  {0x0664, "InvMagicKey"},
  {0x0665, "InvBracelet"},
  {0x0666, "InvLetter"},
  {0x0667, "InvCompassQ1"},
  {0x0668, "InvMapQ1"},
  {0x0669, "InvCompass9"},
  {0x066A, "InvMap9"},
  {0x066C, "InvClock"},
  {0x066D, "InvRupees"},
  {0x066E, "InvKeys"},
  {0x066F, "HeartValues"},
  {0x0670, "HeartPartial"},
  {0x0671, "InvTriforce"},
  {0x0674, "InvBoomerang"},
  {0x0675, "InvMagicBoom"},
  {0x0676, "InvMagicShield"},
  {0x067C, "MaxBombs"},
  {0x0656, "SelectedB"},
}
for _, c in ipairs(cells) do
  local addr, name = c[1], c[2]
  f:write(string.format("  $%04X %s = $%02X\n", addr, name, R(addr)))
end
f:close()
client.screenshot((os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/inventory_verify.png")
print("wrote " .. OUT)
client.exit()

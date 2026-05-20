-- HUD B-item RCA: gameplay-only state (no subscreen).
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end; joypad.set({},1); emu.frameadvance() end

idle(240)
press({A=true,B=true,C=true}, 8); idle(60)
-- Move Link to confirm gameplay
press({Right=true}, 30); idle(30)

local f = io.open("C:\\tmp\\hud_rca.txt", "w")

-- VDP reg 11 (mode 3) Window position, reg 17/18 Window H/V split
-- Plane B priority bit not relevant; sprite prio bit is in SAT attr.
f:write("=== Pause state ===\n")
f:write(string.format("g_paused $FF80E0 = $%02X\n", memory.read_u8(0x80E0, "68K RAM")))
f:write(string.format("nes_ram[$8656] SelectedItemSlot = $%02X\n", memory.read_u8(0x8656, "68K RAM")))
f:write(string.format("nes_ram[$8658] InvBombs = $%02X\n", memory.read_u8(0x8658, "68K RAM")))

f:write("\n=== SAT slot 10 (HUD_B_ITEM) ===\n")
local off = 0xF400 + 10*8
local y = memory.read_u16_be(off+0, "VRAM")
local sl = memory.read_u8(off+2, "VRAM")
local lk = memory.read_u8(off+3, "VRAM")
local a = memory.read_u16_be(off+4, "VRAM")
local x = memory.read_u16_be(off+6, "VRAM")
f:write(string.format("y=%d (pixel %d)  size=$%02X  link=%d  attr=$%04X  x=%d (pixel %d)\n",
  y, y-128, sl, lk, a, x, x-128))
f:write(string.format("  tile=%d  pal=%d  hflip=%d  prio=%d\n",
  a%0x800, (a>>13)&3, (a>>11)&1, (a>>15)&1))

f:write("\n=== SAT slots 0-15 (full chain) ===\n")
for slot = 0, 15 do
  off = 0xF400 + slot*8
  y = memory.read_u16_be(off+0, "VRAM")
  lk = memory.read_u8(off+3, "VRAM")
  a = memory.read_u16_be(off+4, "VRAM")
  x = memory.read_u16_be(off+6, "VRAM")
  f:write(string.format("  %2d: y=%4d x=%4d link=%3d tile=%4d pal=%d\n",
    slot, y, x, lk, a%0x800, (a>>13)&3))
end

-- VDP regs
f:write("\n=== VDP regs ===\n")
for r = 0, 23 do
  local v = memory.read_u8(r, "VDP")
  f:write(string.format("  R%02d = $%02X\n", r, v))
end

f:close()
client.screenshot("C:\\tmp\\hud_rca.png")
client.exit()

-- Probe SAT slot 10 (HUD_B_ITEM) live during gameplay.
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end; joypad.set({},1); emu.frameadvance() end

idle(240)
press({A=true,B=true,C=true}, 8); idle(120)

local OUT = "C:\\tmp\\hud_b_item_dump.txt"
local f = io.open(OUT, "w")
local SAT = 0xF400
for slot = 0, 15 do
  local off = SAT + slot * 8
  local y = memory.read_u16_be(off+0, "VRAM")
  local sl = memory.read_u8(off+2, "VRAM")
  local lk = memory.read_u8(off+3, "VRAM")
  local a = memory.read_u16_be(off+4, "VRAM")
  local x = memory.read_u16_be(off+6, "VRAM")
  local tile = a % 0x800
  local pal = (a >> 13) & 3
  f:write(string.format("slot %2d: y=%4d link=%3d tile=%4d pal=%d x=%4d (sz=$%02X attr=$%04X)\n",
    slot, y, lk, tile, pal, x, sl, a))
end
f:write(string.format("\nnes_ram[$8656] SelectedItemSlot=$%02X\n", memory.read_u8(0x8656, "68K RAM")))
f:write(string.format("g_inventory mirror $8657 Items=$%02X $8658 Bombs=$%02X\n",
  memory.read_u8(0x8657, "68K RAM"), memory.read_u8(0x8658, "68K RAM")))
f:close()
client.screenshot("C:\\tmp\\hud_b_item_live.png")
client.exit()

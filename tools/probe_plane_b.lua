-- Probe plane A contents + VSRAM mid-subphase=02 (long story/treasures scroll).
-- Advance to frame 2000 which is well inside sp2 on Gen.
local frame = 0
while frame < 2000 do
  emu.frameadvance()
  frame = frame + 1
end
local f = io.open("C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/nt_b_plane_f2000.txt","w")
f:write(string.format("frame=%d\n", frame))
for row=0,63 do
  local base = 0xC000 + row*0x80
  local line = string.format("row%02d:", row)
  -- Only first 32 tile words (the NES-visible 256px span within plane)
  for col=0,31 do
    local w = memory.read_u16_be(base + col*2, "VRAM")
    line = line .. string.format(" %04X", w)
  end
  f:write(line.."\n")
end
f:write("VSRAM:")
for i=0,19 do
  local w = memory.read_u16_be(i*2, "VSRAM")
  f:write(string.format(" %04X", w))
end
f:write("\n")
-- NES-side PPU shadow and zero-page flags
f:write("PPU_SHADOW:")
for i=0,0x20 do
  local b = memory.read_u8(0x0800+i, "68K RAM")
  f:write(string.format(" %02X", b))
end
f:write("\n")
f:write(string.format("NES[58]=%02X [E2]=%02X [E3]=%02X [FC]=%02X [FD]=%02X [FF]=%02X [5C]=%02X [12]=%02X\n",
  memory.read_u8(0x0058,"68K RAM"),
  memory.read_u8(0x00E2,"68K RAM"),
  memory.read_u8(0x00E3,"68K RAM"),
  memory.read_u8(0x00FC,"68K RAM"),
  memory.read_u8(0x00FD,"68K RAM"),
  memory.read_u8(0x00FF,"68K RAM"),
  memory.read_u8(0x005C,"68K RAM"),
  memory.read_u8(0x0012,"68K RAM")))
f:write(string.format("HINT_Q_COUNT=%02X Q0_CTR=%02X Q0_V=%04X Q1_CTR=%02X Q1_V=%04X\n",
  memory.read_u8(0x0816,"68K RAM"),
  memory.read_u8(0x0817,"68K RAM"),
  memory.read_u16_be(0x0818,"68K RAM"),
  memory.read_u8(0x081A,"68K RAM"),
  memory.read_u16_be(0x081B,"68K RAM")))
f:close()
client.exit()

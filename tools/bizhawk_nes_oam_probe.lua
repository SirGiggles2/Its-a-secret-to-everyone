-- Dump NES OAM at f700 (title screen). OAM is 256 bytes, 64 sprites x 4 bytes.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/nes_oam_f700.txt"
local fh = io.open(OUT, "w")
while emu.framecount() < 700 do emu.frameadvance() end

fh:write("=== NES OAM at f700 (title screen) ===\n")
fh:write("# byte0=Y, byte1=tile, byte2=attr, byte3=X\n")
for i = 0, 63 do
  local base = i*4
  local y = memory.read_u8(base+0, "OAM")
  local t = memory.read_u8(base+1, "OAM")
  local a = memory.read_u8(base+2, "OAM")
  local x = memory.read_u8(base+3, "OAM")
  if y < 0xF0 then -- NES hides sprites at Y>=$F0
    fh:write(string.format("spr %02d: Y=%02X T=%02X A=%02X X=%02X\n", i, y, t, a, x))
  end
end
fh:close()
client.exit()

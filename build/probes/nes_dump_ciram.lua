-- nes_dump_ciram.lua — one-shot dump of NES PPU nametable + scroll regs
-- for the chr_viewer_rom test ROM. Lets us verify nametable cell content
-- vs the table we baked into PRG.
local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/chr_viewer_nt_dump.txt"
for _ = 1, 240 do emu.frameadvance() end

local f = io.open(OUT, "w")
-- CIRAM domain — 2 KB nametable storage ($2000-$27FF, mirrored to $2800-$2FFF)
f:write("Domains:\n")
for _, d in ipairs(memory.getmemorydomainlist()) do
  f:write(string.format("  %s = %d\n", d, memory.getmemorydomainsize(d)))
end
f:write("\nNametable $2000-$20FF (rows 0..7):\n")
local nt_first = {}
for i = 0, 0xFF do
  nt_first[i + 1] = memory.read_u8(i, "CIRAM (nametables)")
end
for r = 0, 7 do
  local row = {}
  for c = 0, 31 do
    row[#row + 1] = string.format("%02X", nt_first[r * 32 + c + 1])
  end
  f:write(string.format("row %d: %s\n", r, table.concat(row, " ")))
end

-- Attribute table at $23C0
f:write("\nAttribute table $23C0 (64 bytes):\n")
local attr = {}
for i = 0, 0x3F do
  attr[#attr + 1] = string.format("%02X", memory.read_u8(0x3C0 + i, "CIRAM (nametables)"))
end
f:write(table.concat(attr, " ") .. "\n")

-- RAM zero-page state vars
f:write("\nRAM zero-page state:\n")
f:write(string.format("  $10 (bank)    = %02X\n", memory.read_u8(0x10, "RAM")))
f:write(string.format("  $11 (subpal)  = %02X\n", memory.read_u8(0x11, "RAM")))
f:write(string.format("  $15 (page)    = %02X\n", memory.read_u8(0x15, "RAM")))
f:write(string.format("  $16 (8x16)    = %02X\n", memory.read_u8(0x16, "RAM")))

f:close()
print("wrote " .. OUT)
client.exit()

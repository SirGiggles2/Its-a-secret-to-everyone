-- ow_audio_deepdump.lua — full Z80 + chip-write evidence.
local function R(o)   return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function RZ(o)  return memory.read_u8(o, "Z80 RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\ow_audio_deepdump.txt"
local f = io.open(OUT, "w")
local function logf(fmt, ...) f:write(string.format(fmt, ...) .. "\n"); f:flush() end

-- boot
idle(60)
logf("[BOOT] gm=$%02X xgm_owns=$%02X", R(0x0012), R(0xE02C))

-- A+B+C into gameplay
for _=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(120)

logf("[OW]   gm=$%02X scene=%d room=$%02X xgm_owns=$%02X",
     R(0x0012), R(0x7204), R(0x7205), R(0xE02C))

-- Hash the first 256 bytes of ow_theme_vgm in ROM ($049600 was prior, may differ)
-- Scan ROM for "XGM " magic too
logf("--- ROM scan for XGM/Vgm/sonic-XGM ---")
local sz = memory.getmemorydomainsize("MD CART")
for off = 0, sz - 4, 256 do
  local b0 = memory.read_u8(off, "MD CART")
  local b1 = memory.read_u8(off+1, "MD CART")
  local b2 = memory.read_u8(off+2, "MD CART")
  local b3 = memory.read_u8(off+3, "MD CART")
  if b0 == 0x58 and b1 == 0x47 and b2 == 0x4D and b3 == 0x20 then
    logf(" XGM magic @ ROM $%06X", off); break
  end
end

-- Locate sonic1.xgm signature — first 4 bytes of sonic1.xgm
local sonic_marker = {0x00, 0x10, 0x00, 0x00}  -- placeholder; we'll dump first 64 bytes from anywhere we find an aligned blob
-- Just dump first 32 bytes of every 256-aligned region with non-zero entropy near where audio data lives
logf("--- ROM $048000..$050000 (16K window) signatures ---")
for base = 0x48000, 0x50000, 0x1000 do
  local s = string.format("$%06X:", base)
  for i = 0, 15 do
    s = s .. string.format(" %02X", memory.read_u8(base+i, "MD CART"))
  end
  logf("%s", s)
end

-- Z80 RAM full dump
logf("--- Z80 RAM $0000..$00FF ---")
for base = 0, 0xF0, 0x10 do
  local s = string.format("%04X:", base)
  for i = 0, 15 do s = s .. string.format(" %02X", RZ(base+i)) end
  logf("%s", s)
end
logf("--- Z80 RAM $0100..$01FF ---")
for base = 0x100, 0x1F0, 0x10 do
  local s = string.format("%04X:", base)
  for i = 0, 15 do s = s .. string.format(" %02X", RZ(base+i)) end
  logf("%s", s)
end
logf("--- Z80 RAM $0200..$03FF (driver code region) ---")
for base = 0x200, 0x3F0, 0x10 do
  local s = string.format("%04X:", base)
  for i = 0, 15 do s = s .. string.format(" %02X", RZ(base+i)) end
  logf("%s", s)
end
logf("--- Z80 RAM $1C00..$1CFF (XGM sample id table) ---")
for base = 0x1C00, 0x1CF0, 0x10 do
  local s = string.format("%04X:", base)
  for i = 0, 15 do s = s .. string.format(" %02X", RZ(base+i)) end
  logf("%s", s)
end

-- Sample 60 frames of Z80 $0102 (play state byte) to see if it ticks
logf("--- 60-frame trace of Z80 $0100..$0107 ---")
for fr = 1, 60 do
  emu.frameadvance()
  if fr % 10 == 0 then
    logf("  f%2d: %02X %02X %02X %02X %02X %02X %02X %02X",
      fr, RZ(0x100), RZ(0x101), RZ(0x102), RZ(0x103),
          RZ(0x104), RZ(0x105), RZ(0x106), RZ(0x107))
  end
end

client.exit()

-- ow_theme_isplaying.lua — boot, enter OW, dump Z80 state to see if
-- the XGM driver is actually playing music after XGM_startPlay.
--
-- XGM v1 Z80 driver (drv_xgm.s80) keeps state at known Z80 RAM offsets:
--   $0100  pendingFrm / play state (non-zero = song active)
--   $0102  playState
--   Pattern-pointer + sample table loaded into Z80 RAM after startPlay.
-- We'll just dump $0000..$0400 to inspect.

local function R(o)   return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\ow_theme_isplaying.txt"
local f = io.open(OUT, "w")
local function logf(fmt, ...) f:write(string.format(fmt, ...) .. "\n"); f:flush() end

idle(60)
for _=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(120)

logf("gm=$%02X scene=%d room=$%02X xgm_owns=$%02X",
     R(0x0012), R(0x7204), R(0x7205), R(0xE02C))

-- List domains
logf("---domains---")
for _, d in ipairs(memory.getmemorydomainlist()) do
  logf(" %s size=%d", d, memory.getmemorydomainsize(d))
end

-- Dump Z80 RAM low region
logf("---Z80 RAM $0000..$00FF---")
for base = 0, 0xF0, 0x10 do
  local s = string.format("%04X:", base)
  for i = 0, 15 do
    s = s .. string.format(" %02X", memory.read_u8(base+i, "Z80 RAM"))
  end
  logf("%s", s)
end
logf("---Z80 RAM $0100..$01FF---")
for base = 0x100, 0x1F0, 0x10 do
  local s = string.format("%04X:", base)
  for i = 0, 15 do
    s = s .. string.format(" %02X", memory.read_u8(base+i, "Z80 RAM"))
  end
  logf("%s", s)
end

-- Look for our VGM magic "Vgm " bytes in M68K ROM space
logf("---scan ROM for VGM magic 'Vgm '---")
for _, d in ipairs(memory.getmemorydomainlist()) do
  if d == "MD CART" then
    local sz = memory.getmemorydomainsize(d)
    local hits = 0
    for off = 0, sz - 4, 256 do
      if memory.read_u8(off,   d) == 0x56 and
         memory.read_u8(off+1, d) == 0x67 and
         memory.read_u8(off+2, d) == 0x6D and
         memory.read_u8(off+3, d) == 0x20 then
        logf(" VGM blob @ ROM $%06X", off)
        hits = hits + 1
        if hits >= 5 then break end
      end
    end
    if hits == 0 then logf(" no VGM magic found in ROM") end
    break
  end
end

client.exit()

-- Dump Plane A rows 30-59 and CRAM at the moment curV=$40 NT1 sub=02 is reached.
-- This matches the gen_t11 snapshot where FAIRY/CLOCK labels are missing.
local system = emu.getsystemid() or "?"
local is_gen = (system == "GEN" or system == "SAT")
local LABEL = is_gen and "gen" or "nes"
local out = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/items_vram2_" .. LABEL .. ".txt"

local rd8
if is_gen then rd8 = function(a) return memory.read_u8(a, "68K RAM") end
else rd8 = function(a) return mainmemory.read_u8(a) end end

local frame = 0
while frame < 5000 do
  emu.frameadvance()
  frame = frame + 1
  local phase = rd8(0x42C)
  local sub   = rd8(0x42D)
  local curV  = rd8(0xFC)
  local ctrl  = rd8(0xFF)
  local nt    = (ctrl % 4 >= 2) and 1 or 0
  if phase == 1 and sub == 2 and curV == 0x40 and nt == 1 then break end
end

local f = io.open(out, "w")
f:write(string.format("label=%s frame=%d\n", LABEL, frame))

if is_gen then
  -- Plane A all rows 0-63 (NT_A + NT_B + dead zone)
  for row=0,63 do
    local base = 0xC000 + row*0x80
    local line = string.format("row%02d:", row)
    for col=0,31 do
      local w = memory.read_u16_be(base + col*2, "VRAM")
      line = line .. string.format(" %04X", w)
    end
    f:write(line .. "\n")
  end
  -- CRAM all 64 entries
  f:write("CRAM:")
  for i=0,63 do
    local w = memory.read_u16_be(i*2, "CRAM")
    f:write(string.format(" %04X", w))
    if (i+1) % 16 == 0 then f:write("\n     ") end
  end
  f:write("\n")
  -- VSRAM first 4 entries
  f:write("VSRAM:")
  for i=0,3 do f:write(string.format(" %04X", memory.read_u16_be(i*2, "VSRAM"))) end
  f:write("\n")
  -- HINT queue state (see nes_io.asm _apply_genesis_scroll)
  f:write(string.format("HINT_Q_COUNT=%02X Q0_CTR=%02X Q0_V=%04X Q1_CTR=%02X Q1_V=%04X\n",
    memory.read_u8(0x0816,"68K RAM"),
    memory.read_u8(0x0817,"68K RAM"),
    memory.read_u16_be(0x0818,"68K RAM"),
    memory.read_u8(0x081A,"68K RAM"),
    memory.read_u16_be(0x081B,"68K RAM")))
else
  -- NES: dump nametable $2800 (NT_B) tiles
  f:write("NT_B ($2800):\n")
  for row=0,29 do
    local line = string.format("row%02d:", row)
    for col=0,31 do
      local b = memory.read_u8(0x2800 + row*32 + col, "PPU Bus")
      line = line .. string.format(" %02X", b)
    end
    f:write(line .. "\n")
  end
  -- NES palettes $3F00-$3F1F
  f:write("PAL:")
  for i=0,31 do f:write(string.format(" %02X", memory.read_u8(0x3F00+i, "PPU Bus"))) end
  f:write("\n")
end

f:write(string.format("NES[FC]=%02X [FF]=%02X [42C]=%02X [42D]=%02X\n",
  rd8(0xFC), rd8(0xFF), rd8(0x42C), rd8(0x42D)))
f:close()
client.exit()

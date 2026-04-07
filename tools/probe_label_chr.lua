-- Dump Gen VRAM CHR pattern bytes for the tiles used by FAIRY/CLOCK labels
-- and compare against tiles shared with HEART (which renders).
-- Advances to the same state as probe_items_vram: phase=1 sub=2 curV=$40 nt=1.
local out = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/label_chr_gen.txt"

local function rd8(a) return memory.read_u8(a, "68K RAM") end

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
f:write(string.format("frame=%d\n", frame))

-- Tiles to inspect: letter glyphs used by label text.
-- From items_vram2_gen: row55 FAIRY=010F 010A 0112 011B 0122 ; CLOCK=010C 0115 0118 010C 0114
-- Row47 HEART=0111 010E 010A 011B 011D (H E A R T) renders fine as reference.
-- Each tile is 32 bytes (4BPP, 8x8).
local tiles = {
  {name="H (HEART)",   idx=0x111},
  {name="E (HEART)",   idx=0x10E},
  {name="A (shared)",  idx=0x10A},
  {name="R (shared)",  idx=0x11B},
  {name="T (HEART)",   idx=0x11D},
  {name="F (FAIRY)",   idx=0x10F},
  {name="I (FAIRY)",   idx=0x112},
  {name="Y (FAIRY)",   idx=0x122},
  {name="C (CLOCK)",   idx=0x10C},
  {name="L (CLOCK)",   idx=0x115},
  {name="O (CLOCK)",   idx=0x118},
  {name="K (CLOCK)",   idx=0x114},
}

for _,t in ipairs(tiles) do
  local addr = t.idx * 32  -- tile index * 32 bytes
  f:write(string.format("tile %03X @ VRAM $%04X  %s:\n", t.idx, addr, t.name))
  for row=0,7 do
    local line = "  "
    for col=0,3 do
      local b = memory.read_u8(addr + row*4 + col, "VRAM")
      line = line .. string.format("%02X ", b)
    end
    -- also ascii pixel view: each nibble is a pixel 0..F
    local pix = ""
    for col=0,3 do
      local b = memory.read_u8(addr + row*4 + col, "VRAM")
      local hi = math.floor(b / 16)
      local lo = b % 16
      pix = pix .. ((hi==0) and "." or "#") .. ((lo==0) and "." or "#")
    end
    f:write(line .. " " .. pix .. "\n")
  end
end

-- Also sanity check: ppu-shadow CHR source bytes? Not easily — CHR pattern lives in Gen VRAM.
-- Dump first 16 bytes of the NES CHR mirror (if we staged it in 68K RAM) — skip, not maintained.

f:close()
client.exit()

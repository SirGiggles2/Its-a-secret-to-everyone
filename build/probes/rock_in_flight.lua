-- rock_in_flight.lua — catch flying rock mid-flight; dump VRAM tile +
-- SAT + slot info to verify NES tile $98 rendered at Genesis VRAM 1093.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16(o) return memory.read_u16_be(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function VR(o) return memory.read_u8(o, "VRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\rock_in_flight.txt"
local f = io.open(OUT, "w")

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)

-- Walk Up to scroll into room $67
for i=1,200 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(60)

-- Stay in room $67. Idle while octoroks shoot.
idle(60)

-- Hunt: every frame check slots 8..11 for type $53/$54 (flying rock)
local found_slot = nil
local found_frame = nil
for fr=1,1800 do
  emu.frameadvance()
  for s=8,11 do
    local t = R(0x834F + s)
    if t == 0x53 or t == 0x54 then
      found_slot = s
      found_frame = fr
      break
    end
  end
  if found_slot then break end
end

if found_slot then
  f:write(string.format("=== ROCK FOUND slot=%d frame=%d ===\n", found_slot, found_frame))
  -- Capture IMMEDIATELY before destroy
  local s = found_slot
  f:write(string.format("slot %d: type=$%02X X=$%02X Y=$%02X dir=$%02X spd=$%02X state=$%02X mvt=$%02X anim=$%02X\n",
    s, R(0x834F+s), R(0x8070+s), R(0x8084+s), R(0x8098+s),
    R(0x83BC+s), R(0x80AC+s), R(0x8028+s), R(0x83B0+s)))
  client.screenshot("C:\\tmp\\rock_in_flight.png")
  -- Now idle 4 frames and capture again
  idle(4)
  f:write(string.format("+4f:   type=$%02X X=$%02X Y=$%02X\n",
    R(0x834F+s), R(0x8070+s), R(0x8084+s)))
  client.screenshot("C:\\tmp\\rock_in_flight_4f.png")
else
  f:write("ROCK NOT SEEN in 1800 frames — octorok didn't shoot\n")
end

-- Dump all 12 enemy slots
f:write("\n=== All enemy slots ===\n")
for s=0,11 do
  local t = R(0x834F + s)
  if t ~= 0 then
    f:write(string.format("slot %2d: type=$%02X X=$%02X Y=$%02X dir=$%02X spd=$%02X\n",
      s, t, R(0x8070+s), R(0x8084+s), R(0x8098+s), R(0x83BC+s)))
  end
end

-- Dump Genesis VRAM at tile slots for NES $98/$99/$9A/$9B (rock body 8x16x2)
-- OW enemies tile_base = 1069 (SPR_BASE 1025 + 44). NES tile $X → Genesis 1069+(X-$8E).
for _, nes_t in ipairs({0x9E, 0x9F, 0xA0, 0xA1}) do
  local gen_tile = 1069 + (nes_t - 0x8E)
  f:write(string.format("\n=== Genesis VRAM tile %d (NES $%02X) ===\n", gen_tile, nes_t))
  local TILE_BASE_BYTES = gen_tile * 32
  for row=0,7 do
    local off = TILE_BASE_BYTES + row*4
    f:write(string.format("  row%d: %02X %02X %02X %02X\n",
      row, VR(off), VR(off+1), VR(off+2), VR(off+3)))
  end
end

-- CRAM dump
f:write("\n=== CRAM (Genesis 4x16 palette) ===\n")
for pal=0,3 do
  f:write(string.format("PAL%d:", pal))
  for c=0,15 do
    local off = pal*32 + c*2
    local v = memory.read_u16_be(off, "CRAM")
    f:write(string.format(" $%04X", v))
  end
  f:write("\n")
end

-- VDP regs (read raw)
f:write("\n=== VDP register snapshot ===\n")
-- VDP regs aren't directly readable via memory.read; use BizHawk's vdp.* if available
-- Just dump SAT at multiple candidate addresses to see which has real data
for _, base in ipairs({0xA800, 0xB800, 0xC000, 0xD800, 0xE000, 0xF000, 0xF800, 0xFC00}) do
  local sample_y = memory.read_u16_be(base, "VRAM")
  local sample_attr = memory.read_u16_be(base+4, "VRAM")
  f:write(string.format("  $%04X: y=$%04X attr=$%04X\n", base, sample_y, sample_attr))
end

-- Dump ALL non-empty SAT entries
f:write("\n=== Full SAT dump (non-empty entries) ===\n")
local SAT = 0xF400
for s=0,79 do
  local off = SAT + s*8
  local y    = memory.read_u16_be(off, "VRAM")
  local size = memory.read_u8(off+2, "VRAM")
  local link = memory.read_u8(off+3, "VRAM")
  local tile_attr = memory.read_u16_be(off+4, "VRAM")
  local x    = memory.read_u16_be(off+6, "VRAM")
  local tile = tile_attr & 0x7FF
  if y ~= 0 or tile_attr ~= 0 or x ~= 0 then
    f:write(string.format("  sat %2d: y=$%04X size=$%02X link=$%02X tile=%d attr=$%04X x=$%04X\n",
      s, y, size, link, tile, tile_attr, x))
  end
end

f:close()
idle(10)
client.exit()

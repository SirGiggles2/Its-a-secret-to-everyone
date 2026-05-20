-- Genesis beam slot 2 capture in 4 directions. Press direction then A button (sword).
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end; joypad.set({},1); emu.frameadvance() end

idle(240)
press({A=true,B=true,C=true}, 8); idle(120)

local function dump_slot2(label, f)
  local off = 0xF400 + 2*8
  local y = memory.read_u16_be(off+0, "VRAM")
  local sz = memory.read_u8(off+2, "VRAM")
  local lk = memory.read_u8(off+3, "VRAM")
  local a = memory.read_u16_be(off+4, "VRAM")
  local x = memory.read_u16_be(off+6, "VRAM")
  f:write(string.format("%s: y=%d (px %d) sz=$%02X lk=%d attr=$%04X x=%d (px %d) tile=%d pal=%d hf=%d vf=%d\n",
    label, y, y-128, sz, lk, a, x, x-128, a%0x800, (a>>13)%4, (a>>11)%2, (a>>12)%2))
end

local f = io.open("C:\\tmp\\gen_beam_4dir.txt", "w")
f:write("=== Genesis SAT slot 2 BEAM across 4 directions ===\n")

-- Try BOTH A and B buttons (port may have A/B swap)
for _, sword_btn in ipairs({"A", "B"}) do
  f:write("\n### Sword button = " .. sword_btn .. " ###\n")
  for _, dir in ipairs({"Up","Down","Left","Right"}) do
    -- Face that direction
    press({[dir]=true}, 5); idle(5)
    press({[sword_btn]=true}, 1)
    for fr = 1, 12 do
      dump_slot2(string.format("%s %s fr%2d", sword_btn, dir, fr), f)
      idle(1)
    end
    idle(60)
  end
end

f:close()
client.screenshot("C:\\tmp\\gen_beam_4dir.png")
client.exit()

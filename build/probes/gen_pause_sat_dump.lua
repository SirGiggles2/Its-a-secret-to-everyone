-- Dump SAT after pause enter.
local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/pause_sat.txt"

local function press(b, n) for _=1,n do joypad.set(b, 1); emu.frameadvance() end; joypad.set({}, 1); emu.frameadvance() end
local function idle(n) for _=1,n do emu.frameadvance() end end

idle(240)
press({A=true, B=true, C=true}, 8); idle(120)
press({Start=true}, 6); idle(30)

local f = io.open(OUT, "w")
f:write("SAT @ $F400 after pause:\n")
for slot = 0, 30 do
  local off = 0xF400 + slot * 8
  local y    = memory.read_u16_be(off + 0, "VRAM")
  local sz   = memory.read_u16_be(off + 2, "VRAM")
  local attr = memory.read_u16_be(off + 4, "VRAM")
  local x    = memory.read_u16_be(off + 6, "VRAM")
  local tile_id = attr % 0x800
  f:write(string.format("  slot %2d: y=%3d  tile=%4d  link=%3d  attr=$%04X  x=%3d\n",
    slot, y, tile_id, sz % 0x100, attr, x))
end
f:close()
client.screenshot((os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/pause_sat_dump.png")
client.exit()

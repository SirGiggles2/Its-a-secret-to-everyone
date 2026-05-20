-- Spawn stress harness, dump SAT to verify all 11 enemies render.
local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp"

local function idle(n) for _=1,n do emu.frameadvance() end end

idle(180)
joypad.set({A=true, B=true, C=true}, 1)
for _=1,8 do emu.frameadvance() end
joypad.set({}, 1)
idle(240)  -- enemies fully spawned + animated

client.screenshot(OUT .. "/enemies_sat_dump.png")

-- SAT base = $F400 (gameplay context per PR-2 Option F)
-- SAT entry = 8 bytes: y(2) + size_link(2) + attr(2) + x(2)
local f = io.open(OUT .. "/enemies_sat_dump.txt", "w")
f:write("SAT dump (gameplay context, base $F400):\n")
f:write("slot |   y  | size_link |   attr   |   x\n")
for slot = 0, 30 do
  local off = 0xF400 + slot * 8
  local y    = memory.read_u16_be(off + 0, "VRAM")
  local sz   = memory.read_u16_be(off + 2, "VRAM")
  local attr = memory.read_u16_be(off + 4, "VRAM")
  local x    = memory.read_u16_be(off + 6, "VRAM")
  local tile_id = attr & 0x07FF
  f:write(string.format("%4d | %4d |   %04X    |   %04X   | %4d  tile=%4d\n",
    slot, y, sz, attr, x, tile_id))
end
f:close()
print("done")
client.exit()

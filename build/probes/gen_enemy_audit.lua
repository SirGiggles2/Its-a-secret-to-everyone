-- Audit enemy render: spawn stress harness, cross-reference ObjType + SAT.
local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp"

local function idle(n) for _=1,n do emu.frameadvance() end end

idle(180)
joypad.set({A=true, B=true, C=true}, 1)
for _=1,8 do emu.frameadvance() end
joypad.set({}, 1)
idle(180)  -- enemies spawn + AI ticks settle

client.screenshot(OUT .. "/enemy_audit.png")

-- VDP reg 5 = SAT base. Read via VDP register state.
-- For Genesis SGDK with PR-2 Option F, SAT could be $F400 (gameplay) or $F800 (title).
-- Read VDP reg 5 isn't directly accessible; just try both addrs.

local function read_sat_entry(base, slot)
  local off = base + slot * 8
  return {
    y = memory.read_u16_be(off + 0, "VRAM"),
    sz_link = memory.read_u16_be(off + 2, "VRAM"),
    attr = memory.read_u16_be(off + 4, "VRAM"),
    x = memory.read_u16_be(off + 6, "VRAM"),
  }
end

-- ObjType slot N at $FF034F + N. BizHawk 68K RAM domain offset = $034F + N.
local function read_obj_type(slot)
  return memory.read_u8(0x034F + slot, "68K RAM")
end

local function read_obj_x(slot)
  -- ObjX at $0070 per NES Z1 convention; verify against nes_ram_sync
  return memory.read_u8(0x0070 + slot, "68K RAM")
end
local function read_obj_y(slot)
  return memory.read_u8(0x0028 + slot, "68K RAM") -- ObjY at $0028
end

local f = io.open(OUT .. "/enemy_audit.txt", "w")
f:write("ENEMY AUDIT — stress harness, ObjType + SAT cross-ref\n\n")

f:write("ObjType[slots 1..11] from RAM $034F+:\n")
for slot = 1, 11 do
  local t = read_obj_type(slot)
  local x = read_obj_x(slot)
  local y = read_obj_y(slot)
  f:write(string.format("  slot %2d: type=$%02X x=$%02X y=$%02X\n", slot, t, x, y))
end

f:write("\nSAT @ $F400 slots 0..15:\n")
for slot = 0, 15 do
  local e = read_sat_entry(0xF400, slot)
  local tile_id = e.attr & 0x07FF
  f:write(string.format("  slot %2d: y=%3d  tile=%4d  attr=$%04X  link=$%04X  x=%3d\n",
    slot, e.y, tile_id, e.attr, e.sz_link, e.x))
end

f:write("\nSAT @ $F800 slots 0..15:\n")
for slot = 0, 15 do
  local e = read_sat_entry(0xF800, slot)
  local tile_id = e.attr & 0x07FF
  f:write(string.format("  slot %2d: y=%3d  tile=%4d  attr=$%04X  link=$%04X  x=%3d\n",
    slot, e.y, tile_id, e.attr, e.sz_link, e.x))
end

f:close()
print("audit done")
client.exit()

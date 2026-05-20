-- tile_67_dump.lua — walk to $67, hold UP, sample tile under foot
-- (mirror off 21 = tile_under_link_foot, raw NES BG tile id).
-- Also dump first 256 bytes of mirror to see any walkable data nearby.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function S16BE(o)
  local v = R16BE(o); if v >= 0x8000 then v = v - 0x10000 end; return v
end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\tile_67.txt"
local f = io.open(OUT, "w")

local function snap(tag)
  f:write(string.format("%-14s rm=$%02X X=$%04X Y=$%04X face=%d walk=%d walkN=%d col=%d row=%d tile=$%02X stable=%d\n",
    tag, R(0x7205),
    S16BE(0x7206) & 0xFFFF, S16BE(0x7208) & 0xFFFF,
    R(0x720A), R(0x7223), R(0x7224), R(0x7225), R(0x7226), R(0x7215), R(0x7212)))
end

idle(60)
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
memory.write_u8(0x73FA, 0x01, "68K RAM")

for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(30)
snap("spawn_77")

-- Walk north to $67 (clamps at top after enough frames)
for i=1,400 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(20)
snap("clamped_at_67_top")

-- OW raw tile cache lives at $FF7400 (per debug runtime header).
-- Layout: 708 bytes = 16 cols × 22 raw tile rows × 2 bytes? Or pairs?
-- Try dumping just enough to see the top of $67.
f:write("\n-- OW raw tile cache (first 80 bytes from $FF7400) --\n")
for i=0,79 do
  if i % 16 == 0 then f:write(string.format("\n$%04X: ", 0x7400+i)) end
  f:write(string.format("%02X ", R(0x7400+i)))
end
f:write("\n")

-- Scan walkable map via brute force: hold UP and step by direct memory
-- write of player.y. Mirror offset 8-9 = link_y. But we can't write game state.
-- Instead, sweep X positions and sample walkN at each.
f:write("\n-- WalkN sweep across $67 row 2 (Y stays $54-ish) --\n")
for i=1,300 do joypad.set({Left=true}, 1); emu.frameadvance() end
idle(10)
snap("after_far_left")
for i=1,400 do
  joypad.set({Right=true, Up=true}, 1); emu.frameadvance()
  if i % 5 == 0 then snap("RU_"..i) end
end

client.screenshot("C:\\tmp\\tile_67.png")
f:write("\nDONE\n")
f:close()
gui.text(8, 8, "tile done")
idle(20)
client.exit()

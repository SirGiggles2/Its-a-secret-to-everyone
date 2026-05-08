local OUT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\probes\\ph5\\uw_collision_boot_proof.json"
local SCREENSHOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\probes\\ph5\\uw_collision_boot_proof.png"
local TILE_ADDR = 0x0945
local LINK_X_ADDR = 0x000E
local LINK_Y_ADDR = 0x000C
local ROOM_ADDR = 0x0010
local EXPECTED = {
{0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0},
{0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0},
{0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,1,1,0,0,0,0},
{0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,1,1,0,0,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
{0,0,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0},
{0,0,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0}
}

local function read_u8(addr)
  return memory.read_u8(addr, "68K RAM") or 0
end

local function read_s16(addr)
  return memory.read_s16_be(addr, "68K RAM") or 0
end

for _ = 1, 180 do
  emu.frameadvance()
end

local diff = {}
local walk = 0
local block = 0
for col = 0, 31 do
  for row = 0, 21 do
    local actual = read_u8(TILE_ADDR + col * 22 + row)
    local expected = EXPECTED[col + 1][row + 1]
    if actual ~= 0 then walk = walk + 1 else block = block + 1 end
    if ((actual ~= 0) and 1 or 0) ~= expected then
      diff[#diff + 1] = string.format(
        '{"col":%d,"row":%d,"expected":%d,"actual":%d}',
        col, row, expected, actual)
    end
  end
end

for row = 0, 21 do
  for col = 0, 31 do
    local actual = read_u8(TILE_ADDR + col * 22 + row)
    local fill = actual ~= 0 and 0x7000D050 or 0x70E02028
    gui.drawBox(8 + col * 8, 56 + row * 8,
                8 + col * 8 + 7, 56 + row * 8 + 7,
                0x50000000, fill)
  end
end
gui.drawBox(0, 0, 255, 18, 0xC0000000, 0xC0000000)
gui.text(4, 3, "UW collision proof: diff=" .. tostring(#diff) ..
    " room=$" .. string.format("%02X", read_u8(ROOM_ADDR)),
    0xFFFFFFFF, 0xC0000000)
emu.frameadvance()
client.screenshot(SCREENSHOT)

local f = assert(io.open(OUT, "w"))
f:write('{\n')
f:write('  "pass": ', (#diff == 0) and 'true' or 'false', ',\n')
f:write('  "room": ', read_u8(ROOM_ADDR), ',\n')
f:write('  "link_x": ', read_s16(LINK_X_ADDR), ',\n')
f:write('  "link_y": ', read_s16(LINK_Y_ADDR), ',\n')
f:write('  "tile_addr": ', TILE_ADDR, ',\n')
f:write('  "walkable_count": ', walk, ',\n')
f:write('  "blocked_count": ', block, ',\n')
f:write('  "diff_count": ', #diff, ',\n')
f:write('  "diff": [', table.concat(diff, ","), ']\n')
f:write('}\n')
f:close()
client.exit()

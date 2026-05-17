-- cave_entry_v2.lua — slow walk-up + sample standing_tile + cave-entry counter.
-- Sentinels: NES $07FC = cave entry fire counter, $07FD = last standing tile.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\cave_entry_v2.txt"
local f = io.open(OUT, "w")

local FC = 0x7202; local ROOM = 0x7205; local SCENE = 0x7204
local LX = 0x7207; local LY = 0x7209
local ENTRY_CNT = 0x87FC; local LAST_TILE = 0x87FD

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)

local function state(label)
  f:write(string.format("%s scene=%d room=$%02X X=$%02X Y=$%02X entryCnt=$%02X lastTile=$%02X fc=%d\n",
    label, R(SCENE), R(ROOM), R(LX), R(LY),
    R(ENTRY_CNT), R(LAST_TILE), R16BE(FC)))
end

state("[01 boot]")
client.screenshot("C:\\tmp\\cave_v2_01.png")

-- BEFORE walk: scan PlayAreaTiles in room $77 for cave-entry tiles.
f:write("\nROOM $77 PlayAreaTiles scan (before walk):\n")
local boot_entries = 0
for col=0,31 do
  local col_base = 0xE530 + col * 0x16
  for row=0,21 do
    local t = R(col_base + row)
    if t == 0x24 or t == 0x88 or (t >= 0x70 and t <= 0x73) then
      f:write(string.format("  ROOM77 ENTRY: col=%d row=%d tile=$%02X\n", col, row, t))
      boot_entries = boot_entries + 1
    end
  end
end
f:write(string.format("Room $77 entry tile count: %d\n\n", boot_entries))

-- Walk Up watching for cave entry events; sample standing_tile every frame.
local entries = {}
local prev_entry = R(ENTRY_CNT)
local prev_tile = R(LAST_TILE)
local tile_log = {}    -- (frame, room, Y, tile) when tile changes in $77
local room_changes = 0
local prev_room = R(ROOM)
-- Cave at col 8-9 row 3 (X=$40-$4F, Y=$58). Link X=$78 Y=$8D.
-- NES Z1 4-directional only — alternate Left until X < $50, then Up.
-- After entry fires, log scene transitions.
local prev_scene = R(SCENE)
for i=1,400 do
  local lx = R(LX)
  local btns = {}
  if lx > 0x48 then btns.Left = true else btns.Up = true end
  joypad.set(btns, 1)
  emu.frameadvance()
  local sc = R(SCENE)
  if sc ~= prev_scene then
    tile_log[#tile_log+1] = string.format("frame %d: SCENE CHANGE %d -> %d (room=$%02X X=$%02X Y=$%02X)",
      i, prev_scene, sc, R(ROOM), R(LX), R(LY))
    prev_scene = sc
  end
  local cnt = R(ENTRY_CNT)
  local tile = R(LAST_TILE)
  local room = R(ROOM)
  if room ~= prev_room then
    tile_log[#tile_log+1] = string.format("frame %d: ROOM CHANGE $%02X -> $%02X (Y=$%02X)",
      i, prev_room, room, R(LY))
    room_changes = room_changes + 1
    prev_room = room
  end
  if cnt ~= prev_entry then
    entries[#entries+1] = string.format("frame %d: ENTRY_FIRED cnt %d -> %d (Y=$%02X tile=$%02X scene=%d room=$%02X)",
      i, prev_entry, cnt, R(LY), tile, R(SCENE), R(ROOM))
    prev_entry = cnt
  end
  if tile ~= prev_tile then
    -- Log all tile transitions while in $77 or special tiles always
    if room == 0x77 or tile == 0x24 or tile == 0x88 or (tile >= 0x70 and tile <= 0x73) then
      tile_log[#tile_log+1] = string.format("frame %d (room=$%02X Y=$%02X): tile $%02X -> $%02X",
        i, room, R(LY), prev_tile, tile)
    end
    prev_tile = tile
  end
end
f:write("\nTile transitions during walk:\n")
for _, e in ipairs(tile_log) do f:write("  " .. e .. "\n") end

f:write(string.format("\n%d cave-entry events:\n", #entries))
for _, e in ipairs(entries) do f:write("  " .. e .. "\n") end

state("[02 after walk]")
client.screenshot("C:\\tmp\\cave_v2_02.png")

idle(60)
-- Dump some PlayAreaTiles cells to check if populated
-- col 8 row 4 = $6530 + 8*$16 + 4 = $65DC. Address via $86xx (A4 base).
-- PlayAreaTiles: nes_ram[$6530+col*$16+row]. 68K RAM offset = $E530.
-- After walk we're in $67. Need PlayAreaTiles AT ROOM $77 — sample at boot.
-- For now just dump current room's full grid scan for cave-entry tiles.
f:write("\nScan PlayAreaTiles (32 cols x 22 rows) for cave-entry tiles:\n")
local found_entries = 0
for col=0,31 do
  local col_base = 0xE530 + col * 0x16
  for row=0,21 do
    local t = R(col_base + row)
    if t == 0x24 or t == 0x88 or (t >= 0x70 and t <= 0x73) then
      f:write(string.format("  CAVE-ENTRY TILE: col=%d row=%d tile=$%02X\n", col, row, t))
      found_entries = found_entries + 1
    end
  end
end
f:write(string.format("Total cave-entry tiles in current PlayAreaTiles: %d\n", found_entries))

-- Dump cols 12-17 rows 0-10 to see structure near boot cave area
f:write("\nUpper-screen tiles (cols 12-17, rows 0-10):\n")
for col=12,17 do
  local col_base = 0xE530 + col * 0x16
  f:write(string.format("  col %02d:", col))
  for row=0,10 do
    f:write(string.format(" $%02X", R(col_base + row)))
  end
  f:write("\n")
end

idle(15)
client.exit()

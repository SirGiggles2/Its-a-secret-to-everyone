-- BizHawk live UW walkability overlay.
--
-- Default mode draws the actual 32x22 collision tile mask that Link samples.
-- Edit MODE below to inspect directional movement-coordinate walkability:
--   "tile", "left", "right", "up", "down"

local MODE = "tile"
local SCREEN_X = 0
local SCREEN_Y = 64
local VISUAL_X_BIAS = 0
local TILE = 8
local SAMPLE = 4
local NES_PLAY_AREA = 0x6530
local NES_THRESHOLD = 0x034A

local function parse_env_hex(value, fallback)
  if value == nil or value == "" then return fallback end
  return tonumber(value) or tonumber((value:gsub("^0x", "")), 16) or fallback
end

local GEN_TILE_WALKABLE_ADDR = parse_env_hex(os.getenv("CODEX_UW_OVERLAY_TILE_WALKABLE"), 0)
local GEN_LINK_X_ADDR = parse_env_hex(os.getenv("CODEX_UW_OVERLAY_LINK_X"), 0)
local GEN_LINK_Y_ADDR = parse_env_hex(os.getenv("CODEX_UW_OVERLAY_LINK_Y"), 0)

local function domain_exists(name)
  for _, domain in ipairs(memory.getmemorydomainlist()) do
    if domain == name then return true end
  end
  return false
end

local GEN_RAM_DOMAIN = "M68K BUS"
local GEN_ADDR_BASE = 0x00FF0000
if domain_exists("68K RAM") then
  GEN_RAM_DOMAIN = "68K RAM"
  GEN_ADDR_BASE = 0
elseif domain_exists("M68K RAM") then
  GEN_RAM_DOMAIN = "M68K RAM"
  GEN_ADDR_BASE = 0
end

local function gen_u8(addr)
  return memory.read_u8(GEN_ADDR_BASE + addr, GEN_RAM_DOMAIN) or 0
end

local function gen_s16(addr)
  return memory.read_s16_be(GEN_ADDR_BASE + addr, GEN_RAM_DOMAIN)
end

local ok_system, system_id = pcall(emu.getsystemid)
if ok_system and system_id ~= "NES" then
  SCREEN_Y = 56
  VISUAL_X_BIAS = 8
end

local COLOR_WALK_FILL = 0x7000D050
local COLOR_BLOCK_FILL = 0x70E02028
local COLOR_GRID = 0x50000000
local COLOR_LINE = 0xFFFFFFFF
local COLOR_TEXT_BG = 0xC0000000
local COLOR_TEXT = 0xFFFFFFFF
local COLOR_HOTSPOT = 0xFFFFFF00

local DOOR_E = 0
local DOOR_W = 1
local DOOR_S = 2
local DOOR_N = 3

-- Room $73, L1Q1: E=open, W=open, S=open, N=key.
local DOOR_TYPE = {
  [DOOR_E] = 0,
  [DOOR_W] = 0,
  [DOOR_S] = 0,
  [DOOR_N] = 5,
}
local KEYS = 3

local function tile_walkable(col, row)
  if col < 0 or col > 31 or row < 0 or row > 21 then
    return false
  end
  if ok_system and system_id == "NES" then
    local threshold = memory.read_u8(NES_THRESHOLD, "System Bus") or 0x78
    local tile = memory.read_u8(NES_PLAY_AREA + col * 22 + row, "System Bus") or 0xFF
    return tile < threshold
  end
  if GEN_TILE_WALKABLE_ADDR == 0 then
    return false
  end
  return gen_u8(GEN_TILE_WALKABLE_ADDR + col * 22 + row) ~= 0
end

local function door_passable(door_dir)
  local t = DOOR_TYPE[door_dir] or 1
  if t == 0 then return true end
  if (t == 5 or t == 6) and KEYS > 0 then return true end
  return false
end

local function doorway_at(x, y)
  if y == 0x8D then
    if x >= 0x00 and x < 0x21 then return DOOR_W end
    if x >= 0xCF and x < 0xF1 then return DOOR_E end
  end
  if x == 0x78 then
    if y >= 0x3D and y < 0x5E then return DOOR_N end
    if y >= 0xBD and y < 0xDE then return DOOR_S end
  end
  return nil
end

local function doorway_axis_matches(door_dir, dir)
  if door_dir == DOOR_E or door_dir == DOOR_W then
    return dir == "left" or dir == "right"
  end
  return dir == "up" or dir == "down"
end

local function doorway_toward(door_dir)
  if door_dir == DOOR_E then return "right" end
  if door_dir == DOOR_W then return "left" end
  if door_dir == DOOR_S then return "down" end
  return "up"
end

local function doorway_pass(dir, x, y)
  local door_dir = doorway_at(x, y)
  if door_dir == nil then return nil end
  if not doorway_axis_matches(door_dir, dir) then return false end
  if dir == doorway_toward(door_dir) then
    return door_passable(door_dir)
  end
  return true
end

local function sample_nes(dir, x, y)
  local base_y = y + 0x0B
  if dir == "right" then
    return (x >= 0xF0) and x or (x + 0x10), base_y
  elseif dir == "left" then
    return (x < 0x10) and x or (x - 0x08), base_y
  elseif dir == "down" then
    return x, (base_y >= 0xDD) and base_y or (base_y + 0x08)
  elseif dir == "up" then
    return x, base_y - 0x08
  end
  return x, y
end

local function move_allowed(dir, x, y)
  local door = doorway_pass(dir, x, y)
  if door ~= nil then return door end

  local hot_x, hot_y = sample_nes(dir, x, y)
  if hot_y < 0x40 then return false end
  local col = math.floor(hot_x / 8)
  local row = math.floor((hot_y - 0x40) / 8)
  if col < 0 or col > 31 or row < 0 or row > 21 then return true end
  if not tile_walkable(col, row) then return false end
  if (dir == "up" or dir == "down") and col < 31 then
    return tile_walkable(col + 1, row)
  end
  return true
end

local function draw_tile_overlay()
  for row = 0, 21 do
    for col = 0, 31 do
      local x0 = SCREEN_X + VISUAL_X_BIAS + col * TILE
      local y0 = SCREEN_Y + row * TILE
      local fill = tile_walkable(col, row) and COLOR_WALK_FILL or COLOR_BLOCK_FILL
      gui.drawBox(x0, y0, x0 + TILE - 1, y0 + TILE - 1, COLOR_GRID, fill)
    end
  end
end

local function draw_move_overlay(dir)
  for y = 0, 175, SAMPLE do
    for x = 0, 255, SAMPLE do
      local ok = move_allowed(dir, x - VISUAL_X_BIAS, SCREEN_Y + y)
      local fill = ok and COLOR_WALK_FILL or COLOR_BLOCK_FILL
      gui.drawBox(SCREEN_X + x, SCREEN_Y + y,
                  SCREEN_X + x + SAMPLE - 1, SCREEN_Y + y + SAMPLE - 1,
                  fill, fill)
    end
  end
  for y = 0, 176, 8 do
    gui.drawLine(SCREEN_X, SCREEN_Y + y, SCREEN_X + 255, SCREEN_Y + y, COLOR_GRID)
  end
  for x = 0, 256, 8 do
    gui.drawLine(SCREEN_X + x, SCREEN_Y, SCREEN_X + x, SCREEN_Y + 175, COLOR_GRID)
  end
end

local function read_link_pos()
  if ok_system and system_id ~= "NES" then
    if GEN_LINK_X_ADDR == 0 or GEN_LINK_Y_ADDR == 0 then return nil, nil end
    local x = gen_s16(GEN_LINK_X_ADDR)
    local y = gen_s16(GEN_LINK_Y_ADDR)
    return x, y
  end
  return nil, nil
end

local function draw_live_probe(dir)
  if dir ~= "left" and dir ~= "right" and dir ~= "up" and dir ~= "down" then
    return
  end
  local x, y = read_link_pos()
  if x == nil or y == nil then return end
  local hot_x, hot_y = sample_nes(dir, x, y)
  gui.drawBox(x, y, x + 15, y + 15, COLOR_LINE, 0x00000000)
  gui.drawBox(hot_x - 2, hot_y - 2, hot_x + 2, hot_y + 2,
              COLOR_HOTSPOT, COLOR_HOTSPOT)
end

local function draw_legend()
  gui.drawBox(0, 0, 255, 17, COLOR_TEXT_BG, COLOR_TEXT_BG)
  gui.text(4, 2, "UW live walkability  mode=" .. MODE ..
      "  xbias=" .. VISUAL_X_BIAS .. "  green=walk red=block yellow=hotspot",
      COLOR_TEXT, COLOR_TEXT_BG)
end

while true do
  if MODE == "tile" then
    draw_tile_overlay()
  elseif MODE == "left" or MODE == "right" or MODE == "up" or MODE == "down" then
    draw_move_overlay(MODE)
    draw_live_probe(MODE)
  else
    MODE = "tile"
    draw_tile_overlay()
  end
  draw_legend()
  emu.frameadvance()
end

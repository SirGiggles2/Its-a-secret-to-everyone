-- Live Genesis UW walk debugger for BizHawk.
--
-- Shows the exact runtime collision facts for Link's current position and
-- writes build/reports/uw_live_walk_debug/latest.json every few frames.
-- Launcher passes symbol addresses through CODEX_UW_LIVE_* env vars.

local OUT_JSON = os.getenv("CODEX_UW_LIVE_OUT_JSON") or "uw_live_walk_debug.json"

local function getenv_num(name, fallback)
  local v = os.getenv(name)
  if v == nil or v == "" then return fallback end
  return tonumber(v) or tonumber(v:gsub("^0x", ""), 16) or fallback
end

local ADDR = {
  tile_walkable = getenv_num("CODEX_UW_LIVE_TILE_WALKABLE", 0),
  door_types = getenv_num("CODEX_UW_LIVE_DOOR_TYPES", 0),
  cur_opened = getenv_num("CODEX_UW_LIVE_CUR_OPENED", 0),
  room_id = getenv_num("CODEX_UW_LIVE_ROOM_ID", 0),
  scene = getenv_num("CODEX_UW_LIVE_SCENE", 0),
  link_x = getenv_num("CODEX_UW_LIVE_LINK_X", 0),
  link_y = getenv_num("CODEX_UW_LIVE_LINK_Y", 0),
  link_dir = getenv_num("CODEX_UW_LIVE_LINK_DIR", 0),
  link_face = getenv_num("CODEX_UW_LIVE_LINK_FACE", 0),
  link_keys = getenv_num("CODEX_UW_LIVE_LINK_KEYS", 0),
  grid_offset = getenv_num("CODEX_UW_LIVE_GRID_OFFSET", 0),
  pos_frac = getenv_num("CODEX_UW_LIVE_POS_FRAC", 0),
  doorway_dir = getenv_num("CODEX_UW_LIVE_DOORWAY_DIR", 0),
  scroll_state = getenv_num("CODEX_UW_LIVE_SCROLL_STATE", 0),
  scroll_frame = getenv_num("CODEX_UW_LIVE_SCROLL_FRAME", 0),
}

local PROBE_BASE = 0x7000
local TITLE_PHASE_ADDR = 0x8000 + 0x07F0

local function domain_exists(name)
  for _, domain in ipairs(memory.getmemorydomainlist()) do
    if domain == name then return true end
  end
  return false
end

local RAM_DOMAIN = "M68K BUS"
local RAM_ADDR_BASE = 0x00FF0000
if domain_exists("68K RAM") then
  RAM_DOMAIN = "68K RAM"
  RAM_ADDR_BASE = 0
elseif domain_exists("M68K RAM") then
  RAM_DOMAIN = "M68K RAM"
  RAM_ADDR_BASE = 0
end

local TOP = 0x38
local DOWN_ASIS_Y = 0xD5
local X_BIAS = 0

local DIRS = {
  { name = "down",  id = 1, color = 0xFF00FFFF },
  { name = "up",    id = 2, color = 0xFFFFFF00 },
  { name = "left",  id = 3, color = 0xFFFF80FF },
  { name = "right", id = 4, color = 0xFF80FF80 },
}

local DOOR_E = 0
local DOOR_W = 1
local DOOR_S = 2
local DOOR_N = 3

local DOOR_NAME = { [0] = "E", [1] = "W", [2] = "S", [3] = "N", [255] = "none" }
local DOOR_TYPE_NAME = {
  [0] = "open",
  [1] = "wall",
  [2] = "false",
  [3] = "false2",
  [4] = "bomb",
  [5] = "key",
  [6] = "key2",
  [7] = "shutter",
}
local DIR_NAME = { [0] = "none", [1] = "down", [2] = "up", [3] = "left", [4] = "right" }

local function u8(addr)
  if addr == 0 then return 0 end
  return memory.read_u8(RAM_ADDR_BASE + addr, RAM_DOMAIN) or 0
end

local function s8_from_u8(v)
  if v >= 0x80 then return v - 0x100 end
  return v
end

local function s16(addr)
  if addr == 0 then return 0 end
  local hi = u8(addr)
  local lo = u8(addr + 1)
  local v = hi * 256 + lo
  if v >= 0x8000 then v = v - 0x10000 end
  return v
end

local function u16(addr)
  if addr == 0 then return 0 end
  return u8(addr) * 256 + u8(addr + 1)
end

local function u32_small(addr)
  if addr == 0 then return 0 end
  local b0 = u8(addr)
  local b1 = u8(addr + 1)
  local b2 = u8(addr + 2)
  local b3 = u8(addr + 3)
  if b3 ~= 0 then return b3 end
  if b2 ~= 0 then return b2 end
  if b1 ~= 0 then return b1 end
  return b0
end

local function tile_walkable(col, row)
  if col < 0 or col > 31 or row < 0 or row > 21 then
    return false, 0
  end
  local v = u8(ADDR.tile_walkable + col * 22 + row)
  return v ~= 0, v
end

local function door_type(door_dir)
  if door_dir == nil or door_dir < 0 or door_dir > 3 or ADDR.door_types == 0 then
    return 1
  end
  return u8(ADDR.door_types + door_dir)
end

local function door_opened(door_dir)
  if door_dir == nil or door_dir < 0 or door_dir > 3 then return false end
  return (u8(ADDR.cur_opened) & (1 << door_dir)) ~= 0
end

local function doorway_at(dir_name, x, y)
  if dir_name == "left" or dir_name == "right" then
    if y == 0x85 then
      if x >= 0x00 and x < 0x21 then return DOOR_W end
      if x >= 0xCF and x < 0xF1 then return DOOR_E end
    end
  else
    if x == 0x78 then
      if y >= 0x35 and y < 0x56 then return DOOR_N end
      if y >= 0xB5 and y < 0xD6 then return DOOR_S end
    end
  end
  return nil
end

local function doorway_axis_matches(door_dir, dir_name)
  if door_dir == DOOR_E or door_dir == DOOR_W then
    return dir_name == "left" or dir_name == "right"
  end
  return dir_name == "up" or dir_name == "down"
end

local function doorway_toward(door_dir)
  if door_dir == DOOR_E then return "right" end
  if door_dir == DOOR_W then return "left" end
  if door_dir == DOOR_S then return "down" end
  return "up"
end

local function door_passable_for_touch(door_dir)
  local t = door_type(door_dir)
  if t == 0 then return true, "open door" end
  if t == 1 then return false, "wall door" end
  if t == 2 or t == 3 then
    if door_opened(door_dir) then return true, "false wall opened" end
    return false, "false wall timer/not opened"
  end
  if t == 5 or t == 6 then
    if door_opened(door_dir) then return true, "key door already opened" end
    if u8(ADDR.link_keys) > 0 then return true, "key door and keys>0" end
    return false, "key door no keys"
  end
  if t == 4 or t == 7 then
    if door_opened(door_dir) then return true, "triggered opened" end
    return false, "bomb/shutter not opened"
  end
  return false, "unknown door type"
end

local function sample(dir_name, x, y)
  local base_y = y + 0x0B
  if dir_name == "right" then
    return (x >= 0xF0) and x or (x + 0x10), base_y
  elseif dir_name == "left" then
    return (x < 0x10) and x or (x - 0x08), base_y
  elseif dir_name == "down" then
    return x, (base_y >= DOWN_ASIS_Y) and base_y or (base_y + 0x08)
  elseif dir_name == "up" then
    return x, base_y - 0x08
  end
  return x, y
end

local function analyze_dir(dir_name, x, y, grid_offset)
  local out = {
    dir = dir_name,
    x = x,
    y = y,
    source = "tile",
    ok = false,
    reason = "",
    door = nil,
    hot_x = 0,
    hot_y = 0,
    col = -1,
    row = -1,
    tile1 = 0,
    tile2 = nil,
  }

  if grid_offset ~= 0 then
    out.source = "midgrid"
    out.ok = true
    out.reason = "mid-grid: NES skips tile collision until offset 0"
    return out
  end

  local door_dir = doorway_at(dir_name, x, y)
  if door_dir ~= nil then
    out.source = "door"
    out.door = door_dir
    if not doorway_axis_matches(door_dir, dir_name) then
      out.ok = false
      out.reason = "door axis mismatch"
      return out
    end
    if dir_name == doorway_toward(door_dir) then
      out.ok, out.reason = door_passable_for_touch(door_dir)
    else
      out.ok = true
      out.reason = "backing out of doorway"
    end
    return out
  end

  local hot_x, hot_y = sample(dir_name, x, y)
  out.hot_x = hot_x
  out.hot_y = hot_y
  if hot_y < TOP then
    out.ok = false
    out.reason = "hot_y above playfield"
    return out
  end

  local tile_x = hot_x - X_BIAS
  local col = (tile_x < 0) and -1 or math.floor(tile_x / 8)
  local row = math.floor((hot_y - TOP) / 8)
  out.col = col
  out.row = row
  if col < 0 or col > 31 or row < 0 or row > 21 then
    out.ok = true
    out.reason = "sample outside room collision bounds"
    return out
  end

  local walk1, v1 = tile_walkable(col, row)
  out.tile1 = v1
  if not walk1 then
    out.ok = false
    out.reason = "primary tile blocked"
    return out
  end
  if (dir_name == "up" or dir_name == "down") and col < 31 then
    local walk2, v2 = tile_walkable(col + 1, row)
    out.tile2 = v2
    if not walk2 then
      out.ok = false
      out.reason = "vertical second-column tile blocked"
      return out
    end
  end
  out.ok = true
  out.reason = "sampled tile(s) walkable"
  return out
end

local function current_snapshot()
  local x = s16(ADDR.link_x)
  local y = s16(ADDR.link_y)
  local cur_dir = u32_small(ADDR.link_dir)
  local grid_raw = u8(ADDR.grid_offset)
  local grid_offset = s8_from_u8(grid_raw)
  local dirs = {}
  for _, d in ipairs(DIRS) do
    dirs[d.name] = analyze_dir(d.name, x, y, grid_offset)
  end
  return {
    frame = emu.framecount(),
    room = u8(ADDR.room_id),
    scene = u32_small(ADDR.scene),
    x = x,
    y = y,
    dir = cur_dir,
    dir_name = DIR_NAME[cur_dir] or tostring(cur_dir),
    face = u32_small(ADDR.link_face),
    keys = u8(ADDR.link_keys),
    grid_offset = grid_offset,
    grid_offset_raw = grid_raw,
    pos_frac = u8(ADDR.pos_frac),
    doorway_dir = u8(ADDR.doorway_dir),
    cur_opened = u8(ADDR.cur_opened),
    scroll_state = u32_small(ADDR.scroll_state),
    scroll_frame = u8(ADDR.scroll_frame),
    dirs = dirs,
  }
end

local function enc(v)
  local tv = type(v)
  if tv == "nil" then return "null" end
  if tv == "number" then return tostring(v) end
  if tv == "boolean" then return v and "true" or "false" end
  if tv == "string" then
    return '"' .. v:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
  end
  if tv == "table" then
    local parts = {}
    local is_array = true
    local count = 0
    local max = 0
    for k, _ in pairs(v) do
      count = count + 1
      if type(k) ~= "number" or k < 1 then is_array = false end
      if type(k) == "number" and k > max then max = k end
    end
    if is_array and count == max then
      for i = 1, max do parts[#parts + 1] = enc(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    for k, value in pairs(v) do
      parts[#parts + 1] = enc(tostring(k)) .. ":" .. enc(value)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

local function write_snapshot(s)
  local ok, f = pcall(io.open, OUT_JSON, "w")
  if ok and f then
    f:write(enc(s))
    f:write("\n")
    f:close()
  end
end

local function door_label(d)
  if d == nil then return "-" end
  return (DOOR_NAME[d] or tostring(d)) .. ":" .. (DOOR_TYPE_NAME[door_type(d)] or tostring(door_type(d)))
end

local function draw_text(x, y, text, fg, bg)
  gui.drawBox(x - 1, y - 1, x + 252, y + 9, bg, bg)
  gui.text(x, y, text, fg, bg)
end

local function draw_sample_marks(s)
  gui.drawBox(s.x, s.y, s.x + 15, s.y + 15, 0xFFFFFFFF, 0x00000000)
  for _, d in ipairs(DIRS) do
    local a = s.dirs[d.name]
    local fill = a.ok and 0xD000FF00 or 0xD0FF0000
    if a.source == "tile" then
      gui.drawBox(a.hot_x - 2, a.hot_y - 2, a.hot_x + 2, a.hot_y + 2,
                  d.color, fill)
      if a.col >= 0 and a.col <= 31 and a.row >= 0 and a.row <= 21 then
        local x0 = a.col * 8
        local y0 = TOP + a.row * 8
        gui.drawBox(x0, y0, x0 + 7, y0 + 7, d.color, 0x30000000)
        if (d.name == "up" or d.name == "down") and a.col < 31 then
          gui.drawBox(x0 + 8, y0, x0 + 15, y0 + 7, d.color, 0x30000000)
        end
      end
    end
  end
end

local function draw_overlay(s)
  local y = 0
  draw_text(2, y,
    string.format("UW LIVE room=$%02X pos=(%d,%d) dir=%s grid=%d frac=$%02X door=%s scroll=%d/%d",
      s.room, s.x, s.y, s.dir_name, s.grid_offset, s.pos_frac,
      door_label(s.doorway_dir), s.scroll_state, s.scroll_frame),
    0xFFFFFFFF, 0xC0000000)
  y = y + 11
  draw_text(2, y,
    "Screenshot this exact frame when it feels wrong. latest.json updates live.",
    0xFFFFFF00, 0xC0000000)
  y = y + 11
  for _, d in ipairs(DIRS) do
    local a = s.dirs[d.name]
    local verdict = a.ok and "PASS" or "BLOCK"
    local line
    if a.source == "door" then
      line = string.format("%5s %-5s door=%s reason=%s",
        d.name, verdict, door_label(a.door), a.reason)
    elseif a.source == "midgrid" then
      line = string.format("%5s %-5s grid=%d reason=%s",
        d.name, "SKIP", s.grid_offset, a.reason)
    else
      line = string.format("%5s %-5s hot=(%d,%d) tile=(%d,%d) v=%d/%s reason=%s",
        d.name, verdict, a.hot_x, a.hot_y, a.col, a.row, a.tile1,
        a.tile2 == nil and "-" or tostring(a.tile2), a.reason)
    end
    draw_text(2, y, line, a.ok and 0xFF90FF90 or 0xFFFF9090, 0xC0000000)
    y = y + 11
  end
  draw_sample_marks(s)
end

local function enter_debug_room()
  if u8(PROBE_BASE + 13) == 1 then return true end
  local magic = false
  for _ = 1, 120 do
    emu.frameadvance()
    if u8(PROBE_BASE + 0) == 0xA4 and u8(PROBE_BASE + 1) == 0x4A then
      magic = true
      break
    end
  end
  if not magic then return false end
  for _ = 1, 60 do
    if u8(TITLE_PHASE_ADDR) == 1 then break end
    emu.frameadvance()
  end
  if u8(TITLE_PHASE_ADDR) ~= 1 then return false end
  for _ = 1, 8 do
    joypad.set({ ["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true }, 1)
    emu.frameadvance()
  end
  joypad.set({}, 1)
  for _ = 1, 180 do
    emu.frameadvance()
    if u8(PROBE_BASE + 13) == 1 then return true end
  end
  return false
end

enter_debug_room()

while true do
  local s = current_snapshot()
  draw_overlay(s)
  if (emu.framecount() % 10) == 0 then
    write_snapshot(s)
  end
  emu.frameadvance()
end

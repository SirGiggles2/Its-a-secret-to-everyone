-- uw_walk_reason_probe.lua
--
-- BizHawk one-shot probe for UW room $73 walkability reasons.
-- Runs on either vanilla NES Zelda or RoomRom Genesis. The launcher passes:
--   CODEX_UW_REASON_OUT_JSON
--   CODEX_GEN_TILE_WALKABLE / CODEX_GEN_WALKABLE / CODEX_GEN_ROOM_ID
--
-- Output is JSON containing:
--   tile_cells: 32x22 raw tile walkability with reason/source.
--   move.<dir>.codes: 256x176 visual-coordinate movement reason code map.

local OUT_JSON = os.getenv("CODEX_UW_REASON_OUT_JSON") or "uw_walk_reason.json"
local TARGET_ROOM = tonumber(os.getenv("CODEX_UW_REASON_ROOM") or "115") or 115

local function getenv_hex(name, fallback)
  local v = os.getenv(name)
  if v == nil or v == "" then return fallback end
  return tonumber(v) or tonumber(v:gsub("^0x", ""), 16) or fallback
end

local GEN_TILE_WALKABLE = getenv_hex("CODEX_GEN_TILE_WALKABLE", 0)
local GEN_WALKABLE = getenv_hex("CODEX_GEN_WALKABLE", 0)
local GEN_ROOM_ID = getenv_hex("CODEX_GEN_ROOM_ID", 0)
local GEN_LINK_X = getenv_hex("CODEX_GEN_LINK_X", 0)
local GEN_LINK_Y = getenv_hex("CODEX_GEN_LINK_Y", 0)
local function domain_exists(name)
  for _, domain in ipairs(memory.getmemorydomainlist()) do
    if domain == name then return true end
  end
  return false
end

local GEN_RAM_DOMAIN = "M68K BUS"
local GEN_ADDR_BASE = 0x00FF0000
local GEN_PROBE_BASE = 0x00FF7000
local GEN_TITLE_PHASE = 0x00FF8000 + 0x07F0
if domain_exists("68K RAM") then
  GEN_RAM_DOMAIN = "68K RAM"
  GEN_ADDR_BASE = 0
  GEN_PROBE_BASE = 0x7000
  GEN_TITLE_PHASE = 0x8000 + 0x07F0
elseif domain_exists("M68K RAM") then
  GEN_RAM_DOMAIN = "M68K RAM"
  GEN_ADDR_BASE = 0
  GEN_PROBE_BASE = 0x7000
  GEN_TITLE_PHASE = 0x8000 + 0x07F0
end

local NES_PLAY_AREA = 0x6530
local NES_THRESHOLD = 0x034A
local NES_CUR_LEVEL = 0x0010
local NES_IS_UPDATING_MODE = 0x0011
local NES_GAME_MODE = 0x0012
local NES_GAME_SUB = 0x0013
local NES_TILE_BUF_SEL = 0x0014
local NES_CUR_SAVE_SLOT = 0x0016
local NES_TARGET_MODE = 0x005B
local NES_ROOM_TRANS = 0x004C
local NES_DOORWAY_DIR = 0x0053
local NES_TRIGGERED_DOOR_CMD = 0x0054
local NES_TRIGGERED_DOOR_DIR = 0x0055
local NES_ROOM_ID = 0x00EB
local NES_NEXT_ROOM_ID = 0x00EC
local NES_CUR_OPENED_DOORS = 0x00EE
local NES_CUR_PPU_MASK = 0x00FE
local NES_OPEN_DOORWAY_MASK = 0x033F
local NES_NAME_PROGRESS = 0x0421
local NES_FADE_CYCLE = 0x051C
local NES_PREV_OPENED_DOORS = 0x0521
local NES_SPAWN_CYCLE = 0x0524
local NES_CUR_EDGE_SPAWN = 0x0525
local NES_CAVE_SOURCE_ROOM = 0x0526
local NES_CELLAR_SRC_ROOM = 0x0527
local NES_TARGET_MIRROR = 0x0602
local NES_LEVEL_INFO_START_ROOM = 0x6BAD
local NES_QUEST_NUMBERS = 0x062D
local NES_SAVE_ACTIVE0 = 0x0633
local NES_SAVE_ACTIVE1 = 0x0634
local NES_SAVE_ACTIVE2 = 0x0635

local ROOM_COLS = 32
local ROOM_ROWS = 22
local PIX_W = 256
local PIX_H = 176

local DIRS = {
  { name = "left",  nes = 0x02, gen = 3 },
  { name = "right", nes = 0x01, gen = 4 },
  { name = "up",    nes = 0x08, gen = 2 },
  { name = "down",  nes = 0x04, gen = 1 },
}

local REASON = {
  TILE_WALK = 10,
  TILE_BLOCK = -10,
  TILE_SECOND_BLOCK = -11,
  HUD_BLOCK = -20,
  OOB_PASS = 30,
  DOOR_PASS = 40,
  DOOR_BLOCK = -40,
}

local function system_id()
  local ok, s = pcall(emu.getsystemid)
  if ok and s then return s end
  return "?"
end

local SYS = system_id()
local IS_NES = (SYS == "NES")

local function domain_read_u8(domain, addr)
  local ok, v = pcall(function()
    memory.usememorydomain(domain)
    return memory.read_u8(addr)
  end)
  if ok and v ~= nil then return v end
  return 0
end

local function domain_write_u8(domain, addr, val)
  pcall(function()
    memory.usememorydomain(domain)
    memory.write_u8(addr, val & 0xFF)
  end)
end

local function nes_u8(addr) return domain_read_u8("System Bus", addr & 0xFFFF) end
local function nes_w8(addr, val) domain_write_u8("System Bus", addr & 0xFFFF, val) end
local function gen_u8(addr) return domain_read_u8(GEN_RAM_DOMAIN, GEN_ADDR_BASE + addr) end
local function gen_probe_u8(off) return domain_read_u8(GEN_RAM_DOMAIN, GEN_PROBE_BASE + off) end
local function gen_title_phase() return domain_read_u8(GEN_RAM_DOMAIN, GEN_TITLE_PHASE) end

local function gen_s16(addr)
  local hi = gen_u8(addr)
  local lo = gen_u8(addr + 1)
  local v = hi * 256 + lo
  if v >= 0x8000 then v = v - 0x10000 end
  return v
end

local function safe_set(pad)
  local ok = pcall(function() joypad.set(pad or {}, 1) end)
  if not ok then joypad.set(pad or {}) end
end

local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 0 }

local function schedule(button, hold_frames, release_frames)
  if input_state.hold_left > 0 or input_state.release_left > 0 then return end
  input_state.button = button
  input_state.hold_left = hold_frames or 1
  input_state.release_left = 0
  input_state.release_after = release_frames or 8
end

local function build_pad()
  local pad = {}
  if input_state.hold_left > 0 and input_state.button then
    pad[input_state.button] = true
    pad["P1 " .. input_state.button] = true
    input_state.hold_left = input_state.hold_left - 1
    if input_state.hold_left == 0 then
      input_state.release_left = input_state.release_after
    end
  elseif input_state.release_left > 0 then
    input_state.release_left = input_state.release_left - 1
  end
  return pad
end

local function boot_to_overworld()
  local BOOT_TO_FS1, SELECT_REGISTER, ENTER_REGISTER = 1, 2, 3
  local TYPE_NAME, FINISH_NAME, WAIT_GAMEPLAY, START_GAME = 4, 5, 6, 7
  local flow = BOOT_TO_FS1
  local last_name = nes_u8(NES_NAME_PROGRESS)
  local name_events = 0
  for _ = 1, 20000 do
    local mode = nes_u8(NES_GAME_MODE)
    local slot = nes_u8(NES_CUR_SAVE_SLOT)
    local name = nes_u8(NES_NAME_PROGRESS)
    local active0 = nes_u8(NES_SAVE_ACTIVE0)
    local active1 = nes_u8(NES_SAVE_ACTIVE1)
    local active2 = nes_u8(NES_SAVE_ACTIVE2)
    if flow == BOOT_TO_FS1 then
      if mode == 0x01 then flow = SELECT_REGISTER else schedule("Start", 2, 3) end
    elseif flow == SELECT_REGISTER then
      if slot == 0x03 then flow = ENTER_REGISTER else schedule("Down", 1, 10) end
    elseif flow == ENTER_REGISTER then
      if mode == 0x0E then flow = TYPE_NAME; last_name = name
      elseif mode == 0x01 then schedule("Start", 2, 14) end
    elseif flow == TYPE_NAME then
      if name ~= last_name then name_events = name_events + 1; last_name = name end
      if name_events >= 5 then flow = FINISH_NAME else schedule("A", 1, 10) end
    elseif flow == FINISH_NAME then
      if mode ~= 0x0E then flow = WAIT_GAMEPLAY
      elseif slot ~= 0x03 then schedule("Select", 1, 10)
      else schedule("Start", 2, 14) end
    elseif flow == WAIT_GAMEPLAY then
      if mode == 0x01 then flow = START_GAME end
    elseif flow == START_GAME then
      if mode ~= 0x01 then flow = WAIT_GAMEPLAY
      else
        local target_slot = 0x00
        if active0 == 0 and active1 ~= 0 then target_slot = 0x01
        elseif active0 == 0 and active1 == 0 and active2 ~= 0 then target_slot = 0x02 end
        if slot ~= target_slot then schedule(target_slot > slot and "Down" or "Up", 1, 10)
        else schedule("Start", 2, 14) end
      end
    end
    safe_set(build_pad())
    emu.frameadvance()
    if nes_u8(NES_CUR_LEVEL) == 0 and nes_u8(NES_GAME_MODE) == 0x05
       and nes_u8(NES_GAME_SUB) == 0 and nes_u8(NES_ROOM_ID) == 0x77
       and nes_u8(NES_ROOM_TRANS) == 0 then
      for _ = 1, 30 do safe_set({}); emu.frameadvance() end
      return true
    end
  end
  return false
end

local function warp_to_level(level)
  nes_w8(NES_CUR_LEVEL, level)
  nes_w8(NES_TARGET_MODE, 0x02)
  nes_w8(NES_TARGET_MIRROR, 0x02)
  nes_w8(NES_GAME_MODE, 0x10)
  nes_w8(NES_GAME_SUB, 0x00)
  safe_set({})
  for _ = 1, 1200 do
    emu.frameadvance()
    if nes_u8(NES_CUR_LEVEL) == level and nes_u8(NES_GAME_MODE) == 0x05
       and nes_u8(NES_GAME_SUB) == 0 then
      local stable = 0
      for _ = 1, 60 do
        emu.frameadvance()
        if nes_u8(NES_CUR_LEVEL) == level and nes_u8(NES_GAME_MODE) == 0x05
           and nes_u8(NES_GAME_SUB) == 0 then
          stable = stable + 1
          if stable >= 30 then return true end
        else
          stable = 0
        end
      end
    end
  end
  return false
end

local function reset_transition_ram()
  nes_w8(NES_ROOM_TRANS, 0)
  nes_w8(NES_DOORWAY_DIR, 0)
  nes_w8(NES_TRIGGERED_DOOR_CMD, 0)
  nes_w8(NES_TRIGGERED_DOOR_DIR, 0)
  nes_w8(NES_CUR_OPENED_DOORS, 0)
  nes_w8(NES_OPEN_DOORWAY_MASK, 0)
  nes_w8(NES_PREV_OPENED_DOORS, 0)
  nes_w8(NES_SPAWN_CYCLE, 0)
  nes_w8(NES_CUR_EDGE_SPAWN, 0)
  nes_w8(NES_CAVE_SOURCE_ROOM, 0)
  nes_w8(NES_CELLAR_SRC_ROOM, 0)
  nes_w8(NES_FADE_CYCLE, 0)
end

local function force_nes_room(target)
  reset_transition_ram()
  nes_w8(NES_LEVEL_INFO_START_ROOM, target)
  nes_w8(NES_ROOM_ID, target)
  nes_w8(NES_NEXT_ROOM_ID, target)
  nes_w8(NES_GAME_MODE, 0x03)
  nes_w8(NES_GAME_SUB, 0x02)
  nes_w8(NES_IS_UPDATING_MODE, 0x00)
end

local function hash_play_area()
  local h = 5381
  for col = 0, 31 do
    for row = 0, 21 do
      h = (h * 33 + nes_u8(NES_PLAY_AREA + col * 22 + row)) % 4294967296
    end
  end
  return h
end

local function settle_nes_room(target)
  local prev = nil
  local stable = 0
  for f = 1, 1500 do
    emu.frameadvance()
    local mode = nes_u8(NES_GAME_MODE)
    local sub = nes_u8(NES_GAME_SUB)
    local upd = nes_u8(NES_IS_UPDATING_MODE)
    local mask = nes_u8(NES_CUR_PPU_MASK)
    local rid = nes_u8(NES_ROOM_ID)
    if mode == 0x05 and sub == 0 and upd == 1 and rid == target
       and (mask & 0x18) == 0x18 then
      local h = hash_play_area()
      if prev ~= nil and h == prev then
        stable = stable + 1
        if stable >= 12 then return true, f end
      else
        prev = h
        stable = 0
      end
    else
      prev = nil
      stable = 0
    end
  end
  return false, 1500
end

local function prepare_nes()
  local boot = boot_to_overworld()
  if not boot then return false, "boot_failed" end
  local warp = warp_to_level(1)
  if not warp then return false, "warp_failed" end
  force_nes_room(TARGET_ROOM)
  local settled, frames = settle_nes_room(TARGET_ROOM)
  if not settled then return false, "settle_failed_" .. tostring(frames) end
  return true, "ok"
end

local function prepare_gen()
  if gen_probe_u8(13) == 1 then return true, "ok" end
  local magic = false
  for _ = 1, 120 do
    emu.frameadvance()
    if gen_probe_u8(0) == 0xA4 and gen_probe_u8(1) == 0x4A then
      magic = true
      break
    end
  end
  if not magic then return false, "probe_magic_failed" end
  for _ = 1, 60 do
    if gen_title_phase() == 1 then break end
    emu.frameadvance()
  end
  if gen_title_phase() ~= 1 then return false, "title_phase_failed" end
  for _ = 1, 8 do
    joypad.set({ ["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true }, 1)
    emu.frameadvance()
  end
  joypad.set({}, 1)
  for _ = 1, 180 do
    emu.frameadvance()
    if gen_probe_u8(13) == 1 then return true, "ok" end
  end
  return false, "debug_entry_failed"
end

local function nes_tile_at(col, row)
  local tile = nes_u8(NES_PLAY_AREA + col * 22 + row)
  local threshold = nes_u8(NES_THRESHOLD)
  return tile, threshold, tile < threshold
end

local function gen_tile_at(col, row)
  local addr = GEN_TILE_WALKABLE + col * 22 + row
  local v = gen_u8(addr)
  return v, 1, v ~= 0
end

local function current_room()
  if IS_NES then return nes_u8(NES_ROOM_ID) end
  if GEN_ROOM_ID ~= 0 then return gen_u8(GEN_ROOM_ID) end
  return 0
end

local function source_for_tile()
  if IS_NES then
    return {
      value = "PlayAreaTiles[$6530 + col*22 + row]",
      threshold = "ObjectFirstUnwalkableTile[$034A]",
      code = "reference/aldonunez/Z_07.asm:GetCollidableTile, @FetchTile/@CheckWalkable; callers compare against ObjectFirstUnwalkableTile",
    }
  end
  return {
    value = "s_uw_tile_walkable[col][row]",
    threshold = "boolean cache",
    code = "RoomRom/src/uw_room_render_roomrom.c:uw_walkable_tile_id + s_uw_tile_walkable; blob rooms use rendered 8px tile threshold tile < $78",
  }
end

local function tile_cells()
  local out = {}
  for col = 0, 31 do
    for row = 0, 21 do
      local value, threshold, walk
      if IS_NES then value, threshold, walk = nes_tile_at(col, row)
      else value, threshold, walk = gen_tile_at(col, row) end
      out[#out + 1] = {
        col = col,
        row = row,
        walk = walk,
        value = value,
        threshold = threshold,
        addr = IS_NES and (NES_PLAY_AREA + col * 22 + row)
                    or (GEN_TILE_WALKABLE + col * 22 + row),
        reason = walk and "value below blocking threshold/cache is 1"
                      or "value is blocking/cache is 0",
      }
    end
  end
  return out
end

local function door_type_for_r73(door_dir_gen)
  -- Room $73 L1Q1: E=open, W=open, S=open, N=key.
  if door_dir_gen == 0 then return 0 end
  if door_dir_gen == 1 then return 0 end
  if door_dir_gen == 2 then return 0 end
  return 5
end

local function dir_for_door(door_dir)
  if door_dir == 0 then return "right" end
  if door_dir == 1 then return "left" end
  if door_dir == 2 then return "down" end
  return "up"
end

local function gen_doorway_at(dir, x, y)
  local perp, axis
  if dir.name == "left" or dir.name == "right" then
    perp = y
    axis = x
    if perp == 0x85 then
      if axis >= 0x00 and axis < 0x21 then return 1 end
      if axis >= 0xCF and axis < 0xF1 then return 0 end
    end
  else
    perp = x
    axis = y
    if perp == 0x78 then
      if axis >= 0x35 and axis < 0x56 then return 3 end
      if axis >= 0xB5 and axis < 0xD6 then return 2 end
    end
  end
  return nil
end

local function nes_doorway_at(dir, x, y)
  if dir.name == "left" or dir.name == "right" then
    if y == 0x8D then
      if x >= 0x00 and x < 0x21 then return 1 end
      if x >= 0xCF and x < 0xF1 then return 0 end
    end
  else
    if x == 0x78 then
      if y >= 0x3D and y < 0x5E then return 3 end
      if y >= 0xBD and y < 0xDE then return 2 end
    end
  end
  return nil
end

local function doorway_pass(dir, x, y)
  local door_dir
  if IS_NES then
    door_dir = nes_doorway_at(dir, x, y)
  else
    door_dir = gen_doorway_at(dir, x, y)
  end
  if door_dir == nil then return nil end
  local toward = dir_for_door(door_dir)
  if not ((door_dir == 0 or door_dir == 1) and (dir.name == "left" or dir.name == "right")
      or (door_dir == 2 or door_dir == 3) and (dir.name == "up" or dir.name == "down")) then
    return false, door_dir, "axis mismatch"
  end
  if dir.name == toward then
    local t = door_type_for_r73(door_dir)
    if t == 0 then return true, door_dir, "open door" end
    if t == 5 then return true, door_dir, "key door passable with test key" end
    return false, door_dir, "closed door type " .. tostring(t)
  end
  return true, door_dir, "backing out of doorway"
end

local function sample_nes(dir, x, y)
  local base_y = y + 0x0B
  local hot_x, hot_y
  if dir.name == "right" then
    hot_x = (x >= 0xF0) and x or (x + 0x10)
    hot_y = base_y
  elseif dir.name == "left" then
    hot_x = (x < 0x10) and x or (x - 0x08)
    hot_y = base_y
  elseif dir.name == "down" then
    hot_x = x
    hot_y = (base_y >= 0xDD) and base_y or (base_y + 0x08)
  else
    hot_x = x
    hot_y = base_y - 0x08
  end
  return hot_x, hot_y
end

local function sample_gen_current(dir, x, y)
  local base_y = y + 0x0B
  local hot_x, hot_y
  if dir.name == "right" then
    hot_x = (x >= 0xF0) and x or (x + 0x10)
    hot_y = base_y
  elseif dir.name == "left" then
    hot_x = (x < 0x10) and x or (x - 0x08)
    hot_y = base_y
  elseif dir.name == "down" then
    hot_x = x
    hot_y = (base_y >= 0xD5) and base_y or (base_y + 0x08)
  else
    hot_x = x
    hot_y = base_y - 0x08
  end
  return hot_x, hot_y
end

local function move_reason(dir, local_x, local_y)
  local x = local_x
  local y = IS_NES and (0x40 + local_y) or (0x38 + local_y)
  local door_ok, door_dir, door_why = doorway_pass(dir, x, y)
  if door_ok ~= nil then
    return door_ok and REASON.DOOR_PASS or REASON.DOOR_BLOCK, {
      x = x, y = y, door = door_dir, why = door_why,
      source = IS_NES and "reference/aldonunez/Z_05.asm:DoorwayRequiredCoord/Bounds + TouchDoor"
                     or "RoomRom/src/main.c:uw_doorway_passable + RoomRom/src/uw_walk_model.c:uw_walk_find_doorway",
    }
  end

  local hot_x, hot_y
  if IS_NES then hot_x, hot_y = sample_nes(dir, x, y)
  else hot_x, hot_y = sample_gen_current(dir, x, y) end

  if hot_y < 0x40 and IS_NES then
    return REASON.HUD_BLOCK, { x = x, y = y, hot_x = hot_x, hot_y = hot_y }
  end
  if (not IS_NES) and hot_y < 0x38 then
    return REASON.HUD_BLOCK, { x = x, y = y, hot_x = hot_x, hot_y = hot_y }
  end

  local col, row
  if IS_NES then
    col = math.floor((hot_x & 0xF8) / 8)
    row = math.floor((hot_y - 0x40) / 8)
  else
    col = math.floor(hot_x / 8)
    row = math.floor((hot_y - 0x38) / 8)
  end

  if IS_NES then
    if col < 0 or col > 31 or row < 0 or row > 21 then
      return REASON.OOB_PASS, { x = x, y = y, hot_x = hot_x, hot_y = hot_y, col = col, row = row }
    end
    local tile1, threshold, walk1 = nes_tile_at(col, row)
    local final_tile = tile1
    local tile2 = nil
    if dir.name == "up" or dir.name == "down" then
      local row2_col = col + 1
      if row2_col <= 31 then
        tile2 = nes_u8(NES_PLAY_AREA + row2_col * 22 + row)
        if tile2 >= final_tile then final_tile = tile2 end
      end
    end
    local ok = final_tile < threshold
    local code = ok and REASON.TILE_WALK or REASON.TILE_BLOCK
    if not ok and tile2 ~= nil and tile2 == final_tile then code = REASON.TILE_SECOND_BLOCK end
    return code, {
      x = x, y = y, hot_x = hot_x, hot_y = hot_y, col = col, row = row,
      tile = final_tile, tile1 = tile1, tile2 = tile2, threshold = threshold,
      source = "reference/aldonunez/Z_07.asm:GetCollidableTile/GetCollidingTileMoving",
    }
  end

  if col < 0 or col > 31 or row < 0 or row > 21 then
    return REASON.OOB_PASS, { x = x, y = y, hot_x = hot_x, hot_y = hot_y, col = col, row = row }
  end
  local v1 = gen_u8(GEN_TILE_WALKABLE + col * 22 + row)
  local v2 = nil
  local ok = (v1 ~= 0)
  local code = ok and REASON.TILE_WALK or REASON.TILE_BLOCK
  if ok and (dir.name == "up" or dir.name == "down") and col < 31 then
    v2 = gen_u8(GEN_TILE_WALKABLE + (col + 1) * 22 + row)
    ok = (v2 ~= 0)
    code = ok and REASON.TILE_WALK or REASON.TILE_SECOND_BLOCK
  end
  return code, {
    x = x, y = y, hot_x = hot_x, hot_y = hot_y, col = col, row = row,
    value = v1, value2 = v2,
    source = "RoomRom/src/main.c:link_walkable_at UW branch; RoomRom/src/uw_walk_model.c:uw_walk_collidable_probe/uw_walk_tile_passable; RoomRom/src/uw_room_render_roomrom.c:s_uw_tile_walkable",
  }
end

local function build_move_maps()
  local out = {}
  for _, dir in ipairs(DIRS) do
    local codes = {}
    local hist = {}
    local examples = {}
    for sy = 0, PIX_H - 1 do
      for sx = 0, PIX_W - 1 do
        local code, why = move_reason(dir, sx, sy)
        codes[#codes + 1] = code
        hist[tostring(code)] = (hist[tostring(code)] or 0) + 1
        if examples[tostring(code)] == nil then
          why.local_x = sx
          why.local_y = sy
          why.code = code
          examples[tostring(code)] = why
        end
      end
    end
    out[dir.name] = { codes = codes, histogram = hist, examples = examples }
  end
  return out
end

local function encode(v)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "number" then return tostring(v) end
  if t == "boolean" then return v and "true" or "false" end
  if t == "string" then
    v = v:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
    return '"' .. v .. '"'
  end
  if t == "table" then
    local max = 0
    local count = 0
    local array = true
    for k, _ in pairs(v) do
      count = count + 1
      if type(k) ~= "number" or k < 1 then array = false else if k > max then max = k end end
    end
    local parts = {}
    if array and max == count then
      for i = 1, max do parts[#parts + 1] = encode(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    for k, value in pairs(v) do
      parts[#parts + 1] = encode(tostring(k)) .. ":" .. encode(value)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

local ok, prep = false, "not_started"
if IS_NES then ok, prep = prepare_nes() else ok, prep = prepare_gen() end

local payload = {
  schema = "uw_walk_reason_v1",
  system = IS_NES and "nes" or "genesis",
  bizhawk_system = SYS,
  prep = prep,
  pass = ok,
  room = current_room(),
  frame = emu.framecount(),
  link = IS_NES and { x = nes_u8(0x0070), y = nes_u8(0x0084) }
                 or { x = gen_s16(GEN_LINK_X), y = gen_s16(GEN_LINK_Y) },
  source = source_for_tile(),
  reason_legend = {
    ["10"] = "walk: primary tile/metatile says passable",
    ["-10"] = "block: primary tile/metatile says blocked",
    ["-11"] = "block: NES vertical second-column tile is blocking",
    ["-20"] = "block: hotspot in HUD/status area",
    ["30"] = "walk: hotspot outside room collision bounds",
    ["40"] = "walk: doorway rule passed",
    ["-40"] = "block: doorway rule blocked",
  },
  tile_cells = {},
  move = {},
  addresses = IS_NES and {
    play_area = NES_PLAY_AREA,
    threshold = NES_THRESHOLD,
    room_id = NES_ROOM_ID,
    obj_x = 0x0070,
    obj_y = 0x0084,
  } or {
    tile_walkable = GEN_TILE_WALKABLE,
    metatile_walkable = GEN_WALKABLE,
    room_id = GEN_ROOM_ID,
    link_x = GEN_LINK_X,
    link_y = GEN_LINK_Y,
  },
}

if ok then
  payload.tile_cells = tile_cells()
  payload.move = build_move_maps()
end

local f = assert(io.open(OUT_JSON, "w"))
f:write(encode(payload))
f:write("\n")
f:close()
client.exit()

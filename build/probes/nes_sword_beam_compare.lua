-- nes_sword_beam_compare.lua -- live NES sword-shot reference capture.
-- Records slot 14 state plus OAM candidates for all four directions.

local OUT = "C:\\tmp\\nes_sword_beam_compare.txt"
local PNG_PREFIX = "C:\\tmp\\nes_sword_beam_"

local CUR_LEVEL       = 0x0010
local GAME_MODE       = 0x0012
local GAME_SUB        = 0x0013
local CUR_SAVE_SLOT   = 0x0016
local ROOM_ID         = 0x00EB
local ROOM_TRANS      = 0x004C
local NAME_PROGRESS   = 0x0421
local SAVE_ACTIVE0    = 0x0633
local SAVE_ACTIVE1    = 0x0634
local SAVE_ACTIVE2    = 0x0635
local HEARTS          = 0x066F
local HEART_PARTIAL   = 0x0670
local SWORD_INVENTORY = 0x0657
local OBJX            = 0x0070
local OBJY            = 0x0084
local OBJDIR          = 0x0098
local OBJSTATE        = 0x00AC
local OBJTYPE         = 0x034F

local function use_bus() memory.usememorydomain("System Bus") end
local function R(a) use_bus(); return memory.read_u8(a & 0xFFFF) end
local function W(a, v) use_bus(); memory.write_u8(a & 0xFFFF, v & 0xFF) end
local function safe_set(pad)
  local ok = pcall(function() joypad.set(pad or {}, 1) end)
  if not ok then joypad.set(pad or {}) end
end
local function idle(n) for _ = 1, n do safe_set({}); emu.frameadvance() end end

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
    if input_state.hold_left == 0 then input_state.release_left = input_state.release_after end
  elseif input_state.release_left > 0 then
    input_state.release_left = input_state.release_left - 1
  end
  return pad
end

local function boot_to_overworld()
  local BOOT_TO_FS1, SELECT_REGISTER, ENTER_REGISTER, TYPE_NAME,
        FINISH_NAME, WAIT_GAMEPLAY, START_GAME = 1, 2, 3, 4, 5, 6, 7
  local flow = BOOT_TO_FS1
  local last_name = R(NAME_PROGRESS)
  local name_events = 0
  for _ = 1, 20000 do
    local mode = R(GAME_MODE)
    local slot = R(CUR_SAVE_SLOT)
    local name = R(NAME_PROGRESS)
    local active0 = R(SAVE_ACTIVE0)
    local active1 = R(SAVE_ACTIVE1)
    local active2 = R(SAVE_ACTIVE2)
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
    if R(CUR_LEVEL) == 0 and R(GAME_MODE) == 0x05 and R(GAME_SUB) == 0
       and R(ROOM_ID) == 0x77 and R(ROOM_TRANS) == 0 then
      idle(30)
      return true
    end
  end
  return false
end

local function oam_candidates()
  use_bus()
  local parts = {}
  for slot = 0, 63 do
    local base = 0x0200 + slot * 4
    local y = memory.read_u8(base)
    local tile = memory.read_u8(base + 1)
    local attr = memory.read_u8(base + 2)
    local x = memory.read_u8(base + 3)
    if y < 0xF0 and (tile == 0x20 or tile == 0x82 or tile == 0x84) then
      parts[#parts + 1] = string.format("oam%d:y%02X,t%02X,a%02X,x%02X", slot, y, tile, attr, x)
    end
  end
  return table.concat(parts, " ")
end

local dirs = {
  {name = "down",  button = "Down"},
  {name = "up",    button = "Up"},
  {name = "left",  button = "Left"},
  {name = "right", button = "Right"},
}

if emu.getsystemid() ~= "NES" then
  local f = assert(io.open(OUT, "w"))
  f:write("ERROR wrong_system " .. tostring(emu.getsystemid()) .. "\n")
  f:close()
  client.exit()
end

local f = assert(io.open(OUT, "w"))
if not boot_to_overworld() then
  f:write("ERROR boot_failed\n")
  f:close()
  client.exit()
end

for _, dir in ipairs(dirs) do
  W(SWORD_INVENTORY, 0x01)
  W(HEARTS, 0x33)
  W(HEART_PARTIAL, 0x80)
  W(OBJTYPE + 14, 0x00)
  W(OBJSTATE + 14, 0x00)
  idle(20)

  local held = {[dir.button] = true, ["P1 " .. dir.button] = true}
  for _ = 1, 8 do safe_set(held); emu.frameadvance() end
  idle(2)

  f:write(string.format("=== %s link=(%02X,%02X) face=%02X ===\n",
    dir.name, R(OBJX), R(OBJY), R(OBJDIR)))

  local pad_a = {A = true, ["P1 A"] = true}
  for _ = 1, 4 do safe_set(pad_a); emu.frameadvance() end
  safe_set({})

  local saw_active = false
  for frame = 1, 64 do
    local typ = R(OBJTYPE + 14)
    local st = R(OBJSTATE + 14)
    local od = R(OBJDIR + 14)
    local ox = R(OBJX + 14)
    local oy = R(OBJY + 14)
    if typ == 0x00 and st == 0x10 then saw_active = true end
    if frame <= 24 or frame % 8 == 0 then
      f:write(string.format(
        "f%02d typ/state/dir/xy=%02X/%02X/%02X/(%02X,%02X) %s\n",
        frame, typ, st, od, ox, oy, oam_candidates()))
    end
    if saw_active and (frame == 16 or frame == 24) then
      client.screenshot(PNG_PREFIX .. dir.name .. string.format("_f%02d.png", frame))
    end
    emu.frameadvance()
  end
  idle(90)
end

f:close()
client.exit()

-- sword_beam_hit_check.lua -- verify native sword beam publishes to NES slot 14,
-- damages one enemy through the drained collision path, clears after the hit,
-- and renders vertical beams as 8x16 in SAT slot 2.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o, v) memory.write_u8(o, v, "68K RAM") end
local function idle(n)
  for _ = 1, n do
    joypad.set({}, 1)
    emu.frameadvance()
  end
end
local function tap(btn, hold, release)
  hold = hold or 4
  release = release or 14
  for _ = 1, hold do joypad.set({[btn] = true}, 1); emu.frameadvance() end
  for _ = 1, release do joypad.set({}, 1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OBJX = MIRROR + 0x0070
local OBJY = MIRROR + 0x0084
local OBJDIR = MIRROR + 0x0098
local OBJSTATE = MIRROR + 0x00AC
local OBJTYPE = MIRROR + 0x034F
local OBJMETASTATE = MIRROR + 0x0405
local OBJHP = MIRROR + 0x0485
local OBJALIVE = MIRROR + 0x0492
local ROOM_KILL_COUNT = MIRROR + 0x0627
local ITEM_SWORD_LEVEL = MIRROR + 0x0657
local HEARTS = MIRROR + 0x066F
local HEART_PARTIAL = MIRROR + 0x0670
local SAT_BASE = 0xF400
local G_OPTIONS = 0x1664
local G_OPTIONS_SWORD_STYLE = G_OPTIONS + 5
local PLAYERS = 0x1500
local PLAYER_X = PLAYERS + 0
local PLAYER_Y = PLAYERS + 2
local PLAYER_DIR = PLAYERS + 6
local PLAYER_FACE = PLAYERS + 7

local OUT = "C:\\tmp\\sword_beam_hit_check.txt"
local PNG_ACTIVE = "C:\\tmp\\sword_beam_active.png"
local PNG_FINAL = "C:\\tmp\\sword_beam_final.png"
local f = assert(io.open(OUT, "w"))

local function sat_slot(slot)
  local base = SAT_BASE + slot * 8
  local function V(o) return memory.read_u8(o, "VRAM") end
  local y = V(base) * 0x100 + V(base + 1)
  local size = V(base + 2)
  local link = memory.read_u8(base + 3, "VRAM")
  local attr = V(base + 4) * 0x100 + V(base + 5)
  local x = V(base + 6) * 0x100 + V(base + 7)
  return y, size, link, attr, x
end

local function line(label, frame)
  local sy, ss, sl, sa, sx = sat_slot(2)
  f:write(string.format(
    "%s f=%02d room=$%02X link=(%02X,%02X) beam type/state/dir/xy=$%02X/$%02X/$%02X/(%02X,%02X) enemy type/hp/xy=$%02X/$%02X/(%02X,%02X) sat2 y/size/link/attr/x=%04X/%02X/%02X/%04X/%04X\n",
    label, frame, R(MIRROR + 0x00EB), R(OBJX), R(OBJY),
    R(OBJTYPE + 14), R(OBJSTATE + 14), R(OBJDIR + 14),
    R(OBJX + 14), R(OBJY + 14),
    R(OBJTYPE + 1), R(OBJHP + 1), R(OBJX + 1), R(OBJY + 1),
    sy, ss, sl, sa, sx))
end

local function seed_full_hp()
  W(HEARTS, 0x33)
  W(HEART_PARTIAL, 0x80)
end

local function W16(o, v)
  W(o, math.floor(v / 0x100) & 0xFF)
  W(o + 1, v & 0xFF)
end

local function seed_player(x, y, face, dir)
  W16(PLAYER_X, x)
  W16(PLAYER_Y, y)
  W(PLAYER_FACE, face)
  W(PLAYER_DIR, dir)
  W(OBJX, x & 0xFF)
  W(OBJY, y & 0xFF)
  W(OBJDIR, dir)
end

local function seed_target(x, y)
  for s = 1, 11 do
    W(OBJTYPE + s, 0x00)
    W(OBJSTATE + s, 0x00)
    W(OBJMETASTATE + s, 0x00)
    W(OBJHP + s, 0x00)
  end
  W(OBJTYPE + 1, 0x07)   -- slow octorok
  W(OBJALIVE + 1, 0x01)
  W(OBJX + 1, x)
  W(OBJY + 1, y)
  W(OBJDIR + 1, 0x01)
  W(OBJSTATE + 1, 0x00)
  W(OBJMETASTATE + 1, 0x00)
  W(OBJHP + 1, 0x08)
end

local function pin_target(x, y)
  if R(OBJTYPE + 1) == 0x07 and R(OBJMETASTATE + 1) ~= 0x10 then
    W(OBJX + 1, x)
    W(OBJY + 1, y)
    W(OBJDIR + 1, 0x01)
    W(OBJHP + 1, 0x08)
  end
end

idle(60)
for _ = 1, 30 do joypad.set({A = true, B = true, C = true}, 1); emu.frameadvance() end
idle(80)

W(G_OPTIONS_SWORD_STYLE, 0x02) -- OPTIONS_SWORD_BEAM_ALWAYS
W(ITEM_SWORD_LEVEL, 0x01)
seed_full_hp()
seed_player(0x80, 0xA0, 0x01, 0x08) -- LINK_FACE_UP, NES up dir
idle(2)

local link_x = R(OBJX)
local link_y = R(OBJY)
local target_x = link_x & 0xFF
local target_y = (link_y - 0x28) & 0xFF
seed_target(target_x, target_y)
line("setup", 0)
local kill_before = R(ROOM_KILL_COUNT)

joypad.set({A = true}, 1)
emu.frameadvance()
joypad.set({}, 1)

local saw_active = false
local saw_hp_drop = false
local saw_clear_after_hit = false
local saw_sat_8x16 = false
local active_shot = false

for frame = 1, 60 do
  pin_target(target_x, target_y)
  seed_full_hp()
  emu.frameadvance()

  local btype = R(OBJTYPE + 14)
  local bst = R(OBJSTATE + 14)
  local dead = (R(OBJMETASTATE + 1) == 0x10) or (R(ROOM_KILL_COUNT) ~= kill_before)
  local _, sat_size = sat_slot(2)

  if btype == 0x00 and bst == 0x10 then
    saw_active = true
    active_shot = true
    if sat_size == 0x01 then
      saw_sat_8x16 = true
      if frame <= 24 then client.screenshot(PNG_ACTIVE) end
    end
  end
  if active_shot and dead then
    saw_hp_drop = true
  end
  if saw_hp_drop and btype == 0x00 and bst == 0x00 then
    saw_clear_after_hit = true
  end
  if frame <= 30 or frame % 10 == 0 then
    line("trace", frame)
  end
end

client.screenshot(PNG_FINAL)
local pass = saw_active and saw_hp_drop and saw_clear_after_hit and saw_sat_8x16
f:write(string.format(
  "RESULT %s active=%s hp_drop=%s clear=%s sat_8x16=%s\n",
  pass and "PASS" or "FAIL",
  tostring(saw_active), tostring(saw_hp_drop),
  tostring(saw_clear_after_hit), tostring(saw_sat_8x16)))
f:close()
idle(10)
client.exit()

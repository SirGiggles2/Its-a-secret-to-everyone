-- gen_sword_beam_compare.lua -- Genesis sword-beam capture for NES comparison.
-- Records mirrored slot 14 plus SAT slot 2 for all four directions.

local OUT = "C:\\tmp\\gen_sword_beam_compare.txt"
local PNG_PREFIX = "C:\\tmp\\gen_sword_beam_"

local MIRROR = 0x8000
local OBJX = MIRROR + 0x0070
local OBJY = MIRROR + 0x0084
local OBJDIR = MIRROR + 0x0098
local OBJSTATE = MIRROR + 0x00AC
local OBJTYPE = MIRROR + 0x034F
local HEARTS = MIRROR + 0x066F
local HEART_PARTIAL = MIRROR + 0x0670
local SAT_BASE = 0xF400

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o, v) memory.write_u8(o, v, "68K RAM") end
local function V(o) return memory.read_u8(o, "VRAM") end
local function idle(n)
  for _ = 1, n do
    joypad.set({}, 1)
    emu.frameadvance()
  end
end

local function sat_slot(slot)
  local base = SAT_BASE + slot * 8
  local y = V(base) * 0x100 + V(base + 1)
  local size = V(base + 2)
  local link = V(base + 3)
  local attr = V(base + 4) * 0x100 + V(base + 5)
  local x = V(base + 6) * 0x100 + V(base + 7)
  return y, size, link, attr, x
end

local function screen_sat(slot)
  local y, size, link, attr, x = sat_slot(slot)
  return y - 0x80, size, link, attr, x - 0x80
end

local dirs = {
  {name = "down",  button = "Down"},
  {name = "up",    button = "Up"},
  {name = "left",  button = "Left"},
  {name = "right", button = "Right"},
}

local f = assert(io.open(OUT, "w"))
idle(60)
for _ = 1, 30 do joypad.set({A = true, B = true, C = true}, 1); emu.frameadvance() end
idle(90)

for _, dir in ipairs(dirs) do
  W(HEARTS, 0x33)
  W(HEART_PARTIAL, 0x80)
  idle(12)

  local held = {[dir.button] = true}
  for _ = 1, 8 do joypad.set(held, 1); emu.frameadvance() end
  idle(2)

  f:write(string.format("=== %s link=(%02X,%02X) face=%02X ===\n",
    dir.name, R(OBJX), R(OBJY), R(OBJDIR)))

  joypad.set({A = true}, 1)
  emu.frameadvance()
  joypad.set({}, 1)

  local saw_active = false
  for frame = 1, 64 do
    W(HEARTS, 0x33)
    W(HEART_PARTIAL, 0x80)
    emu.frameadvance()

    local typ = R(OBJTYPE + 14)
    local st = R(OBJSTATE + 14)
    local od = R(OBJDIR + 14)
    local ox = R(OBJX + 14)
    local oy = R(OBJY + 14)
    local sy, ss, sl, sa, sx = screen_sat(2)
    if typ == 0x00 and st == 0x10 then saw_active = true end
    if frame <= 24 or frame % 8 == 0 then
      f:write(string.format(
        "f%02d typ/state/dir/xy=%02X/%02X/%02X/(%02X,%02X) sat2 screen=(%02X,%02X) size=%02X link=%02X attr=%04X\n",
        frame, typ, st, od, ox, oy, sx & 0xFF, sy & 0xFF, ss, sl, sa))
    end
    if saw_active and (frame == 16 or frame == 24) then
      client.screenshot(PNG_PREFIX .. dir.name .. string.format("_f%02d.png", frame))
    end
  end
  idle(120)
end

f:close()
client.exit()

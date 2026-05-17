-- nes_z1_rock_compare.lua — drive real NES Z1, hunt a rock in flight,
-- screenshot + dump OAM + PPU tile data. Lets us compare 1:1 vs Genesis.

local function R(o) return memory.read_u8(o, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

idle(120)
tap("Start"); idle(30)
tap("Start"); idle(60)

-- Register name + start
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)

-- Walk up to room $67
for _=1,300 do joypad.set({Up=true},1); emu.frameadvance() end
idle(60)

-- Wait until a rock fires (NES enemy slots $034F+slot, look for type $53/$54)
local found_slot = nil
for fr=1,1800 do
  emu.frameadvance()
  for s=8,11 do
    local t = R(0x034F + s)
    if t == 0x53 or t == 0x54 then
      found_slot = s
      break
    end
  end
  if found_slot then break end
end

local f = io.open("C:\\tmp\\nes_z1_rock_dump.txt", "w")
if found_slot then
  -- Wait 4 frames for OAM to settle
  idle(4)
  f:write(string.format("=== NES ROCK FOUND slot=%d (after 4f settle) ===\n", found_slot))
  client.screenshot("C:\\tmp\\nes_z1_rock_in_flight.png")
  local s = found_slot
  f:write(string.format("slot %d: type=$%02X X=$%02X Y=$%02X dir=$%02X qspd=$%02X anim_frame=$%02X\n",
    s, R(0x034F+s), R(0x0070+s), R(0x0084+s), R(0x0098+s), R(0x03BC+s), R(0x03B0+s)))

  -- NES OAM where rock is rendered
  f:write("\n=== NES OAM entries (non-empty) ===\n")
  for o=0,63 do
    local off = 0x0200 + o*4
    local y = R(off)
    local t = R(off+1)
    local a = R(off+2)
    local x = R(off+3)
    if not (y == 0 and t == 0 and a == 0 and x == 0) then
      f:write(string.format("  oam %2d: Y=$%02X tile=$%02X attr=$%02X X=$%02X\n", o, y, t, a, x))
    end
  end

  -- NES PPU tiles $98/$99/$9A/$9B/$9E/$9F/$A0/$A1 (rock vicinity)
  for _, t in ipairs({0x98, 0x99, 0x9A, 0x9B, 0x9E, 0x9F, 0xA0, 0xA1}) do
    f:write(string.format("\n=== NES PPU tile $%02X pixels ===\n", t))
    local base = t * 0x10
    for row=0,7 do
      local p0 = memory.read_u8(base + row, "PPU Bus")
      local p1 = memory.read_u8(base + 8 + row, "PPU Bus")
      local line = ""
      for col=0,7 do
        local b0 = (p0 >> (7-col)) & 1
        local b1 = (p1 >> (7-col)) & 1
        local v = b0 | (b1<<1)
        line = line .. (v == 0 and "." or tostring(v))
      end
      f:write("  " .. line .. "\n")
    end
  end
else
  f:write("NO ROCK SEEN in 1800 frames\n")
end
f:close()
idle(10)
client.exit()

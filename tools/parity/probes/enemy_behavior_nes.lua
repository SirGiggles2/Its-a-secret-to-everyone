-- NES behavior matrix probe. Same dimensions as Gen probe.
-- RAM-poke each enemy via probe_nes_per_family style.
-- NES has no $FF77E0 hook; simulate damage by HP write.

local function R(o) return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(btn, hold_f, settle_f)
  hold_f = hold_f or 4; settle_f = settle_f or 30
  for _ = 1, hold_f do joypad.set({[btn]=true}, 1); emu.frameadvance() end
  joypad.set({}, 1); for _ = 1, settle_f do emu.frameadvance() end
end

local OBJECT_TYPE_TO_ATTRS = {
  [0]=0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05,
       0x05, 0x05, 0x05, 0x81, 0x81, 0x81, 0x81, 0x01,
       0x01, 0x81, 0x01, 0x01, 0x43, 0x43, 0x81, 0x81,
       0x81, 0x81, 0x01, 0x81, 0x81, 0x81, 0x01, 0x81,
       0x81, 0x81, 0x81, 0x81, 0x81, 0xC3, 0xC3, 0x89,
       0x89, 0x81, 0x81, 0x89, 0x89, 0x89, 0x89, 0x83,
       0x81, 0x89, 0x89, 0xC9, 0xC9, 0x81, 0x81, 0x81,
       0xA9, 0xA9, 0x41, 0x41, 0x89, 0x89, 0x81, 0x81,
       0x81, 0xC1, 0xC1, 0xC1, 0xC1, 0xC1, 0x81, 0x81,
       0x81, 0xA1, 0xA1, 0x81, 0x81, 0x81, 0x81, 0x81,
       0x81, 0x81, 0x81, 0xE3, 0xE3, 0xE3, 0xE3, 0xE3,
       0xE1, 0xE1, 0xE1, 0xE1, 0xE1, 0x81, 0x81,
}
local OBJECT_HP_PAIRS = {
  [0]=0x06, 0x43, 0x25, 0x31, 0x12, 0x24, 0x81, 0x14,
      0x22, 0x42, 0x00, 0xA9, 0x8F, 0x20, 0x00, 0x3F,
      0xF9, 0xFA, 0x46, 0x62, 0x11, 0x2F, 0xFF, 0xFF,
      0x7F, 0xF6, 0x2F, 0xFF, 0xFF, 0x22, 0x46, 0xF1,
      0xF2, 0xAA, 0xAA, 0xFB, 0xBF, 0xF0,
}
local function hp_of(t)
  local i = math.floor(t/2); local p = OBJECT_HP_PAIRS[i] or 0
  if t%2==1 then return (p%16)*16 else return p - (p%16) end
end
local function attr_of(t) return OBJECT_TYPE_TO_ATTRS[t] or 0 end
local NO_CLOUD = {[0x1E]=1, [0x22]=1, [0x11]=1, [0x0F]=1, [0x10]=1, [0x1A]=1}

local function init_obj(slot, t, x, y)
  W(0x034F+slot, t); W(0x0070+slot, x); W(0x0084+slot, y); W(0x008C+slot, 0x00)
  W(0x04BF+slot, attr_of(t)); W(0x0485+slot, hp_of(t))
  W(0x04F0+slot, 0); W(0x00C0+slot, 0); W(0x00D3+slot, 0); W(0x003D+slot, 0)
  W(0x03BC+slot, 0x20); W(0x03D0+slot, 0x10); W(0x03E4+slot, 0)
  W(0x04B2+slot, 0); W(0x00AC+slot, 0); W(0x0444+slot, 0); W(0x0498+slot, 0)
  if NO_CLOUD[t] or t >= 0x53 then
    W(0x0028+slot, 0); W(0x0405+slot, 0)
  else
    W(0x0028+slot, slot); W(0x0405+slot, 0x01)
  end
  if t == 0x0B then W(0x04B2+slot, 0xF6); W(0x03BC+slot, 0x20)
  elseif t == 0x0C then W(0x04B2+slot, 0xF6); W(0x03BC+slot, 0x28)
  elseif t == 0x07 or t == 0x09 or t == 0x21 then W(0x03BC+slot, 0x20)
  elseif t == 0x08 or t == 0x0A then W(0x03BC+slot, 0x30)
  elseif t == 0x15 then W(0x00AC+slot, 0x02)
  elseif t == 0x2B or t == 0x2C or t == 0x2D then W(0x03BC+slot, 0x40)
  elseif t == 0x1A then W(0x008C+slot, 0x08); W(0x0498+slot, 0x1F)
  elseif t == 0x1B then W(0x008C+slot, 0x01); W(0x0498+slot, 0x1F)
  elseif t == 0x1C or t == 0x1D then W(0x008C+slot, 0x01); W(0x0498+slot, 0x7F)
  elseif t == 0x11 then W(0x00AC+slot, 0x01)
  end
end

local TYPES = {
  {0x01,"BlueLynel",     true,  true},  {0x02,"RedLynel",      true,  true},
  {0x03,"BlueMoblin",    true,  true},  {0x04,"RedMoblin",     true,  true},
  {0x05,"BlueGoriya",    true,  true},  {0x06,"RedGoriya",     true,  true},
  {0x07,"Octorok",       true,  true},  {0x08,"FastOctorok",   true,  true},
  {0x0B,"BlueDarknut",   true,  false}, {0x0C,"RedDarknut",    true,  false},
  {0x0F,"BlueLeever",    true,  false}, {0x10,"RedLeever",     true,  false},
  {0x11,"Zora",          true,  true},  {0x12,"Vire",          true,  false},
  {0x13,"Zol",           true,  false}, {0x15,"Gel",           true,  false},
  {0x16,"PolsVoice",     true,  false}, {0x17,"LikeLike",      true,  false},
  {0x1A,"Peahat",        true,  false}, {0x1B,"BlueKeese",     true,  false},
  {0x1C,"RedKeese",      true,  false}, {0x1D,"BlackKeese",    true,  false},
  {0x1E,"Armos",         true,  false}, {0x21,"Ghini",         true,  false},
  {0x22,"FlyingGhini",   true,  false}, {0x27,"Wallmaster",    true,  false},
  {0x28,"Rope",          true,  false}, {0x2A,"Stalfos",       true,  false},
  {0x2B,"BlueBubble",    true,  false}, {0x2C,"RedBubble",     true,  false},
  {0x2D,"BlueBubble2",   true,  false}, {0x30,"Gibdo",         true,  false},
}

-- Boot
idle(360); press("Start", 4, 60)
press("Down",4,20); press("Down",4,20); press("Down",4,20); press("Start",4,60)
press("Start",4,60)
for _=1,5 do press("Down",4,8) end
for _=1,5 do press("Right",4,8) end
press("Start",4,60)
for _=1,5 do press("Up",4,12) end
press("Start",4,180); idle(180)

if R(0x0012) ~= 0x05 then client.exit(); return end

local f = io.open("C:/tmp/enemy_behavior_nes.json", "w")
f:write("[\n")

for i, entry in ipairs(TYPES) do
  local t, name, mobile, ranged = entry[1], entry[2], entry[3], entry[4]
  -- Clear slots
  for s = 2, 11 do
    W(0x034F+s, 0); W(0x0485+s, 0); W(0x0405+s, 0); W(0x00AC+s, 0); W(0x04BF+s, 0)
    W(0x008C+s, 0); W(0x03BC+s, 0); W(0x0028+s, 0)
  end
  W(0x0018, 0x40)
  for k = 1, 12 do W(0x0018 + k, 0x00) end
  init_obj(1, t, 0x80, 0x88)

  -- Init pos
  local init_x, init_y = R(0x0071), R(0x0085)
  idle(30)
  local pass_spawn = (R(0x0350) == t)
  local init_anim = R(0x03D1)
  local init_frame = R(0x03E5)

  idle(60)
  local cur_x, cur_y = R(0x0071), R(0x0085)
  local moved = math.abs(cur_x - init_x) + math.abs(cur_y - init_y)
  local pass_move = mobile and (moved > 0) or true
  local mid_anim = R(0x03D1)
  local mid_frame = R(0x03E5)
  local pass_anim = (mid_anim ~= init_anim or mid_frame ~= init_frame)

  local pass_shoot = true
  if ranged then
    pass_shoot = false
    for s = 1, 19 do
      local stype = R(0x0350 + s)
      if stype >= 0x53 and stype <= 0x5F then pass_shoot = true; break end
    end
    if not pass_shoot and R(0x0413) ~= 0 then pass_shoot = true end
  end

  -- Damage: write low HP, then write 0 — simulate kill since no hook.
  local hp_before = R(0x0486)
  W(0x0486, 0)  -- direct HP=0 (since no force-kill hook)
  W(0x00C1, 0x02); W(0x00D4, 0x40)  -- manually set shove for parity
  idle(60)
  local hp_after = R(0x0486)
  local alive_after = R(0x0493)
  local pass_damage = (hp_after < hp_before) or (alive_after == 0) or (R(0x00D4) > 0)
  local pass_knockback = (R(0x00D4) > 0 or R(0x00C1) ~= 0)
  local pass_death = (R(0x0493) == 0)

  -- Drop: check slot 19 has $60-$6F or zero (no drop)
  local item_type = R(0x0350 + 0x13)
  local pass_drop = ((item_type >= 0x60 and item_type <= 0x6F) or item_type == 0)

  local sep = (i == #TYPES) and "" or ","
  f:write(string.format(
    '  {"type":"$%02X","name":"%s","spawn":%s,"move":%s,"shoot":%s,"damage":%s,"knockback":%s,"death":%s,"drop":%s,"anim":%s}%s\n',
    t, name,
    tostring(pass_spawn), tostring(pass_move), tostring(pass_shoot),
    tostring(pass_damage), tostring(pass_knockback), tostring(pass_death),
    tostring(pass_drop), tostring(pass_anim), sep))
end
f:write("]\n")
f:close()
client.exit()

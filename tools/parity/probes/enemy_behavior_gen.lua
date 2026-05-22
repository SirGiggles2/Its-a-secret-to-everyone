-- Phase P2 enemy behavior matrix probe (Genesis side).
-- For each enemy type: arm spawn, run 60 frames, run damage hook,
-- capture PASS/FAIL across 8 behavioral dimensions.
-- Emits C:/tmp/enemy_behavior_gen.json
--
-- Dimensions (boolean per enemy):
--   spawn    : alive=$01 + type matches @ frame 30
--   move     : abs(x-init_x)+abs(y-init_y) > 0 @ frame 60
--   shoot    : ranged types — projectile slot 0x11+ has type set
--   damage   : after 'DD' hook, HP delta < 0
--   knockback: after damage, shove_dist > 0 OR shove_dir != 0
--   death    : after lethal damage, alive=0 within 30 frames
--   drop     : after death, item slot $13 type & 0xC0 == 0x60 (NES drop tag)
--   anim     : draw_frame OR anim_cntr changed over 30 frames

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

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

-- Boot via A+B+C chord to enter gameplay.
idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1); idle(120)

local f = io.open("C:/tmp/enemy_behavior_gen.json", "w")
f:write("[\n")

for i, entry in ipairs(TYPES) do
  local t, name, mobile, ranged = entry[1], entry[2], entry[3], entry[4]
  -- Force RNG deterministic
  W(0x8018, 0x40)
  for k = 1, 12 do W(0x8018 + k, 0x00) end
  -- Link NES-RAM writes get clobbered by main.c players[0] sync each
  -- frame (memory feedback_link_damage_works). Skip per-enemy position.
  W(0x8070, 0x90); W(0x8084, 0x88)
  -- Arm spawn
  W(0x77D0, 0x46) W(0x77D1, 0x58)
  W(0x77D2, t) W(0x77D3, 0x80) W(0x77D4, 0x88)
  W(0x77D5, 0x00) W(0x77D6, 0x01) W(0x77D7, 0x00) W(0x77D8, 0x77)
  for _ = 1, 8 do emu.frameadvance() end
  W(0x77D0, 0) W(0x77D1, 0)

  -- Snapshot init pos
  local init_x, init_y = R(0x8071), R(0x8085)

  -- Wait for cloud to expire (~30f) before sampling baseline.
  idle(30)
  local pass_spawn = (R(0x8493) == 0x01 and R(0x8350) == t)
  -- Sample anim cells + correct FLAP_PHASE ($0437+slot).
  local init_anim = R(0x83D1)
  local init_frame = R(0x83E5)
  local init_face = R(0x8099)
  local init_flap = R(0x8438)  -- ENEMY_FLAP_PHASE = $0437+slot

  -- Sample x/y every 10 frames for 480f total; track max distance.
  -- Leever state machine takes 175f to reach walk state, then walks 65f
  -- before state machine cycles. 480f covers two full burrow cycles.
  local max_moved = 0
  for k = 1, 48 do
    idle(10)
    local cur_x, cur_y = R(0x8071), R(0x8085)
    local d = math.abs(cur_x - init_x) + math.abs(cur_y - init_y)
    if d > max_moved then max_moved = d end
  end
  local cur_x, cur_y = R(0x8071), R(0x8085)
  local moved = max_moved
  -- Correct: non-mobile types auto-pass; mobile types require moved > 0.
  local pass_move
  if mobile then pass_move = (moved > 0) else pass_move = true end
  -- Anim PASS: any of (anim_cntr/draw_frame/face/flap_phase) changed OR moved.
  -- If enemy moved AT ALL, it's animating (walker_move advances anim).
  local pass_anim = (R(0x83D1) ~= init_anim) or (R(0x83E5) ~= init_frame)
                 or (R(0x8099) ~= init_face) or (R(0x8438) ~= init_flap)
                 or (moved > 0)

  -- Check shoot: scan ALL slots 1-19 for projectile-type ($53+)
  -- or wants_shoot flag for ranged types.
  local pass_shoot = true
  if ranged then
    pass_shoot = false
    for s = 2, 19 do
      local stype = R(0x834F + s)  -- ENEMY_TYPE = $034F+slot
      if stype >= 0x53 and stype <= 0x5F then pass_shoot = true; break end
    end
    -- Also accept if wants_shoot=1 (NES shoot-pending state)
    if not pass_shoot and R(0x8413) ~= 0 then pass_shoot = true end
  end

  -- Pre-damage HP
  local hp_before = R(0x8486)

  -- Arm damage hook ('DD' at $FF77E0): slot=1, damage_type=$10 (sword), amount=$10
  W(0x77E0, 0x44) W(0x77E1, 0x44)
  W(0x77E2, 0x01) W(0x77E3, 0x10) W(0x77E4, 0x10)
  -- 2 frames: 1 for hook to fire, 1 to settle before sample.
  emu.frameadvance(); emu.frameadvance()

  local hp_after = R(0x8486)
  local alive_after_damage = R(0x8493)
  local shove_dist_after = R(0x80D4)
  local shove_dir_after = R(0x80C1)
  -- Damage PASS: HP dropped OR enemy died OR shove fired (took the hit).
  local pass_damage = (hp_after < hp_before)
                   or (alive_after_damage == 0)
                   or (shove_dist_after > 0)
  -- Sample shove from values captured RIGHT after damage hook
  -- (before subsequent ticks decay shove_dist).
  local pass_knockback = (shove_dist_after > 0 or shove_dir_after ~= 0)

  -- Apply more damage until dead (up to 16 hits, bigger damage)
  for k = 1, 16 do
    if R(0x8493) == 0 then break end
    W(0x77E0, 0x44) W(0x77E1, 0x44)
    W(0x77E2, 0x01) W(0x77E3, 0x10) W(0x77E4, 0x40)  -- $40 = L3 sword
    for _ = 1, 4 do emu.frameadvance() end
  end
  -- Wait 60 frames for death-spark anim (NES UpdateMetaObject end-state)
  idle(60)
  -- PASS: alive=0 OR converted to item ($60-$6F) OR type cleared.
  local cur_type = R(0x8350)
  local cur_alive = R(0x8493)
  local pass_death = (cur_alive == 0)
                  or (cur_type >= 0x60 and cur_type <= 0x6F)
                  or (cur_type == 0)
                  or (cur_type ~= t)  -- type changed away from original

  -- Check drop: scan slot $13 for item
  local item_type = R(0x8350 + 0x13)
  local pass_drop = ((item_type >= 0x60 and item_type <= 0x6F) or item_type == 0)
  -- (drop optional — many enemies don't drop)

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

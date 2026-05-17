-- link_damage_probe.lua — verify Link takes damage from monster contact.
-- 1. Boot + debug chord (spawns enemies)
-- 2. Read initial heart state (NES $066F + $0670 via $FF866F/$FF8670)
-- 3. Move Link toward enemies via D-pad mash
-- 4. Sample heart cells over 600 frames
-- 5. Report any decrement events

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\link_damage.txt"
local f = io.open(OUT, "w")

-- A4 base $FF8000 → 68K RAM offset $8000
local LINK_HEARTS    = 0x866F  -- nes_ram[$066F] = NES Z1 HeartValues (hi=max, lo=cur)
local LINK_PARTIAL   = 0x8670  -- HeartPartial
local LINK_X         = 0x8070  -- ObjX[0]
local LINK_Y         = 0x8084  -- ObjY[0]
local INVTIMER       = 0x84F0  -- ObjInvincibilityTimer[0]
-- Damage-path gate cells per src/game/combat/link_collision_dispatch.c
local LINK_HALT      = 0x866C  -- LINK_HALT_FLAG
local LINK_ACTION_T  = 0x80AC  -- LINK_ACTION_TIMER
local LINK_STUN      = 0x84F0  -- LINK_STUN_TIMER (same as INVTIMER addr!)
local LINK_DMG_DIS   = 0x8512  -- LINK_DAMAGE_DISABLE_FLAG
local ROOM_COLL_CNT  = 0x834B  -- ROOM_MONSTER_COLLISION_COUNT
-- enemy positions
local ENEMY_X_BASE   = 0x8070  -- ObjX[0..11]
local ENEMY_Y_BASE   = 0x8084
local ENEMY_TYPE_BASE = 0x834F

idle(60)
-- A+B+C chord enters debug mode (forces gameplay + spawns enemies)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)

local function snapshot(label)
  local hv = R(LINK_HEARTS)
  local hp = R(LINK_PARTIAL)
  local lx = R(LINK_X)
  local ly = R(LINK_Y)
  local inv = R(INVTIMER)
  local halt = R(LINK_HALT)
  local act = R(LINK_ACTION_T)
  local dmg_dis = R(LINK_DMG_DIS)
  local coll = R(ROOM_COLL_CNT)
  f:write(string.format("%s HV=$%02X HP=$%02X X=$%02X Y=$%02X invT=$%02X halt=$%02X actT=$%02X dmgDis=$%02X collCnt=$%02X\n",
    label, hv, hp, lx, ly, inv, halt, act, dmg_dis, coll))
  -- Enemy types + positions
  for slot=1,4 do
    local t = R(ENEMY_TYPE_BASE + slot)
    local ex = R(ENEMY_X_BASE + slot)
    local ey = R(ENEMY_Y_BASE + slot)
    if t ~= 0 then
      f:write(string.format("  enemy slot %d: type=$%02X X=$%02X Y=$%02X (dx=%d dy=%d)\n",
        slot, t, ex, ey, ex - lx, ey - ly))
    end
  end
  return hv, hp
end

snapshot("[01 boot]")

-- Walk toward enemies. Default debug room $77 has Link at (78,8D). Up first.
local events = {}
local hv_prev, hp_prev = R(LINK_HEARTS), R(LINK_PARTIAL)
for i=1,900 do
  -- Cycle directions to wander into enemy hitboxes
  local btns = {}
  local phase = (i // 60) % 4
  if phase == 0 then btns.Up = true
  elseif phase == 1 then btns.Right = true
  elseif phase == 2 then btns.Down = true
  else btns.Left = true end
  joypad.set(btns, 1)
  emu.frameadvance()
  local hv = R(LINK_HEARTS)
  local hp = R(LINK_PARTIAL)
  if hv ~= hv_prev or hp ~= hp_prev then
    events[#events+1] = string.format("frame %d: HV $%02X->$%02X HP $%02X->$%02X (X=$%02X Y=$%02X)",
      i, hv_prev, hv, hp_prev, hp, R(LINK_X), R(LINK_Y))
    hv_prev, hp_prev = hv, hp
  end
end

f:write(string.format("\n%d heart-state events:\n", #events))
for _, e in ipairs(events) do f:write("  " .. e .. "\n") end
snapshot("\n[02 final]")

client.screenshot("C:\\tmp\\link_damage.png")
idle(10)
client.exit()

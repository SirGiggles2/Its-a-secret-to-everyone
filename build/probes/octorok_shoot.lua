-- octorok_shoot.lua — verify octorok shoots flying rocks when Link
-- axis-aligned. Force-place an octorok adjacent to Link via direct RAM
-- writes, then watch ENEMY_SHOT_COUNT + new enemy slots populating
-- with type $53 (flying rock).

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\octorok_shoot.txt"
local f = io.open(OUT, "w")

-- A4 base $FF8000
local OBJTYPE  = 0x834F
local OBJALIVE = 0x8492
local OBJX     = 0x8070
local OBJY     = 0x8084
local OBJDIR   = 0x8098
local SHOT_CNT = 0x834C  -- ENEMY_SHOT_COUNT
local WANTS    = 0x8412  -- ENEMY_PUSH_TIMER = ObjWantsToShoot
local SHOOT_T  = 0x8451  -- ObjShootTimer

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)

f:write(string.format("Link X=$%02X Y=$%02X\n", R(0x8070), R(0x8084)))

-- Force slot 1 to red slow octorock (type $07), positioned at Link's Y but X=$50
-- (Link X is ~$78). Same Y → axis-aligned vertically.
local lx = R(0x8070)
local ly = R(0x8084)
W(OBJTYPE + 1, 0x07)         -- RedSlowOctorock
W(OBJALIVE + 1, 0x01)
W(OBJX + 1, 0x50)            -- to Link's left
W(OBJY + 1, ly)              -- same Y line
W(OBJDIR + 1, 0x01)          -- facing right (toward Link)
W(WANTS + 1, 0x00)           -- start with wants=0; AI must set
W(SHOOT_T + 1, 0x00)

f:write(string.format("[setup] octorok slot 1: type=$%02X X=$%02X Y=$%02X dir=$%02X\n",
  R(OBJTYPE+1), R(OBJX+1), R(OBJY+1), R(OBJDIR+1)))

-- Watch SHOT_CNT + slot 11 (highest, scan target for c_shoot_if_wanted) for 600f
local shot_events = {}
local shot_cnt_prev = R(SHOT_CNT)
local slot11_type_prev = R(OBJTYPE + 11)
local wants_max = 0
for i=1,600 do
  -- Hold position; don't let Link wander
  joypad.set({}, 1)
  emu.frameadvance()
  local sc = R(SHOT_CNT)
  local s11 = R(OBJTYPE + 11)
  local wt = R(WANTS + 1)
  if wt > wants_max then wants_max = wt end
  if sc ~= shot_cnt_prev then
    shot_events[#shot_events+1] = string.format("frame %d: SHOT_CNT $%02X->$%02X",
      i, shot_cnt_prev, sc)
    shot_cnt_prev = sc
  end
  if s11 ~= slot11_type_prev then
    shot_events[#shot_events+1] = string.format("frame %d: slot 11 type $%02X->$%02X (X=$%02X Y=$%02X)",
      i, slot11_type_prev, s11, R(OBJX+11), R(OBJY+11))
    slot11_type_prev = s11
  end
end

f:write(string.format("\nShot events: %d\n", #shot_events))
for _, e in ipairs(shot_events) do f:write("  " .. e .. "\n") end
f:write(string.format("max ObjWantsToShoot slot1 = $%02X\n", wants_max))
f:write(string.format("[final] slot1 X=$%02X Y=$%02X type=$%02X alive=$%02X\n",
  R(OBJX+1), R(OBJY+1), R(OBJTYPE+1), R(OBJALIVE+1)))

-- Dump ObjType for all 12 slots to see what's populated
f:write("ObjType[0..11]: ")
for s=0,11 do f:write(string.format("$%02X ", R(OBJTYPE+s))) end
f:write("\n")

client.screenshot("C:\\tmp\\octorok_shoot.png")
idle(10)
client.exit()

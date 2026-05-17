-- shot_despawn.lua — verify flying rock destroys when crossing room edge.
-- Force-place octorok facing right, near right edge. Watch slot 11 (shot
-- target) for spawn + destroy events.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\shot_despawn.txt"
local f = io.open(OUT, "w")

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)

-- Position octorok adjacent to right edge facing right + axis-aligned with Link
local OBJTYPE = 0x834F
local OBJALIVE = 0x8492
local OBJX = 0x8070
local OBJY = 0x8084
local OBJDIR = 0x8098
local OBJSTATE = 0x80AC

W(OBJTYPE + 1, 0x07)   -- SlowOctorock
W(OBJALIVE + 1, 0x01)
W(OBJX + 1, 0xE0)      -- near right edge
W(OBJY + 1, R(0x8084)) -- match Link Y
W(OBJDIR + 1, 0x01)    -- facing right
idle(5)

f:write(string.format("[setup] Link X=$%02X Y=$%02X\n", R(0x8070), R(0x8084)))
f:write(string.format("[setup] octorok slot 1: X=$%02X Y=$%02X dir=$%02X\n",
  R(OBJX+1), R(OBJY+1), R(OBJDIR+1)))

-- Track slot 11 across 400 frames
local prev_type = R(OBJTYPE + 11)
local prev_state = R(OBJSTATE + 11)
local prev_x = R(OBJX + 11)
local events = {}
local spawn_count = 0
local destroy_count = 0
for i=1,400 do
  joypad.set({}, 1); emu.frameadvance()
  local t = R(OBJTYPE + 11)
  local st = R(OBJSTATE + 11)
  local x = R(OBJX + 11)
  if t ~= prev_type then
    if prev_type == 0 and t ~= 0 then
      events[#events+1] = string.format("f%d: spawn slot11 type=$%02X X=$%02X",
        i, t, x)
      spawn_count = spawn_count + 1
    elseif prev_type ~= 0 and t == 0 then
      events[#events+1] = string.format("f%d: DESTROY slot11 (was $%02X X=$%02X->$%02X)",
        i, prev_type, prev_x, x)
      destroy_count = destroy_count + 1
    end
    prev_type = t
  end
  if math.abs(x - prev_x) > 4 and t == 0x53 then
    -- log only X transitions to right edge area
    if x >= 0xF0 or x <= 0x08 then
      events[#events+1] = string.format("f%d: slot11 X=$%02X (edge area)", i, x)
    end
  end
  prev_x = x
  prev_state = st
end

f:write(string.format("\n%d spawns, %d destroys\n", spawn_count, destroy_count))
for _, e in ipairs(events) do f:write("  " .. e .. "\n") end
f:write(string.format("\n[final] slot11 type=$%02X X=$%02X state=$%02X\n",
  R(OBJTYPE+11), R(OBJX+11), R(OBJSTATE+11)))

client.screenshot("C:\\tmp\\shot_despawn.png")
idle(10)
client.exit()

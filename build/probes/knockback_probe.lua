-- knockback_probe.lua — force enemy collision with Link, observe shove
-- direction, position movement, stun timer decrement, palette flash.
-- Watch nes_ram cells: $0070 (Link X) $0084 (Link Y) $00C0 (ShoveDir)
-- $00D3 (ShoveDist) $04F0 (StunTimer) $066F (Hearts).

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\knockback.txt"
local f = io.open(OUT, "w")

-- Boot + chord + arm mirror
idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)

local LX     = 0x8070; local LY     = 0x8084
local SHOVED = 0x80C0; local SHOVET = 0x80D3
local STUN   = 0x84F0; local HEARTS = 0x866F
local OBJTYPE = 0x834F; local OBJALIVE = 0x8492
local OBJX = 0x8070; local OBJY = 0x8084

local function snap(label)
  f:write(string.format("%s X=$%02X Y=$%02X ShoveDir=$%02X ShoveDist=$%02X Stun=$%02X HV=$%02X\n",
    label, R(LX), R(LY), R(SHOVED), R(SHOVET), R(STUN), R(HEARTS)))
end

snap("[01 boot]")

-- Force-place RedSlowOctorock right next to Link
W(OBJTYPE + 1, 0x07)
W(OBJALIVE + 1, 0x01)
W(OBJX + 1, R(LX) + 4)   -- 4px to Link's right
W(OBJY + 1, R(LY))       -- same Y
idle(5)

snap("[02 enemy placed adjacent]")

-- Sample every frame for 60f and log shove/position changes
local events = {}
local prev_x = R(LX); local prev_y = R(LY)
local prev_shove_dir = R(SHOVED); local prev_shove_dist = R(SHOVET)
local prev_stun = R(STUN)
local hits = 0
for i=1,120 do
  joypad.set({}, 1)
  emu.frameadvance()
  local x = R(LX); local y = R(LY)
  local sd = R(SHOVED); local st = R(SHOVET); local stun = R(STUN)
  if sd ~= prev_shove_dir then
    events[#events+1] = string.format("f%d: ShoveDir $%02X->$%02X (X=$%02X Y=$%02X)",
      i, prev_shove_dir, sd, x, y); prev_shove_dir = sd
    if sd ~= 0 then hits = hits + 1 end
  end
  if st ~= prev_shove_dist then
    events[#events+1] = string.format("f%d: ShoveDist $%02X->$%02X", i, prev_shove_dist, st)
    prev_shove_dist = st
  end
  if stun ~= prev_stun then
    events[#events+1] = string.format("f%d: Stun $%02X->$%02X", i, prev_stun, stun)
    prev_stun = stun
  end
  if x ~= prev_x or y ~= prev_y then
    events[#events+1] = string.format("f%d: pos ($%02X,$%02X)->($%02X,$%02X)",
      i, prev_x, prev_y, x, y); prev_x = x; prev_y = y
  end
end
f:write(string.format("\n%d events, %d hits\n", #events, hits))
for _, e in ipairs(events) do f:write("  " .. e .. "\n") end

snap("\n[03 final]")
client.screenshot("C:\\tmp\\knockback.png")
idle(10)
client.exit()

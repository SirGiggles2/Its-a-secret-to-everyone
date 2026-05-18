-- probe_link_hp.lua — verify Link takes damage from monster collision.
-- Spawn octorok next to Link (same x/y), trace LINK_HEARTS ($066F) +
-- LINK_PARTIAL_HEART ($0670) over 240 frames.

local function R(off)  return memory.read_u8(off, "68K RAM") end
local function W(off,v) memory.write_u8(off, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local NES = 0x8000

-- Boot to gameplay via A+B+C chord edge-trigger
idle(120)
joypad.set({},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance()
joypad.set({A=true,B=true,C=true},1); emu.frameadvance()
joypad.set({A=true,B=true,C=true},1); emu.frameadvance()
joypad.set({},1); idle(120)

-- Read Link's REAL position after boot (RoomRom's players[0].x/y synced
-- to NES mirror at $0070/$0084 each scroll-stable frame).
local link_actual_x = R(NES + 0x0070)
local link_actual_y = R(NES + 0x0084)
print(string.format("Link actual pos = (%02X, %02X)", link_actual_x, link_actual_y))

-- Arm probe: Red Moblin type $04 at Link's REAL position.
W(0x77D0, 0x46); W(0x77D1, 0x58)
W(0x77D2, 0x04)
W(0x77D3, link_actual_x); W(0x77D4, link_actual_y); W(0x77D5, 0x02)
W(0x77D6, 0x01); W(0x77D7, 0x00); W(0x77D8, 0x77)

-- Wait for hook to consume
local waited = 0
while waited < 60 and (R(0x77D0) ~= 0 or R(0x77D1) ~= 0) do
  emu.frameadvance(); waited = waited + 1
end

-- Force Link to same position as octorok every frame (lock overlap)
-- Track HeartValues + Partial + StunTimer + InvincibilityTimer
local f = io.open("C:/tmp/efx_link_hp.txt", "w")
f:write("# probe_link_hp: Link in octorok contact, 240 frames\n")
f:write("frame | LinkX LinkY LinkDir | HV$66F PH$670 STN$3D INV$04F0 | EnX EnY EnDir EnHit\n")

for fr=0,240 do
  -- Force moblin to overlap Link's CURRENT position every frame.
  local lx = R(NES + 0x0070)
  local ly = R(NES + 0x0084)
  W(NES + 0x0070 + 1, lx)
  W(NES + 0x0084 + 1, ly)

  local hv  = R(NES + 0x066F)
  local ph  = R(NES + 0x0670)
  local stn = R(NES + 0x003D)
  local inv = R(NES + 0x04F0)
  local action = R(NES + 0x00AC)  -- LINK_ACTION_TIMER
  local halt   = R(NES + 0x066C)  -- LINK_HALT_FLAG
  local disable = R(NES + 0x0512) -- LINK_DAMAGE_DISABLE_FLAG
  local rmcc = R(NES + 0x0340)    -- ROOM_MONSTER_COLLISION_COUNT (guess)
  local lnx = R(NES + 0x0070)
  local lny = R(NES + 0x0084)
  local lnd = R(NES + 0x0098)
  local enx = R(NES + 0x0070 + 1)
  local eny = R(NES + 0x0084 + 1)
  local end_dir = R(NES + 0x0098 + 1)
  local enhit = R(NES + 0x04F0 + 1)
  local enstun = R(NES + 0x003D + 1)
  local enmeta = R(NES + 0x0405 + 1)
  local enalive = R(NES + 0x0492 + 1)
  local sent = R(0x77E0)
  local sentn = R(0x77E1)
  local s2 = R(0x77E2)  -- check_link entries
  local s3 = R(0x77E3)  -- preinit entries
  local s4 = R(0x77E4)  -- post-bail entries
  local s5 = R(0x77E5)  -- collide-true entries
  local snm_x = R(0x77F0)  -- monster middle X (last collide input)
  local snm_y = R(0x77F1)
  local snl_x = R(0x77F2)  -- Link hitbox X
  local snl_y = R(0x77F3)
  local snt_x = R(0x77F4)  -- threshold X
  local snt_y = R(0x77F5)
  f:write(string.format("f%d | L%02X,%02X | HV%02X PH%02X | E%02X,%02X,m%02X | chk=%02X coll=%02X harm=%02X | mX=%02X mY=%02X lX=%02X lY=%02X tX=%02X tY=%02X\n",
    fr, lnx, lny, hv, ph, enx, eny, enmeta, s2, s5, sentn, snm_x, snm_y, snl_x, snl_y, snt_x, snt_y))
  emu.frameadvance()
end
f:close()
client.screenshot("C:/tmp/efx_link_hp.png")
client.exit()

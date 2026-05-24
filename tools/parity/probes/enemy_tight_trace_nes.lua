-- v6-D tight trace probe NES side. Type $07 Octorok in slot 1.
-- Warps to OW r$77 (start room), force-clears all enemies, pokes one
-- Octorok at fixed position, snapshots RNG, then samples (x, y, dir,
-- state, anim, qspd, frac, mvTm, projectile-spawn-frame) every frame
-- for 240 frames. Emits JSON.

local function R(o) return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b,h,s) h=h or 4; s=s or 30
  for _=1,h do joypad.set({[b]=true},1); emu.frameadvance() end
  joypad.set({},1); for _=1,s do emu.frameadvance() end
end

-- Boot
idle(360); press("Start",4,60)
press("Down",4,20); press("Down",4,20); press("Down",4,20); press("Start",4,60)
press("Start",4,60)
for _=1,5 do press("Down",4,8) end
for _=1,5 do press("Right",4,8) end
press("Start",4,60)
for _=1,5 do press("Up",4,12) end
press("Start",4,180); idle(180)

-- Warp to OW r$77 (start room — Link spawn point, single tile area)
W(0x0070, 0x78); W(0x0084, 0x80); W(0x0098, 0x08)
W(0x0010, 0x00); W(0x00EB, 0x77); W(0x0012, 0x06)
idle(180)
W(0x00EB, 0x77); W(0x0010, 0x00); W(0x0012, 0x05)
W(0x0070, 0x78); W(0x0084, 0x80)
idle(60)

-- Pin RNG seed (single byte $0018 = Random per Variables.inc:8).
W(0x0018, 0x42)

-- Clear all enemy slots
for s = 1, 19 do
  W(0x034F+s, 0); W(0x0485+s, 0); W(0x0405+s, 0); W(0x00AC+s, 0); W(0x04BF+s, 0)
  W(0x0098+s, 0); W(0x03BC+s, 0); W(0x0028+s, 0); W(0x03D0+s, 0); W(0x03E4+s, 0)
  W(0x00C0+s, 0); W(0x00D3+s, 0); W(0x04F0+s, 0)
end

-- Spawn one Octorok ($07) in slot 1 at fixed pos
local TYPE = 0x07
local INIT_X, INIT_Y = 0x70, 0x60
W(0x034F+1, TYPE)
W(0x0070+1, INIT_X); W(0x0084+1, INIT_Y); W(0x0098+1, 0x04)  -- facing down
W(0x04BF+1, 0x05)  -- ObjAttr from OBJECT_TYPE_TO_ATTRS[7]
W(0x0485+1, 0x10)  -- HP 1 hit
W(0x03BC+1, 0x20)  -- QSpeed
W(0x03D0+1, 0x10)  -- AnimSpec
W(0x03E4+1, 0)     -- AnimFrame
W(0x0028+1, 1)     -- ObjTimer = slot (cloud spawn)
W(0x0405+1, 0x01)  -- Metastate=1 (spawning)
W(0x04F0+1, 0); W(0x00C0+1, 0); W(0x00D3+1, 0)

local f = io.open("C:/tmp/enemy_tight_trace_nes.json", "w")
f:write("{\n")
f:write(string.format('  "type":"$%02X",\n', TYPE))
f:write(string.format('  "init_x":%d, "init_y":%d, "rng_seed":[$%02X,$%02X,$%02X],\n',
  INIT_X, INIT_Y, R(0x0017), R(0x0018), R(0x0019)))
f:write('  "frames":[\n')

for frame = 0, 239 do
  local proj_type = 0
  local proj_x = 0
  local proj_y = 0
  -- Scan projectile slots for $53-$5F (shots)
  for s = 2, 19 do
    local t = R(0x034F+s)
    if t >= 0x53 and t <= 0x5F then
      proj_type = t; proj_x = R(0x0070+s); proj_y = R(0x0084+s); break
    end
  end
  local sep = (frame == 239) and "" or ","
  f:write(string.format(
    '    {"f":%3d, "x":$%02X, "y":$%02X, "dir":$%02X, "st":$%02X, "ms":$%02X, "anim":$%02X, "qspd":$%02X, "frac":$%02X, "mvtm":$%02X, "hp":$%02X, "alive":$%02X, "proj":$%02X, "px":$%02X, "py":$%02X, "rng":$%02X}%s\n',
    frame,
    R(0x0070+1), R(0x0084+1), R(0x0098+1), R(0x00AC+1), R(0x0405+1),
    R(0x03E4+1), R(0x03BC+1), R(0x03A8+1), R(0x0028+1),
    R(0x0485+1), R(0x0493+1),
    proj_type, proj_x, proj_y, R(0x0019), sep))
  f:flush()
  emu.frameadvance()
end
f:write('  ]\n}\n')
f:close()
client.exit()

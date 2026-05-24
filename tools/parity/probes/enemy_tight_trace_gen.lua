-- v6-D tight trace probe Gen side. Mirrors NES probe exactly.
-- Type $07 Octorok in slot 1. Warps via $FF73F8 probe-control to OW r$77.
-- Pins RNG, force-spawns Octorok, samples per-frame for 240 frames.

local NES_BASE = 0x8000
local function R(o)   return memory.read_u8(NES_BASE + o, "68K RAM") end
local function W(o,v) memory.write_u8(NES_BASE + o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function safe_set(p)
  local ok = pcall(function() joypad.set(p or {}, 1) end)
  if not ok then joypad.set(p or {}) end
end

local PROBE_CTRL = 0x73F8

-- Boot via A+B+C chord
for _ = 1, 60 do emu.frameadvance() end
for _ = 1, 30 do
  safe_set({A=true, B=true, C=true,
            ["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
  emu.frameadvance()
end
safe_set({})
for _ = 1, 240 do emu.frameadvance() end

-- Warp to OW r$77 via probe-control hook
W(0x0098, 0x08)
memory.write_u8(PROBE_CTRL + 0, 0x52, "68K RAM")  -- 'R'
memory.write_u8(PROBE_CTRL + 1, 0x50, "68K RAM")  -- 'P'
memory.write_u8(PROBE_CTRL + 3, 0, "68K RAM")     -- scene=OW
memory.write_u8(PROBE_CTRL + 4, 0, "68K RAM")     -- level=0
memory.write_u8(PROBE_CTRL + 5, 0, "68K RAM")
memory.write_u8(PROBE_CTRL + 6, 0x77, "68K RAM")  -- room
memory.write_u8(PROBE_CTRL + 7, 0x5A, "68K RAM")  -- trigger
for _ = 1, 30 do
  emu.frameadvance()
  if memory.read_u8(PROBE_CTRL + 7, "68K RAM") == 0 then break end
end
idle(180)

-- Pin RNG seed (single byte $0018 = Random per Variables.inc:8).
W(0x0018, 0x42)

-- Clear all enemy slots
for s = 1, 19 do
  W(0x034F+s, 0); W(0x0485+s, 0); W(0x0405+s, 0); W(0x00AC+s, 0); W(0x04BF+s, 0)
  W(0x0098+s, 0); W(0x03BC+s, 0); W(0x0028+s, 0); W(0x03D0+s, 0); W(0x03E4+s, 0)
  W(0x00C0+s, 0); W(0x00D3+s, 0); W(0x04F0+s, 0)
end

local TYPE = 0x07
local INIT_X, INIT_Y = 0x70, 0x60
W(0x034F+1, TYPE)
W(0x0070+1, INIT_X); W(0x0084+1, INIT_Y); W(0x0098+1, 0x04)
W(0x04BF+1, 0x05)
W(0x0485+1, 0x10)
W(0x03BC+1, 0x20)
W(0x03D0+1, 0x10)
W(0x03E4+1, 0)
W(0x0028+1, 1)
W(0x0405+1, 0x01)
W(0x04F0+1, 0); W(0x00C0+1, 0); W(0x00D3+1, 0)
W(0x0492+1, 1)  -- ENEMY_ALIVE_FLAG: Gen convention 1=alive, 0=skip

local f = io.open("C:/tmp/enemy_tight_trace_gen.json", "w")
f:write("{\n")
f:write(string.format('  "type":"$%02X",\n', TYPE))
f:write(string.format('  "init_x":%d, "init_y":%d, "rng_seed":[$%02X,$%02X,$%02X],\n',
  INIT_X, INIT_Y, R(0x0017), R(0x0018), R(0x0019)))
f:write('  "frames":[\n')

for frame = 0, 239 do
  local proj_type = 0
  local proj_x = 0
  local proj_y = 0
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

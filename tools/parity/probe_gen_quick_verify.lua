-- Quick post-fix verification probe: 6 rooms covering key visual scenarios.
local NES_BASE = 0x8000
local function R(o)   return memory.read_u8(NES_BASE + o, "68K RAM") end
local function W(o,v) memory.write_u8(NES_BASE + o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function safe_set(p)
  local ok = pcall(function() joypad.set(p or {}, 1) end)
  if not ok then joypad.set(p or {}) end
end
local PROBE_CTRL = 0x73F8

for _ = 1, 60 do emu.frameadvance() end
for _ = 1, 30 do
  safe_set({A=true, B=true, C=true,
            ["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
  emu.frameadvance()
end
safe_set({})
for _ = 1, 240 do emu.frameadvance() end

local function warp(level, room)
  W(0x0098, 0x08)
  local scene = (level == 0) and 0 or 1
  memory.write_u8(PROBE_CTRL + 0, 0x52, "68K RAM")
  memory.write_u8(PROBE_CTRL + 1, 0x50, "68K RAM")
  memory.write_u8(PROBE_CTRL + 3, scene, "68K RAM")
  memory.write_u8(PROBE_CTRL + 4, level, "68K RAM")
  memory.write_u8(PROBE_CTRL + 5, 0, "68K RAM")
  memory.write_u8(PROBE_CTRL + 6, room, "68K RAM")
  memory.write_u8(PROBE_CTRL + 7, 0x5A, "68K RAM")
  for _ = 1, 30 do
    emu.frameadvance()
    if memory.read_u8(PROBE_CTRL + 7, "68K RAM") == 0 then break end
  end
  idle(240)
end

local rooms = {
  {lv=0x00, rm=0x77, name="OW_Start"},
  {lv=0x00, rm=0x67, name="OW_Octorok"},
  {lv=0x00, rm=0x04, name="OW_Lynel"},
  {lv=0x00, rm=0x37, name="OW_Peahat"},
  {lv=0x01, rm=0x73, name="L1_entry"},
  {lv=0x01, rm=0x35, name="L1_Aquamentus"},
}

for _, r in ipairs(rooms) do
  warp(r.lv, r.rm)
  client.screenshot(string.format("C:/tmp/gen_quick_%s.png", r.name))
end

client.exit()

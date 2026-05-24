-- UW sweep verify: probe-warp L1-L9 entry rooms + capture state.

local NES_BASE = 0x8000
local function R(o) return memory.read_u8(NES_BASE + o, "68K RAM") end
local function W(o,v) memory.write_u8(NES_BASE + o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function safe_set(p)
  local ok = pcall(function() joypad.set(p or {}, 1) end)
  if not ok then joypad.set(p or {}) end
end
local PROBE_CTRL = 0x73F8

for _ = 1, 60 do emu.frameadvance() end
for _ = 1, 30 do
  safe_set({A=true, B=true, C=true, ["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
  emu.frameadvance()
end
safe_set({})
for _ = 1, 240 do emu.frameadvance() end

local function warp(level, room)
  W(0x0098, 0x08)
  memory.write_u8(PROBE_CTRL + 0, 0x52, "68K RAM")
  memory.write_u8(PROBE_CTRL + 1, 0x50, "68K RAM")
  memory.write_u8(PROBE_CTRL + 3, 1, "68K RAM")
  memory.write_u8(PROBE_CTRL + 4, level, "68K RAM")
  memory.write_u8(PROBE_CTRL + 5, 0, "68K RAM")
  memory.write_u8(PROBE_CTRL + 6, room, "68K RAM")
  memory.write_u8(PROBE_CTRL + 7, 0x5A, "68K RAM")
  for _ = 1, 30 do
    emu.frameadvance()
    if memory.read_u8(PROBE_CTRL + 7, "68K RAM") == 0 then break end
  end
  idle(180)
end

-- Picked from g_uw_room_lookup populated lists per level (orig Q1).
local entries = {
  {lv=1, rm=0x73}, {lv=2, rm=0x7D}, {lv=3, rm=0x7D}, {lv=4, rm=0x45},
  {lv=4, rm=0x72}, {lv=5, rm=0x78}, {lv=6, rm=0x7B}, {lv=7, rm=0x7B},
  {lv=8, rm=0x7F}, {lv=9, rm=0x77},
}

local out = io.open("C:/tmp/gen_uw_sweep.txt","w")
for _, e in ipairs(entries) do
  warp(e.lv, e.rm)
  out:write(string.format("L%d r$%02X actual lv=$%02X rm=$%02X gm=$%02X\n",
    e.lv, e.rm, R(0x0010), R(0x00EB), R(0x0012)))
  client.screenshot(string.format("C:/tmp/gen_uw_L%d_r%02X.png", e.lv, e.rm))
end
out:close()
client.exit()

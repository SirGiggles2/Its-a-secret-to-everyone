-- Probe known-good NES boss room IDs on Gen. Capture each.

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
  idle(240)
end

local out = io.open("C:/tmp/gen_known_bosses.txt", "w")

local bosses = {
  {lv=1, rm=0x35, name="L1_Aquamentus"},
  {lv=2, rm=0x73, name="L2_Dodongo"},
  {lv=3, rm=0x0F, name="L3_Manhandla"},
  {lv=4, rm=0x45, name="L4_Gleeok2"},
  {lv=5, rm=0x06, name="L5_Digdogger"},
  {lv=6, rm=0x0F, name="L6_GohmaRed"},
  {lv=7, rm=0x23, name="L7_Aquamentus2"},
  {lv=8, rm=0x1F, name="L8_Gleeok4"},
  {lv=9, rm=0x1E, name="L9_Patra"},
  {lv=9, rm=0x1F, name="L9_Ganon"},
}

for _, b in ipairs(bosses) do
  warp(b.lv, b.rm)
  out:write(string.format("\n=== %s lv=$%02X rm=$%02X (actual lv=$%02X rm=$%02X) ===\n",
    b.name, b.lv, b.rm, R(0x0010), R(0x00EB)))
  out:write("Slots:\n")
  local any = false
  for s = 1, 19 do
    local t = R(0x034F + s)
    if t ~= 0 then
      any = true
      out:write(string.format("  s%02d t=$%02X x=$%02X y=$%02X dir=$%02X attr=$%02X hp=$%02X\n",
        s, t, R(0x0070+s), R(0x0084+s), R(0x0098+s),
        R(0x04BF+s), R(0x0485+s)))
    end
  end
  if not any then out:write("  (empty)\n") end
  client.screenshot(string.format("C:/tmp/gen_boss_%s.png", b.name))
end

out:close()
client.exit()

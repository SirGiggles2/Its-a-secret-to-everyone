-- Targeted L1 r$35 Aquamentus check (real boss room per LevelInfo byte 26).

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

local out = io.open("C:/tmp/gen_l1_boss_check.txt", "w")
local rooms = {
  {lv=0x01, rm=0x35, name="L1_boss_r35_REAL"},
}

for _, r in ipairs(rooms) do
  W(0x0098, 0x08)
  memory.write_u8(PROBE_CTRL + 0, 0x52, "68K RAM")
  memory.write_u8(PROBE_CTRL + 1, 0x50, "68K RAM")
  memory.write_u8(PROBE_CTRL + 3, 1, "68K RAM")
  memory.write_u8(PROBE_CTRL + 4, r.lv, "68K RAM")
  memory.write_u8(PROBE_CTRL + 5, 0, "68K RAM")
  memory.write_u8(PROBE_CTRL + 6, r.rm, "68K RAM")
  memory.write_u8(PROBE_CTRL + 7, 0x5A, "68K RAM")
  for _ = 1, 30 do
    emu.frameadvance()
    if memory.read_u8(PROBE_CTRL + 7, "68K RAM") == 0 then break end
  end
  idle(240)

  out:write(string.format("\n=== %s (actual lv=$%02X rm=$%02X gm=$%02X) ===\n",
    r.name, R(0x0010), R(0x00EB), R(0x0012)))
  out:write("Slots:\n")
  for s = 1, 19 do
    local t = R(0x034F + s)
    if t ~= 0 then
      out:write(string.format("  s%02d t=$%02X x=$%02X y=$%02X dir=$%02X attr=$%02X hp=$%02X\n",
        s, t, R(0x0070+s), R(0x0084+s), R(0x0098+s), R(0x04BF+s), R(0x0485+s)))
    end
  end
  client.screenshot(string.format("C:/tmp/gen_%s.png", r.name))
end

out:close()
client.exit()

local function R(o) return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b,h,s) h=h or 4; s=s or 30
  for _=1,h do joypad.set({[b]=true},1); emu.frameadvance() end
  joypad.set({},1); for _=1,s do emu.frameadvance() end
end

idle(360); press("Start",4,60)
press("Down",4,20); press("Down",4,20); press("Down",4,20); press("Start",4,60)
press("Start",4,60)
for _=1,5 do press("Down",4,8) end
for _=1,5 do press("Right",4,8) end
press("Start",4,60)
for _=1,5 do press("Up",4,12) end
press("Start",4,180); idle(180)

local out = io.open("C:/tmp/nes_known_bosses.txt", "w")

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
  W(0x0070, 0x78); W(0x0084, 0x80); W(0x0098, 0x08)
  W(0x0010, b.lv); W(0x00EB, b.rm); W(0x0012, 0x06)
  idle(180)
  W(0x00EB, b.rm); W(0x0010, b.lv); W(0x0012, 0x05)
  W(0x0070, 0x78); W(0x0084, 0x80)
  idle(120)

  out:write(string.format("\n=== %s lv=$%02X rm=$%02X (actual lv=$%02X rm=$%02X) BossRoomId=$%02X ===\n",
    b.name, b.lv, b.rm, R(0x0010), R(0x00EB), R(0x6BBC)))
  out:write("Slots:\n")
  local any = false
  for s = 1, 19 do
    local t = R(0x034F + s)
    if t ~= 0 then
      any = true
      out:write(string.format("  s%02d t=$%02X x=$%02X y=$%02X dir=$%02X attr=$%02X hp=$%02X\n",
        s, t, R(0x0070+s), R(0x0084+s), R(0x0098+s), R(0x04BF+s), R(0x0485+s)))
    end
  end
  if not any then out:write("  (empty)\n") end
  client.screenshot(string.format("C:/tmp/nes_boss_%s.png", b.name))
end

out:close()
client.exit()

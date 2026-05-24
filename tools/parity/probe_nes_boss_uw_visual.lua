-- NES side mirror of Gen boss/UW visual sweep.

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

local out = io.open("C:/tmp/nes_boss_uw_visual.txt", "w")

local rooms = {
  {lv=0x01, rm=0x73, name="L1_entry_r73"},
  {lv=0x01, rm=0x36, name="L1_Aquamentus_r36"},
  {lv=0x02, rm=0x7D, name="L2_entry_r7D"},
  {lv=0x02, rm=0x4F, name="L2_Dodongo_r4F"},
  {lv=0x03, rm=0x60, name="L3_entry_r60"},
  {lv=0x03, rm=0x36, name="L3_Manhandla_r36"},
  {lv=0x04, rm=0x7C, name="L4_entry_r7C"},
  {lv=0x04, rm=0x35, name="L4_Gleeok2_r35"},
  {lv=0x05, rm=0x55, name="L5_entry_r55"},
  {lv=0x05, rm=0x36, name="L5_Digdogger_r36"},
  {lv=0x06, rm=0x68, name="L6_entry_r68"},
  {lv=0x06, rm=0x37, name="L6_Gohma_r37"},
  {lv=0x07, rm=0x12, name="L7_entry_r12"},
  {lv=0x07, rm=0x0F, name="L7_Aquamentus_r0F"},
  {lv=0x08, rm=0x57, name="L8_entry_r57"},
  {lv=0x08, rm=0x6A, name="L8_Gleeok4_r6A"},
  {lv=0x09, rm=0x71, name="L9_entry_r71"},
  {lv=0x09, rm=0x35, name="L9_Patra_r35"},
  {lv=0x09, rm=0x13, name="L9_Ganon_r13"},
}

for _, r in ipairs(rooms) do
  -- Warp
  W(0x0070, 0x78); W(0x0084, 0x80); W(0x0098, 0x08)
  W(0x0010, r.lv); W(0x00EB, r.rm); W(0x0012, 0x06)
  idle(180)
  W(0x00EB, r.rm); W(0x0010, r.lv); W(0x0012, 0x05)
  W(0x0070, 0x78); W(0x0084, 0x80)
  idle(120)

  out:write(string.format("\n=== %s (target lv=$%02X rm=$%02X | actual lv=$%02X rm=$%02X gm=$%02X) ===\n",
    r.name, r.lv, r.rm, R(0x0010), R(0x00EB), R(0x0012)))

  out:write("Slots (1-19):\n")
  local any_slot = false
  for s = 1, 19 do
    local t = R(0x034F + s)
    if t ~= 0 then
      any_slot = true
      out:write(string.format("  s%02d t=$%02X x=$%02X y=$%02X dir=$%02X attr=$%02X ms=$%02X anim=$%02X hp=$%02X\n",
        s, t, R(0x0070+s), R(0x0084+s), R(0x0098+s),
        R(0x04BF+s), R(0x0405+s), R(0x03E4+s), R(0x0485+s)))
    end
  end
  if not any_slot then out:write("  (no slots populated)\n") end

  client.screenshot(string.format("C:/tmp/nes_visual_%s_f300.png", r.name))
end

out:close()
client.exit()

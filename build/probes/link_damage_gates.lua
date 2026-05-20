-- link_damage_gates.lua — sample all collision-gate cells while Link is
-- adjacent to an octorok. Find which gate prevents harm_link.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn,h,r)
  h=h or 6; r=r or 30
  for _=1,h do joypad.set({[btn]=true},1); emu.frameadvance() end
  for _=1,r do joypad.set({},1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\link_damage_gates.txt"
local f = io.open(OUT, "w")

local function dump(lbl)
  f:write(string.format("\n[%s]\n", lbl))
  f:write(string.format("  link=(%02X,%02X) face=$%02X\n",
    R(MIRROR+0x0070), R(MIRROR+0x0084), R(MIRROR+0x0098)))
  f:write(string.format("  hv=$%02X hpartial=$%02X\n",
    R(MIRROR+0x066F), R(MIRROR+0x0670)))
  f:write(string.format("  HALT($066C)=$%02X ACTION_TIMER($00AC)=$%02X\n",
    R(MIRROR+0x066C), R(MIRROR+0x00AC)))
  f:write(string.format("  LinkStunTimer($04F0)=$%02X InvincTimer($04E8)=$%02X InvClock($066E)=$%02X\n",
    R(MIRROR+0x04F0), R(MIRROR+0x04E8), R(MIRROR+0x066E)))
  for s=1,4 do
    local t = R(MIRROR+0x034F+s)
    local x = R(MIRROR+0x0070+s)
    local y = R(MIRROR+0x0084+s)
    local stun = R(MIRROR+0x04F0+s)
    local hit = R(MIRROR+0x0479+s) -- guess at MON_HIT_REACTION
    local stat = R(MIRROR+0x03B5+s) -- MON_STATUS_FLAGS guess
    if t ~= 0 then
      f:write(string.format("  s%d t=$%02X xy=(%02X,%02X) stun=$%02X hit=$%02X stat=$%02X\n",
        s,t,x,y,stun,hit,stat))
    end
  end
end

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
idle(60)

tap("X"); tap("Up"); tap("X")
idle(40)
dump("teleport $67")

-- Walk Up to align Y=5D row.
for _=1,55 do joypad.set({Up=true},1); emu.frameadvance() end
for _=1,8 do joypad.set({},1); emu.frameadvance() end
dump("aligned row 5D")

-- Walk LEFT into slot 4 octorok.
for _=1,40 do joypad.set({Left=true},1); emu.frameadvance() end
for _=1,4 do joypad.set({},1); emu.frameadvance() end
dump("after 40 left")

-- Per-frame dump while pressing left.
for i=1,30 do
  joypad.set({Left=true},1); emu.frameadvance()
  if i%3==0 then dump(string.format("press-left +%d", i)) end
end

client.screenshot("C:\\tmp\\link_damage_gates.png")
f:close()
gui.text(8,8,"gates done")
idle(20)
client.exit()

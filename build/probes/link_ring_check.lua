-- link_ring_check.lua — check LINK_RING_LEVEL ($0662) value at boot
-- and after entering gameplay. Hypothesis: uninit garbage shifts dmg to 0.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn,h,r)
  h=h or 6; r=r or 30
  for _=1,h do joypad.set({[btn]=true},1); emu.frameadvance() end
  for _=1,r do joypad.set({},1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\link_ring.txt"
local f = io.open(OUT, "w")

local function dump(lbl)
  f:write(string.format("\n[%s]\n", lbl))
  f:write(string.format("  hv=$%02X hpartial=$%02X ring($0662)=$%02X\n",
    R(MIRROR+0x066F), R(MIRROR+0x0670), R(MIRROR+0x0662)))
  f:write(string.format("  COMBAT_HARM_FLAG($05A1?)=$%02X CombatThreshX($05?)=$%02X CombatThreshY=$%02X\n",
    R(MIRROR+0x05A1), R(MIRROR+0x05A2), R(MIRROR+0x05A3)))
  f:write(string.format("  $00..$10:"))
  for o=0,16 do f:write(string.format(" %02X", R(MIRROR+o))) end
  f:write("\n")
end

idle(10)
dump("boot frame 10")
idle(120)
dump("boot frame 130")
for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
idle(60)
dump("post-gameplay-enter")

tap("X"); tap("Up"); tap("X")
idle(40)
dump("teleport $67")

client.screenshot("C:\\tmp\\link_ring.png")
f:close()
gui.text(8,8,"ring done")
idle(20)
client.exit()

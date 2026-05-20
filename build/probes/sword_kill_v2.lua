-- sword_kill_v2.lua — align Link to enemy Y row, then swing.
-- $67 has 4 octoroks: slot1=(40,5D) slot4=(50,5D) at top row.
-- Walk Link Up ~$30 px then Left ~$30 px to reach (~48,5D).
local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn,h,r)
  h=h or 6; r=r or 30
  for _=1,h do joypad.set({[btn]=true},1); emu.frameadvance() end
  for _=1,r do joypad.set({},1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\sword_kill_v2.txt"
local f = io.open(OUT, "w")

local function dump(lbl)
  f:write(string.format("\n[%s] room=$%02X link=(%02X,%02X) objdir=$%02X swordSt=$%02X swordDir=$%02X\n",
    lbl, R(MIRROR+0x00EB), R(MIRROR+0x0070), R(MIRROR+0x0084),
    R(MIRROR+0x0098),                     -- Link ObjDir
    R(MIRROR+0x00AC+13),                  -- Sword ObjState (slot 13)
    R(MIRROR+0x0098+13)))                 -- Sword ObjDir
  for s=1,5 do
    local t = R(MIRROR+0x034F+s)
    local hp = R(MIRROR+0x0485+s)
    local x = R(MIRROR+0x0070+s)
    local y = R(MIRROR+0x0084+s)
    if t ~= 0 then
      f:write(string.format("  slot %d type=$%02X hp=$%02X pos=(%02X,%02X)\n",
        s,t,hp,x,y))
    end
  end
end

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
idle(60)

-- Teleport $77 -> $67
tap("X"); tap("Up"); tap("X")
idle(40)
dump("after teleport $67")

-- Walk Up until Y ~ $5D (need to drop Y from $8D by $30 = 48 px). 48 frames Up.
for _=1,55 do joypad.set({Up=true},1); emu.frameadvance() end
for _=1,8 do joypad.set({},1); emu.frameadvance() end
dump("after walk Up")

-- Walk Left to reach X~$58 (Link at $78, need ~$30 px left)
for _=1,40 do joypad.set({Left=true},1); emu.frameadvance() end
for _=1,8 do joypad.set({},1); emu.frameadvance() end
dump("after walk Left")

-- Swing sword. Track sword state per-frame during swing.
joypad.set({A=true}, 1); emu.frameadvance()
joypad.set({}, 1); emu.frameadvance()
dump("swing +2f")
idle(2)
dump("swing +4f")
idle(4)
dump("swing +8f")
idle(4)
dump("swing +12f")
idle(8)
dump("swing +20f")
idle(30)
dump("swing +50f")

-- Try another swing
joypad.set({A=true}, 1); emu.frameadvance()
joypad.set({}, 1); emu.frameadvance()
idle(30)
dump("swing2 done")

-- Walk further left + swing repeatedly
for round=1,5 do
  for _=1,6 do joypad.set({Left=true},1); emu.frameadvance() end
  for _=1,4 do joypad.set({},1); emu.frameadvance() end
  joypad.set({A=true}, 1); emu.frameadvance()
  joypad.set({}, 1); emu.frameadvance()
  idle(30)
  dump(string.format("round %d", round))
end

client.screenshot("C:\\tmp\\sword_kill_v2.png")
f:close()
gui.text(8,8,"sword v2 done")
idle(20)
client.exit()

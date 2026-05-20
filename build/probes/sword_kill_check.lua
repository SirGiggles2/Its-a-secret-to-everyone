-- sword_kill_check.lua — verify sword damages + kills enemies.
-- Teleport $77 -> $67 (4 octoroks, simpler room). Walk adjacent + swing.
-- Track ObjHP[1..4] over swings.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn,h,r)
  h=h or 6; r=r or 30
  for _=1,h do joypad.set({[btn]=true},1); emu.frameadvance() end
  for _=1,r do joypad.set({},1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\sword_kill.txt"
local f = io.open(OUT, "w")

local function dump(lbl)
  f:write(string.format("\n[%s] room=$%02X link=(%02X,%02X) face=%02X frame=%d\n",
    lbl, R(MIRROR+0x00EB), R(MIRROR+0x0070), R(MIRROR+0x0084),
    R(MIRROR+0x000F), emu.framecount()))
  for s=1,5 do
    local t = R(MIRROR+0x034F+s)
    local hp = R(MIRROR+0x0485+s)
    local x = R(MIRROR+0x0070+s)
    local y = R(MIRROR+0x0084+s)
    local st = R(MIRROR+0x00AC+s)
    if t ~= 0 then
      f:write(string.format("  slot %d type=$%02X hp=$%02X state=$%02X pos=(%02X,%02X)\n",
        s,t,hp,st,x,y))
    end
  end
end

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
idle(60)

-- Teleport to $67 (1 up from $77)
tap("X")
tap("Up")
tap("X")
idle(40)

dump("after teleport $67")

-- Sword level seeded to 1 = wood = 16 dmg. Octorok HP = 1 stab = die.
-- Link at (78,8D). Walk left + swing.
-- 5 cycles of: walk-left 8f + swing A 4f + idle 20f
for cycle=1,8 do
  for _=1,12 do joypad.set({Left=true},1); emu.frameadvance() end
  for _=1,4 do joypad.set({},1); emu.frameadvance() end
  for _=1,3 do joypad.set({A=true},1); emu.frameadvance() end
  for _=1,25 do joypad.set({},1); emu.frameadvance() end
  dump(string.format("cycle %d", cycle))
end

-- Now move down + swing
for cycle=1,5 do
  for _=1,8 do joypad.set({Down=true},1); emu.frameadvance() end
  for _=1,3 do joypad.set({A=true},1); emu.frameadvance() end
  for _=1,25 do joypad.set({},1); emu.frameadvance() end
  dump(string.format("down-cycle %d", cycle))
end

client.screenshot("C:\\tmp\\sword_kill.png")
f:close()
gui.text(8,8,"sword kill done")
idle(20)
client.exit()

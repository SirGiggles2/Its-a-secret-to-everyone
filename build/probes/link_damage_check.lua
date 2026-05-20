-- link_damage_check.lua — verify Link takes damage from enemy contact.
-- Teleport $67 (4 octoroks: slot 1 @ (40,5D), slot 4 @ (50,5D)).
-- Walk Link from (78,8D) UP to (78,65) row, then LEFT into slot 4 at X=$50.
-- Sample heart_values ($066F) + heart_partial ($0670) + invincibility timer.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn,h,r)
  h=h or 6; r=r or 30
  for _=1,h do joypad.set({[btn]=true},1); emu.frameadvance() end
  for _=1,r do joypad.set({},1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\link_damage.txt"
local f = io.open(OUT, "w")

local function dump(lbl)
  f:write(string.format("\n[%s] room=$%02X link=(%02X,%02X) face=$%02X hv=$%02X hp=$%02X\n",
    lbl, R(MIRROR+0x00EB), R(MIRROR+0x0070), R(MIRROR+0x0084),
    R(MIRROR+0x0098), R(MIRROR+0x066F), R(MIRROR+0x0670)))
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
dump("post-boot")

-- Teleport $77 -> $67
tap("X"); tap("Up"); tap("X")
idle(40)
dump("after teleport $67")

-- Walk Up to align with enemy row Y=$5D
for _=1,55 do joypad.set({Up=true},1); emu.frameadvance() end
for _=1,8 do joypad.set({},1); emu.frameadvance() end
dump("after walk Up")

-- Walk LEFT directly into octorok slot 4 @ X=$50. Don't swing.
-- Link at X=$78 needs ~$28 left to be on top of enemy.
for cycle=1,12 do
  for _=1,8 do joypad.set({Left=true},1); emu.frameadvance() end
  for _=1,6 do joypad.set({},1); emu.frameadvance() end
  dump(string.format("left-cycle %d", cycle))
end

-- Walk Down/Right/Up to bump other octoroks
for cycle=1,8 do
  for _=1,8 do joypad.set({Down=true},1); emu.frameadvance() end
  for _=1,6 do joypad.set({},1); emu.frameadvance() end
  dump(string.format("down-cycle %d", cycle))
end

client.screenshot("C:\\tmp\\link_damage.png")
f:close()
gui.text(8,8,"link damage done")
idle(20)
client.exit()

-- enemy_spawn_check.lua — boot, teleport from $77 to $01, verify enemies.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn, hold, release)
  hold = hold or 2
  release = release or 4
  for _=1,hold do joypad.set({[btn]=true}, 1); emu.frameadvance() end
  for _=1,release do joypad.set({}, 1); emu.frameadvance() end
end

local OUT = "C:\\tmp\\enemy_spawn.txt"
local f = io.open(OUT, "w")
local MIRROR = 0x8000

idle(60)
-- Enter gameplay
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(80)

local function snapshot(label)
  f:write(string.format("\n=== %s ===\n", label))
  f:write(string.format("game_mode=%02X cur_level=%02X cur_room=%02X link=(%02X,%02X)\n",
    R(MIRROR+0x0012), R(MIRROR+0x0010), R(MIRROR+0x00EB),
    R(MIRROR+0x0070), R(MIRROR+0x0084)))
  local any = false
  local lines = {}
  for s=1,11 do
    local t = R(MIRROR + 0x034F + s)
    local fl = R(MIRROR+0x0098+s)
    local x = R(MIRROR+0x0070+s)
    local y = R(MIRROR+0x0084+s)
    if t ~= 0 then
      any = true
      table.insert(lines, string.format("  slot %2d type=%02X flag=%02X (%02X,%02X)", s,t,fl,x,y))
    end
  end
  f:write(string.format("any_enemy_spawned=%s\n", tostring(any)))
  for _,l in ipairs(lines) do f:write(l.."\n") end
  local room = R(MIRROR + 0x00EB)
  f:write(string.format("LBA_C[$%02X]=%02X LBA_D[$%02X]=%02X\n",
    room, R(MIRROR+0x697E+room), room, R(MIRROR+0x69FE+room)))
end

snapshot("after debug_enter (boot room $77)")

-- Press X to enter teleport mode (BUTTON_X edge-trigger)
tap("X", 2, 6)
snapshot("after X (teleport mode)")

-- Teleport from $77 (r7,c7) up to $07 (r0,c7) via 7 Up taps
for i=1,7 do tap("Up", 2, 6) end
snapshot("after Up *7 (target $07)")

-- Then left from $07 (r0,c7) to $01 (r0,c1) via 6 Left taps
for i=1,6 do tap("Left", 2, 6) end
snapshot("after Left *6 (target $01)")

client.screenshot("C:\\tmp\\enemy_spawn.png")
f:close()
gui.text(8, 8, "done")
idle(20)
client.exit()

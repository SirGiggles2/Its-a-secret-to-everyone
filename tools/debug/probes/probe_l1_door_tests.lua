-- probe_l1_shutter.lua — in r$63 after clear, try A+B+C+START shutter trigger,
-- then try B-button (key door), then bomb (B+Z+C). See which opens north exit.

local OUT = "C:\\tmp\\l1_shutter.txt"
local SHOT = "C:\\tmp\\l1_sh\\"
os.execute("mkdir " .. SHOT .. " 2>NUL")

local function nesram(off) return memory.read_u8(0x8000 + off, "68K RAM") end
local function press(buttons, frames)
  for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(n) for i = 1, n do emu.frameadvance() end end

local trace = {}
local function snap(label)
  trace[#trace+1] = string.format("%-30s L(%3d,%3d) rm=$%02X opened=$%02X shut_trig=$%02X",
    label, nesram(0x0070), nesram(0x0084), nesram(0x00EB),
    nesram(0x07F8),  -- guess: opened-doors sentinel (if any)
    nesram(0x07E9)   -- guess: shutter trigger counter
  )
end

idle(120)
press({A=true, B=true, C=true}, 8); idle(60)
press({Mode=true}, 4); idle(60); snap("UW r73")

press({Up=true}, 180); idle(30); snap("in r63")
client.screenshot(SHOT .. "01_in_r63.png")

-- Clear r$63
for i = 1, 15 do
  local alive = 0
  for s = 1, 11 do if nesram(0x034F + s) ~= 0 then alive = alive + 1 end end
  if alive == 0 then break end
  for _, dir in ipairs({"Up", "Right", "Down", "Left"}) do
    press({[dir]=true}, 10)
    for _ = 1, 3 do press({A=true}, 4); idle(12) end
  end
end
snap("cleared r63")
client.screenshot(SHOT .. "02_cleared.png")

-- TEST 1: Try shutter trigger A+B+C+START
press({A=true, B=true, C=true, Start=true}, 8); idle(60); snap("after A+B+C+START")
client.screenshot(SHOT .. "03_shutter_trig.png")

-- Walk Up to north door
press({Up=true}, 120); snap("after shutter walk Up")
client.screenshot(SHOT .. "04_after_shutter.png")

-- TEST 2: Walk to center top + try B (key door touch)
press({Down=true}, 30); idle(20)
for x_target = 100, 160, 20 do
  press({Up=true}, 30)
  press({B=true}, 4); idle(20)
  press({Left=true}, 10)
end
snap("after key door attempts")
client.screenshot(SHOT .. "05_key_attempts.png")

-- TEST 3: Bomb (B+Z+C chord per main.c:2100)
press({B=true, Z=true, C=true}, 4); idle(60); snap("after B+Z+C bomb")
client.screenshot(SHOT .. "06_bomb.png")

press({Up=true}, 180); snap("walk Up post-bomb")
client.screenshot(SHOT .. "07_post_bomb.png")

-- TEST 4: try other exits — east + west doors
press({Down=true}, 60); press({Right=true}, 240); snap("walk to east wall")
client.screenshot(SHOT .. "08_east.png")
press({Right=true}, 60); snap("east push")
client.screenshot(SHOT .. "09_east_push.png")

press({Left=true}, 480); snap("walk far left")
client.screenshot(SHOT .. "10_west.png")
press({Left=true}, 60); snap("west push")
client.screenshot(SHOT .. "11_west_push.png")

local f = io.open(OUT, "w")
f:write("L1 r$63 shutter / key / bomb probe — " .. os.date() .. "\n")
f:write("=============================================================\n\n")
for _, l in ipairs(trace) do f:write(l .. "\n") end
f:close()
print("Wrote " .. OUT)

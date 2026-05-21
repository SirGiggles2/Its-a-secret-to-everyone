-- probe_l1_advance.lua — clear r$63, align to north door, advance L1 northward
-- toward Aquamentus boss room.

local OUT = "C:\\tmp\\l1_advance.txt"
local SHOT = "C:\\tmp\\l1_advance\\"
os.execute("mkdir " .. SHOT .. " 2>NUL")

local function nesram(off) return memory.read_u8(0x8000 + off, "68K RAM") end
local function press(buttons, frames)
  for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(n) for i = 1, n do emu.frameadvance() end end

local trace = {}
local rooms_visited = {}
local last_room = 0xFF

local function snap(label)
  local rm = nesram(0x00EB)
  if rm ~= last_room then
    rooms_visited[#rooms_visited+1] = string.format("frame=%6d label=%s rm=$%02X lvl=$%02X",
      emu.framecount(), label, rm, nesram(0x0010))
    last_room = rm
  end
  local alive = 0
  for s = 1, 11 do
    if nesram(0x034F + s) ~= 0 then alive = alive + 1 end
  end
  trace[#trace+1] = string.format("%-30s L(%3d,%3d) rm=$%02X alive=%d",
    label, nesram(0x0070), nesram(0x0084), rm, alive)
end

local function alive_count()
  local n = 0
  for s = 1, 11 do
    if nesram(0x034F + s) ~= 0 then n = n + 1 end
  end
  return n
end

local function clear_room(label)
  -- Cycle 4 dirs + swing until empty
  for i = 1, 25 do
    if alive_count() == 0 then break end
    for _, dir in ipairs({"Up", "Right", "Down", "Left"}) do
      if alive_count() == 0 then break end
      press({[dir]=true}, 10)
      for _ = 1, 3 do press({A=true}, 4); idle(12) end
    end
  end
  snap(label .. " cleared")
end

local function align_x(target_x, max_frames)
  local cur = nesram(0x0070)
  if cur < target_x then
    press({Right=true}, math.min(target_x - cur + 4, max_frames))
  elseif cur > target_x then
    press({Left=true}, math.min(cur - target_x + 4, max_frames))
  end
end

local function align_y(target_y, max_frames)
  local cur = nesram(0x0084)
  if cur < target_y then
    press({Down=true}, math.min(target_y - cur + 4, max_frames))
  elseif cur > target_y then
    press({Up=true}, math.min(cur - target_y + 4, max_frames))
  end
end

-- Boot + UW
idle(120)
press({A=true, B=true, C=true}, 8); idle(60)
press({Mode=true}, 4); idle(60); snap("UW r73")
client.screenshot(SHOT .. "01_r73.png")

-- Walk to r$63
press({Up=true}, 180); idle(30); snap("entered r63")
client.screenshot(SHOT .. "02_r63.png")

clear_room("r63")
client.screenshot(SHOT .. "03_r63_clear.png")

-- Align with north door, walk through
align_x(120, 80)
align_y(80, 60)
snap("aligned for north door")
press({Up=true}, 60); snap("through north door attempt")
client.screenshot(SHOT .. "04_north_door.png")

-- Continue trying directions
press({Up=true}, 120); snap("up more")
press({Up=true}, 120); snap("up 3")

snap("after north door push")
client.screenshot(SHOT .. "05_post_north.png")

-- If new room entered, clear it
local rm_now = nesram(0x00EB)
if rm_now ~= 0x63 then
  trace[#trace+1] = string.format("NEW ROOM: $%02X", rm_now)
  clear_room("new room")
  client.screenshot(SHOT .. "06_new_room_clear.png")

  -- Continue north
  align_x(120, 80)
  press({Up=true}, 180); snap("up in new room")
  client.screenshot(SHOT .. "07_advancing.png")

  clear_room("third room")
  client.screenshot(SHOT .. "08_third_clear.png")

  press({Up=true}, 180)
  client.screenshot(SHOT .. "09_final.png")
end

local f = io.open(OUT, "w")
f:write("L1 advance — " .. os.date() .. "\n")
f:write("============================================================\n\n")
f:write("ROOMS VISITED:\n")
for _, l in ipairs(rooms_visited) do f:write("  " .. l .. "\n") end
f:write("\nTRACE:\n")
for _, l in ipairs(trace) do f:write(l .. "\n") end
f:close()
print("Wrote " .. OUT)

-- scan_ow_moblin_gen.lua — Genesis: teleport-scan all OW rooms,
-- record which contain moblin ($03/$04). Then dump SAT for first hit.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

-- Boot via A+B+C
idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1); idle(60)
-- Press X for MODE_TELEPORT
joypad.set({X=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance()
idle(15)

local f = io.open("C:/tmp/scan_ow_moblin_gen.txt", "w")
f:write("Genesis OW moblin scan\n")

local found_room = nil
local function tap_dir(d)
  joypad.set({[d]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance()
  idle(8)
end

-- Walk through grid: full sweep 0..7 rows x 0..15 cols (128 rooms)
for row=0,7 do
  for col=0,15 do
    -- Navigate to (row, col)
    local target = row*16 + col
    for _=1,32 do
      local cur = R(0x80EB)
      if cur == target then break end
      local cur_row = cur >> 4
      local cur_col = cur & 0x0F
      if cur_col < col then tap_dir("Right")
      elseif cur_col > col then tap_dir("Left")
      elseif cur_row < row then tap_dir("Down")
      elseif cur_row > row then tap_dir("Up")
      else break end
    end
    idle(10)  -- let enemies populate
    local room = R(0x80EB)
    -- Scan slots
    for s=1,11 do
      local t = R(0x834F + s)
      if t == 0x03 or t == 0x04 then
        if not found_room then found_room = room end
        f:write(string.format("room=$%02X slot=%d type=$%02X\n", room, s, t))
      end
    end
  end
end

f:write(string.format("\nfirst_moblin_room=$%02X\n", found_room or 0xFF))
f:close()

-- If found, screenshot it
if found_room then
  -- Teleport back via grid walk
  local row = found_room >> 4
  local col = found_room & 0x0F
  for _=1,32 do
    local cur = R(0x80EB)
    if cur == found_room then break end
    local cur_row = cur >> 4
    local cur_col = cur & 0x0F
    if cur_col < col then tap_dir("Right")
    elseif cur_col > col then tap_dir("Left")
    elseif cur_row < row then tap_dir("Down")
    elseif cur_row > row then tap_dir("Up")
    else break end
  end
  idle(60)
  client.screenshot("C:/tmp/scan_ow_moblin_gen.png")
end

client.exit()

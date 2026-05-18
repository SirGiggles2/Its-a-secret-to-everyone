-- find_moblin_room.lua — NES: scan all OW rooms for one containing a moblin
-- Boot, walk around with teleport tricks. Simpler: dump LevelInfo_Foes table.
-- NES LevelInfo_RoomFoes addr unknown -- use brute: walk past start, check $034F+slot

local function R(o) return memory.read_u8(o, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

-- Boot through title
idle(120); tap("Start"); idle(30); tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)

local f = io.open("C:/tmp/find_moblin_room.txt", "w")
f:write("NES OW Moblin scan\n")

-- Wait for room to populate
idle(60)
local start_room = R(0x00EB)
f:write(string.format("start room=$%02X\n", start_room))

-- Scan many rooms by walking. Actually simpler: dump the LevelInfo tables.
-- LevelInfo for OW lives in bank 5 ROM, but we can scan all $034F entries
-- as we navigate.

-- Just look at current room enemies
for s=1,11 do
  local t = R(0x034F+s)
  if t == 0x03 or t == 0x04 then
    f:write(string.format("FOUND moblin type=$%02X slot=%d in room $%02X\n", t, s, R(0x00EB)))
  end
end

-- Walk in all 4 directions, log enemies seen
local dirs = {"Up","Down","Left","Right"}
for d=1,40 do
  joypad.set({[dirs[(d%4)+1]]=true},1)
  for _=1,30 do emu.frameadvance() end
  joypad.set({},1)
  local room = R(0x00EB)
  for s=1,11 do
    local t = R(0x034F+s)
    if t == 0x03 or t == 0x04 then
      f:write(string.format("FOUND moblin type=$%02X slot=%d in room $%02X\n", t, s, room))
    end
  end
end

f:write("scan done\n")
f:close()
client.exit()

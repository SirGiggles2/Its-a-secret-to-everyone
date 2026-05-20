-- Genesis room $66 spawn capture, 120 frames.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

idle(60)
-- Enter Debug.md gameplay via A+B+C chord
for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1); idle(60)
-- Press X to toggle MODE_TELEPORT
joypad.set({X=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance()
idle(15)
-- Navigate grid: walk D-pad to reach $66 (row 6 col 6).
-- Need to know starting room. Read $7205, calc deltas.
local cur = R(0x80EB)
local tgt_row = 0x66 >> 4   -- 6
local tgt_col = 0x66 & 0x0F -- 6
local function tap_dir(d)
  joypad.set({[d]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance()
  idle(8)
end
for _=1,32 do
  cur = R(0x80EB)
  if cur == 0x66 then break end
  local cur_row = cur >> 4
  local cur_col = cur & 0x0F
  if cur_col < tgt_col then tap_dir("Right")
  elseif cur_col > tgt_col then tap_dir("Left")
  elseif cur_row < tgt_row then tap_dir("Down")
  elseif cur_row > tgt_row then tap_dir("Up")
  else break end
end
idle(8)

local f = io.open("C:/tmp/spawn_66_gen.txt", "w")
f:write(string.format("=== Genesis room $66 spawn (RoomId=$%02X) ===\n", R(0x80EB)))
for s=1,11 do
  local t = R(0x834F+s)
  if t ~= 0 then
    f:write(string.format("slot %2d: type=$%02X X=$%02X Y=$%02X dir=$%02X qspd=$%02X\n",
      s, t, R(0x8070+s), R(0x8084+s), R(0x8098+s), R(0x83BC+s)))
  end
end
f:write(string.format("LinkX=$%02X LinkY=$%02X LinkDir=$%02X\n", R(0x8070), R(0x8084), R(0x8098)))
f:write(string.format("FoeCounts[0..3] = $%02X $%02X $%02X $%02X\n", R(0xEBA2), R(0xEBA3), R(0xEBA4), R(0xEBA5)))
f:write(string.format("LBA_C[$66]=$%02X LBA_D[$66]=$%02X\n", R(0xE9E4), R(0xEA64)))
f:write(string.format("ObjectFirstUnwalkableTile=$%02X\n", R(0x834A)))

client.screenshot("C:/tmp/spawn_66_gen.png")
f:close()
client.exit()

-- gen_spawn_67.lua — capture Genesis spawn positions immediately after
-- entering room $67. Logs each enemy slot type/X/Y/dir at the moment
-- enemy_loop_room_init completes. Compare against NES truth:
--   slot 1: X=$60 Y=$5D dir=$01
--   slot 2: X=$10 Y=$95 dir=$08
--   slot 3: X=$60 Y=$5D dir=$01
--   slot 4: X=$80 Y=$7D dir=$08
local R = function(o) return memory.read_u8(o, "68K RAM") end
local W = function(o,v) memory.write_u8(o, v, "68K RAM") end
local idle = function(n) for _=1,n do emu.frameadvance() end end

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)
for i=1,400 do joypad.set({Up=true},1); emu.frameadvance(); if R(0x7205) == 0x67 then break end end
joypad.set({},1)
-- Capture ON the frame slots first populate (no idle), then again @+1f for compare
local function dump_label(label, fh)
  fh:write(string.format("\n--- %s ---\n", label))
  for s=1,11 do
    local t = R(0x834F + s)
    if t ~= 0 then
      fh:write(string.format("  slot %2d: type=$%02X X=$%02X Y=$%02X dir=$%02X spd=$%02X\n",
        s, t, R(0x8070+s), R(0x8084+s), R(0x8098+s), R(0x83BC+s)))
    end
  end
end
-- Wait until slot 1 type becomes non-zero (spawn done this frame)
for _=1,60 do if R(0x8350) ~= 0 then break end; emu.frameadvance() end

local f = io.open("C:/tmp/gen_spawn_67.txt", "w")
f:write("=== Genesis room $67 spawn positions ===\n")
dump_label("f0 (slots first populated)", f)
emu.frameadvance()
dump_label("f1", f)
emu.frameadvance()
dump_label("f2", f)
for _=1,5 do emu.frameadvance() end
dump_label("f8", f)

-- Also dump key spawn-algo input state
f:write("\n=== Spawn-algo state ===\n")
f:write(string.format("RoomId         ($7205) = $%02X\n", R(0x7205)))
f:write(string.format("CurLevel       ($7252) = $%02X\n", R(0x7252)))
f:write(string.format("LinkObjDir     ($8098) = $%02X\n", R(0x8098)))
f:write(string.format("nes_ram[$000F] (scratch)= $%02X\n", R(0x800F)))
f:write(string.format("ObjectFirstUnwalkableTile ($834A) = $%02X\n", R(0x834A)))
f:write(string.format("DungeonSpawnCycle ($8524) = $%02X\n", R(0x8524)))
f:write(string.format("FoeCounts[0..3] ($EBA2..) = $%02X $%02X $%02X $%02X\n",
  R(0xEBA2), R(0xEBA3), R(0xEBA4), R(0xEBA5)))
f:write(string.format("LBA_C[$67] ($E9E5) = $%02X\n", R(0xE9E5)))
f:write(string.format("LBA_D[$67] ($EA65) = $%02X\n", R(0xEA65)))

f:close()
client.screenshot("C:/tmp/gen_spawn_67.png")
client.exit()

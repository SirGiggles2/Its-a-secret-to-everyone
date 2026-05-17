-- octorok_audit.lua — diagnose octorok bugs: spawn placement, movement,
-- shot sprite. Compare against NES Z1 expected behavior.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\octorok_audit.txt"
local f = io.open(OUT, "w")

local OBJTYPE  = 0x834F
local OBJALIVE = 0x8492
local OBJX     = 0x8070
local OBJY     = 0x8084
local OBJDIR   = 0x8098
local OBJSPEED = 0x83CB  -- ENEMY_WALK_SPEED $03CB+slot
local OBJSTATE = 0x80AC  -- ObjState $00AC+slot
local ROOM     = 0x7205

-- Boot + chord
idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)

f:write(string.format("Room: $%02X  Link X=$%02X Y=$%02X\n",
  R(ROOM), R(0x8070), R(0x8084)))

-- Snapshot all 12 slots
local function dump_slots(label)
  f:write(string.format("\n=== %s ===\n", label))
  for s=0,11 do
    local t = R(OBJTYPE + s)
    if t ~= 0 then
      f:write(string.format("  slot %2d: type=$%02X alive=$%02X X=$%02X Y=$%02X dir=$%02X spd=$%02X state=$%02X\n",
        s, t, R(OBJALIVE+s), R(OBJX+s), R(OBJY+s), R(OBJDIR+s),
        R(OBJSPEED+s), R(OBJSTATE+s)))
    end
  end
end

dump_slots("Initial spawn (post-chord)")

-- Wait 60 frames, dump again to see movement
idle(60)
dump_slots("After 60 frames (movement check)")

idle(60)
dump_slots("After 120 frames")

-- Find any active shot (type $53)
f:write("\nProjectile dump (type $53):\n")
for s=1,11 do
  local t = R(OBJTYPE + s)
  if t == 0x53 then
    f:write(string.format("  slot %d: X=$%02X Y=$%02X dir=$%02X state=$%02X\n",
      s, R(OBJX+s), R(OBJY+s), R(OBJDIR+s), R(OBJSTATE+s)))
  end
end

-- NES Z1 expected at room $77 boot: 3 RedOctorocks. Let me check OW $77
-- LevelBlockAttrs C/D to see what the spawn template SHOULD be.
f:write("\nLBA cells for room $77 (NES drain expected):\n")
-- LBA tables: data/dungeons.c per NES Z1 OW LevelBlockAttrs.
-- Quick read: where does DUNGEON_LBA_C live?

-- DungeonRoomObjCount in nes_ram. Actual address depends on define.
-- Cells $0349 = RoomObjCount per Z1 docs.
f:write(string.format("  RoomObjCount ($0349) = %d\n", R(0x8349)))
f:write(string.format("  RoomTemplateType ($034A) = $%02X\n", R(0x834A)))

client.screenshot("C:\\tmp\\octorok_audit.png")
idle(10)
client.exit()

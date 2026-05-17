-- octorok_visual.lua — walk to room with octoroks, screenshot, dump slot state.
-- Sample every 60f to track movement.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\octorok_visual.txt"
local f = io.open(OUT, "w")

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)

-- Walk up to scroll into room $67
for i=1,200 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(60)
client.screenshot("C:\\tmp\\octorok_visual_room67.png")

local function dump(label)
  f:write(string.format("\n=== %s ===\n", label))
  f:write(string.format("Link X=$%02X Y=$%02X  Room=$%02X\n",
    R(0x8070), R(0x8084), R(0x7205)))
  for s=0,11 do
    local t = R(0x834F + s)
    if t ~= 0 then
      -- ENEMY_WALK_SPEED at $03BC+slot, ObjState $00AC+slot,
      -- ObjTimer $0028+slot, ObjStunTimer $003D+slot, ObjAnimCntr $0364+slot
      f:write(string.format("  slot %2d: type=$%02X X=$%02X Y=$%02X dir=$%02X spd=$%02X state=$%02X mvt=$%02X stunt=$%02X\n",
        s, t, R(0x8070+s), R(0x8084+s), R(0x8098+s),
        R(0x83BC+s), R(0x80AC+s), R(0x8028+s), R(0x803D+s)))
    end
  end
end

dump("Just scrolled into $67")

-- Wait 60f, dump movement state again
idle(60)
dump("After 60f")

idle(60)
dump("After 120f")

-- NES LBA values for room $67 (from install_ow blob)
-- LBA_C at $697E+$67=$69E5, LBA_D at $69FE+$67=$6A65
-- 68K RAM domain: $9E5, $A65 + $8000 = $E9E5, $EA65
f:write("\nLBA cells for room $67:\n")
f:write(string.format("  LBA_C ($697E+$67=$69E5) = $%02X\n", R(0xE9E5)))
f:write(string.format("  LBA_D ($69FE+$67=$6A65) = $%02X\n", R(0xEA65)))
f:write("FoeCounts ($6BA2..$6BA5):\n")
for i=0,3 do
  f:write(string.format("  foe[%d] = %d\n", i, R(0xEBA2 + i)))
end

idle(10)
client.exit()

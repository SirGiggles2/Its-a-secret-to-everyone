-- nes_octorok_baseline.lua — NES Z1: navigate to OW $67, dump octorok
-- spawn + AI state across 60 frames. Output for Genesis-side byte-diff.
local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/octorok_baseline_nes.txt"

local function press(b, n)
  for _=1,n do joypad.set(b, 1); emu.frameadvance() end
  joypad.set({}, 1); emu.frameadvance()
end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function R(addr) return memory.read_u8(addr, "RAM") end

-- Boot
idle(240)
-- Title -> FS
press({Start=true}, 8); idle(120)
-- FS slot 1 register name -> A then Start
press({A=true}, 4); idle(40)
press({Start=true}, 4); idle(120)
-- In cave $80; walk south to exit
press({Down=true}, 200); idle(60)
-- Now on OW $77; walk north to $67
press({Up=true}, 200); idle(120)

-- Confirm room
local room = R(0x00EB)
print(string.format("NES room id $%02X (expected $67 or $77)", room))

local f = io.open(OUT, "w")
f:write(string.format("NES OCTOROK BASELINE — room $%02X\n", room))
f:write("Link pos: X=$" .. string.format("%02X", R(0x0070)) ..
        " Y=$" .. string.format("%02X", R(0x0028)) .. "\n")
-- NES LevelBlockAttrsByteF $4CD — current-room flags (bit3 = edge spawn)
local lba_f = R(0x04CD)
f:write(string.format("LevelBlockAttrsByteF $04CD = $%02X (bit3 edge-spawn = %s)\n",
  lba_f, (lba_f % 16 >= 8) and "SET" or "CLEAR"))
f:write("\n")

-- Per-slot RAM addresses (NES Z1 per reference/aldonunez/Variables.inc):
--   ObjTimer       $0028 + slot
--   ObjX           $0070 + slot
--   ObjY           $0084 + slot
--   ObjDir         $0098 + slot
--   ObjState       $00AC + slot
--   ObjType        $034F + slot
--   ObjQSpeedFrac  $03BC + slot
--   ObjAnimFrame   $03E4 + slot

local function dump_frame(label, fr)
  f:write(string.format("\n--- %s (frame %d post-room-enter) ---\n", label, fr))
  f:write("slot | type | X    | Y    | dir | state | timer | qspd | aFr\n")
  for slot = 0, 11 do
    local t   = R(0x034F + slot)
    local x   = R(0x0070 + slot)
    local y   = R(0x0084 + slot)
    local d   = R(0x0098 + slot)
    local s   = R(0x00AC + slot)
    local tm  = R(0x0028 + slot)
    local q   = R(0x03BC + slot)
    local af  = R(0x03E4 + slot)
    f:write(string.format("  %2d |  $%02X |  $%02X |  $%02X | $%02X |  $%02X  | $%02X | $%02X | $%02X\n",
      slot, t, x, y, d, s, tm, q, af))
  end
end

dump_frame("frame_0", 0)

-- Advance frame counter snapshots
for i = 1, 6 do
  idle(10)
  dump_frame("frame_" .. (i*10), i*10)
end

-- Also dump Random table at $0019 (used for shoot RNG)
f:write("\n\nRandom table $0010..$001F:\n")
for i = 0x10, 0x1F do
  f:write(string.format("  $%02X = $%02X\n", i, R(i)))
end

f:close()
client.screenshot((os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/octorok_baseline_nes.png")
print("wrote " .. OUT)
client.exit()

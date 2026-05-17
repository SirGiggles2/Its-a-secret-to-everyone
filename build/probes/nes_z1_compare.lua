-- nes_z1_compare.lua — drive real NES Z1, dump live OAM + PALRAM + CHR
-- for direct visual comparison vs Genesis port. Uses brute file-select
-- sequence. Output to C:\tmp\nes_z1_*

local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

-- 1. Boot through title sequence
idle(120)   -- logo + scroll
tap("Start"); idle(30)   -- past title
tap("Start"); idle(60)   -- to file select

-- 2. File select. NES Z1 cursor starts at slot 1. If slot empty,
-- registering name needed. Try: register name → enter empty → start.
-- Sequence: Down to Register Your Name, Start, on register screen
-- press Down a few times to reach End, Start to accept.
tap("Down")               -- cursor to slot 2
tap("Down")               -- slot 3
tap("Down")               -- Register Your Name
tap("Start")              -- enter register screen
idle(60)

-- On register: cursor on letter grid. Press Down lots to reach End,
-- then Start.
for _=1,8 do tap("Down") end
tap("Start")              -- finish registering
idle(60)

-- Back at file select. Cursor near bottom. Go up to slot 1.
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up")
idle(30)
tap("Start")              -- begin game on slot 1
idle(120)

-- 3. Should now be in game. Capture initial screenshot.
client.screenshot("C:\\tmp\\nes_z1_boot.png")

-- 4. Walk up to reach octorok room. NES Link spawns at room $77 facing
-- up. Hold Up to scroll into room $67.
for _=1,300 do joypad.set({Up=true},1); emu.frameadvance() end
idle(60)
client.screenshot("C:\\tmp\\nes_z1_octorok_room.png")

-- 5. Dump live data.
local f = io.open("C:\\tmp\\nes_z1_dump.txt", "w")

-- NES PPU OAM is at $0200-$02FF (RAM mirror). Read all 64 sprites.
f:write("=== NES OAM (64 sprites × 4 bytes) ===\n")
for s=0,63 do
  local off = 0x0200 + s*4
  local y = memory.read_u8(off, "RAM")
  local tile = memory.read_u8(off+1, "RAM")
  local attr = memory.read_u8(off+2, "RAM")
  local x = memory.read_u8(off+3, "RAM")
  if not (y == 0 and tile == 0 and attr == 0 and x == 0) then
    f:write(string.format("  slot %2d: Y=$%02X tile=$%02X attr=$%02X X=$%02X (subpal=%d hflip=%d vflip=%d)\n",
      s, y, tile, attr, x, attr & 3, (attr>>6)&1, (attr>>7)&1))
  end
end

-- PALRAM at $3F00-$3F1F (need PPU memory access)
f:write("\n=== NES PALRAM ===\n")
local has_ppu = false
for _, d in ipairs(memory.getmemorydomainlist()) do
  if d == "PPU Bus" then has_ppu = true; break end
end
if has_ppu then
  f:write("BG palette ($3F00-$3F0F):\n  ")
  for i=0,15 do f:write(string.format("$%02X ", memory.read_u8(0x3F00+i, "PPU Bus"))) end
  f:write("\nSPR palette ($3F10-$3F1F):\n  ")
  for i=0,15 do f:write(string.format("$%02X ", memory.read_u8(0x3F10+i, "PPU Bus"))) end
  f:write("\n")
else
  f:write("PPU Bus domain not available; trying memory.readbyterange via $3F00\n")
end

-- Enemy positions/states (NES Variables.inc: ObjX $0070, ObjY $0084,
-- ObjType $034F, ObjState $00AC, ObjAnimFrame $03B0)
f:write("\n=== NES enemy slots ===\n")
for s=0,11 do
  local t = memory.read_u8(0x034F+s, "RAM")
  if t ~= 0 then
    local x = memory.read_u8(0x0070+s, "RAM")
    local y = memory.read_u8(0x0084+s, "RAM")
    local dir = memory.read_u8(0x0098+s, "RAM")
    local state = memory.read_u8(0x00AC+s, "RAM")
    local qspd = memory.read_u8(0x03BC+s, "RAM")
    local mvt = memory.read_u8(0x0028+s, "RAM")
    local frame = memory.read_u8(0x03B0+s, "RAM")
    f:write(string.format("  slot %2d: type=$%02X X=$%02X Y=$%02X dir=$%02X state=$%02X qspd=$%02X mvt=$%02X anim=$%02X\n",
      s, t, x, y, dir, state, qspd, mvt, frame))
  end
end

f:write(string.format("\nLink: X=$%02X Y=$%02X dir=$%02X Room=$%02X\n",
  memory.read_u8(0x0070, "RAM"), memory.read_u8(0x0084, "RAM"),
  memory.read_u8(0x0098, "RAM"), memory.read_u8(0x00EB, "RAM")))

f:close()
idle(15)
client.exit()

-- nes_palram_cloud.lua — capture NES PALRAM at room $67 during spawn
-- cloud. Dumps SPR palette ($3F10-$3F1F) so we know NES sub-pal 1
-- colors used for cloud rendering.

local function R(o) return memory.read_u8(o, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

idle(120)
tap("Start"); idle(30)
tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)

-- Walk up to room $67
for fr=1,400 do
  joypad.set({Up=true},1)
  emu.frameadvance()
  if R(0x00EB) == 0x67 then break end
end
joypad.set({},1)

-- Wait until cloud shows at frame ~100
idle(102)
client.screenshot("C:\\tmp\\nes_cloud_visible.png")

local f = io.open("C:\\tmp\\nes_palram_cloud.txt", "w")
f:write("=== NES PALRAM at room $67 cloud-visible moment ===\n")

-- PPU Bus access for PALRAM ($3F00-$3F1F)
local has_ppu = false
for _, d in ipairs(memory.getmemorydomainlist()) do
  if d == "PPU Bus" then has_ppu = true; break end
end
if has_ppu then
  f:write("BG palette ($3F00-$3F0F):\n  ")
  for i=0,15 do f:write(string.format("$%02X ", memory.read_u8(0x3F00+i, "PPU Bus"))) end
  f:write("\nSPR palette ($3F10-$3F1F):\n  ")
  for i=0,15 do f:write(string.format("$%02X ", memory.read_u8(0x3F10+i, "PPU Bus"))) end
  f:write("\n\nSub-pals:\n")
  for sp=0,3 do
    local base = 0x3F10 + sp*4
    f:write(string.format("  sub-pal %d ($%04X): $%02X $%02X $%02X $%02X\n",
      sp, base,
      memory.read_u8(base+0, "PPU Bus"),
      memory.read_u8(base+1, "PPU Bus"),
      memory.read_u8(base+2, "PPU Bus"),
      memory.read_u8(base+3, "PPU Bus")))
  end
else
  f:write("PPU Bus not available\n")
end

-- Dump OAM for cloud sprites (look at attr byte to know which sub-pal)
f:write("\n=== Cloud OAM entries (tile $34/$70/$72/$74) ===\n")
for o=0,63 do
  local off = 0x0200 + o*4
  local y = R(off)
  local t = R(off+1)
  local a = R(off+2)
  local x = R(off+3)
  if t == 0x34 or t == 0x70 or t == 0x72 or t == 0x74 then
    f:write(string.format("  oam %2d: Y=$%02X tile=$%02X attr=$%02X X=$%02X (sub-pal=%d)\n",
      o, y, t, a, x, a & 0x03))
  end
end

f:close()
client.exit()

-- scene_walk_nes_reference.lua — NES Z1 reference capture matching
-- scene_walk_full.lua scene labels. Output per scene to
-- $CODEX_BIZHAWK_ROOT/scene_walk_nes/<label>/:
--   {label}.png, {label}_state.txt, {label}_palram.bin (32 B),
--   {label}_oam.bin (256 B), {label}_nt.bin (4096 B nametable+attribute),
--   {label}_chr.bin (8192 B pattern table $0000-$1FFF), {label}_ram.bin (2 KB)

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp"
local ROOT = OUT .. "/scene_walk_nes"
os.execute('mkdir "' .. ROOT:gsub("/","\\") .. '" 2>nul')

local function R(off) return memory.read_u8(off, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, n)
  for _=1,n do joypad.set(b, 1); emu.frameadvance() end
  joypad.set({}, 1); emu.frameadvance()
end

local function dump_domain(domain, base, size, path)
  local chunks = {}
  for i = 0, size-1 do chunks[#chunks+1] = string.char(memory.read_u8(base + i, domain)) end
  local f = io.open(path, "wb"); f:write(table.concat(chunks)); f:close()
end

local function write_state_txt(path, label)
  local f = io.open(path, "w")
  f:write("=== " .. label .. " ===\n")
  f:write(string.format("frame=%d\n", emu.framecount()))
  f:write(string.format("GameMode=$%02X Submode=$%02X CurRoom=$%02X Scene=$%02X Level=$%02X\n",
      R(0x0012), R(0x0013), R(0x00EB), R(0x00FB), R(0x010A)))
  f:write(string.format("Link X=$%02X Y=$%02X Face=$%02X State=$%02X\n",
      R(0x0070), R(0x0084), R(0x0098), R(0x00AC)))
  f:write(string.format("Hearts=$%02X partial=$%02X Containers=$%02X Rupees=$%02X\n",
      R(0x066F), R(0x0670), R(0x066E), R(0x066D)))
  f:write("\n--- PALRAM (32 B, BG 16 + SPR 16) ---\n")
  f:write("BG :")
  for i = 0, 15 do f:write(string.format(" %02X", memory.read_u8(0x3F00 + i, "PPU Bus"))) end
  f:write("\nSPR:")
  for i = 0, 15 do f:write(string.format(" %02X", memory.read_u8(0x3F10 + i, "PPU Bus"))) end
  f:write("\n\n--- OAM slot 0..15 ---\n")
  for s = 0, 15 do
    local b = s*4
    f:write(string.format("  s%02d Y=%02X tile=%02X attr=%02X X=%02X\n",
        s,
        memory.read_u8(b+0, "OAM"),
        memory.read_u8(b+1, "OAM"),
        memory.read_u8(b+2, "OAM"),
        memory.read_u8(b+3, "OAM")))
  end
  f:close()
end

local function capture(label)
  local dir = ROOT .. "/" .. label
  os.execute('mkdir "' .. dir:gsub("/","\\") .. '" 2>nul')
  client.screenshot(dir .. "/" .. label .. ".png")
  write_state_txt(dir .. "/" .. label .. "_state.txt", label)
  dump_domain("OAM",     0x0000, 256,   dir .. "/" .. label .. "_oam.bin")
  -- PALRAM via PPU Bus $3F00-$3F1F (mirror at $3F20+ has same)
  do
    local chunks = {}
    for i = 0, 31 do chunks[#chunks+1] = string.char(memory.read_u8(0x3F00 + i, "PPU Bus")) end
    local f = io.open(dir .. "/" .. label .. "_palram.bin", "wb"); f:write(table.concat(chunks)); f:close()
  end
  -- Nametables $2000-$2FFF (4 KB = 2 nametables + attribute tables)
  dump_domain("PPU Bus", 0x2000, 4096,  dir .. "/" .. label .. "_nt.bin")
  -- Pattern tables $0000-$1FFF (8 KB)
  dump_domain("PPU Bus", 0x0000, 8192,  dir .. "/" .. label .. "_chr.bin")
  -- 2 KB main RAM
  dump_domain("RAM",     0x0000, 2048,  dir .. "/" .. label .. "_ram.bin")
  print(string.format("captured %-36s frame=%d gamemode=$%02X room=$%02X",
      label, emu.framecount(), R(0x0012), R(0x00EB)))
end

-- ============================================================
-- Scene-walk sequence — NES Z1 (no second-chord harness on NES)
-- ============================================================

-- 01: title — boot wait through copyright + title screen
idle(180)
capture("01_title")

-- 02: post_start — Start past title to FS
press({Start=true}, 8); idle(120)
capture("02_post_chord")  -- label match for diff

-- 03: settle — at FS cursor (or already gameplay if Start skipped FS)
idle(180)
capture("03_post_chord_settle")

-- 04: walk_down — A on file slot 1 then Start enters gameplay; if already
-- past FS, Down on OW moves Link south
press({A=true}, 4); idle(30)
press({Start=true}, 4); idle(120)
press({Down=true}, 200); idle(60)
capture("04_walk_down")

-- 05: walk_left
press({Left=true}, 200); idle(60)
capture("05_walk_left")

-- 06: walk_up
press({Up=true}, 200); idle(60)
capture("06_walk_up")

-- 07: walk_right
press({Right=true}, 200); idle(60)
capture("07_walk_right")

-- 08: walk_north_far
press({Up=true}, 400); idle(80)
capture("08_walk_north_far")

-- 09: inventory_open — Start mid-gameplay
press({Start=true}, 4); idle(120)
capture("09_inventory_open")

-- 10: inventory_cycle
press({Right=true}, 6); idle(30)
press({A=true}, 4); idle(60)
capture("10_inventory_cycle")

-- 11: inventory_close
press({Start=true}, 4); idle(120)
capture("11_inventory_close")

-- 12: sword_swing — B for sword
press({B=true}, 8); idle(60)
capture("12_sword_swing")

-- 13: extended_walk
press({Down=true}, 300); idle(60)
press({Right=true}, 300); idle(60)
capture("13_extended_walk")

-- 14: stress_harness — no harness on NES; capture current state for diff
-- (NES has no debug stress harness; this captures equivalent frame budget
-- so the diff column at this label simply documents the divergence)
idle(180)
capture("14_stress_harness")

-- 15: stress_harness_settle
idle(600)
capture("15_stress_harness_settle")

gui.text(8, 8, "scene_walk_nes done")
idle(30)
print("scene_walk_nes_reference: done")
client.exit()

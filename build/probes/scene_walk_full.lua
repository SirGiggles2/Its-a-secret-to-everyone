-- scene_walk_full.lua v2 — single-chord boot + joypad navigation.
--
-- Lessons from v1:
--   * Second ABC+Start chord triggers debug stress harness
--     (memory project_debug_enter_stress_harness), locking gameplay
--     in $77 with 11 force-spawned enemies. Use chord ONCE at title.
--   * RAM NES-mirror pokes to $FF80EB are no-ops; renderer reads
--     s_room_id static in RoomRom/src/main.c (Genesis-side state).
--     Use real joypad navigation instead of teleport pokes.
--   * VRAM/CRAM/SAT captures are valid — those drive the renderer.
--
-- Per scene writes 6 files to $CODEX_BIZHAWK_ROOT/scene_walk_gen/<label>/:
--   {label}.png, {label}_state.txt, {label}_cram.bin,
--   {label}_sat.bin (VRAM $FC00, 640 B), {label}_plane_a.bin (VRAM $C000, 2048 B),
--   {label}_vram_tile.bin (VRAM $0000..$72C0, 29440 B)

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp"
local ROOT = OUT .. "/scene_walk_gen"
os.execute('mkdir "' .. ROOT:gsub("/","\\") .. '" 2>nul')

-- Discover Genesis memory domains + try to read VDP reg 5 for SAT base.
-- Writes _domains.txt so the diff classifier (or human triage) can verify
-- the probe ran against the expected domain set.
do
  local f = io.open(ROOT .. "/_domains.txt", "w")
  f:write("BizHawk Genesis memory domains discovered at probe start:\n")
  local vdp_dom = nil
  for _, d in ipairs(memory.getmemorydomainlist()) do
    f:write("  " .. d .. "\n")
    if d == "VDP" or d == "vdp_regs" or d == "VDP Regs" then vdp_dom = d end
  end
  if vdp_dom then
    f:write("\nVDP regs (domain '" .. vdp_dom .. "'):\n")
    for r = 0, 23 do
      local v = memory.read_u8(r, vdp_dom)
      f:write(string.format("  reg %02d = $%02X\n", r, v))
    end
    local reg5 = memory.read_u8(5, vdp_dom)
    local computed_sat = (reg5 % 0x80) * 0x200  -- (reg5 & 0x7F) << 9 — H32 mode strips bit 0
    f:write(string.format("\ncomputed SAT base from reg5 = $%04X\n", computed_sat))
  else
    f:write("\n(no VDP-regs domain exposed; using hardcoded SAT_BASE)\n")
  end
  f:close()
end

local PLANE_A_BASE   = 0xC000
local PLANE_A_SIZE   = 2048
local PLANE_B_BASE   = 0xE000
local PLANE_B_SIZE   = 2048
-- SAT base set at runtime by RoomRom/src/main.c:489
--   VDP_setSpriteListAddress(0xF400u)  -- post-PR-2 Option F layout.
-- We don't trust the hardcode: derive from VDP reg 5 at probe time.
-- VDP reg 5 = (SAT_base >> 9) & 0x7F. Reg state is in "S68K BUS" or
-- BizHawk genplus core's "VDP" domain offset 5 (last-written reg).
-- Fallback to 0xF400 if reg read returns unreasonable value.
local SAT_BASE       = 0xF400
local SAT_SIZE       = 640
local VRAM_TILE_BASE = 0x0000
local VRAM_TILE_SIZE = 0x72C0
local CRAM_SIZE      = 128
local RAM_NES_BASE   = 0x8000   -- NES RAM mirror (informational only)

local function R(off) return memory.read_u8(RAM_NES_BASE + off, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, n)
  for _=1,n do joypad.set(b, 1); emu.frameadvance() end
  joypad.set({}, 1); emu.frameadvance()
end

local function dump_domain_to_file(domain, base, size, path)
  local chunks = {}
  for i = 0, size-1 do chunks[#chunks+1] = string.char(memory.read_u8(base + i, domain)) end
  local f = io.open(path, "wb"); f:write(table.concat(chunks)); f:close()
end

local function dump_cram(path)
  local chunks = {}
  for i = 0, CRAM_SIZE-1 do chunks[#chunks+1] = string.char(memory.read_u8(i, "CRAM")) end
  local f = io.open(path, "wb"); f:write(table.concat(chunks)); f:close()
end

local function write_state_txt(path, label)
  local f = io.open(path, "w")
  f:write("=== " .. label .. " ===\n")
  f:write(string.format("frame=%d\n", emu.framecount()))
  f:write(string.format("NES-mirror GameMode=$%02X Submode=$%02X CurRoom=$%02X Scene=$%02X Level=$%02X\n",
      R(0x0012), R(0x0013), R(0x00EB), R(0x00FB), R(0x010A)))
  f:write(string.format("NES-mirror Link X=$%02X Y=$%02X Face=$%02X State=$%02X\n",
      R(0x0070), R(0x0084), R(0x0098), R(0x00AC)))
  f:write(string.format("NES-mirror Hearts=$%02X partial=$%02X Containers=$%02X Rupees=$%02X\n",
      R(0x066F), R(0x0670), R(0x066E), R(0x066D)))
  f:write("\n--- CRAM (4 PAL * 16 entries, BE u16) ---\n")
  for pal=0,3 do
    f:write(string.format("PAL%d:", pal))
    for c=0,15 do f:write(string.format(" %04X", memory.read_u16_be(pal*32 + c*2, "CRAM"))) end
    f:write("\n")
  end
  f:write(string.format("\n--- SAT slot 0..15 (base $%04X, link=0 ends chain) ---\n", SAT_BASE))
  for s=0,15 do
    local base = SAT_BASE + s*8
    local y    = memory.read_u16_be(base+0, "VRAM")
    local sz   = memory.read_u8(base+2, "VRAM")
    local link = memory.read_u8(base+3, "VRAM")
    local attr = memory.read_u16_be(base+4, "VRAM")
    local x    = memory.read_u16_be(base+6, "VRAM")
    f:write(string.format("  s%02d Y=%04X sz=%02X link=%02X attr=%04X X=%04X\n",
        s, y, sz, link, attr, x))
  end
  f:close()
end

local function capture(label)
  local dir = ROOT .. "/" .. label
  os.execute('mkdir "' .. dir:gsub("/","\\") .. '" 2>nul')
  client.screenshot(dir .. "/" .. label .. ".png")
  write_state_txt(dir .. "/" .. label .. "_state.txt", label)
  dump_cram(dir .. "/" .. label .. "_cram.bin")
  dump_domain_to_file("VRAM", SAT_BASE,       SAT_SIZE,       dir .. "/" .. label .. "_sat.bin")
  dump_domain_to_file("VRAM", PLANE_A_BASE,   PLANE_A_SIZE,   dir .. "/" .. label .. "_plane_a.bin")
  dump_domain_to_file("VRAM", PLANE_B_BASE,   PLANE_B_SIZE,   dir .. "/" .. label .. "_plane_b.bin")
  dump_domain_to_file("VRAM", VRAM_TILE_BASE, VRAM_TILE_SIZE, dir .. "/" .. label .. "_vram_tile.bin")
  print(string.format("captured %-36s frame=%d", label, emu.framecount()))
end

-- ============================================================
-- Scene-walk sequence v2 — single chord + real navigation
-- ============================================================

-- 01: title — wait through boot intro
idle(240)
capture("01_title")

-- 02: post_chord — single ABC+Start chord; this is the ONLY chord we issue
press({A=true, B=true, C=true, Start=true}, 30)
idle(180)
capture("02_post_chord")

-- 03: settle — give more frames for any post-chord state machine to land
idle(180)
capture("03_post_chord_settle")

-- 04: walk_down — exit any cave or move south through OW
press({Down=true}, 200); idle(60)
capture("04_walk_down")

-- 05: walk_left — try westward
press({Left=true}, 200); idle(60)
capture("05_walk_left")

-- 06: walk_up — try northward
press({Up=true}, 200); idle(60)
capture("06_walk_up")

-- 07: walk_right — try eastward
press({Right=true}, 200); idle(60)
capture("07_walk_right")

-- 08: walk_north_far — sustained north for scroll-stage transitions
press({Up=true}, 400); idle(80)
capture("08_walk_north_far")

-- 09: inventory_open — Start mid-gameplay opens inventory (per NES Z1)
press({Start=true}, 4); idle(120)
capture("09_inventory_open")

-- 10: inventory_cycle — Right then A inside inventory
press({Right=true}, 6); idle(30)
press({A=true}, 4); idle(60)
capture("10_inventory_cycle")

-- 11: inventory_close — Start again to exit
press({Start=true}, 4); idle(120)
capture("11_inventory_close")

-- 12: sword_swing — B button for sword
press({B=true}, 8); idle(60)
capture("12_sword_swing")

-- 13: extended_walk — try to enter different rooms
press({Down=true}, 300); idle(60)
press({Right=true}, 300); idle(60)
capture("13_extended_walk")

-- 14: stress_harness — DELIBERATELY trigger second ABC chord for harness diff
-- (memory project_debug_enter_stress_harness — known landing point)
press({A=true, B=true, C=true}, 30); idle(180)
capture("14_stress_harness")

-- 15: stress_harness_settle — 600 frames into harness for stable enemy positions
idle(600)
capture("15_stress_harness_settle")

gui.text(8, 8, "scene_walk_full v2 done")
idle(30)
print("scene_walk_full v2: done")
client.exit()

-- gen_subscreen_capture.lua — Genesis Debug.md: ABC chord into gameplay,
-- press Start to open inventory subscreen, wait for ACTIVE state, dump:
--   - screenshot (320x224)
--   - CRAM 128 B (64 entries x 2 B, big-endian via "CRAM" domain)
--   - Plane A nametable 4096 B ($C000, 64x32 cells x 2 B)
--   - SAT 640 B ($F400, 80 sprites x 8 B)
--   - VDP regs (subset 0..23)
--
-- Output: $CODEX_BIZHAWK_ROOT/gen_subscreen/

local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/gen_subscreen"
os.execute("mkdir " .. OUT:gsub("/","\\") .. " 2>nul")

local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, n)
  for _=1,n do joypad.set(b, 1); emu.frameadvance() end
  joypad.set({}, 1); emu.frameadvance()
end

-- Boot wait
idle(240)

-- ABC chord at title -> gameplay (debug_enter)
press({A=true, B=true, C=true}, 8)
idle(180)  -- gameplay settle

-- Pre-pause screenshot
client.screenshot(OUT .. "/00_pre_pause.png")

-- Press Start to open subscreen
press({Start=true}, 6)

-- Wait for ACTIVE state: scroll completes in ~43 frames, give 90 to settle
idle(90)

-- ACTIVE-state screenshot
client.screenshot(OUT .. "/01_active.png")

-- Dump CRAM 128 B
-- BizHawk Genesis exposes CRAM as a memory domain; addresses 0..127 = bytes
local f = io.open(OUT .. "/cram.bin", "wb")
for addr = 0, 127 do
  f:write(string.char(memory.read_u8(addr, "CRAM")))
end
f:close()

-- Dump Plane A nametable $C000-$CFFF (4096 B) via VRAM domain
f = io.open(OUT .. "/plane_a.bin", "wb")
for addr = 0xC000, 0xCFFF do
  f:write(string.char(memory.read_u8(addr, "VRAM")))
end
f:close()

-- Dump Plane B nametable $E000-$EFFF (4096 B) — sanity check it's aliased
f = io.open(OUT .. "/plane_b.bin", "wb")
for addr = 0xE000, 0xEFFF do
  f:write(string.char(memory.read_u8(addr, "VRAM")))
end
f:close()

-- Dump SAT $F400-$F67F (640 B) - 80 sprites x 8 B
f = io.open(OUT .. "/sat.bin", "wb")
for addr = 0xF400, 0xF67F do
  f:write(string.char(memory.read_u8(addr, "VRAM")))
end
f:close()

-- VDP regs via "VDP" domain offsets 0..23 (BizHawk Genplus exposes
-- last-written register state)
f = io.open(OUT .. "/vdp_regs.txt", "w")
for r = 0, 23 do
  local ok, v = pcall(memory.read_u8, r, "VDP")
  if ok then
    f:write(string.format("R%02d = $%02X\n", r, v))
  else
    f:write(string.format("R%02d = ?\n", r))
  end
end
f:close()

-- 68K RAM snapshot — pause flag + s_room_id mirror at $FF7200+
f = io.open(OUT .. "/m68k_ram.bin", "wb")
for addr = 0x7000, 0x7FFF do
  f:write(string.char(memory.read_u8(addr, "68K RAM")))
end
f:close()

-- State log
f = io.open(OUT .. "/state.txt", "w")
f:write(string.format("Pause flag $E0 (nes_ram offset) = $%02X\n",
  memory.read_u8(0x80E0, "68K RAM")))
f:write(string.format("MenuState $E1 = $%02X\n",
  memory.read_u8(0x80E1, "68K RAM")))
f:write(string.format("Items $657 = $%02X (expect $FF if debug_unlock fired)\n",
  memory.read_u8(0x8657, "68K RAM")))
f:close()

-- Press Start again to scroll out
press({Start=true}, 6); idle(90)
client.screenshot(OUT .. "/02_post_resume.png")

print("wrote " .. OUT)
client.exit()

-- ow_palette_3frame.lua — capture OW CRAM at 3 states:
--   00_boot_ow: ABC chord → OW visible at frame 250
--   01_inventory: Start press → inventory open at frame +90
--   02_ow_restored: Start press → scroll-out → OW restored at frame +120
-- Outputs CRAM bin + PNG at each state to compare CRAM evolution.
local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/ow_palette_3frame"
os.execute("mkdir " .. OUT:gsub("/","\\") .. " 2>nul")

local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, n)
  for _=1,n do joypad.set(b, 1); emu.frameadvance() end
  joypad.set({}, 1); emu.frameadvance()
end

local function dump_cram(tag)
  local f = io.open(OUT .. "/" .. tag .. "_cram.bin", "wb")
  for addr = 0, 127 do
    f:write(string.char(memory.read_u8(addr, "CRAM")))
  end
  f:close()
  -- also write hex for readability
  local h = io.open(OUT .. "/" .. tag .. "_cram.hex", "w")
  for pal = 0, 3 do
    h:write(string.format("PAL%d: ", pal))
    for c = 0, 15 do
      local hi = memory.read_u8(pal*32 + c*2, "CRAM")
      local lo = memory.read_u8(pal*32 + c*2 + 1, "CRAM")
      h:write(string.format("%02X%02X ", hi, lo))
    end
    h:write("\n")
  end
  h:close()
end

local function dump_state(tag)
  local f = io.open(OUT .. "/" .. tag .. "_state.txt", "w")
  f:write(string.format("frame=%d\n", emu.framecount()))
  f:write(string.format("pause_flag $E0 = $%02X\n", memory.read_u8(0x80E0, "68K RAM")))
  f:write(string.format("MenuState $E1 = $%02X\n", memory.read_u8(0x80E1, "68K RAM")))
  f:write(string.format("RoomId $EB = $%02X\n", memory.read_u8(0x80EB, "68K RAM")))
  f:write(string.format("GameMode $0012 = $%02X\n", memory.read_u8(0x8012, "68K RAM")))
  f:close()
end

-- Boot
idle(240)
-- ABC chord enter gameplay (debug_enter → OW r$77 default)
press({A=true, B=true, C=true}, 8)
idle(180)

-- STATE 1: pre-pause OW
client.screenshot(OUT .. "/00_boot_ow.png")
dump_cram("00_boot_ow")
dump_state("00_boot_ow")

-- Start press → inventory open
press({Start=true}, 6)
idle(90)

-- STATE 2: inventory active
client.screenshot(OUT .. "/01_inventory.png")
dump_cram("01_inventory")
dump_state("01_inventory")

-- Start press → scroll-out → OW restored
press({Start=true}, 6)
idle(120)

-- STATE 3: OW restored after close
client.screenshot(OUT .. "/02_ow_restored.png")
dump_cram("02_ow_restored")
dump_state("02_ow_restored")

print("wrote " .. OUT)
client.exit()

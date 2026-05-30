-- nes_r77_palram.lua — boot NES Z1, register name, start game,
-- arrive at OW r$77, dump $3F00..$3F1F PALRAM + screenshot.
local OUT = "C:\\tmp\\nes_r77_palram"
os.execute("mkdir " .. OUT .. " 2>nul")

local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn, hold, gap)
  hold = hold or 4
  gap = gap or 6
  for _=1,hold do joypad.set({[btn]=true}, 1); emu.frameadvance() end
  for _=1,gap do joypad.set({}, 1); emu.frameadvance() end
end

-- Boot through title to file select to game
idle(240)
tap("Start", 4, 30); idle(30)
tap("Start", 4, 30)
for _=1,3 do tap("Down", 4, 6) end
tap("Start", 4, 30); idle(60)
for _=1,6 do tap("Down", 4, 4) end
tap("Start", 4, 30); idle(60)
for _=1,4 do tap("Up", 4, 6) end
tap("Start", 4, 30); idle(60)
tap("Start", 4, 30); idle(180)  -- begin + arrive at OW r$77

-- Discover available memory domains
local f = io.open(OUT .. "/domains.txt", "w")
for _, d in ipairs(memory.getmemorydomainlist()) do
  f:write(d .. "\n")
end
f:close()

-- If inventory open (MenuState/PauseFlag at $E0 nonzero), close it
local pause = memory.read_u8(0xE0, "RAM")
if pause ~= 0 then
  tap("Start", 4, 30); idle(60)
end

-- Dump RAM state
f = io.open(OUT .. "/state.txt", "w")
f:write(string.format("frame=%d\n", emu.framecount()))
f:write(string.format("GameMode $12 = $%02X\n", memory.read_u8(0x12, "RAM")))
f:write(string.format("RoomId $EB = $%02X\n", memory.read_u8(0xEB, "RAM")))
f:write(string.format("Pause $E0 = $%02X (pre-close=$%02X)\n",
  memory.read_u8(0xE0, "RAM"), pause))
f:write(string.format("LevelInfo $0606..$0615:\n"))
for a = 0x0606, 0x0615 do
  f:write(string.format(" $%04X=$%02X\n", a, memory.read_u8(a, "RAM")))
end
f:close()

-- Dump PALRAM $3F00..$3F1F (32 bytes BG + SPR)
f = io.open(OUT .. "/palram.txt", "w")
f:write("BG PALRAM $3F00..$3F0F (4 sub-pals x 4 colors):\n")
for sp = 0, 3 do
  f:write(string.format(" subpal %d: ", sp))
  for c = 0, 3 do
    f:write(string.format("$%02X ", memory.read_u8(sp*4 + c, "PALRAM")))
  end
  f:write("\n")
end
f:write("SPR PALRAM $3F10..$3F1F (4 sub-pals x 4 colors):\n")
for sp = 0, 3 do
  f:write(string.format(" subpal %d: ", sp))
  for c = 0, 3 do
    f:write(string.format("$%02X ", memory.read_u8(0x10 + sp*4 + c, "PALRAM")))
  end
  f:write("\n")
end
f:close()

-- Raw binary too
f = io.open(OUT .. "/palram.bin", "wb")
for a = 0, 0x1F do
  f:write(string.char(memory.read_u8(a, "PALRAM")))
end
f:close()

client.screenshot(OUT .. "/r77_nes.png")
print("wrote " .. OUT)
client.exit()

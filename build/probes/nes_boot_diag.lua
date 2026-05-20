-- Screenshot NES every 30 frames during boot to see what's on screen.
local function R(o) return memory.read_u8(o, "WRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local f = io.open("C:/tmp/nes_boot_diag.txt", "w")
f:write("NES boot diag\n")

for stage=1,10 do
  idle(60)
  f:write(string.format("stage %d (frame ~%d): GameMode($12)=$%02X RoomId($EB)=$%02X LinkX($70)=$%02X LinkY($84)=$%02X RAM[0]=$%02X\n",
    stage, stage*60, R(0x12), R(0xEB), R(0x70), R(0x84), R(0x00)))
  client.screenshot(string.format("C:/tmp/nes_boot_%02d.png", stage))
end

f:write("Tap Start now\n")
for s=1,5 do
  joypad.set({Start=true}, 1)
  emu.frameadvance()
  joypad.set({}, 1)
  idle(30)
  f:write(string.format("after-Start %d: GameMode($12)=$%02X RoomId=$%02X\n", s, R(0x12), R(0xEB)))
  client.screenshot(string.format("C:/tmp/nes_after_start_%d.png", s))
end

f:close()
client.exit()

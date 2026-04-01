local root = [[C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF]]
local pattern_path = root .. [[\builds\reports\nes_start_bg_pattern.bin]]
local nametable_path = root .. [[\builds\reports\nes_start_bg_nametable.bin]]
local attr_path = root .. [[\builds\reports\nes_start_bg_attr.bin]]
local palram_path = root .. [[\builds\reports\nes_start_bg_palram.bin]]
local report_path = root .. [[\builds\reports\nes_start_bg_dump.txt]]

memory.usememorydomain("System Bus")

local function press(buttons)
  joypad.set(buttons, 1)
  emu.frameadvance()
  joypad.set({}, 1)
  emu.frameadvance()
end

local function write_bytes(path, bytes)
  local f = io.open(path, "wb")
  if not f then
    return false
  end
  for i = 1, #bytes do
    f:write(string.char(bytes[i]))
  end
  f:close()
  return true
end

local function write_report(lines)
  local f = io.open(report_path, "w")
  if not f then
    return
  end
  for _, line in ipairs(lines) do
    f:write(line, "\n")
  end
  f:close()
end

for _ = 1, 240 do
  emu.frameadvance()
end

press({ Start = true })
for _ = 1, 180 do
  emu.frameadvance()
end

press({ Start = true })
for _ = 1, 1500 do
  emu.frameadvance()
end

local room_id = memory.read_u8(0x00EB)
local world_flags_lo = memory.read_u8(0x0065)
local world_flags_hi = memory.read_u8(0x0066)
local world_flags_addr = world_flags_lo + world_flags_hi * 0x100
local room_flags = memory.read_u8(world_flags_addr + room_id)
local ppu_ctrl = memory.read_u8(0x00FF)
local bg_pattern_base = 0
if (ppu_ctrl & 0x10) ~= 0 then
  bg_pattern_base = 0x1000
end

memory.usememorydomain("CHR")

local pattern = {}
for addr = bg_pattern_base, bg_pattern_base + 0x0FFF do
  pattern[#pattern + 1] = memory.read_u8(addr)
end

memory.usememorydomain("CIRAM (nametables)")
local nametable = {}
for addr = 0x0000, 0x03BF do
  nametable[#nametable + 1] = memory.read_u8(addr)
end

local attr = {}
for addr = 0x03C0, 0x03FF do
  attr[#attr + 1] = memory.read_u8(addr)
end

memory.usememorydomain("PALRAM")
local palram = {}
for addr = 0x00, 0x1F do
  palram[#palram + 1] = memory.read_u8(addr)
end

write_bytes(pattern_path, pattern)
write_bytes(nametable_path, nametable)
write_bytes(attr_path, attr)
write_bytes(palram_path, palram)
memory.usememorydomain("System Bus")
write_report({
  string.format("Frame: %d", emu.framecount()),
  string.format("RoomId: $%02X", room_id),
  string.format("CurPpuControl_2000: $%02X", ppu_ctrl),
  string.format("BgPatternBase: $%04X", bg_pattern_base),
  string.format("WorldFlagsAddr: $%04X", world_flags_addr),
  string.format("RoomFlags[$%02X]: $%02X", room_id, room_flags),
  "Pattern: " .. pattern_path,
  "Nametable: " .. nametable_path,
  "Attr: " .. attr_path,
  "Palram: " .. palram_path,
})

client.exit()

-- NES live tracker. Boots via registration dance (known-working).
-- Dumps slot 1 + Link state per frame to C:/tmp/track_nes.log.
-- User runs ROM, can walk anywhere. Probe captures whatever happens.
local function R(o) return memory.read_u8(o, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

-- Boot dance (matches working nes_z1_compare.lua).
idle(120); tap("Start"); idle(30); tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)

local f = io.open("C:/tmp/track_nes.log", "w")
f:write("# NES live tracker\n")
f:write("# frame | LinkX/Y/dir/HP | room/mode/fc | enemy slots\n")

local frame_count = 0
local last_room = 0xFF

while true do
  frame_count = frame_count + 1
  local link_x = R(0x0070)
  local link_y = R(0x0084)
  local link_d = R(0x0098)
  local link_st = R(0x00AC)
  local room = R(0x00EB)
  local mode = R(0x0012)
  local fc = R(0x0015)

  if room ~= last_room then
    f:write(string.format("\n## ROOM CHANGE $%02X -> $%02X at frame %d\n", last_room, room, frame_count))
    last_room = room
  end

  local slot_str = ""
  local n = 0
  for s=1,11 do
    local t = R(0x034F+s)
    if t ~= 0 then
      n = n + 1
      slot_str = slot_str .. string.format(" s%d:t$%02X X$%02X Y$%02X d$%02X qspd$%02X frac$%02X grid$%02X mvTm$%02X meta$%02X shTm$%02X wTSh$%02X hit$%02X inDir$%02X",
        s, t,
        R(0x0070+s), R(0x0084+s), R(0x0098+s),
        R(0x03BC+s), R(0x03A8+s), R(0x0394+s),
        R(0x0028+s), R(0x0405+s),
        R(0x0451+s), R(0x0412+s), R(0x04F0+s),
        R(0x03F8+s))
    end
  end

  f:write(string.format("f%d | Lx$%02X y$%02X d$%02X st$%02X | room$%02X mode$%02X fc$%02X | n=%d%s\n",
    frame_count, link_x, link_y, link_d, link_st, room, mode, fc, n, slot_str))

  if frame_count % 30 == 0 then f:flush() end

  gui.text(2, 2, string.format("NES f=%d room=$%02X mode=$%02X", frame_count, room, mode))
  gui.text(2, 12, string.format("L x=$%02X y=$%02X d=$%02X", link_x, link_y, link_d))
  gui.text(2, 22, string.format("enemies=%d", n))

  emu.frameadvance()
end

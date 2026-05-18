-- track_all.lua — continuous full-state tracker. User plays normally,
-- probe logs every frame to C:/tmp/track_all.log + draws live overlay.
-- No joypad grab. Run until BizHawk closed; log truncated each launch.

local R = function(o) return memory.read_u8(o, "68K RAM") end
local R16 = function(o) return memory.read_u16_be(o, "68K RAM") end

local LOG_PATH = "C:/tmp/track_all.log"
local f = io.open(LOG_PATH, "w")
if not f then
  print("FAILED to open " .. LOG_PATH)
  return
end
f:write("# track_all.lua started\n")
f:write("# Format: frame | LinkX/Y/dir/state/anim/HP/stun | room/scene/mode | enemy_slots\n")

local frame_count = 0
local last_room = 0xFF

while true do
  frame_count = frame_count + 1

  local link_x   = R(0x8070)
  local link_y   = R(0x8084)
  local link_dir = R(0x8098)
  local link_st  = R(0x80AC)
  local link_an  = R(0x83B0)
  local link_hp  = R(0x86B0)   -- HeartValue
  local link_max = R(0x86B4)   -- MaxHearts
  local link_stn = R(0x803D)   -- StunTimer
  local link_inv = R(0x84F0)   -- InvincibilityTimer
  local link_shv = R(0x80D3)   -- ShoveDistance

  local room    = R(0x7205)
  local scene   = R(0x07EE)    -- scene sentinel slot if any
  local mode    = R(0x8012)    -- GameMode
  local fcnt    = R(0x8015)    -- FrameCounter

  local rupees  = R(0x86BE)
  local bombs   = R(0x86B0)    -- already heart, fix later
  local keys    = R(0x86BF)

  -- Enemy slot summary
  local slot_str = ""
  local active = 0
  for s=1,11 do
    local t = R(0x834F + s)
    if t ~= 0 then
      active = active + 1
      local meta = R(0x8405 + s)
      local tm   = R(0x8028 + s)
      local st   = R(0x80AC + s)
      slot_str = slot_str .. string.format(" s%d:t$%02X X$%02X Y$%02X d$%02X qspd$%02X frac$%02X grid$%02X mvTm$%02X meta$%02X shTm$%02X wTSh$%02X hit$%02X inDir$%02X",
        s, t,
        R(0x8070+s), R(0x8084+s), R(0x8098+s),
        R(0x83BC+s), R(0x83A8+s), R(0x8394+s),
        R(0x8028+s), R(0x8405+s),
        R(0x8451+s), R(0x8412+s), R(0x84F0+s),
        R(0x83F8+s))
    end
  end

  -- Detect room change
  if room ~= last_room then
    f:write(string.format("\n## ROOM CHANGE %02X -> %02X at frame %d\n", last_room, room, frame_count))
    last_room = room
  end

  f:write(string.format("f%d | Lx$%02X y$%02X d$%02X st$%02X anim$%02X HP$%02X/$%02X stun$%02X inv$%02X | room$%02X mode$%02X fc$%02X | n=%d%s\n",
    frame_count, link_x, link_y, link_dir, link_st, link_an, link_hp, link_max, link_stn, link_inv,
    room, mode, fcnt, active, slot_str))

  -- Flush every 60 frames so log is live
  if frame_count % 60 == 0 then f:flush() end

  -- Live overlay (top-left of screen)
  gui.text(2, 2,  string.format("f=%d room=$%02X mode=$%02X", frame_count, room, mode))
  gui.text(2, 12, string.format("L x=$%02X y=$%02X d=$%02X HP=%d stun=$%02X", link_x, link_y, link_dir, link_hp, link_stn))
  gui.text(2, 22, string.format("enemies=%d", active))
  local oy = 32
  for s=1,11 do
    local t = R(0x834F + s)
    if t ~= 0 then
      gui.text(2, oy, string.format("s%d t$%02X x$%02X y$%02X m$%02X", s, t, R(0x8070+s), R(0x8084+s), R(0x8405+s)))
      oy = oy + 10
    end
  end

  emu.frameadvance()
end

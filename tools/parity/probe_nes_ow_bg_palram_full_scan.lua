-- Scan all 128 NES OW rooms, capture full BG PALRAM ($3F00..$3F0F).
-- Force-warp each room via RAM write to $EB + GameMode $06 trigger.
-- Wait for InitMode5Play to patch palette, dump 16 bytes.
-- Emit C array to replace src/game/world/ow_bg_palram_table.c body.
local function R(o) return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function PAL(o) return memory.read_u8(o, "PALRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, hold, settle)
  for _=1,hold do joypad.set({[b]=true}, 1); emu.frameadvance() end
  joypad.set({}, 1); for _=1,settle do emu.frameadvance() end
end

-- Boot to gameplay (same flow as probe_nes_ow_subpal3_scan.lua)
idle(360); press("Start", 4, 60)
press("Down",4,20); press("Down",4,20); press("Down",4,20)
press("Start",4,60); press("Start",4,60)
for _=1,5 do press("Down",4,8) end
for _=1,5 do press("Right",4,8) end
press("Start",4,60)
for _=1,5 do press("Up",4,12) end
press("Start",4,180); idle(180)

local f = io.open("C:/tmp/nes_ow_bg_palram_full.txt","w")
f:write("/* Auto-captured live NES BG PALRAM $3F00..$3F0F per OW room.\n")
f:write(" * Probe: tools/parity/probe_nes_ow_bg_palram_full_scan.lua. */\n")
f:write('#include "ow_bg_palram_table.h"\n\n')
f:write("const unsigned char k_ow_bg_palram_per_room[128][16] = {\n")

for room = 0, 127 do
  -- Force OW + room id + reload
  W(0x0010, 0x00)
  W(0x00EB, room)
  W(0x0012, 0x06)  -- LoadLevel -> InitEnterRoom -> Play
  idle(120)        -- transition
  idle(60)         -- patch settle

  f:write(string.format("    [0x%02X] = { ", room))
  for byte = 0, 15 do
    f:write(string.format("0x%02X", PAL(byte)))
    if byte < 15 then f:write(", ") end
  end
  f:write(" },\n")
  f:flush()
end

f:write("};\n")
f:close()
client.exit()

-- link_sprite_audit.lua — full Link visual audit.
-- Dumps CRAM (palettes), SAT (sprite table), and PNG at multiple
-- moments to verify Link tile/palette/size.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\link_sprite.txt"
local f = io.open(OUT, "w")

local function dump_cram(label)
  f:write(string.format("\n-- CRAM @ %s --\n", label))
  for pal=0,3 do
    f:write(string.format("PAL%d:", pal))
    for c=0,15 do
      f:write(string.format(" %04X", memory.read_u16_be(pal*32 + c*2, "CRAM")))
    end
    f:write("\n")
  end
end

local function dump_sat(label, count)
  f:write(string.format("\n-- SAT @ %s (first %d slots) --\n", label, count))
  -- SGDK SAT typically at VRAM $B400 in default layout, but this code
  -- moved it to $F400 (init_video).
  local sat = 0xF400
  for i=0,count-1 do
    local y    = memory.read_u16_be(sat + i*8 + 0, "VRAM")
    local sz   = memory.read_u8 (sat + i*8 + 2, "VRAM")
    local link = memory.read_u8 (sat + i*8 + 3, "VRAM")
    local attr = memory.read_u16_be(sat + i*8 + 4, "VRAM")
    local x    = memory.read_u16_be(sat + i*8 + 6, "VRAM")
    f:write(string.format("  slot %02d: Y=%04X sz=%02X link=%02X attr=%04X X=%04X (tile=%d pal=%d)\n",
      i, y, sz, link, attr, x, attr & 0x7FF, (attr >> 13) & 0x3))
  end
end

idle(60)
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
memory.write_u8(0x73FA, 0x01, "68K RAM")

for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(60)

f:write(string.format("=== POST-ENTRY ===\nscene=%d rm=$%02X X=$%02X Y=$%02X face=%d\n",
  R(0x7204), R(0x7205), R(0x7207), R(0x7209), R(0x720A)))
dump_cram("post-entry")
dump_sat("post-entry", 16)
client.screenshot("C:\\tmp\\link_audit_01_entry.png")

-- Walk DOWN a bit so Link is in idle-down-facing pose
for i=1,30 do joypad.set({Down=true}, 1); emu.frameadvance() end
idle(15)
f:write(string.format("\n=== POST-DOWN ===\nface=%d (0=down 1=up 2=left 3=right)\n", R(0x720A)))
dump_sat("post-down", 8)
client.screenshot("C:\\tmp\\link_audit_02_facing_down.png")

-- Face right
for i=1,30 do joypad.set({Right=true}, 1); emu.frameadvance() end
idle(15)
f:write(string.format("\n=== POST-RIGHT ===\nface=%d\n", R(0x720A)))
dump_sat("post-right", 8)
client.screenshot("C:\\tmp\\link_audit_03_facing_right.png")

-- Face left
for i=1,30 do joypad.set({Left=true}, 1); emu.frameadvance() end
idle(15)
f:write(string.format("\n=== POST-LEFT ===\nface=%d\n", R(0x720A)))
dump_sat("post-left", 8)
client.screenshot("C:\\tmp\\link_audit_04_facing_left.png")

-- Face up (back to north, also triggers scroll if at edge)
for i=1,30 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(15)
f:write(string.format("\n=== POST-UP ===\nface=%d\n", R(0x720A)))
dump_sat("post-up", 8)
client.screenshot("C:\\tmp\\link_audit_05_facing_up.png")

-- Try sword (B button)
for i=1,5 do joypad.set({B=true}, 1); emu.frameadvance() end
idle(10)
f:write(string.format("\n=== POST-SWORD ===\nface=%d\n", R(0x720A)))
dump_sat("post-sword", 12)
client.screenshot("C:\\tmp\\link_audit_06_sword.png")

f:write("\nDONE\n")
f:close()
gui.text(8, 8, "audit done")
idle(20)
client.exit()
